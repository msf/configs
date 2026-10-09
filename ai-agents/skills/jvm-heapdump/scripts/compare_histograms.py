#!/usr/bin/env python3
"""Compare two jcmd GC.class_histogram files."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

LINE = re.compile(r"\s*\d+:\s+(\d+)\s+(\d+)\s+(.*\S)\s*$")


def parse(path: Path) -> dict[str, tuple[int, int]]:
    classes: dict[str, tuple[int, int]] = {}
    for line in path.read_text(errors="replace").splitlines():
        match = LINE.fullmatch(line)
        if match:
            classes[match.group(3)] = (int(match.group(1)), int(match.group(2)))
    if not classes:
        raise ValueError(f"no histogram rows found in {path}")
    return classes


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("earlier", type=Path)
    parser.add_argument("later", type=Path)
    parser.add_argument("--top", type=int, default=40)
    args = parser.parse_args()
    if args.top < 1:
        parser.error("--top must be positive")

    earlier = parse(args.earlier)
    later = parse(args.later)
    rows = []
    for class_name in earlier.keys() | later.keys():
        old_instances, old_bytes = earlier.get(class_name, (0, 0))
        new_instances, new_bytes = later.get(class_name, (0, 0))
        rows.append(
            (
                new_bytes - old_bytes,
                new_instances - old_instances,
                class_name,
                old_bytes,
                new_bytes,
            )
        )
    rows.sort(reverse=True)

    print(f"earlier={args.earlier}\nlater={args.later}\n")
    print(f"{'dBytes':>14} {'dInstances':>13} {'old_MB':>10} {'new_MB':>10}  class")
    print("-" * 90)
    for byte_delta, instance_delta, class_name, old_bytes, new_bytes in rows[: args.top]:
        print(
            f"{byte_delta:>14} {instance_delta:>13} "
            f"{old_bytes / 1e6:>10.1f} {new_bytes / 1e6:>10.1f}  {class_name}"
        )

    old_total = sum(value[1] for value in earlier.values())
    new_total = sum(value[1] for value in later.values())
    print("-" * 90)
    print(
        f"TOTAL live bytes: old={old_total / 1e9:.2f} GB "
        f"new={new_total / 1e9:.2f} GB delta={(new_total - old_total) / 1e9:+.2f} GB"
    )


if __name__ == "__main__":
    main()
