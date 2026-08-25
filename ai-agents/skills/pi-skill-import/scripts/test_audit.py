#!/usr/bin/env python3

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from audit import model_id, parse_frontmatter, run_audit, scan_tree


class AuditTest(unittest.TestCase):
    def make_home(self, root: Path) -> tuple[Path, Path, Path]:
        home = root / "home"
        public = home / "configs/ai-agents"
        private = home / "configs-private"
        live = home / ".pi/agent"
        for path in (
            public / "skills/good",
            public / "agents/pi",
            public / "commands",
            public / "tools/extensions/example",
            public / "home/.pi/agent",
            private,
            live / "skills",
            live / "agents",
            live / "prompts",
            live / "extensions",
        ):
            path.mkdir(parents=True, exist_ok=True)

        (public / "skills/good/SKILL.md").write_text(
            "---\nname: good\ndescription: Good skill.\n---\n"
        )
        (public / "agents/pi/worker.md").write_text(
            "---\nname: worker\ndescription: Worker.\ntools: read, grep\n---\n"
        )
        (public / "commands/example.md").write_text("---\ndescription: Example\n---\nDo it.\n")
        (public / "tools/extensions/example/index.ts").write_text("export default function () {}\n")
        (public / "home/.pi/agent/settings.json").write_text("{}\n")
        (public / "AGENTS.md").write_text("# Agents\n")
        (private / "lessons.md").write_text("# Lessons\n")
        (public / "tools/manifest.txt").write_text(
            "repo .pi/agent/AGENTS.md ai-agents/AGENTS.md\n"
            "prepo .pi/agent/lessons.md lessons.md\n"
            "mirror .pi/agent/settings.json\n"
            "repo .pi/agent/skills/good ai-agents/skills/good\n"
            "repo .pi/agent/agents/worker.md ai-agents/agents/pi/worker.md\n"
            "repo .pi/agent/prompts/example.md ai-agents/commands/example.md\n"
            "repo .pi/agent/extensions/example ai-agents/tools/extensions/example\n"
        )

        (live / "skills/good").symlink_to(public / "skills/good", target_is_directory=True)
        (live / "agents/worker.md").symlink_to(public / "agents/pi/worker.md")
        (live / "prompts/example.md").symlink_to(public / "commands/example.md")
        (live / "extensions/example").symlink_to(public / "tools/extensions/example", target_is_directory=True)
        (live / "settings.json").symlink_to(public / "home/.pi/agent/settings.json")
        (live / "AGENTS.md").symlink_to(public / "AGENTS.md")
        (live / "lessons.md").symlink_to(private / "lessons.md")
        return home, public, live

    def test_clean_owned_projection_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, _, _ = self.make_home(Path(directory))
            result = run_audit(home, validate=False, model_check=False)
            self.assertEqual(result.errors, [])
            self.assertEqual((result.skill_count, result.agent_count), (1, 1))

    def test_detects_dangling_and_recursive_skill_resources(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, public, live = self.make_home(Path(directory))
            (live / "skills/missing").symlink_to(public / "skills/missing", target_is_directory=True)

            nested = public / "skills/bundle/inner"
            nested.mkdir(parents=True)
            (nested / "SKILL.md").write_text(
                "---\nname: nested\ndescription: Nested skill.\n---\n"
            )
            (live / "skills/bundle").symlink_to(public / "skills/bundle", target_is_directory=True)

            loose = public / "skills/loose.md"
            loose.write_text("---\nname: loose\ndescription: Loose skill.\n---\n")
            (live / "skills/loose.md").symlink_to(loose)

            result = run_audit(home, validate=False, model_check=False)
            self.assertEqual(result.skill_count, 3)
            self.assertTrue(any("dangling Pi skill symlink" in error for error in result.errors))
            self.assertTrue(any("not declared in manifest" in error for error in result.errors))

    def test_detects_stale_extensionless_file_and_external_resource_link(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            skill = root / "owned/skill"
            external = root / "upstream"
            (skill / "scripts").mkdir(parents=True)
            external.mkdir()
            (skill / "scripts/run").write_text("use ~/.config/opencode/skills/example\n")
            (external / "reference.md").write_text("upstream\n")
            (skill / "references").symlink_to(external, target_is_directory=True)

            stale, link_errors = scan_tree(skill, [root / "owned"])
            self.assertEqual(len(stale), 1)
            self.assertTrue(any("outside owned roots" in error for error in link_errors))

    def test_rejects_non_scalar_agent_tools_and_handles_dangling_agent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, public, live = self.make_home(Path(directory))
            (public / "agents/pi/worker.md").write_text(
                "---\nname: worker\ndescription: >\n  Worker description.\ntools:\n  read: true\n---\n"
            )
            (live / "agents/missing.md").symlink_to(public / "agents/pi/missing.md")

            result = run_audit(home, validate=False, model_check=False)
            self.assertTrue(any("tools must be a comma-separated scalar" in error for error in result.errors))
            self.assertTrue(any("dangling Pi agent symlink" in error for error in result.errors))

    def test_frontmatter_and_model_suffix(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "SKILL.md"
            path.write_text("---\nname: example\ndescription: >\n  Works.\n---\n")
            self.assertEqual(parse_frontmatter(path)["description"], "Works.")
        self.assertEqual(model_id("openai-codex/gpt-5.6-sol:xhigh"), "openai-codex/gpt-5.6-sol")


if __name__ == "__main__":
    unittest.main()
