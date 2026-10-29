#!/usr/bin/env python3
"""Untrusted, bounded qualification of the installed native language reader.

Selects at most 100 real validation questions by a reproducible hash (40 by
default), then reads them in one fresh native process. Gold comparison is exact
text; the dataset is not assumed infallible. No upstream Reader/Engine is
constructed, and no language-equivalence or specialist-panel score is claimed.

Required inputs are a KB-bound reader image, its build receipt and pinned
val.json. --cases-file may restrict the sampling pool to an existing explicit
case list, such as qualify_programs.py's 233 gold-program cases. Every supplied
case is checked against its actual validation row before sampling. Gold programs
are only provenance and terminal labels; they are NEVER sent to the reader.

The child imports the installed oracle_native, opens one Image and Runtime,
measures fresh-process startup, query times, PSS/RSS and then creates exactly
256 scoped tenant handles on that Runtime. Only three additional reads run.
Filesystem caches are not evicted. A configurable 8 MiB default growth bound
checks handle creation, not the data/index working set or a production quota.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import importlib
import importlib.machinery
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time

PROCESS_STARTED = time.perf_counter()
VAL_SHA256 = "b4aed6ab3d7ad071722064fe3bb02bc028cfbeb15da5f7115d57a1e2d198f3bb"
KB_SHA256 = "04da7408320c5cb7023c44372cce32846d56d369d8865d2e61a18c3956661a7c"
OUTCOMES = ("answered_correct", "answered_wrong", "refused", "unknown", "errors")
COVERAGE = "whole_and_exact_fragment_outer_v1"


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def digest(path):
    with Path(path).open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def read_json(path, bound):
    path = Path(path)
    with path.open("rb") as source:
        encoded = source.read(bound + 1)
    if len(encoded) > bound:
        raise ValueError(f"input exceeds {bound} bytes: {path}")
    return json.loads(encoded)


def write_json(path, value):
    with Path(path).open("x", encoding="utf-8") as destination:
        json.dump(value, destination, ensure_ascii=False, indent=2, allow_nan=False)
        destination.write("\n")


def memory():
    result = {}
    sources = [
        ("/proc/self/smaps_rollup", {"Pss": "pss_kib", "Private_Dirty": "private_dirty_kib",
                                    "Private_Clean": "private_clean_kib"}),
        ("/proc/self/status", {"VmRSS": "rss_kib", "VmHWM": "peak_rss_kib", "Threads": "threads"}),
    ]
    for path, keys in sources:
        try:
            for line in Path(path).read_text().splitlines():
                key, _, text = line.partition(":")
                if key in keys:
                    result[keys[key]] = int(text.split()[0])
        except (OSError, ValueError) as error:
            result.setdefault("unavailable", []).append(f"{path}: {type(error).__name__}")
    return result


def delta(after, before):
    return {key: after[key] - before[key] for key in
            ("pss_kib", "rss_kib", "private_dirty_kib", "private_clean_kib", "threads")
            if key in after and key in before}


def timings(values):
    if not values:
        return {"count": 0, "p50_seconds": None, "p95_seconds": None, "max_seconds": None}
    ordered = sorted(values)
    return {"count": len(values), "p50_seconds": statistics.median(values),
            "p95_seconds": ordered[max(0, math.ceil(.95 * len(ordered)) - 1)],
            "max_seconds": ordered[-1]}


def clip(text, limit=2048):
    if text is None:
        return {"text": None, "truncated": False}
    encoded = text.encode("utf-8")
    return {"text": encoded[:limit].decode("utf-8", errors="ignore"),
            "truncated": len(encoded) > limit,
            **({"bytes": len(encoded), "sha256": hashlib.sha256(encoded).hexdigest()}
               if len(encoded) > limit else {})}


def val_case(row, index):
    if not isinstance(row, dict) or not isinstance(row.get("question"), str) or not row["question"]:
        raise ValueError(f"validation row {index} has no question")
    program = row.get("program")
    if not isinstance(program, list) or not program or not isinstance(program[-1].get("function"), str):
        raise ValueError(f"validation row {index} has no program terminal")
    gold = row.get("answer")
    if not isinstance(gold, (str, int, float)) or isinstance(gold, bool):
        raise ValueError(f"validation row {index} has unsupported gold answer")
    if len(row["question"].encode()) > 65536 or len(str(gold).encode()) > 65536:
        raise ValueError("qualification question/gold exceeds 64 KiB")
    return {"source_index": index, "question": row["question"], "gold": str(gold),
            "terminal": program[-1]["function"], "program_sha256": hashlib.sha256(canonical(program).encode()).hexdigest()}


def select_cases(validation, cases_file, count, seed):
    dataset = read_json(validation, 32 * 1024 * 1024)
    if not isinstance(dataset, list) or not dataset:
        raise ValueError("validation corpus must be a nonempty list")
    if cases_file:
        supplied = read_json(cases_file, 16 * 1024 * 1024)
        if not isinstance(supplied, list) or not 1 <= len(supplied) <= 1000:
            raise ValueError("explicit case pool must contain 1..1000 rows")
        pool, seen = [], set()
        for row in supplied:
            index = row.get("source_index") if isinstance(row, dict) else None
            if not isinstance(index, int) or isinstance(index, bool) or not 0 <= index < len(dataset) or index in seen:
                raise ValueError("explicit cases require unique validation source_index values")
            seen.add(index)
            case = val_case(dataset[index], index)
            if row.get("question") != case["question"] or str(row.get("gold")) != case["gold"]:
                raise ValueError(f"explicit case {index} does not match validation question/gold")
            if "program" not in row or canonical(row["program"]) != canonical(dataset[index]["program"]):
                raise ValueError(f"explicit case {index} does not match its validation program")
            if "terminal" in row and row["terminal"] != case["terminal"]:
                raise ValueError(f"explicit case {index} has a changed terminal")
            pool.append(case)
    else:
        pool = [val_case(row, index) for index, row in enumerate(dataset)]
    selected = sorted(pool, key=lambda case: hashlib.sha256(
        (seed + "\0" + canonical(case)).encode()).hexdigest())[:count]
    return selected, {"dataset_rows": len(dataset), "pool_rows": len(pool),
                      "pool_by_terminal": dict(sorted(Counter(c["terminal"] for c in pool).items())),
                      "selected_by_terminal": dict(sorted(Counter(c["terminal"] for c in selected).items()))}


def installed_provenance(native):
    # A maturin package may have a Python __init__ wrapper. Bind actual loaded
    # extension bytes as well as the package's entry file when present.
    files = {str(Path(native.__file__).resolve())}
    suffixes = tuple(importlib.machinery.EXTENSION_SUFFIXES)
    for name, module in list(sys.modules.items()):
        path = getattr(module, "__file__", None)
        if (name == "oracle_native" or name.startswith("oracle_native.")) and path and path.endswith(suffixes):
            files.add(str(Path(path).resolve()))
    return {"module": "oracle_native", "files": [{"path": path, "sha256": digest(path)} for path in sorted(files)]}


def observe(tenant, native, case):
    started = time.perf_counter()
    cpu_started = time.process_time()
    try:
        result = json.loads(tenant.read_whole(case["question"], native.Cancellation()))
        if result.get("coverage") != COVERAGE:
            raise ValueError(f"native read lacks explicit {COVERAGE} coverage")
        status, answer = result.get("status"), result.get("answer")
        if status == "answered":
            if not isinstance(answer, str) or result.get("distinct_answers") != [answer]:
                raise ValueError("answered native result does not have one agreed string")
            if result.get("reason") is not None:
                raise ValueError("answered native result carries a refusal reason")
            outcome = "answered_correct" if answer == case["gold"] else "answered_wrong"
        elif status in {"refused", "ambiguous", "unknown"}:
            if answer is not None:
                raise ValueError("unanswered native result carries an answer")
            if not isinstance(result.get("reason"), str):
                raise ValueError("unanswered native result has no explicit reason")
            outcome = "unknown" if status == "unknown" else "refused"
        else:
            raise ValueError(f"unknown native reader status {status!r}")
        return {"source_index": case["source_index"], "terminal": case["terminal"], "outcome": outcome,
                "native_status": status, "reason": result.get("reason"), "answer": clip(answer),
                "matched_programs": result.get("matched_programs"), "successful_readings": len(result.get("readings", [])),
                "unsupported_programs": result.get("unsupported_programs"),
                "ambiguous_executions": result.get("ambiguous_executions"),
                "seconds": time.perf_counter() - started,
                "cpu_seconds": time.process_time() - cpu_started}
    except Exception as error:
        # Budget and operational failures remain errors, not unknown/refusal.
        return {"source_index": case["source_index"], "terminal": case["terminal"], "outcome": "errors",
                "native_status": None, "reason": "execution_error", "answer": clip(None),
                "error_type": type(error).__name__, "error": clip(str(error)),
                "seconds": time.perf_counter() - started,
                "cpu_seconds": time.process_time() - cpu_started}


def native_child(args):
    work = Path(args.work)
    cases = read_json(work / "cases.json", 16 * 1024 * 1024)
    if not isinstance(cases, list) or not 1 <= len(cases) <= 100:
        raise ValueError("native child requires 1..100 selected cases")
    receipt = read_json(args.image_receipt, 1024 * 1024)
    before = memory()
    started = time.perf_counter()
    native = importlib.import_module("oracle_native")
    imported = time.perf_counter()
    import_memory = memory()
    image_started = time.perf_counter()
    image = native.Image(args.image, receipt["image_sha256"], args.limits_json)
    image_opened = time.perf_counter()
    runtime = native.Runtime.from_image(image, str(work / "native-reader-state.sqlite"))
    # These are the same scoped handles later used for the 256-handle sample.
    tenant = runtime.tenant("reader_qualification")
    ready_at = time.perf_counter()
    ready_memory = memory()
    observations = []
    first_completed_at = None
    for case in cases:
        observations.append(observe(tenant, native, case))
        if first_completed_at is None:
            first_completed_at = time.perf_counter()
        if image.active_workers != 0:
            raise RuntimeError("a serial read returned without releasing its worker")
    after_queries = memory()
    # Count exactly 256 scoped handles including the qualification handle.
    handles = [tenant]
    tenant_samples = [{"handles": 1, "memory": after_queries, "active_workers": image.active_workers}]
    for index in range(1, 256):
        handles.append(runtime.tenant(f"reader_scope_{index}"))
        if len(handles) in {16, 64, 256}:
            tenant_samples.append({"handles": len(handles), "memory": memory(), "active_workers": image.active_workers})
    after_handles = memory()
    growth = delta(after_handles, after_queries)
    metric = "pss_kib" if "pss_kib" in growth else "rss_kib" if "rss_kib" in growth else None
    within_growth_bound = metric is not None and growth[metric] <= args.tenant_memory_growth_kib
    tenant_reads = [observe(handles[index], native, cases[0]) for index in (0, 127, 255)]
    # Comparing outcomes cannot make the three repeats part of the gold score.
    stable = all((row["outcome"], row["native_status"], row["reason"], row["answer"])
                 == (observations[0]["outcome"], observations[0]["native_status"],
                     observations[0]["reason"], observations[0]["answer"]) for row in tenant_reads)
    checks = {"handles": len(handles), "configured_workers": json.loads(args.limits_json).get("workers", 2),
              "active_workers_after": image.active_workers, "same_results_across_three_scopes": stable,
              "handle_creation_growth": growth, "growth_metric": metric,
              "handle_growth_bound_kib": args.tenant_memory_growth_kib,
              "within_handle_growth_bound": within_growth_bound,
              "samples": tenant_samples, "extra_read_count": len(tenant_reads), "extra_reads": tenant_reads,
              "passed": len(handles) == 256 and image.active_workers == 0 and stable and within_growth_bound
                        and not any(row["outcome"] == "errors" for row in tenant_reads)}
    metrics = {"scope": "one fresh native process; filesystem caches not evicted",
               "native_import_seconds": imported - started,
               "image_open_seconds": image_opened - image_started,
               "runtime_and_first_handle_seconds": ready_at - image_opened,
               "import_to_ready_seconds": ready_at - started,
               "fresh_process_to_ready_seconds": ready_at - PROCESS_STARTED,
               "first_query_seconds": observations[0]["seconds"],
               "fresh_process_to_first_query_completed_seconds": first_completed_at - PROCESS_STARTED,
               "all_query_timings": timings([row["seconds"] for row in observations]),
               "completed_query_timings": timings([row["seconds"] for row in observations if row["outcome"] != "errors"]),
               "error_query_timings": timings([row["seconds"] for row in observations if row["outcome"] == "errors"]),
               "query_cpu_clock": "time.process_time; native/Python/SQLite CPU in this process, excluding descheduling and waits",
               "all_query_cpu_timings": timings([row["cpu_seconds"] for row in observations]),
               "before_import_memory": before, "after_import_memory": import_memory,
               "ready_memory": ready_memory, "after_queries_memory": after_queries,
               "after_handles_memory": after_handles, "after_scope_reads_memory": memory(),
               "tenant_memory_check": checks}
    write_json(work / "native-observations.json", observations)
    write_json(work / "native-process-metrics.json", metrics)
    print(canonical({"cases": len(observations), "provenance": installed_provenance(native)}))


def summary(cases, observations):
    totals, reasons, statuses, errors = Counter(), Counter(), Counter(), Counter()
    terminals = defaultdict(Counter)
    for case, observation in zip(cases, observations, strict=True):
        if case["source_index"] != observation["source_index"]:
            raise ValueError("observation order mismatch")
        outcome = observation["outcome"]
        if outcome not in OUTCOMES:
            raise ValueError("unknown observation outcome")
        totals[outcome] += 1
        terminals[case["terminal"]][outcome] += 1
        reasons[observation["reason"] or "answered"] += 1
        if observation["native_status"] is not None:
            statuses[observation["native_status"]] += 1
        if outcome == "errors":
            errors[observation["error_type"]] += 1
    return {"counts": {key: totals[key] for key in OUTCOMES},
            "reason_counts": dict(sorted(reasons.items())), "native_status_counts": dict(sorted(statuses.items())),
            "error_types": dict(sorted(errors.items())),
            "by_gold_terminal": {terminal: {key: counts[key] for key in OUTCOMES}
                                 for terminal, counts in sorted(terminals.items())},
            "refused_definition": "native refused and ambiguous statuses; native status counts remain separate"}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--image", required=True)
    parser.add_argument("--image-receipt", required=True)
    parser.add_argument("--validation", required=True, help="pinned val.json")
    parser.add_argument("--cases-file", help="optional prior explicit question/program/gold sample")
    parser.add_argument("--work", required=True, help="new scratch run directory")
    parser.add_argument("--cases", type=int, default=40)
    parser.add_argument("--seed", default="oracle-native-whole-reader-20261028-v1")
    parser.add_argument("--validation-sha256", default=VAL_SHA256)
    parser.add_argument("--source-sha256", default=KB_SHA256)
    parser.add_argument("--limits-json", default='{"workers":2,"timeout_ms":1000,"fuel":10000000}')
    parser.add_argument("--mismatch-limit", type=int, default=20)
    parser.add_argument("--tenant-memory-growth-kib", type=int, default=8192)
    parser.add_argument("--child-timeout-seconds", type=int, default=180)
    parser.add_argument("--mode", choices=["native"], help=argparse.SUPPRESS)
    args = parser.parse_args()
    if not 1 <= args.cases <= 100 or not 0 <= args.mismatch_limit <= 40:
        parser.error("require 1..100 cases and 0..40 retained mismatches")
    if not 1 <= args.child_timeout_seconds <= 1800 or args.tenant_memory_growth_kib < 1:
        parser.error("require a 1..1800-second child timeout and positive handle memory bound")
    limits = json.loads(args.limits_json)
    if not isinstance(limits, dict) or not 1 <= limits.get("workers", 2) <= 8 or not 1 <= limits.get("timeout_ms", 5000) <= 10000:
        parser.error("qualification allows 1..8 workers and 1..10000 ms per query")
    if args.mode:
        native_child(args)
        return
    validation_hash = digest(args.validation)
    if validation_hash != args.validation_sha256:
        raise ValueError("validation hash mismatch")
    receipt = read_json(args.image_receipt, 1024 * 1024)
    capabilities = receipt.get("capabilities", {})
    if receipt.get("source_sha256") != args.source_sha256:
        raise ValueError("image receipt binds a different knowledge base")
    if not isinstance(capabilities.get("reader"), str) or not capabilities["reader"].startswith("oracle-reader-tables-v"):
        raise ValueError("image receipt has no learned reader capability")
    image_hash = receipt.get("image_sha256")
    if not isinstance(image_hash, str) or len(image_hash) != 64:
        raise ValueError("image receipt has no image digest")
    # Image opening in the fresh child verifies actual image bytes against this
    # receipt. The parent deliberately never imports or opens the native image.
    cases, population = select_cases(args.validation,args.cases_file,args.cases,args.seed)
    work = Path(args.work)
    work.mkdir(parents=True,exist_ok=False)
    write_json(work / "cases.json",cases)
    command = [sys.executable,"-B",str(Path(__file__).resolve()),"--mode","native",
               "--image",str(Path(args.image).resolve()),"--image-receipt",str(Path(args.image_receipt).resolve()),
               "--validation",str(Path(args.validation).resolve()),"--work",str(work.resolve()),
               "--limits-json",args.limits_json,"--tenant-memory-growth-kib",str(args.tenant_memory_growth_kib)]
    started = time.perf_counter()
    try:
        process = subprocess.run(command,capture_output=True,text=True,check=False,timeout=args.child_timeout_seconds)
    except subprocess.TimeoutExpired as error:
        write_json(work / "report.json",{"schema":"oracle-native-whole-reader-v1","run_status":"incomplete",
                   "failure":"native child timeout","cases_sha256":digest(work / "cases.json"),
                   "validation_sha256":validation_hash,"timeout_seconds":args.child_timeout_seconds,
                   "captured_stdout":clip((error.stdout or b"").decode() if isinstance(error.stdout,bytes) else (error.stdout or "")),
                   "captured_stderr":clip((error.stderr or b"").decode() if isinstance(error.stderr,bytes) else (error.stderr or ""))})
        raise
    wall_seconds = time.perf_counter()-started
    process_record = {"returncode":process.returncode,"wall_seconds":wall_seconds,
                      "stdout":clip(process.stdout,8192),"stderr":clip(process.stderr,8192)}
    write_json(work / "native-process.json",process_record)
    if process.returncode:
        write_json(work / "report.json",{"schema":"oracle-native-whole-reader-v1","run_status":"incomplete",
                   "failure":"native child failed","process":process_record,"image_receipt":receipt,
                   "cases_sha256":digest(work / "cases.json"),"validation_sha256":validation_hash})
        raise RuntimeError(f"native reader child failed; see {work / 'native-process.json'}")
    child = json.loads(process.stdout)
    observations = read_json(work / "native-observations.json",4*1024*1024)
    metrics = read_json(work / "native-process-metrics.json",4*1024*1024)
    results = summary(cases,observations)
    mismatches = [{"case":{"source_index":case["source_index"],"terminal":case["terminal"],
                           "question":clip(case["question"]),"gold":clip(case["gold"])},"native":observation}
                  for case,observation in zip(cases,observations,strict=True)
                  if observation["outcome"] != "answered_correct"][:args.mismatch_limit]
    write_json(work / "mismatches.json",mismatches)
    report = {"schema":"oracle-native-whole-reader-v1","run_status":"complete",
              "scope":"bounded real questions through native whole and exact fragment/outer templates; no full reader/Engine or specialist-panel claim",
              "coverage":COVERAGE,
              "reference":{"upstream_whole_reader":"not run; no upstream Reader/Engine constructed",
                           "comparison":"dataset gold exact strings; no case-folding, date/unit normalization or tolerance"},
              "python":sys.version,"platform":platform.platform(),"load_average":os.getloadavg(),
              "validation_sha256":validation_hash,"image_receipt":receipt,"native":child["provenance"],
              "limits_overrides":limits,"sample":{"seed":args.seed,"bound":args.cases,"selected":len(cases),
                  **population,"cases_sha256":digest(work / "cases.json"),
                  "sampling_pool_sha256":digest(args.cases_file) if args.cases_file else validation_hash},
              "results":results,"metrics":metrics,"native_process_wall_seconds":wall_seconds,
              "retained_mismatches":len(mismatches),"mismatch_limit":args.mismatch_limit,
              "artifacts":{"cases":"cases.json","observations":"native-observations.json",
                           "mismatches":"mismatches.json","process":"native-process.json",
                           "metrics":"native-process-metrics.json"}}
    write_json(work / "report.json",report)
    print(json.dumps(report,indent=2))
    if results["counts"]["answered_wrong"] or results["counts"]["errors"] or not metrics["tenant_memory_check"]["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
