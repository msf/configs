import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

import sessions


class SessionSearchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)

    def write_session(self, relative, entries):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(json.dumps(entry) + "\n" for entry in entries))
        return path

    def run_cli(self, *args):
        result = subprocess.run(
            [sys.executable, str(Path(sessions.__file__)), *args],
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return [json.loads(line) for line in result.stdout.splitlines()], result.stderr

    def test_search_all_harnesses_by_message_date_not_filename(self):
        common = {"timestamp": "2026-09-17T10:00:00Z"}
        message = {
            "role": "user",
            "content": [{"type": "text", "text": "Project-Orchid"}],
        }
        self.write_session(
            ".pi/agent/sessions/project/2026-08-01_old.jsonl",
            [
                {"type": "session", "id": "pi-id", "cwd": "/project"},
                common | {"type": "message", "message": message},
                common
                | {
                    "type": "message",
                    "message": {
                        "role": "assistant",
                        "content": [{"type": "thinking", "thinking": "Project-Orchid"}],
                    },
                },
                {
                    "type": "message",
                    "timestamp": "2026-09-18T00:00:00Z",
                    "message": message,
                },
            ],
        )
        self.write_session(
            ".claude/projects/project/claude.jsonl",
            [
                common
                | {
                    "type": "user",
                    "sessionId": "claude-id",
                    "cwd": "/project",
                    "message": message,
                },
            ],
        )
        self.write_session(
            ".codex/archived_sessions/codex.jsonl",
            [
                {
                    "type": "session_meta",
                    "payload": {"id": "codex-id", "cwd": "/project"},
                },
                common
                | {"type": "response_item", "payload": {"type": "message"} | message},
                common
                | {
                    "type": "event_msg",
                    "payload": {"type": "user_message", "message": "Project-Orchid"},
                },
            ],
        )
        rows, _ = self.run_cli(
            "search",
            "--home",
            str(self.home),
            "--term",
            "project-orchid",
            "--since",
            "2026-09-17",
            "--until",
            "2026-09-18",
        )
        self.assertEqual(
            {row["session_id"] for row in rows}, {"pi-id", "claude-id", "codex-id"}
        )
        self.assertTrue(all(row["match_count"] == 1 for row in rows))
        self.assertTrue(all("text" not in hit for row in rows for hit in row["hits"]))

    def test_tool_results_are_not_user_evidence(self):
        entry = {
            "type": "user",
            "message": {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "content": [{"type": "text", "text": "verified"}],
                    }
                ],
            },
        }
        self.assertEqual(list(sessions.messages(entry)), [])
        self.assertEqual(
            list(sessions.messages(entry, tools=True)), [("tool_result", "verified")]
        )
        codex = {
            "type": "response_item",
            "payload": {"type": "function_call_output", "output": "ok"},
        }
        self.assertEqual(
            list(sessions.messages(codex, tools=True)), [("tool_result", "ok")]
        )
        pi = {
            "type": "message",
            "message": {
                "role": "toolResult",
                "content": [{"type": "text", "text": "ok"}],
            },
        }
        self.assertEqual(
            list(sessions.messages(pi, tools=True)), [("tool_result", "ok")]
        )

    def test_summaries_and_system_context_are_not_primary(self):
        summary = {"type": "compaction", "summary": "Earlier claim"}
        self.assertEqual(list(sessions.messages(summary)), [])
        self.assertEqual(
            list(sessions.messages(summary, summaries=True)),
            [("summary", "Earlier claim")],
        )
        context = {
            "type": "response_item",
            "payload": {"type": "message", "role": "developer", "content": "ignore"},
        }
        self.assertEqual(
            list(sessions.messages(context, tools=True, summaries=True)), []
        )

    def test_show_redacts_before_truncating_and_preserves_references(self):
        path = self.write_session(
            "example.jsonl",
            [
                {
                    "type": "message",
                    "id": "child",
                    "parentId": "parent",
                    "timestamp": "2026-09-17T10:00:00Z",
                    "message": {
                        "role": "assistant",
                        "content": [
                            {
                                "type": "text",
                                "text": 'api_key="synthetic-value" more details',
                            }
                        ],
                    },
                },
            ],
        )
        rows, _ = self.run_cli(
            "show", str(path), "--start", "1", "--end", "1", "--chars", "22"
        )
        self.assertEqual(rows[0]["parent_id"], "parent")
        self.assertEqual(rows[0]["line"], 1)
        self.assertTrue(rows[0]["truncated"])
        self.assertNotIn("synthetic", rows[0]["text"])
        self.assertIn("[REDACTED]", rows[0]["text"])

    def test_malformed_and_oversized_lines_keep_line_numbers(self):
        path = self.home / "bad.jsonl"
        path.write_bytes(b"x" * 60 + b'\nnot-json\n{"type": "session"}\n')
        original = sessions.MAX_LINE_BYTES
        sessions.MAX_LINE_BYTES = 32
        self.addCleanup(setattr, sessions, "MAX_LINE_BYTES", original)
        with contextlib.redirect_stderr(io.StringIO()) as errors:
            rows = list(sessions.records(path))
        self.assertEqual(rows, [(3, {"type": "session"})])
        self.assertIn("oversized record", errors.getvalue())
        self.assertIn("malformed record", errors.getvalue())

    def test_timezone_and_literal_or_terms(self):
        self.assertEqual(
            sessions.timestamp("2026-09-17T01:00:00+01:00"),
            datetime(2026, 9, 17, tzinfo=timezone.utc),
        )
        path = self.write_session(
            ".pi/agent/sessions/x.jsonl", [{"text": "unrelated [literal]"}]
        )
        self.assertEqual(
            sessions.candidates(path.parent, ["missing", "[literal]"]), [path]
        )

    def test_tool_search_opt_in_and_show_limit(self):
        entry = {
            "type": "response_item",
            "timestamp": "2026-09-17T12:00:00Z",
            "payload": {"type": "custom_tool_call_output", "output": "artifact-only"},
        }
        path = self.write_session(".codex/sessions/tool.jsonl", [entry, entry])
        arguments = (
            "search",
            "--home",
            str(self.home),
            "--term",
            "artifact-only",
            "--since",
            "2026-09-17",
            "--until",
            "2026-09-18",
        )
        rows, _ = self.run_cli(*arguments)
        self.assertEqual(rows, [])
        rows, _ = self.run_cli(*arguments, "--include-tools")
        self.assertEqual(rows[0]["roles"], {"tool_result": 2})
        rows, warning = self.run_cli(
            "show",
            str(path),
            "--start",
            "1",
            "--end",
            "2",
            "--include-tools",
            "--limit",
            "1",
        )
        self.assertEqual(len(rows), 1)
        self.assertIn("excerpt limit", warning)

    def test_codex_text_blocks_and_tool_calls(self):
        entry = {
            "type": "response_item",
            "payload": {
                "type": "message",
                "role": "assistant",
                "content": [{"type": "output_text", "text": "result"}],
            },
        }
        self.assertEqual(list(sessions.messages(entry)), [("assistant", "result")])
        entry["payload"] = {
            "type": "function_call",
            "name": "example",
            "arguments": "{}",
        }
        self.assertEqual(list(sessions.messages(entry)), [])
        self.assertEqual(next(sessions.messages(entry, tools=True))[0], "tool_call")

    def test_invalid_date_and_range_fail(self):
        for args in [
            ("search", "--term", "x", "--since", "bad"),
            ("show", "missing.jsonl", "--start", "1", "--end", "101"),
        ]:
            result = subprocess.run(
                [sys.executable, str(Path(sessions.__file__)), *args],
                capture_output=True,
                text=True,
                check=False,
                timeout=10,
            )
            self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
