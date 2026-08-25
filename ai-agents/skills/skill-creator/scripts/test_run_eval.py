#!/usr/bin/env python3

import unittest

from run_eval import final_text, parse_events, usage


class EventParsingTest(unittest.TestCase):
    def test_extracts_final_assistant_text_and_usage(self) -> None:
        stdout = "\n".join(
            [
                '{"type":"session"}',
                '{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"done"}],"usage":{"output":4}}}',
            ]
        )
        events = parse_events(stdout)
        self.assertEqual(final_text(events), "done")
        self.assertEqual(usage(events), {"output": 4})

    def test_ignores_non_json_lines(self) -> None:
        self.assertEqual(parse_events("noise\n{\"type\":\"agent_start\"}"), [{"type": "agent_start"}])


if __name__ == "__main__":
    unittest.main()
