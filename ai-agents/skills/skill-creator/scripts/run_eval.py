#!/usr/bin/env python3
"""Run isolated Pi skill and baseline evaluations."""

from __future__ import annotations

import argparse
import json
import subprocess
import time
from pathlib import Path
from typing import Any


def final_text(events: list[dict[str, Any]]) -> str:
    for event in reversed(events):
        if event.get("type") != "message_end":
            continue
        message = event.get("message", {})
        if message.get("role") != "assistant":
            continue
        return "".join(
            item.get("text", "")
            for item in message.get("content", [])
            if item.get("type") == "text"
        )
    return ""


def usage(events: list[dict[str, Any]]) -> dict[str, Any]:
    for event in reversed(events):
        if event.get("type") != "message_end":
            continue
        message = event.get("message", {})
        if message.get("role") == "assistant":
            return message.get("usage", {})
    return {}


def parse_events(stdout: str) -> list[dict[str, Any]]:
    events = []
    for line in stdout.splitlines():
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return events


def run_case(
    *,
    prompt: str,
    cwd: Path,
    skill: Path | None,
    model: str,
    thinking: str,
    timeout: int,
    output: Path,
) -> None:
    command = [
        "pi",
        "--mode",
        "json",
        "-p",
        "--no-session",
        "--no-context-files",
        "--no-skills",
        "--model",
        f"{model}:{thinking}",
    ]
    task = prompt
    if skill:
        command.extend(["--skill", str(skill)])
        task = f"Read and apply the skill at {skill}/SKILL.md, then execute this task:\n\n{prompt}"

    started = time.monotonic()
    result = subprocess.run(
        [*command, task],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    elapsed = time.monotonic() - started
    events = parse_events(result.stdout)

    output.mkdir(parents=True, exist_ok=True)
    (output / "transcript.jsonl").write_text(result.stdout)
    (output / "stderr.txt").write_text(result.stderr)
    (output / "final.md").write_text(final_text(events))
    (output / "meta.json").write_text(
        json.dumps(
            {
                "command": command,
                "cwd": str(cwd),
                "duration_seconds": round(elapsed, 3),
                "returncode": result.returncode,
                "usage": usage(events),
            },
            indent=2,
        )
        + "\n"
    )
    if result.returncode != 0:
        raise RuntimeError(f"Pi exited {result.returncode}; see {output / 'stderr.txt'}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skill", type=Path, required=True)
    parser.add_argument("--baseline-skill", type=Path)
    parser.add_argument("--evals", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--thinking", default="high")
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()

    for skill in (args.skill, args.baseline_skill):
        if skill and not (skill / "SKILL.md").is_file():
            parser.error(f"missing {skill / 'SKILL.md'}")

    corpus = json.loads(args.evals.read_text())
    evals = corpus.get("evals", [])
    if not evals:
        parser.error("eval corpus has no evals")

    args.output.mkdir(parents=True, exist_ok=True)
    for case in evals:
        case_id = str(case["id"])
        prompt = str(case["prompt"])
        cwd = Path(case.get("cwd", ".")).expanduser().resolve()
        if not cwd.is_dir():
            parser.error(f"eval {case_id}: cwd is not a directory: {cwd}")

        run_case(
            prompt=prompt,
            cwd=cwd,
            skill=args.skill.resolve(),
            model=args.model,
            thinking=args.thinking,
            timeout=args.timeout,
            output=args.output / case_id / "with-skill",
        )
        run_case(
            prompt=prompt,
            cwd=cwd,
            skill=args.baseline_skill.resolve() if args.baseline_skill else None,
            model=args.model,
            thinking=args.thinking,
            timeout=args.timeout,
            output=args.output / case_id / "baseline",
        )


if __name__ == "__main__":
    main()
