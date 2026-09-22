"""Read-only, metadata-first search of local agent JSONL transcripts."""

import argparse
import json
import re
import subprocess
import sys
from collections import Counter, deque
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Bounds keep a corrupt record or broad query from flooding memory/context.
MAX_LINE_BYTES = 16 * 1024 * 1024
MAX_HITS = 20
ROOTS = {
    "pi": (".pi/agent/sessions", ".pi/agent-lean/sessions"),
    "codex": (".codex/sessions", ".codex/archived_sessions"),
    "claude": (".claude/projects",),
}


def timestamp(value):
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000, timezone.utc)
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed.replace(tzinfo=parsed.tzinfo or timezone.utc).astimezone(timezone.utc)


def records(path):
    with path.open("rb") as source:
        number = 0
        while raw := source.readline(MAX_LINE_BYTES + 1):
            number += 1
            if len(raw) > MAX_LINE_BYTES:
                while raw and not raw.endswith(b"\n"):
                    raw = source.readline(MAX_LINE_BYTES + 1)
                print(
                    f"WARNING: skipped oversized record {path}:{number}",
                    file=sys.stderr,
                )
                continue
            try:
                entry = json.loads(raw)
                if not isinstance(entry, dict):
                    raise TypeError("record is not an object")
            except (ValueError, TypeError, UnicodeDecodeError):
                print(
                    f"WARNING: skipped malformed record {path}:{number}",
                    file=sys.stderr,
                )
                continue
            yield number, entry


def text_content(content):
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    return "\n".join(
        block.get("text", "")
        for block in content
        if isinstance(block, dict)
        and block.get("type") in {"text", "input_text", "output_text"}
    )


def messages(entry, tools=False, summaries=False):
    kind = entry.get("type")
    payload = entry.get("payload", {})
    if summaries and kind in {"compaction", "branch_summary", "compacted"}:
        yield "summary", entry.get("summary", payload.get("message", ""))
    if kind == "response_item":
        if tools and payload.get("type") in {"function_call", "custom_tool_call"}:
            yield "tool_call", json.dumps(payload, ensure_ascii=False)
        if tools and payload.get("type") in {
            "function_call_output",
            "custom_tool_call_output",
        }:
            yield "tool_result", text_content(payload.get("output", ""))
        message = payload if payload.get("type") == "message" else {}
    elif kind in {"message", "user", "assistant"}:
        message = entry.get("message", {})
    else:
        return  # Codex event_msg mirrors response_item; do not count both.
    role = message.get("role")
    if role in {"user", "assistant"}:
        text = text_content(message.get("content"))
        if text:
            yield role, text
    if not tools:
        return
    if role == "toolResult":
        yield "tool_result", text_content(message.get("content"))
    if role == "bashExecution":
        yield "tool_result", message.get("output", "")
    content = message.get("content", [])
    for block in content if isinstance(content, list) else []:
        if block.get("type") in {"toolCall", "tool_use"}:
            yield "tool_call", json.dumps(block, ensure_ascii=False)
        if block.get("type") == "tool_result":
            yield "tool_result", text_content(block.get("content"))


def candidates(root, terms):
    patterns = {variant for term in terms for variant in (term, json.dumps(term)[1:-1])}
    command = ["rg", "--hidden", "--no-ignore", "-l", "-0", "-i", "-F", "-g", "*.jsonl"]
    for pattern in sorted(patterns):
        command.extend(["-e", pattern])
    result = subprocess.run(
        command + [str(root)], capture_output=True, timeout=60, check=False
    )
    if result.returncode not in {0, 1}:
        raise RuntimeError(
            f"rg failed for {root}: {result.stderr.decode(errors='replace')}"
        )
    return [Path(part.decode()) for part in result.stdout.split(b"\0") if part]


def inspect_session(path, args):
    result = {"path": str(path), "session_id": path.stem, "cwd": None}
    roles, hits, latest = Counter(), deque(maxlen=MAX_HITS), None
    count = 0
    terms = [term.casefold() for term in args.term]
    for number, entry in records(path):
        kind = entry.get("type")
        metadata = entry.get("payload", {}) if kind == "session_meta" else entry
        if kind in {"session", "session_meta"}:
            result["session_id"] = metadata.get(
                "id", metadata.get("session_id", path.stem)
            )
        elif entry.get("sessionId"):
            result["session_id"] = entry["sessionId"]
        result["cwd"] = metadata.get("cwd", result["cwd"])
        when = timestamp(entry.get("timestamp"))
        if when is None or not args.since <= when < args.until:
            continue
        for role, text in messages(entry, args.include_tools, args.include_summaries):
            if not any(term in text.casefold() for term in terms):
                continue
            count += 1
            roles[role] += 1
            latest = max(latest, when) if latest else when
            hits.append({"line": number, "role": role, "timestamp": when.isoformat()})
    if not count:
        return None
    return result | {
        "latest_match": latest.isoformat(),
        "match_count": count,
        "roles": dict(roles),
        "hits": list(hits),
        "hits_truncated": count > len(hits),
    }


