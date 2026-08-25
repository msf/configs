#!/usr/bin/env python3
# /// script
# dependencies = ["pyyaml>=6,<7"]
# ///
"""Audit Pi resource ownership and compatibility without modifying state."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import yaml

THINKING_LEVELS = {"off", "minimal", "low", "medium", "high", "xhigh", "max"}
STALE_PATTERNS = {
    "OpenCode compatibility marker": re.compile(r"compatibility:\s*opencode", re.I),
    "OpenCode skill path": re.compile(r"\.config/opencode/skills"),
    "OpenCode agent path": re.compile(r"\.config/opencode/agents"),
    "OpenCode command path": re.compile(r"\.config/opencode/commands"),
    "Claude skill path": re.compile(r"\.claude/skills"),
    "Claude CLI evaluator": re.compile(r"\bclaude\s+-p\b"),
    "OpenCode task tool": re.compile(r"\bTask tool\b", re.I),
    "OpenCode todo tool": re.compile(r"\bTodoList\b"),
}
UPSTREAM_PATH_PARTS = (
    "/.config/opencode/",
    "/.claude/",
    "/.cache/dune-sietch/",
    "/dune/ai-first-engineering/",
)


@dataclass
class AuditResult:
    skill_count: int
    agent_count: int
    errors: list[str]
    warnings: list[str]


def parse_frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text(errors="replace")
    match = re.match(r"\A---\n(.*?)\n---(?:\n|\Z)", text, re.S)
    if not match:
        return {}
    parsed = yaml.safe_load(match.group(1))
    if parsed is None:
        return {}
    if not isinstance(parsed, dict):
        raise ValueError("frontmatter must be a mapping")
    return parsed


def recursive_skill_files(root: Path) -> list[Path]:
    if not root.is_dir():
        return []
    files: list[Path] = []
    for current, directories, names in os.walk(root, followlinks=False):
        directories[:] = [
            name for name in directories
            if not (Path(current) / name).is_symlink()
        ]
        if "SKILL.md" in names:
            files.append(Path(current) / "SKILL.md")
    return sorted(files)


def live_skill_files(root: Path, errors: list[str]) -> list[Path]:
    files: list[Path] = []
    if not root.is_dir():
        errors.append(f"missing Pi skills root: {root}")
        return files

    for entry in sorted(root.iterdir()):
        if entry.is_symlink() and not entry.exists():
            errors.append(f"dangling Pi skill symlink: {entry}")
            continue
        if entry.is_file() and entry.suffix == ".md":
            files.append(entry)
        elif entry.is_dir():
            files.extend(recursive_skill_files(entry))
    return files


def is_owned(path: Path, owned_roots: Iterable[Path]) -> bool:
    resolved = path.resolve(strict=False)
    return any(resolved.is_relative_to(root.resolve()) for root in owned_roots)


def scan_tree(
    root: Path,
    owned_roots: list[Path],
) -> tuple[list[tuple[Path, str]], list[str]]:
    stale: list[tuple[Path, str]] = []
    link_errors: list[str] = []
    if not root.exists():
        return stale, link_errors
    if root.is_file():
        try:
            content = root.read_bytes()
        except OSError as error:
            return stale, [f"cannot read resource {root}: {error}"]
        if b"\0" not in content:
            text = content.decode("utf8", errors="replace")
            stale.extend((root, label) for label, pattern in STALE_PATTERNS.items() if pattern.search(text))
        return stale, link_errors

    for current, directories, files in os.walk(root, followlinks=False):
        current_path = Path(current)
        kept_directories = []
        for name in directories:
            path = current_path / name
            if not path.is_symlink():
                kept_directories.append(name)
                continue
            if not path.exists():
                link_errors.append(f"dangling resource symlink: {path}")
            elif not is_owned(path, owned_roots):
                link_errors.append(f"resource symlink points outside owned roots: {path} -> {path.resolve()}")
        directories[:] = kept_directories

        for name in files:
            path = current_path / name
            if path.is_symlink():
                if not path.exists():
                    link_errors.append(f"dangling resource symlink: {path}")
                    continue
                if not is_owned(path, owned_roots):
                    link_errors.append(f"resource symlink points outside owned roots: {path} -> {path.resolve()}")
                    continue
            try:
                content = path.read_bytes()
            except OSError as error:
                link_errors.append(f"cannot read resource {path}: {error}")
                continue
            if b"\0" in content:
                continue
            text = content.decode("utf8", errors="replace")
            for label, pattern in STALE_PATTERNS.items():
                if pattern.search(text):
                    stale.append((path, label))
    return stale, link_errors


def expand_home(value: str, home: Path) -> str:
    return str(home) + value[1:] if value.startswith("~") else value


def strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)


def configured_paths(settings: dict[str, Any], key: str, home: Path) -> list[Path]:
    paths = []
    for value in settings.get(key, []):
        if isinstance(value, str) and not re.match(r"^(npm|git):", value):
            paths.append(Path(expand_home(value, home)).resolve())
    return paths


def available_models() -> set[str]:
    result = subprocess.run(["pi", "--list-models"], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "pi --list-models failed")
    models = set()
    for line in result.stdout.splitlines():
        columns = line.split()
        if len(columns) >= 2 and "/" not in columns[0]:
            models.add(f"{columns[0]}/{columns[1]}")
    return models


def model_id(value: str) -> str:
    parts = value.rsplit(":", 1)
    return parts[0] if len(parts) == 2 and parts[1] in THINKING_LEVELS else value


def manifest_targets(home: Path) -> tuple[dict[str, Path], list[str]]:
    manifest = home / "configs/ai-agents/tools/manifest.txt"
    if not manifest.is_file():
        return {}, [f"missing agent-config manifest: {manifest}"]

    targets: dict[str, Path] = {}
    errors: list[str] = []
    for line_number, raw_line in enumerate(manifest.read_text().splitlines(), 1):
        fields = raw_line.split("#", 1)[0].split()
        if not fields:
            continue
        if len(fields) < 2:
            errors.append(f"invalid manifest line {line_number}: {raw_line}")
            continue
        kind, path, *arguments = fields
        if path in targets:
            errors.append(f"duplicate manifest path: {path}")
            continue
        if kind == "mirror":
            target = home / "configs/ai-agents/home" / path
        elif kind == "pmirror":
            target = home / "configs-private/home" / path
        elif kind == "repo" and len(arguments) == 1:
            target = home / "configs" / arguments[0]
        elif kind == "prepo" and len(arguments) == 1:
            target = home / "configs-private" / arguments[0]
        elif kind == "home" and len(arguments) == 1:
            target = home / arguments[0]
        else:
            errors.append(f"invalid manifest line {line_number}: {raw_line}")
            continue
        targets[path] = target
    return targets, errors


def check_manifest_projection(
    path: Path,
    home: Path,
    targets: dict[str, Path],
    errors: list[str],
) -> None:
    relative = path.relative_to(home).as_posix()
    expected = targets.get(relative)
    if expected is None:
        errors.append(f"Pi resource is not declared in manifest: {path}")
    elif path.is_symlink() and os.readlink(path) != str(expected):
        errors.append(f"Pi resource differs from manifest: {path} -> {os.readlink(path)}; want {expected}")


def check_live_projection(
    live_root: Path,
    owned_roots: list[Path],
    label: str,
    home: Path,
    targets: dict[str, Path],
    errors: list[str],
) -> None:
    if not live_root.is_dir():
        errors.append(f"missing Pi {label} root: {live_root}")
        return
    for entry in sorted(live_root.iterdir()):
        if entry.name.startswith("."):
            continue
        if entry.is_symlink() and not entry.exists():
            errors.append(f"dangling Pi {label} symlink: {entry}")
        elif not entry.is_symlink():
            errors.append(f"unmanaged direct Pi {label} resource: {entry}")
        elif not is_owned(entry, owned_roots):
            errors.append(f"Pi {label} points outside owned roots: {entry} -> {entry.resolve()}")
        check_manifest_projection(entry, home, targets, errors)


def run_audit(
    home: Path,
    *,
    validate: bool,
    model_check: bool,
) -> AuditResult:
    live_root = home / ".pi/agent"
    live_skills = live_root / "skills"
    live_agents = live_root / "agents"
    settings_path = live_root / "settings.json"
    public_root = home / "configs/ai-agents"
    private_root = home / "configs-private"
    owned_roots = [public_root, private_root]
    owned_skill_roots = [public_root / "skills", private_root / "skills"]
    owned_agent_roots = [public_root / "agents/pi", private_root / "agents/pi"]
    owned_prompt_roots = [public_root / "commands", private_root / "commands"]
    owned_extension_roots = [public_root / "tools/extensions", private_root / "tools/extensions"]
    owned_bin_roots = [public_root / "tools/bin", private_root / "tools/bin"]

    errors: list[str] = []
    warnings: list[str] = []
    targets, manifest_errors = manifest_targets(home)
    errors.extend(manifest_errors)
    if not settings_path.is_file():
        errors.append(f"missing Pi settings: {settings_path}")
        settings: dict[str, Any] = {}
    else:
        settings = json.loads(settings_path.read_text())
        if settings_path.is_symlink() and not is_owned(settings_path, owned_roots):
            errors.append(f"Pi settings point outside owned roots: {settings_path} -> {settings_path.resolve()}")
        elif not settings_path.is_symlink():
            errors.append(f"Pi settings are unmanaged: {settings_path}")
        check_manifest_projection(settings_path, home, targets, errors)

    models_path = live_root / "models.json"
    if models_path.exists() or models_path.is_symlink():
        check_manifest_projection(models_path, home, targets, errors)

    for key in ("skills", "prompts", "extensions", "packages"):
        for value in strings(settings.get(key, [])):
            expanded = expand_home(value, home)
            if any(part in expanded for part in UPSTREAM_PATH_PARTS):
                errors.append(f"settings.{key} has upstream live dependency: {value}")

    skill_paths = live_skill_files(live_skills, errors)
    names: dict[str, set[Path]] = defaultdict(set)
    discovery_roots = [home / ".agents/skills", *configured_paths(settings, "skills", home)]
    for root in discovery_roots:
        skill_paths.extend(recursive_skill_files(root))

    seen_skill_paths: set[Path] = set()
    checked_skill_entries: set[Path] = set()
    for skill_file in skill_paths:
        resolved_skill = skill_file.resolve(strict=False)
        if resolved_skill in seen_skill_paths:
            continue
        seen_skill_paths.add(resolved_skill)

        try:
            fields = parse_frontmatter(skill_file)
        except (OSError, yaml.YAMLError, ValueError) as error:
            errors.append(f"invalid frontmatter {skill_file}: {error}")
            continue
        name = fields.get("name")
        description = fields.get("description")
        if not isinstance(name, str) or not name.strip():
            errors.append(f"skill missing scalar name: {skill_file}")
        else:
            names[name].add(resolved_skill)
        if not isinstance(description, str) or not description.strip():
            errors.append(f"skill missing scalar description: {skill_file}")

        if skill_file.is_relative_to(live_skills):
            top_entry = live_skills / skill_file.relative_to(live_skills).parts[0]
            if not top_entry.is_symlink():
                errors.append(f"unmanaged direct Pi skill resource: {top_entry}")
            elif not is_owned(top_entry, owned_skill_roots):
                errors.append(f"Pi skill points outside owned roots: {top_entry} -> {top_entry.resolve()}")
            if top_entry not in checked_skill_entries:
                check_manifest_projection(top_entry, home, targets, errors)
                checked_skill_entries.add(top_entry)

            skill_root = skill_file.resolve() if skill_file.parent == live_skills else skill_file.parent.resolve()
            stale, link_errors = scan_tree(skill_root, owned_skill_roots)
            errors.extend(link_errors)
            if skill_file.parent.name != "pi-skill-import":
                errors.extend(f"{label}: {path}" for path, label in stale)

            if validate and skill_file.name == "SKILL.md":
                result = subprocess.run(
                    ["uvx", "--from", "skills-ref", "agentskills", "validate", str(skill_file.parent)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if result.returncode != 0:
                    detail = (result.stdout + result.stderr).strip().replace("\n", " | ")
                    errors.append(f"invalid skill {skill_file.parent}: {detail}")

    for name, paths in sorted(names.items()):
        if len(paths) > 1:
            errors.append(f"skill name collision {name}: {', '.join(map(str, sorted(paths)))}")

    models: set[str] = set()
    if model_check:
        try:
            models = available_models()
        except RuntimeError as error:
            errors.append(str(error))

    agent_count = 0
    if not live_agents.is_dir():
        errors.append(f"missing Pi agents root: {live_agents}")
    else:
        for agent_file in sorted(live_agents.glob("*.md")):
            agent_count += 1
            if agent_file.is_symlink() and not agent_file.exists():
                errors.append(f"dangling Pi agent symlink: {agent_file}")
                continue
            if not agent_file.is_symlink():
                errors.append(f"unmanaged direct Pi agent: {agent_file}")
            elif not is_owned(agent_file, owned_agent_roots):
                errors.append(f"Pi agent points outside owned roots: {agent_file} -> {agent_file.resolve()}")
            check_manifest_projection(agent_file, home, targets, errors)

            try:
                fields = parse_frontmatter(agent_file)
            except (OSError, yaml.YAMLError, ValueError) as error:
                errors.append(f"invalid agent frontmatter {agent_file}: {error}")
                continue
            for required in ("name", "description"):
                value = fields.get(required)
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"agent missing scalar {required}: {agent_file}")
            tools = fields.get("tools")
            if tools is not None and (not isinstance(tools, str) or not tools.strip()):
                errors.append(f"agent tools must be a comma-separated scalar: {agent_file}")
            configured_model = fields.get("model")
            if configured_model is not None and not isinstance(configured_model, str):
                errors.append(f"agent model must be a scalar: {agent_file}")
            elif configured_model and models and model_id(configured_model) not in models:
                errors.append(f"agent model unavailable: {agent_file}: {configured_model}")

    for label, roots in (
        ("prompts", owned_prompt_roots),
        ("extensions", owned_extension_roots),
    ):
        check_live_projection(
            live_root / label,
            roots,
            label,
            home,
            targets,
            errors,
        )

    live_bin = live_root / "bin"
    for script in sorted(live_bin.glob("pi-*")) if live_bin.is_dir() else []:
        if not script.is_symlink():
            errors.append(f"unmanaged Pi command wrapper: {script}")
        elif not is_owned(script, owned_bin_roots):
            errors.append(f"Pi command wrapper points outside owned roots: {script} -> {script.resolve()}")
        check_manifest_projection(script, home, targets, errors)

    for name in ("AGENTS.md", "lessons.md"):
        path = live_root / name
        if not path.exists():
            errors.append(f"missing Pi {name}: {path}")
        elif not path.is_symlink():
            errors.append(f"Pi {name} is unmanaged: {path}")
        elif not is_owned(path, owned_roots):
            errors.append(f"Pi {name} points outside owned roots: {path} -> {path.resolve()}")
        check_manifest_projection(path, home, targets, errors)

    external = home / ".agents/skills"
    if recursive_skill_files(external):
        warnings.append(f"external Agent Skills remain independently managed: {external}")
    for package in settings.get("packages", []):
        if isinstance(package, str) and re.match(r"^(npm|git):", package):
            warnings.append(f"Pi package remains independently managed: {package}")

    return AuditResult(len(seen_skill_paths), agent_count, errors, warnings)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--no-validate", action="store_true")
    parser.add_argument("--no-model-check", action="store_true")
    args = parser.parse_args()

    result = run_audit(
        args.home.resolve(),
        validate=not args.no_validate,
        model_check=not args.no_model_check,
    )
    print(f"skills={result.skill_count} agents={result.agent_count}")
    for warning in result.warnings:
        print(f"WARN: {warning}")
    for error in result.errors:
        print(f"ERROR: {error}")
    if result.errors:
        raise SystemExit(1)
    print("OK: Pi resources are owned, valid, and free of stale harness dependencies")


if __name__ == "__main__":
    main()
