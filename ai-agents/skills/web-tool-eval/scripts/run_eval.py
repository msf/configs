#!/usr/bin/env python3
import argparse
from datetime import datetime, timezone
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

NETWORK_COMMAND = re.compile(
    r"https?://|\bcurl\b|\bwget\b|\bgh\s+(?:api|issue|pr|search|repo|release)\b|\b(?:requests|urllib|httpx)\b",
    re.I,
)


def result_text(result):
    if isinstance(result, str):
        return result
    if not isinstance(result, dict):
        return json.dumps(result, ensure_ascii=False)
    parts = [
        item["text"]
        for item in result.get("content", [])
        if isinstance(item, dict) and isinstance(item.get("text"), str)
    ]
    return "\n".join(parts) if parts else json.dumps(result, ensure_ascii=False)


def extract_summary(raw_path, case, duration, returncode, timed_out):
    calls = []
    calls_by_id = {}
    final_answer = ""
    usage = {"input": 0, "output": 0, "cacheRead": 0, "reasoning": 0, "cost": 0.0}

    if raw_path.exists():
        for line in raw_path.open(errors="replace"):
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            if event.get("type") == "tool_execution_start":
                tool = event.get("toolName", "")
                arguments = event.get("args", {})
                command = arguments.get("command", "") if isinstance(arguments, dict) else ""
                network_attempt = tool == "browser_read_url" or (
                    tool == "bash" and bool(NETWORK_COMMAND.search(command))
                )
                call = {
                    "order": len(calls) + 1,
                    "id": event.get("toolCallId"),
                    "tool": tool,
                    "args": arguments,
                    "network_attempt": network_attempt,
                }
                calls.append(call)
                calls_by_id[call["id"]] = call
                continue

            if event.get("type") == "tool_execution_end":
                call = calls_by_id.get(event.get("toolCallId"))
                if call is not None:
                    text = result_text(event.get("result"))
                    call["is_error"] = bool(event.get("isError"))
                    call["result_excerpt"] = text[:2500]
                    status = re.search(r"(?:^|\n)Status:\s*(\d+)", text)
                    if status:
                        call["http_status"] = int(status.group(1))
                continue

            if event.get("type") != "message_end":
                continue
            message = event.get("message", {})
            if message.get("role") != "assistant":
                continue
            texts = [
                part.get("text", "")
                for part in message.get("content", [])
                if part.get("type") == "text"
            ]
            if texts and message.get("stopReason") == "stop":
                final_answer = "\n".join(texts)
            current = message.get("usage", {})
            usage["input"] += current.get("input", 0) or 0
            usage["output"] += current.get("output", 0) or 0
            usage["cacheRead"] += current.get("cacheRead", 0) or 0
            usage["reasoning"] += current.get("reasoning", 0) or 0
            usage["cost"] += (current.get("cost", {}) or {}).get("total", 0) or 0

    network_orders = [call["order"] for call in calls if call["network_attempt"]]
    skill_orders = [
        call["order"]
        for call in calls
        if call["tool"] == "read" and "web-tool-routing/SKILL.md" in str(call.get("args", {}))
    ]

    return {
        "case_id": case["id"],
        "category": case["category"],
        "prompt": case["prompt"],
        "expectations": case["expectations"],
        "max_network_attempts": case["max_network_attempts"],
        "returncode": returncode,
        "timed_out": timed_out,
        "duration_seconds": round(duration, 3),
        "network_attempt_count": len(network_orders),
        "skill_read": bool(skill_orders),
        "skill_read_before_first_network": bool(skill_orders)
        and (not network_orders or min(skill_orders) < min(network_orders)),
        "tool_calls": calls,
        "final_answer": final_answer,
        "usage": usage,
    }


def default_output_dir(model):
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    model_slug = re.sub(r"[^a-zA-Z0-9._-]+", "-", model).strip("-")
    return state_home / "pi/web-tool-evals" / f"{timestamp}-{model_slug}"


def main():
    parser = argparse.ArgumentParser(description="Run isolated web-routing eval cases through Pi")
    parser.add_argument("--eval", required=True, help="Eval JSON path")
    parser.add_argument("--output", help="Artifact directory; defaults under XDG state")
    parser.add_argument("--provider", help="Pi provider; defaults to eval.json executor.provider")
    parser.add_argument("--model", help="Pi model; defaults to eval.json executor.model")
    parser.add_argument("--thinking", help="Pi thinking level; defaults to eval.json executor.thinking")
    parser.add_argument("--timeout", type=int, default=240, help="Timeout per case in seconds")
    parser.add_argument("--case", action="append", dest="cases", help="Run only this case ID; repeatable")
    args = parser.parse_args()

    eval_path = Path(args.eval).resolve()
    spec = json.loads(eval_path.read_text())
    provider = args.provider or spec["executor"]["provider"]
    model = args.model or spec["executor"]["model"]
    thinking = args.thinking or spec["executor"]["thinking"]
    output = Path(args.output).expanduser().resolve() if args.output else default_output_dir(model)

    known_ids = {case["id"] for case in spec["cases"]}
    unknown_ids = set(args.cases or []) - known_ids
    if unknown_ids:
        parser.error(f"unknown case IDs: {', '.join(sorted(unknown_ids))}")
    selected = [case for case in spec["cases"] if not args.cases or case["id"] in args.cases]

    os.umask(0o077)
    output.mkdir(parents=True, exist_ok=False)
    shutil.copy2(eval_path, output / "eval.json")
    (output / "run-metadata.json").write_text(
        json.dumps(
            {
                "started_at": datetime.now(timezone.utc).isoformat(),
                "provider": provider,
                "model": model,
                "thinking": thinking,
                "timeout_seconds": args.timeout,
                "case_ids": [case["id"] for case in selected],
            },
            indent=2,
        )
        + "\n"
    )

    env = os.environ.copy()
    env.pop("PI_SESSION_FILE", None)
    env.pop("PI_SESSION_ID", None)
    safety = (
        "Evaluation safety: perform only read-only retrieval. Do not create, edit, or delete files "
        "and do not mutate remote state. Answer the user request normally without discussing the evaluation."
    )

    for index, case in enumerate(selected, 1):
        case_dir = output / "runs" / case["id"]
        case_dir.mkdir(parents=True)
        raw_path = case_dir / "run.jsonl"
        stderr_path = case_dir / "stderr.log"
        summary_path = case_dir / "summary.json"
        command = [
            "pi",
            "--mode",
            "json",
            "--no-session",
            "--no-approve",
            "--provider",
            provider,
            "--model",
            model,
            "--thinking",
            thinking,
            "--tools",
            "read,bash,browser_read_url",
            "--append-system-prompt",
            safety,
            case["prompt"],
        ]

        print(f"[{index}/{len(selected)}] {case['id']}", flush=True)
        started = time.monotonic()
        returncode = -1
        timed_out = False
        with raw_path.open("w") as stdout, stderr_path.open("w") as stderr:
            try:
                completed = subprocess.run(
                    command,
                    cwd=Path.home(),
                    env=env,
                    stdout=stdout,
                    stderr=stderr,
                    text=True,
                    timeout=args.timeout,
                    check=False,
                )
                returncode = completed.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
        duration = time.monotonic() - started
        summary = extract_summary(raw_path, case, duration, returncode, timed_out)
        summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
        print(
            f"  rc={returncode} timeout={timed_out} network={summary['network_attempt_count']} "
            f"skill={summary['skill_read_before_first_network']} duration={duration:.1f}s",
            flush=True,
        )

    print(f"Artifacts: {output}")


if __name__ == "__main__":
    main()
