#!/usr/bin/env python3
"""Untrusted targeted composition comparison; neither a panel nor fleet score.

The cohort is fixed before either reader runs. Expected entities/counts come
from independent read-only SQL over the pinned source image, with explicit
finite-store coverage, typed attribute equality and concept membership. Learned
rows establish wording availability only; native programs and dataset gold
never establish expected answers. Empty/ambiguous selections require no answer.

Run control and candidate in separate fresh processes, retaining every case,
error and interpretation-family observation. Timing is descriptive only.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import time

import qualify_reader as common

SCHEMA = "oracle-targeted-composition-cases-v1"
DEFAULT_COHORT = Path(__file__).with_name("composition_cases_targeted_20261029.json")
MAX_ROWS = 1000
CLOSURE = """WITH RECURSIVE concepts(id) AS (
 VALUES(?) UNION SELECT p.child FROM parents p JOIN concepts c ON p.parent=c.id
 WHERE p.kind='concept') """
MEMBER = """EXISTS(SELECT 1 FROM parents p WHERE p.child=n.id AND p.kind='entity'
 AND p.parent IN (SELECT id FROM concepts))"""


def bounded_rows(db, sql, params=()):
    rows = db.execute(sql, params).fetchmany(MAX_ROWS + 1)
    if len(rows) > MAX_ROWS:
        raise ValueError("independent SQL result exceeds explicit 1000-row envelope")
    return [list(row) for row in rows]


def attribute_clause(attribute):
    if set(attribute) not in ({"key", "type", "value"}, {"key", "type", "value", "unit"}):
        raise ValueError("unexpected independent attribute fields")
    value = attribute["value"]
    if attribute["type"] == "string" and isinstance(value, str) and "unit" not in attribute:
        pass
    elif (attribute["type"] == "quantity" and type(value) is int
          and -(2**63) <= value < 2**63 and attribute.get("unit") == "1"):
        pass
    else:
        raise ValueError("cohort supports exact strings and integral unit-1 quantities only")
    clause = """EXISTS(SELECT 1 FROM attributes a WHERE a.subject=n.id AND a.key=?
     AND json_extract(a.value,'$.type')=? AND json_extract(a.value,'$.value')=?)"""
    params = [attribute["key"], attribute["type"], value]
    if "unit" in attribute:
        clause = clause[:-1] + " AND json_extract(a.value,'$.unit')=?)"
        params.append(attribute["unit"])
    return clause, params


def select_anchor(db, anchor, attributes):
    clauses, params = [MEMBER], [anchor["concept_id"]]
    for attribute in attributes:
        clause, bindings = attribute_clause(attribute)
        clauses.append(clause)
        params.extend(bindings)
    sql = CLOSURE + "SELECT DISTINCT n.id,n.name FROM nodes n WHERE n.kind='entity' AND "
    sql += " AND ".join(clauses) + " ORDER BY n.id"
    return bounded_rows(db, sql, params), {"sql": sql, "parameters": params}


def verify_source(cohort, image):
    if common.digest(image) != cohort["image"]["sha256"]:
        raise ValueError("actual image hash differs from predeclared source image")
    db = sqlite3.connect(Path(image).resolve().as_uri() + "?mode=ro&immutable=1", uri=True)
    db.execute("PRAGMA query_only=ON")
    work = [0]
    def progress():
        work[0] += 1
        return int(work[0] > 100_000)  # 100 million SQL VM instructions, all cases.
    db.set_progress_handler(progress, 1000)
    try:
        source = db.execute("SELECT value FROM metadata WHERE key='source_sha256'").fetchone()
        if source != (cohort["image"]["source_sha256"],):
            raise ValueError("image source provenance differs from predeclared KB")
        evidence = []
        for case in cohort["cases"]:
            anchor = case["source"]["anchor"]
            anchors, query = select_anchor(db, anchor, anchor["attributes"])
            individual = []
            for attribute in anchor["attributes"]:
                matches, single_query = select_anchor(db, anchor, [attribute])
                individual.append({"attribute": attribute, "matches": matches, **single_query})
            anchor_ids = [row[0] for row in anchors]
            targets, relation_rows, target_query = anchors, [], None
            if "incoming_relation" in case["source"]:
                relation = case["source"]["incoming_relation"]
                if anchor_ids:
                    marks = ",".join("?" for _ in anchor_ids)
                    sql = CLOSURE + """SELECT DISTINCT n.id,n.name FROM edges e
                     JOIN nodes n ON n.id=e.subject WHERE n.kind='entity'
                     AND e.direction='forward' AND e.predicate=? AND e.object IN (""" + marks + ") AND " + MEMBER + " ORDER BY n.id"
                    params = [relation["concept_id"], relation["predicate"], *anchor_ids]
                    targets = bounded_rows(db, sql, params)
                    target_query = {"sql": sql, "parameters": params}
                    relation_rows = bounded_rows(db, """SELECT e.subject,e.predicate,e.direction,
                     e.object,e.qualifiers FROM edges e WHERE e.direction='forward'
                     AND e.predicate=? AND e.object IN (""" + marks + ") ORDER BY e.subject,e.object,e.qualifiers", [relation["predicate"], *anchor_ids])
                else:
                    targets = []
            ids = [row[0] for row in targets]
            expected = case["expected"]
            if ids != expected["entity_ids"]:
                raise ValueError(f"predeclared source entities disagree for {case['id']}: {ids}")
            kind = expected["kind"]
            if kind == "entity":
                answer = targets[0][1] if len(targets) == 1 else None
                if answer != expected["answer"]:
                    raise ValueError(f"independent unique-name answer disagrees: {case['id']}")
            elif kind == "count":
                if not targets or str(len(targets)) != expected["answer"]:
                    raise ValueError(f"independent nonempty count disagrees: {case['id']}")
            elif kind == "decline_ambiguous":
                if len(targets) < 2 or expected["answer"] is not None:
                    raise ValueError(f"source ambiguity premise missing: {case['id']}")
            elif kind == "decline_empty":
                if targets or expected["answer"] is not None:
                    raise ValueError(f"source emptiness premise missing: {case['id']}")
            else:
                raise ValueError("unknown cohort expectation")
            source_rows = []
            for entity in anchor_ids:
                for attribute in anchor["attributes"]:
                    source_rows.extend(bounded_rows(db, """SELECT subject,key,position,value,qualifiers
                     FROM attributes WHERE subject=? AND key=? ORDER BY position""", [entity, attribute["key"]]))
            learned = []
            for family, template in case["wording"]["required_templates"]:
                rows = bounded_rows(db, """SELECT level,skeleton,support FROM reader_template
                 WHERE family=? AND template=? ORDER BY level,skeleton""", [family, template])
                if not rows:
                    raise ValueError(f"predeclared learned wording is absent: {family} {template}")
                learned.append({"family": family, "template": template,
                                "rows": len(rows), "rows_sha256": hashlib.sha256(common.canonical(rows).encode()).hexdigest()})
            absent = []
            for family, template in case["wording"]["absent_canonical_templates"]:
                count = db.execute("SELECT count(*) FROM reader_template WHERE family=? AND template=?", [family, template]).fetchone()[0]
                if count:
                    raise ValueError(f"canonical no-direct-template selection premise changed: {case['id']}")
                absent.append({"family": family, "template": template, "rows": count})
            evidence.append({"id": case["id"], "anchor_matches": anchors, "target_matches": targets,
                             "anchor_query": query, "target_query": target_query,
                             "individual_attribute_matches": individual,
                             "anchor_source_rows": source_rows, "relation_source_rows": relation_rows,
                             "learned_wording": learned, "absent_primary_canonical_wording": absent})
        return evidence
    finally:
        db.close()


def interpretation_families(readings):
    families = set()
    def inspect(template):
        try:
            value = json.loads(template)
        except (json.JSONDecodeError, TypeError):
            families.add("whole_or_exact_fragment")
            return
        if not isinstance(value, dict):
            return
        if "segments" in value:
            families.add("exact_segments")
        if "nested" in value:
            families.add("single_nested")
        for fragment in value.get("fragments", []):
            inspect(fragment.get("template"))
        for child in value.get("children", []):
            if isinstance(child, list) and len(child) == 4:
                inspect(child[2])
    for reading in readings:
        inspect(reading.get("template"))
    return sorted(families)


def observe(tenant, native, case, expected_coverage):
    started, cpu = time.perf_counter(), time.process_time()
    try:
        encoded = tenant.read_whole(case["question"], native.Cancellation())
        result = json.loads(encoded)
        if result.get("coverage") != expected_coverage:
            raise ValueError("native coverage differs from pinned artifact declaration")
        status, answer = result.get("status"), result.get("answer")
        if status == "answered":
            if not isinstance(answer, str) or result.get("distinct_answers") != [answer] or result.get("reason") is not None:
                raise ValueError("malformed agreed native answer")
            outcome = "answered_correct" if answer == case["expected"]["answer"] else "answered_wrong"
        elif status in {"unknown", "refused", "ambiguous"}:
            if answer is not None or not isinstance(result.get("reason"), str):
                raise ValueError("malformed native refusal")
            outcome = "declined_expected" if case["expected"]["kind"].startswith("decline_") else "unanswered"
        else:
            raise ValueError("unknown native status")
        readings = result.get("readings", [])
        return {"id": case["id"], "outcome": outcome, "status": status, "answer": answer,
                "reason": result.get("reason"), "distinct_answers": result.get("distinct_answers"),
                "matched_programs": result.get("matched_programs"), "readings": len(readings),
                "unsupported_programs": result.get("unsupported_programs"),
                "ambiguous_executions": result.get("ambiguous_executions"),
                "interpretation_families": interpretation_families(readings),
                "reading_program_hashes": sorted({hashlib.sha256(common.canonical(row["program"]).encode()).hexdigest() for row in readings}),
                "native_result_sha256": hashlib.sha256(encoded.encode()).hexdigest(),
                "seconds": time.perf_counter() - started, "cpu_seconds": time.process_time() - cpu}
    except Exception as error:
        return {"id": case["id"], "outcome": "errors", "error_type": type(error).__name__,
                "error": common.clip(str(error)), "seconds": time.perf_counter() - started,
                "cpu_seconds": time.process_time() - cpu}


def native_child(args, cohort):
    expected = cohort["artifacts"][args.label]
    if common.digest(args.extension) != expected["sha256"]:
        raise ValueError("extension bytes differ from predeclared artifact")
    spec = importlib.util.spec_from_file_location("oracle_native", str(Path(args.extension).resolve()))
    native = importlib.util.module_from_spec(spec)
    sys.modules["oracle_native"] = native
    spec.loader.exec_module(native)
    image = native.Image(args.image, cohort["image"]["sha256"], common.canonical(cohort["limits"]))
    runtime = native.Runtime.from_image(image, str(Path(args.work) / "state.sqlite"))
    tenant = runtime.tenant("targeted_composition_qualification")
    observations = []
    for case in cohort["cases"]:
        observations.append(observe(tenant, native, case, expected["coverage"]))
        if image.active_workers != 0:
            raise RuntimeError("serial targeted read did not release its worker")
    common.write_json(Path(args.work) / "observations.json", observations)
    print(common.canonical({"artifact": common.installed_provenance(native),
                            "counts": dict(Counter(row["outcome"] for row in observations)),
                            "timings": common.timings([row["seconds"] for row in observations])}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cohort", default=str(DEFAULT_COHORT))
    parser.add_argument("--image", required=True)
    parser.add_argument("--work", required=True, help="new scratch directory")
    parser.add_argument("--control-extension")
    parser.add_argument("--candidate-extension")
    parser.add_argument("--mode", choices=["native"], help=argparse.SUPPRESS)
    parser.add_argument("--label", choices=["control", "candidate"], help=argparse.SUPPRESS)
    parser.add_argument("--extension", help=argparse.SUPPRESS)
    args = parser.parse_args()
    cohort = common.read_json(args.cohort, 256 * 1024)
    cohort_digest = common.digest(args.cohort)
    cases = cohort.get("cases", [])
    if cohort.get("schema") != SCHEMA or not 1 <= len(cases) <= 32:
        raise ValueError("targeted cohort must contain 1..32 predeclared cases")
    ids = [case["id"] for case in cases]
    if len(set(ids)) != len(ids) or any(len(case["question"].encode()) > 65536 for case in cases):
        raise ValueError("duplicate case ids or oversized question")
    if args.mode:
        native_child(args, cohort)
        return
    if not args.control_extension or not args.candidate_extension:
        parser.error("require fixed control and candidate extension paths")
    work = Path(args.work)
    work.mkdir(parents=True, exist_ok=False)
    evidence = verify_source(cohort, args.image)
    common.write_json(work / "source-evidence.json", evidence)
    common.write_json(work / "predeclared-cohort.json", cohort)
    runs, observations = {}, {}
    for label in ["control", "candidate"]:
        directory = work / label
        directory.mkdir()
        extension = getattr(args, label + "_extension")
        command = [sys.executable, "-B", str(Path(__file__).resolve()), "--mode", "native",
                   "--label", label, "--extension", str(Path(extension).resolve()),
                   "--cohort", str((work / "predeclared-cohort.json").resolve()), "--image", str(Path(args.image).resolve()),
                   "--work", str(directory.resolve())]
        try:
            process = subprocess.run(command, capture_output=True, text=True, timeout=120, check=False)
        except subprocess.TimeoutExpired:
            common.write_json(directory / "process.json", {"failure": "child_timeout", "timeout_seconds": 120})
            raise
        common.write_json(directory / "process.json", {"returncode": process.returncode,
                           "stdout": common.clip(process.stdout, 16384), "stderr": common.clip(process.stderr, 16384)})
        if process.returncode:
            raise RuntimeError(f"{label} targeted native process failed; retained process.json")
        runs[label] = json.loads(process.stdout)
        observations[label] = common.read_json(directory / "observations.json", 16 * 1024 * 1024)
        if [row["id"] for row in observations[label]] != ids:
            raise ValueError("case order differs between predeclared cohort and observations")
    changes = [{"id": case["id"], "control": old, "candidate": new}
               for case, old, new in zip(cases, observations["control"], observations["candidate"], strict=True)]
    report = {"schema": SCHEMA, "scope": cohort["scope"], "selection": cohort["selection"],
              "script_sha256": common.digest(__file__), "helper_sha256": common.digest(common.__file__),
              "cohort_sha256": cohort_digest, "image": cohort["image"],
              "source_evidence_sha256": common.digest(work / "source-evidence.json"),
              "limits": cohort["limits"], "runs": runs, "cases": changes,
              "newly_correct_case_ids": [row["id"] for row in changes if row["control"]["outcome"] != "answered_correct" and row["candidate"]["outcome"] == "answered_correct"],
              "lost_correct_case_ids": [row["id"] for row in changes if row["control"]["outcome"] == "answered_correct" and row["candidate"]["outcome"] != "answered_correct"],
              "timing_boundary": "One control and one candidate fresh process, fixed order, warm filesystem; descriptive only, not a matched performance experiment.",
              "coverage_boundary": "Targeted construction from learned wording and source rows; no random/fleet/panel or full Reader7 claim. Primary canonical template absence does not exclude all lexical alternative readings."}
    common.write_json(work / "report.json", report)
    print(json.dumps(report, indent=2))
    if any(row["outcome"] in {"answered_wrong", "errors"} for rows in observations.values() for row in rows):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
