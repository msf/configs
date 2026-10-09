from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from compare_histograms import parse


class HistogramComparisonTests(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)

    def histogram(self, name: str, contents: str) -> Path:
        path = self.directory / name
        path.write_text(contents)
        return path

    def test_parse_jcmd_output(self) -> None:
        path = self.histogram(
            "histogram.txt",
            "1234:\n num     #instances         #bytes  class name (module)\n"
            "   1:          10            160  java.lang.Object (java.base@21)\n"
            "   2:           2             64  [B (java.base@21)\n"
            "Total          12            224\n",
        )
        self.assertEqual(
            parse(path),
            {"java.lang.Object (java.base@21)": (10, 160), "[B (java.base@21)": (2, 64)},
        )

    def test_reject_empty_or_failed_capture(self) -> None:
        for contents in ("", "AttachNotSupportedException: unable to attach\n"):
            with self.subTest(contents=contents):
                path = self.histogram("failed.txt", contents)
                with self.assertRaisesRegex(ValueError, "no histogram rows"):
                    parse(path)

    def test_cli_compares_growing_new_and_removed_classes(self) -> None:
        earlier = self.histogram("earlier.txt", "1: 2 200 Growing\n2: 1 100 Removed\n")
        later = self.histogram("later.txt", "1: 5 500 Growing\n2: 3 150 Added\n")
        script = Path(__file__).with_name("compare_histograms.py")
        result = subprocess.run(
            [sys.executable, str(script), str(earlier), str(later), "--top", "3"],
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        )
        rows = {
            columns[-1]: (int(columns[0]), int(columns[1]))
            for line in result.stdout.splitlines()
            if (columns := line.split()) and columns[-1] in {"Growing", "Added", "Removed"}
        }
        self.assertEqual(rows, {"Growing": (300, 3), "Added": (150, 3), "Removed": (-100, -1)})
        self.assertIn("TOTAL live bytes:", result.stdout)

    def test_cli_rejects_nonpositive_top(self) -> None:
        script = Path(__file__).with_name("compare_histograms.py")
        result = subprocess.run(
            [sys.executable, str(script), "unused", "unused", "--top", "0"],
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("--top must be positive", result.stderr)


if __name__ == "__main__":
    unittest.main()
