"""UNTRUSTED requested-subject evidence for Relation_Request.

This reads exact additional property rows from the same immutable SQLite store.
Their completeness and authenticity are premises, as for the existing fetch.
The predicate itself is executed by the extracted HOL interpreter.
"""
import json

import fetch as F
import subject_request as SR
import query_request as QR

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


def attach(low, evidence, identity=False):
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
    excluded = [576] if identity and constraint == SR.KINDS["country"] else []
    properties = sorted(SR.property_ids(constraint) | set(excluded))
    for attempt in evidence["attempts"]:
        if attempt["dir"] == "inv":
            for subject in attempt["subjects"]:
                subject["rows"] = list(subject["rows"])
                for prop in properties:
                    subject["rows"].extend(exact_rows(subject["qid"], prop))
    evidence["subject_excluded_properties"] = excluded
    evidence["subject_constraint"] = constraint
    evidence["subject_constraint_frames"] = frames
    evidence["subject_constraint_properties"] = properties
    return evidence


def attach_query(query, evidence):
    """Supply literal property rows and separately identified object ancestry.
    Ontology authenticity/completeness remains an explicit external premise.
    """
    expression = QR.constraint(query)
    evidence['query_constraint'] = expression
    properties = QR.property_ids(expression)
    closures = {}
    for attempt in evidence['attempts']:
        if attempt['dir'] != 'fwd':
            continue
        for candidate in attempt['candidates']:
            candidate['rows'] = list(candidate['rows'])
            for prop in properties:
                rows = exact_rows(candidate['qid'], prop)
                candidate['rows'].extend(rows)
                for _, value in rows:
                    if value[0] == 'e':
                        closures[value[1]] = sorted(F.RS1.ancestors(value[1]))
    evidence['query_classes'] = sorted(closures.items())
    evidence['query_interpretation'] = None if query is None else {
        'property': query.prop, 'slot': query.slot, 'kind': query.query_kind,
        'canonical': query.canonical, 'frame': query.frame,
        'assumptions': ['whole-request recognition', 'supplied property rows',
                        'finite source ontology closure']}
    return evidence
