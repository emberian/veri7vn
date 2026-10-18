"""UNTRUSTED requested-subject evidence for Relation_Request.

This reads exact additional property rows from the same immutable SQLite store.
Their completeness and authenticity are premises, as for the existing fetch.
The predicate itself is executed by the extracted HOL interpreter.
"""
import json

import fetch as F
import subject_request as SR

_ROWS = {}


def exact_rows(qid, prop):
    key = (qid, prop)
    if key not in _ROWS:
        _ROWS[key] = [
            [prop, ["e", obj] if obj else (["l", lit] if lit else ["b"])]
            for obj, lit in F.STORE.db.execute(
                "SELECT o, lit FROM fact INDEXED BY fact_sp WHERE s=? AND p=?", key)
        ]
    return _ROWS[key]


def attach(low, evidence):
    constraints = {}
    frames = []
    for attempt in evidence["attempts"]:
        if attempt["dir"] != "inv":
            continue
        compiled = F.RS2.compiled(F.key_of(attempt["key"]))
        match = compiled["inv"][attempt["idx"]].match(low)
        if match is None:
            constraint, frame = ["unknown"], None
        else:
            start, end = match.span("X")
            frame = low[:start] + "{target}" + low[end:]
            constraint = SR.recognize(attempt["prop"], frame)
        constraints[json.dumps(constraint, sort_keys=True)] = constraint
        frames.append(frame)
    # Multiple distinct requested kinds are not silently collapsed to the first.
    constraint = next(iter(constraints.values())) if len(constraints) == 1 else \
        (["unknown"] if constraints else ["any"])
    properties = sorted(SR.property_ids(constraint))
    for attempt in evidence["attempts"]:
        if attempt["dir"] == "inv":
            for subject in attempt["subjects"]:
                subject["rows"] = list(subject["rows"])
                for prop in properties:
                    subject["rows"].extend(exact_rows(subject["qid"], prop))
    evidence["subject_constraint"] = constraint
    evidence["subject_constraint_frames"] = frames
    evidence["subject_constraint_properties"] = properties
    return evidence