def search(args):
    results, roots, scanned = [], [], 0
    for harness in args.harness or ROOTS:
        for relative in ROOTS[harness]:
            root = args.home / relative
            if not root.is_dir():
                continue
            roots.append(str(root))
            for path in candidates(root, args.term):
                scanned += 1
                result = inspect_session(path, args)
                if result:
                    results.append({"harness": harness} | result)
    results.sort(key=lambda item: item["latest_match"], reverse=True)
    for result in results[: args.limit]:
        print(json.dumps(result, ensure_ascii=False))
    print(
        json.dumps(
            {
                "roots": roots,
                "candidate_files": scanned,
                "matching_sessions": len(results),
                "shown": min(len(results), args.limit),
                "since": args.since.isoformat(),
                "until_exclusive": args.until.isoformat(),
            }
        ),
        file=sys.stderr,
    )


def redact(text):
    # Best effort, not a guarantee: inspect excerpts before quoting or publishing.
    text = re.sub(
        r"-----BEGIN [^-]*PRIVATE KEY-----.*?(?:-----END [^-]*PRIVATE KEY-----|$)",
        "[REDACTED PRIVATE KEY]",
        text,
        flags=re.DOTALL,
    )
    text = re.sub(
        r"\b(?:sk-|ghp_|github_pat_|xox[baprs]-)[A-Za-z0-9_-]+",
        "[REDACTED TOKEN]",
        text,
    )
    text = re.sub(r"(?i)(bearer\s+)\S+", r"\1[REDACTED]", text)
    return re.sub(
        r"""(?i)(["']?(?:api[_-]?key|password|secret|access[_-]?token)["']?\s*[:=]\s*)("[^"]*"|'[^']*'|[^\s,}]+)""",
        r"\1[REDACTED]",
        text,
    )


def show(args):
    shown = 0
    for number, entry in records(args.path):
        if number < args.start:
            continue
        if number > args.end:
            break
        for role, text in messages(entry, args.include_tools, args.include_summaries):
            if shown >= args.limit:
                print(
                    f"WARNING: excerpt limit reached at line {number}; narrow the range",
                    file=sys.stderr,
                )
                return
            shown += 1
            safe = redact(text)
            result = {
                "line": number,
                "timestamp": entry.get("timestamp"),
                "role": role,
                "entry_id": entry.get("id", entry.get("uuid")),
                "parent_id": entry.get("parentId"),
                "text": safe[: args.chars],
                "truncated": len(safe) > args.chars,
            }
            print(json.dumps(result, ensure_ascii=False))


def cli():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    finder = commands.add_parser(
        "search", help="list matching sessions, without message text"
    )
    finder.add_argument(
        "--term",
        action="append",
        required=True,
        help="literal, case-insensitive OR term",
    )
    finder.add_argument(
        "--since",
        default=(datetime.now(timezone.utc) - timedelta(days=14)).date().isoformat(),
    )
    finder.add_argument(
        "--until",
        default=(datetime.now(timezone.utc) + timedelta(days=1)).date().isoformat(),
    )
    finder.add_argument("--harness", action="append", choices=ROOTS)
    finder.add_argument(
        "--home",
        type=Path,
        default=Path.home(),
        help="alternate transcript home for fixtures",
    )
    finder.add_argument("--limit", type=int, default=20)
    reader = commands.add_parser("show", help="read a bounded JSONL line range")
    reader.add_argument("path", type=Path)
    reader.add_argument("--start", type=int, required=True)
    reader.add_argument("--end", type=int, required=True)
    reader.add_argument("--chars", type=int, default=1600)
    reader.add_argument("--limit", type=int, default=20)
    for command in (finder, reader):
        command.add_argument("--include-tools", action="store_true")
        command.add_argument("--include-summaries", action="store_true")
    args = parser.parse_args()
    if args.command == "search":
        args.since, args.until = timestamp(args.since), timestamp(args.until)
        if not args.since or not args.until or args.since >= args.until:
            parser.error("require valid ISO dates/times with since < until (exclusive)")
        if not 1 <= args.limit <= 100 or any(
            not term.strip() or "\n" in term for term in args.term
        ):
            parser.error("require nonempty single-line terms and limit 1..100")
        search(args)
    else:
        if (
            not 1 <= args.start <= args.end
            or args.end - args.start >= 100
            or not 1 <= args.chars <= 8000
            or not 1 <= args.limit <= 100
        ):
            parser.error(
                "require a positive range of at most 100 lines, chars 1..8000, and limit 1..100"
            )
        show(args)


if __name__ == "__main__":
    try:
        cli()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
