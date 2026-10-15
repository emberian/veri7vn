"""Focused ledger integrity tests; no Isabelle runtime or external dependencies."""

from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import project


def task(task_id, **changes):
    value = dict(id=task_id, title=f"Task {task_id}", area="test", status="planned",
                 depends_on=[], owner=None, paths=[f"src/{task_id}/**"],
                 deliverables=[f"src/{task_id}/"], acceptance=["Useful result"],
                 checks=["Review the result"], evidence=[], notes="")
    value.update(changes)
    return value


def ledger(*tasks):
    return dict(schema_version=1, updated="2026-10-15", tasks=list(tasks))


class LedgerTests(unittest.TestCase):
    def test_cycle_and_missing_dependency_are_errors(self):
        data = ledger(task("a", depends_on=["b"]), task("b", depends_on=["a", "absent"]))
        errors, _ = project.validate(data)
        self.assertTrue(any("cycle: a -> b -> a" in error for error in errors), errors)
        self.assertIn("b: missing dependency absent", errors)

    def test_done_needs_evidence_and_completed_dependencies(self):
        errors, _ = project.validate(ledger(task("a"), task("b", status="done", depends_on=["a"])))
        self.assertIn("b: done requires evidence references", errors)
        self.assertIn("b: done but dependency a is not done", errors)

    def test_owners_and_blocker_notes_are_required(self):
        errors, _ = project.validate(ledger(task("a", status="active"), task("b", status="review"),
                                            task("c", status="blocked")))
        self.assertIn("a: active requires an owner", errors)
        self.assertIn("b: review requires an owner", errors)
        self.assertIn("c: blocked task requires a blocker in notes", errors)

    def test_duplicate_ids_and_malformed_data(self):
        errors, _ = project.validate(ledger(task("a"), task("a", depends_on="oops")))
        self.assertIn("duplicate task ID: a", errors)
        self.assertIn("a: depends_on must be a list of nonempty strings", errors)
        for malformed in (None, [], {"tasks": 7}, ledger(None)):
            with self.subTest(malformed=malformed):
                self.assertTrue(project.validate(malformed)[0])

    def test_readiness_does_not_trust_ready_label(self):
        data = ledger(task("done", status="done", evidence=["evidence.txt"]),
                      task("start", depends_on=["done"]),
                      task("wait", status="ready", depends_on=["start"]),
                      task("blocked", status="blocked", notes="External input needed"),
                      task("active", status="active", owner="agent"))
        errors, warnings = project.validate(data)
        self.assertEqual(errors, [])
        self.assertEqual([t["id"] for t in project.ready_tasks(data)], ["start"])
        self.assertTrue(any("wait:" in warning for warning in warnings))

    def test_conservative_overlap_examples(self):
        cases = [("src/**", "src/a/file.py", True),
                 ("src/a", "src/a/file.py", True),
                 ("src/*.py", "src/main.py", True),
                 ("src/a*.py", "src/*b.py", True),
                 ("src/a/**", "src/b/**", False),
                 ("src/a/../b/**", "src/b/file.py", True),
                 ("src/*.py", "src/main.thy", False),
                 (".", "any/path", True)]
        for left, right, expected in cases:
            with self.subTest(left=left, right=right):
                self.assertEqual(project.paths_may_overlap(left, right), expected)
                self.assertEqual(project.paths_may_overlap(right, left), expected)
        data = ledger(task("a", status="active", owner="one", paths=["src/**"]),
                      task("b", status="active", owner="two", paths=["src/b.py"]),
                      task("c", paths=["src/**"]))
        errors, warnings = project.validate(data)
        self.assertEqual(errors, [])
        self.assertEqual(len(warnings), 1)
        self.assertIn("possible active edit overlap: a (src/**) / b (src/b.py)", warnings)

    def test_cli_board_is_stable_and_invalid_board_is_empty(self):
        data = ledger(task("a", title="Question | Answer"))
        data["milestones"] = ["Optional metadata is allowed"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tasks.json"
            path.write_text(json.dumps(data))
            stdout, stderr = StringIO(), StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                code = project.main(["board", "--ledger", str(path)])
            self.assertEqual(code, 0)
            self.assertEqual(stderr.getvalue(), "")
            self.assertEqual(stdout.getvalue(), project.board(data, []))
            self.assertIn("Question \\| Answer", stdout.getvalue())
            data["tasks"][0]["status"] = "done"
            path.write_text(json.dumps(data))
            stdout, stderr = StringIO(), StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                code = project.main(["board", "--ledger", str(path)])
            self.assertEqual(code, 1)
            self.assertEqual(stdout.getvalue(), "")
            self.assertIn("done requires evidence", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
