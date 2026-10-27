#!/usr/bin/env python3

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

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
        (live / "lessons.md").write_text("# Local lessons\n")
        (public / "tools/manifest.txt").write_text(
            "repo .pi/agent/AGENTS.md ai-agents/AGENTS.md\n"
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
        return home, public, live

    def test_clean_owned_projection_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, _, _ = self.make_home(Path(directory))
            result = run_audit(home, validate=False, model_check=False)
            self.assertEqual(result.errors, [])
            self.assertEqual((result.skill_count, result.agent_count), (1, 1))

    def test_snapshot_source_home_is_explicit_and_checked(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, public, live = self.make_home(Path(directory))
            source_home = home / ".local/state/pi-config-sync/current"
            snapshot = source_home / "configs/ai-agents"
            snapshot.parent.mkdir(parents=True)
            public.rename(snapshot)
            for link in live.rglob("*"):
                if link.is_symlink():
                    relative = link.readlink().relative_to(public)
                    link.unlink()
                    link.symlink_to(snapshot / relative)

            result = run_audit(home, validate=False, model_check=False, source_home=source_home)
            self.assertEqual(result.errors, [])
            result = run_audit(home, validate=False, model_check=False)
            self.assertTrue(any("outside owned roots" in error for error in result.errors))
            (live / "extensions/example").unlink()
            (live / "extensions/example").symlink_to(source_home / "unowned")
            result = run_audit(home, validate=False, model_check=False, source_home=source_home)
            self.assertTrue(any("dangling" in error for error in result.errors))

    def test_lesson_journal_is_optional_and_must_not_be_managed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, public, live = self.make_home(Path(directory))
            (live / "lessons.md").unlink()
            result = run_audit(home, validate=False, model_check=False)
            self.assertEqual(result.errors, [])

            manifest = public / "tools/manifest.txt"
            manifest.write_text(manifest.read_text() + "prepo .pi/agent/lessons.md lessons.md\n")
            result = run_audit(home, validate=False, model_check=False)
            self.assertTrue(any("lessons.md must remain machine-local" in error for error in result.errors))

    def test_shared_skill_entry_is_audited(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, public, _ = self.make_home(Path(directory))
            shared = public / "skills/shared"
            shared.mkdir()
            (shared / "SKILL.md").write_text("---\nname: shared\ndescription: Shared.\n---\n")
            manifest = public / "tools/manifest.txt"
            manifest.write_text(manifest.read_text() + "skill shared\n")
            (home / ".agents/skills").mkdir(parents=True)
            (home / ".agents/skills/shared").symlink_to(shared, target_is_directory=True)
            (home / ".agents/skills/external").mkdir()

            result = run_audit(home, validate=False, model_check=False)
            self.assertEqual(result.errors, [])
            self.assertEqual(result.skill_count, 2)
            self.assertTrue(any("external" in warning for warning in result.warnings))

            (shared / "notes.md").write_text("see Task tool\n")
            result = run_audit(home, validate=False, model_check=False)
            self.assertTrue(any("OpenCode task tool" in error for error in result.errors))

    def test_host_selectors_choose_settings_and_skills_before_duplicate_checks(self) -> None:
        for host in ("work-host_1", "personal"):
            with self.subTest(host=host), tempfile.TemporaryDirectory() as directory:
                home, public, live = self.make_home(Path(directory))
                work_settings = public / "home/work-settings.json"
                work_settings.write_text("{}\n")
                manifest = public / "tools/manifest.txt"
                manifest.write_text(manifest.read_text().replace(
                    "mirror .pi/agent/settings.json\n",
                    "mirror .pi/agent/settings.json @!work-host_1\n"
                    "repo .pi/agent/settings.json ai-agents/home/work-settings.json @work-host_1\n",
                ) + "skill hosted @work-host_1\n" + "skill hosted @!work-host_1\n")
                hosted = public / "skills/hosted"
                hosted.mkdir()
                (hosted / "SKILL.md").write_text("---\nname: hosted\ndescription: Host skill.\n---\n")
                (home / ".agents/skills").mkdir(parents=True)
                (home / ".agents/skills/hosted").symlink_to(hosted)
                if host == "work-host_1":
                    (live / "settings.json").unlink()
                    (live / "settings.json").symlink_to(work_settings)
                with patch.dict(os.environ, {"AGENTS_HOST": host}):
                    result = run_audit(home, validate=False, model_check=False)
                self.assertEqual(result.errors, [])
                self.assertEqual(result.skill_count, 2)

    def test_host_defaults_to_short_socket_hostname(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, public, _ = self.make_home(Path(directory))
            manifest = public / "tools/manifest.txt"
            manifest.write_text(manifest.read_text().replace(
                "mirror .pi/agent/settings.json\n", "mirror .pi/agent/settings.json @workhost\n",
            ))
            with patch.dict(os.environ), patch("audit.socket.gethostname", return_value="workhost.example"):
                os.environ.pop("AGENTS_HOST", None)
                result = run_audit(home, validate=False, model_check=False)
            self.assertEqual(result.errors, [])

    def test_dormant_public_and_private_skills_follow_host(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, public, _ = self.make_home(Path(directory))
            manifest = public / "tools/manifest.txt"
            manifest.write_text(manifest.read_text() + "skill optional\npskill private-optional\n")
            (public / "tools/dormant.txt").write_text(
                "# personal-only exclusions\npersonal optional\npersonal private-optional\n",
            )
            (home / ".agents/skills").mkdir(parents=True)
            for name, root in (("optional", public), ("private-optional", home / "configs-private")):
                source = root / "skills" / name
                source.mkdir(parents=True)
                (source / "SKILL.md").write_text(f"---\nname: {name}\ndescription: Optional.\n---\n")
                (home / ".agents/skills" / name).symlink_to(source)
            for host in ("workhost", "personal"):
                with self.subTest(host=host), patch.dict(os.environ, {"AGENTS_HOST": host}):
                    result = run_audit(home, validate=False, model_check=False)
                    self.assertEqual(result.errors, [])
                    self.assertEqual(bool(result.warnings), host == "personal")
                    if host == "personal":
                        self.assertIn("optional, private-optional", result.warnings[0])

    def test_malformed_host_selectors_are_manifest_errors(self) -> None:
        for selector in ("@", "@!", "@wo*", "@-work", "@work trailing", "@work @other"):
            with self.subTest(selector=selector), tempfile.TemporaryDirectory() as directory:
                home, public, _ = self.make_home(Path(directory))
                manifest = public / "tools/manifest.txt"
                manifest.write_text(manifest.read_text() + f"skill optional {selector}\n")
                result = run_audit(home, validate=False, model_check=False)
                self.assertEqual(len(result.errors), 1)
                self.assertIn("invalid manifest line 7:", result.errors[0])
                self.assertIn("host selector", result.errors[0])

    def test_shared_skill_also_linked_under_pi_collides(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home, public, _ = self.make_home(Path(directory))
            copy = public / "skills/copy"
            copy.mkdir()
            (copy / "SKILL.md").write_text("---\nname: good\ndescription: Same name.\n---\n")
            manifest = public / "tools/manifest.txt"
            manifest.write_text(manifest.read_text() + "skill copy\n")
            (home / ".agents/skills").mkdir(parents=True)
            (home / ".agents/skills/copy").symlink_to(copy, target_is_directory=True)

            result = run_audit(home, validate=False, model_check=False)
            self.assertTrue(any("skill name collision good" in error for error in result.errors))

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
        self.assertEqual(model_id("openai-codex/gpt-6.1-sol:xhigh"), "openai-codex/gpt-6.1-sol")


if __name__ == "__main__":
    unittest.main()
