#!/usr/bin/env python3
"""Untrusted qualification shim: pinned KQA gold programs, not a proof or scorer.

Runs trusted, explicitly pinned steps_kb.py and the native extension in separate
fresh processes. Exact answer comparison is mechanical evidence against gold,
not an adjudication that the dataset or either implementation is correct. This
does not run the learned language reader or any shipped specialist panel.
"""

import argparse
import ast
from collections import Counter, defaultdict
import hashlib
import importlib
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import platform
import subprocess
import sys
import time


VAL_SHA256 = "b4aed6ab3d7ad071722064fe3bb02bc028cfbeb15da5f7115d57a1e2d198f3bb"
KB_SHA256 = "04da7408320c5cb7023c44372cce32846d56d369d8865d2e61a18c3956661a7c"
STEPS_SHA256 = "455fa3c7df1348914b37e15365670ff4130f99e15ee0625a88e5fe69a1e916e3"
WITHHELD_STATUSES = {"absent", "ambiguous", "ambiguous_operands", "incomparable", "incomplete"}
SCALAR_TERMINALS = {
    "What", "Count", "QueryAttr", "QueryAttrUnderCondition", "QueryAttrQualifier",
    "QueryRelation", "QueryRelationQualifier", "SelectAmong", "SelectBetween",
    "VerifyStr", "VerifyNum", "VerifyYear", "VerifyDate",
}


class UnsupportedOperation(Exception):
    """An unavailable entry point or explicit unknown-operation admission."""


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest(path):
    with Path(path).open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def write_json(path, value):
    # New scratch files only: accidentally reusing a run must not replace receipts.
    with Path(path).open("x") as destination:
        json.dump(value, destination, ensure_ascii=False, indent=2)
        destination.write("\n")


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ValueError(f"cannot load {name} from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def extension_binary_path(module):
    """Installed wheels may expose a package whose __file__ is only Python."""
    def binary_file(candidate):
        filename = getattr(candidate, "__file__", None)
        if filename and str(filename).endswith(tuple(importlib.machinery.EXTENSION_SUFFIXES)):
            return str(Path(filename).resolve())
        return None

    direct = binary_file(module)
    if direct:
        return direct
    binary = getattr(module, "oracle_native", None)
    if binary is None:
        binary = importlib.import_module(f"{module.__name__}.oracle_native")
    path = binary_file(binary)
    if path is None:
        raise ValueError("oracle_native did not resolve to a native extension binary")
    return path


def pinned_operations(steps_path):
    """Read the actual pinned class, not a native advertised capability list."""
    tree = ast.parse(Path(steps_path).read_text())
    classes = [node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == "KQA"]
    if len(classes) != 1:
        raise ValueError("pinned source must define exactly one KQA class")
    return sorted(node.name for node in classes[0].body
                  if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
                  and node.name[:1].isupper())


def sample_cases(path, per_terminal, seed):
    if Path(path).stat().st_size > 32 * 1024 * 1024:
        raise ValueError("validation corpus exceeds qualification's 32 MiB input bound")
    dataset = json.loads(Path(path).read_text())
    if not isinstance(dataset, list):
        raise ValueError("validation corpus must be a list")
    families = defaultdict(list)
    for index, row in enumerate(dataset):
        program = row.get("program")
        if not isinstance(program, list) or not program:
            raise ValueError(f"validation row {index} has no program")
        terminal = program[-1].get("function")
        if not isinstance(terminal, str):
            raise ValueError(f"validation row {index} has no terminal operation")
        if not isinstance(row.get("answer"), (str, int, float)) or isinstance(row["answer"], bool):
            raise ValueError(f"validation row {index} has unsupported gold answer type")
        case = {"source_index": index, "terminal": terminal,
                "question": row.get("question", ""), "program": program,
                "gold": str(row["answer"])}
        key = hashlib.sha256((seed + "\0" + str(index) + "\0" + canonical(program)).encode()).hexdigest()
        families[terminal].append((key, case))
    selected = []
    for terminal in sorted(families):
        selected.extend(case for _, case in sorted(families[terminal], key=lambda pair: pair[0])[:per_terminal])
    return selected, {name: len(rows) for name, rows in sorted(families.items())}, len(dataset)


def live_operations(program):
    """Actual live source instructions, not a claim of instrumented Rust lines."""
    pending, live = [len(program) - 1], set()
    while pending:
        index = pending.pop()
        if not isinstance(index, int) or isinstance(index, bool) or index < 0 or index >= len(program):
            raise ValueError("invalid dataset dependency")
        if index in live:
            continue
        live.add(index)
        dependencies = program[index]["dependencies"]
        if any(not isinstance(dep, int) or isinstance(dep, bool) or dep < 0 or dep >= index
               for dep in dependencies):
            raise ValueError("dataset dependency does not precede consumer")
        pending.extend(dependencies)
    return [program[index]["function"] for index in sorted(live)]


def native_answer(result, terminal):
    """Project only explicit success; never turn ambiguity into a candidate."""
    if result.get("coverage") != "complete_relative_to_image":
        raise ValueError("native result lacks complete-relative-to-image coverage")
    value = result.get("value")
    if terminal == "Count":
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            raise ValueError("Count did not return a nonnegative integer")
        return "answered", str(value), "count"
    if terminal not in SCALAR_TERMINALS:
        return "unsupported", None, "unsupported_terminal_projection"
    if not isinstance(value, dict):
        raise ValueError("scalar projection did not return a structured status")
    status = value.get("status")
    if status in WITHHELD_STATUSES:
        return "withheld", None, status
    if terminal.startswith("Verify"):
        if status != "verified" or not isinstance(value.get("answer"), bool):
            raise ValueError(f"unexpected verification response {status!r}")
        return "answered", "yes" if value["answer"] else "no", status
    if status != "unique":
        raise ValueError(f"unexpected projection response {status!r}")
    candidate = value.get("candidate")
    if terminal in {"What", "SelectAmong", "SelectBetween"}:
        if not isinstance(candidate, dict) or not isinstance(candidate.get("name"), str):
            raise ValueError("unique entity projection has no candidate name")
        return "answered", candidate["name"], status
    # Native display is part of its value contract. Do not convert dates, units,
    # casing or numeric tolerance to make it match the dataset or Python source.
    if not isinstance(value.get("display"), str):
        raise ValueError("unique typed projection has no display string")
    return "answered", value["display"], status


def observation(case, producer):
    started = time.perf_counter()
    try:
        kind, answer, status = producer(case)
        outcome = ("correct" if answer == case["gold"] else "wrong") if kind == "answered" else kind
        return {"source_index": case["source_index"], "terminal": case["terminal"],
                "outcome": outcome, "answer": answer, "status": status,
                "seconds": time.perf_counter() - started, "completed": True}
    except Exception as error:  # Exceptions are retained as failures, never gold answers.
        message = str(error)
        unsupported = isinstance(error, UnsupportedOperation) or "unknown variant" in message
        return {"source_index": case["source_index"], "terminal": case["terminal"],
                "outcome": "unsupported" if unsupported else "withheld", "answer": None,
                "status": "unsupported_operation" if unsupported else "execution_error",
                "error_type": type(error).__name__, "error": message[:2048],
                "seconds": time.perf_counter() - started, "completed": False}


def child(args):
    work = Path(args.work)
    cases = json.loads((work / "cases.json").read_text())
    if args.mode == "reference":
        steps = load_module("qualified_steps_kb", args.steps)
        kqa = steps.KQA(args.source)

        def produce(case):
            unknown = sorted({step["function"] for step in case["program"]
                              if not callable(getattr(kqa, step["function"], None))})
            if unknown:
                raise UnsupportedOperation(f"pinned KQA has no operations {unknown}")
            answer = kqa.run(case["program"])
            return ("withheld", None, "none") if answer is None else ("answered", str(answer), "returned")

        provenance = {"steps_sha256": digest(args.steps)}
    else:
        native = load_module("oracle_native", args.extension) if args.extension else importlib.import_module("oracle_native")
        image_receipt = json.loads(Path(args.image_receipt).read_text())
        runtime = native.Runtime(args.image, image_receipt["image_sha256"],
                                 str(work / "native-state.sqlite"), args.limits_json)
        tenant = runtime.tenant("gold_program_qualification")

        def produce(case):
            if not callable(getattr(tenant, "query_program", None)):
                raise UnsupportedOperation("native tenant has no query_program entry point")
            result = json.loads(tenant.query_program(canonical(case["program"]), native.Cancellation()))
            return native_answer(result, case["terminal"])

        binary = extension_binary_path(native)
        provenance = {"extension_path": binary, "extension_sha256": digest(binary),
                      "import_module_path": native.__file__}
    results = [observation(case, produce) for case in cases]
    write_json(work / f"{args.mode}-observations.json", results)
    print(canonical({"mode": args.mode, "cases": len(results), "provenance": provenance}))


def summarize(cases, observations, operations):
    totals, by_terminal, statuses = Counter(), defaultdict(Counter), Counter()
    operation_attempts, operation_completed, operation_correct = Counter(), Counter(), Counter()
    for case, result in zip(cases, observations, strict=True):
        if case["source_index"] != result["source_index"]:
            raise ValueError("observation order mismatch")
        outcome = result["outcome"]
        totals[outcome] += 1
        by_terminal[case["terminal"]][outcome] += 1
        statuses[result["status"]] += 1
        # Count programs, rather than double-counting repeated instances of an op.
        for operation in set(live_operations(case["program"])):
            operation_attempts[operation] += 1
            if result["completed"]:
                operation_completed[operation] += 1
            if outcome == "correct":
                operation_correct[operation] += 1
    counts = lambda counter: {name: counter[name] for name in ("correct", "wrong", "withheld", "unsupported")}
    return {"counts": counts(totals), "by_terminal": {name: counts(counter) for name, counter in sorted(by_terminal.items())},
            "observed_statuses": dict(sorted(statuses.items())),
            "execution_errors": sum(row["status"] == "execution_error" for row in observations),
            "operation_coverage": {
                "kind": "observed live instructions in evaluated gold programs; not Rust line/branch instrumentation",
                "operations": {operation: {"programs_attempted": operation_attempts[operation],
                    "programs_completed": operation_completed[operation],
                    "programs_matching_gold": operation_correct[operation]} for operation in operations},
                "unexercised_operations": [operation for operation in operations if not operation_completed[operation]],
                "operations_without_a_gold_correct_program": [operation for operation in operations if not operation_correct[operation]],
                "unseen_terminal_operations": sorted(set(operations) - set(by_terminal)),
            }}


def bounded_mismatch(record):
    encoded = canonical(record).encode()
    if len(encoded) <= 16384:
        return record
    return {"source_index": record["case"]["source_index"], "truncated": True,
            "complete_record_sha256": hashlib.sha256(encoded).hexdigest(),
            "preview": encoded[:16384].decode("utf-8", errors="ignore")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="pinned kb.json")
    parser.add_argument("--validation", required=True, help="pinned val.json")
    parser.add_argument("--steps", required=True, help="pinned steps_kb.py")
    parser.add_argument("--image", required=True, help="existing immutable native image")
    parser.add_argument("--image-receipt", required=True)
    parser.add_argument("--extension", help="extension .so; otherwise use the installed oracle_native")
    parser.add_argument("--work", required=True, help="new scratch directory; never an existing run")
    parser.add_argument("--per-terminal", type=int, default=20)
    parser.add_argument("--seed", default="oracle-kqa-programs-c473d28-v1")
    parser.add_argument("--mismatch-limit", type=int, default=30)
    parser.add_argument("--child-timeout-seconds", type=int, default=600)
    parser.add_argument("--limits-json", default='{"workers":2,"timeout_ms":10000}')
    parser.add_argument("--source-sha256", default=KB_SHA256)
    parser.add_argument("--validation-sha256", default=VAL_SHA256)
    parser.add_argument("--steps-sha256", default=STEPS_SHA256)
    parser.add_argument("--source-revision", default="c473d28", help="declared source revision, retained with hashes")
    parser.add_argument("--mode", choices=["reference", "native"], help=argparse.SUPPRESS)
    args = parser.parse_args()
    if not 1 <= args.per_terminal <= 20 or not 0 <= args.mismatch_limit <= 100 or args.child_timeout_seconds < 1:
        parser.error("require 1..20 per terminal, 0..100 retained mismatches, and a positive timeout")
    if args.mode:
        child(args)
        return
    paths = {"source": (args.source, args.source_sha256), "validation": (args.validation, args.validation_sha256),
             "steps": (args.steps, args.steps_sha256)}
    hashes = {}
    for name, (path, expected) in paths.items():
        actual = digest(path)
        if actual != expected:
            raise ValueError(f"{name} hash mismatch: {actual} != {expected}")
        hashes[name] = actual
    receipt = json.loads(Path(args.image_receipt).read_text())
    if receipt["source_sha256"] != hashes["source"]:
        raise ValueError("native image receipt binds a different knowledge base")
    operations = pinned_operations(args.steps)
    cases, population, dataset_rows = sample_cases(args.validation, args.per_terminal, args.seed)
    work = Path(args.work)
    work.mkdir(parents=True, exist_ok=False)
    write_json(work / "cases.json", cases)
    command = [sys.executable, "-B", str(Path(__file__).resolve()),
               "--source", str(Path(args.source).resolve()), "--validation", str(Path(args.validation).resolve()),
               "--steps", str(Path(args.steps).resolve()), "--image", str(Path(args.image).resolve()),
               "--image-receipt", str(Path(args.image_receipt).resolve()), "--work", str(work.resolve()),
               "--limits-json", args.limits_json]
    if args.extension:
        command += ["--extension", str(Path(args.extension).resolve())]
    children = []
    for mode in ("reference", "native"):
        try:
            result = subprocess.run(command + ["--mode", mode], check=False, capture_output=True, text=True,
                                    timeout=args.child_timeout_seconds)
        except subprocess.TimeoutExpired:
            write_json(work / "report.json", {"schema": "oracle-native-gold-programs-v1",
                       "run_status": "incomplete", "failure": f"{mode} process timeout",
                       "input_sha256": hashes, "cases_sha256": digest(work / "cases.json"),
                       "completed_children": children})
            raise
        write_json(work / f"{mode}-process.json", {"returncode": result.returncode,
                   "stdout": result.stdout[-8192:], "stderr": result.stderr[-8192:]})
        if result.returncode:
            write_json(work / "report.json", {"schema": "oracle-native-gold-programs-v1",
                       "run_status": "incomplete", "failure": f"{mode} child exited {result.returncode}",
                       "input_sha256": hashes, "cases_sha256": digest(work / "cases.json"),
                       "completed_children": children})
            raise RuntimeError(f"{mode} child failed; inspect {work / (mode + '-process.json')}")
        children.append(json.loads(result.stdout))
    observations = {mode: json.loads((work / f"{mode}-observations.json").read_text())
                    for mode in ("reference", "native")}
    summaries = {mode: summarize(cases, rows, operations) for mode, rows in observations.items()}
    comparison, mismatches = Counter(), []
    for case, reference, native in zip(cases, observations["reference"], observations["native"], strict=True):
        same = (reference["outcome"], reference["answer"]) == (native["outcome"], native["answer"])
        comparison["same_outcome_and_answer" if same else "different_outcome_or_answer"] += 1
        if not same or native["outcome"] != "correct" or reference["outcome"] != "correct":
            if len(mismatches) < args.mismatch_limit:
                mismatches.append(bounded_mismatch({"case": case, "reference": reference, "native": native}))
    write_json(work / "mismatches.json", mismatches)
    report = {"schema": "oracle-native-gold-programs-v1", "run_status": "complete",
              "scope": "bounded gold structured programs; no learned reader or specialist-panel claim",
              "comparison": "exact strings; no case-folding, tolerance, unit or date normalization",
              "python": sys.version, "platform": platform.platform(), "input_sha256": hashes,
              "declared_source_revision": args.source_revision, "image_receipt": receipt, "child_processes": children,
              "limits_overrides": json.loads(args.limits_json),
              "sample": {"seed": args.seed, "per_terminal_bound": args.per_terminal,
                         "dataset_rows": dataset_rows, "population_by_terminal": population,
                         "selected": len(cases), "selected_by_terminal": dict(Counter(case["terminal"] for case in cases)),
                         "cases_sha256": digest(work / "cases.json")},
              "results": summaries, "source_native_comparison": dict(comparison),
              "retained_mismatches": len(mismatches), "mismatch_limit": args.mismatch_limit,
              "artifacts": {"cases": "cases.json", "mismatches": "mismatches.json",
                            "reference": "reference-observations.json", "native": "native-observations.json"}}
    write_json(work / "report.json", report)
    print(json.dumps(report, indent=2))
    if summaries["native"]["counts"]["wrong"] or summaries["native"]["counts"]["unsupported"] or summaries["native"]["execution_errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
