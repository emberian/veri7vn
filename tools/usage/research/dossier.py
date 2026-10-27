#!/usr/bin/env python3
"""Untrusted research review aid; annotations never certify or rewrite Oracle answers.

Consumes retained run_batch rows without querying any service. Callers declare the
relation they need independently of Oracle. The tool compares *visible* property
IDs, provides navigation links for Wikidata IDs, and preserves opaque references.
This is a review queue, not a semantic entailment checker or source verification.
"""
import argparse
import copy
import json
import re
from collections import Counter
from pathlib import Path

IDENTIFIER = re.compile(r"(?<![A-Za-z0-9_])([QP][1-9][0-9]*)(?![A-Za-z0-9_])")


def visible_evidence(reply):
    """Do not mine replaced replies or arbitration hypotheses as current support."""
    answer = reply.get("response", "")
    refs = reply.get("references", [])
    strings = [answer] if isinstance(answer, str) else []
    if isinstance(refs, list):
        for ref in refs:
            if isinstance(ref, str):
                strings.append(ref)
            elif isinstance(ref, dict):
                # Unknown metadata remains in original_result, not evidence here.
                strings.extend(ref[k] for k in ("id", "text", "url")
                               if isinstance(ref.get(k), str))
    return strings


def annotate(row, requirements=None):
    requirements = requirements or {}
    envelope = row.get("response", {})
    reply = envelope.get("reply", {}) if isinstance(envelope, dict) else {}
    if not isinstance(reply, dict):
        reply = {}
    strings = visible_evidence(reply)
    identifiers = sorted(set(IDENTIFIER.findall("\n".join(strings))))
    properties = [i for i in identifiers if i.startswith("P")]
    expected = requirements.get("acceptable_properties", [])
    if not isinstance(expected, list) or any(not re.fullmatch(r"P[1-9][0-9]*", p)
                                            for p in expected):
        raise ValueError("acceptable_properties must be a list of Wikidata P IDs")
    flags = []
    if row.get("state") != "response" or row.get("http_status") != 200 or envelope.get("outcome") != "completed":
        flags.append("transport_or_runtime_failure")
    if reply.get("status") != "answered":
        flags.append("not_answered")
    elif expected and properties and not set(properties).intersection(expected):
        flags.append("property_mismatch")
    elif expected and not properties:
        flags.append("property_not_exposed")
    refs = reply.get("references")
    if reply.get("status") == "answered" and not refs:
        flags.append("no_structured_references")
    # Q IDs navigate to entities, not independently verified sources for the claim.
    links = [{"identifier": identifier,
              "url": "https://www.wikidata.org/wiki/" +
                     ("Property:" if identifier.startswith("P") else "") + identifier,
              "purpose": "navigation_only_not_verified_support"}
             for identifier in identifiers]
    return {
        "id": row.get("id"),
        "status": reply.get("status"),
        "review_flags": flags,
        "requested_relation": copy.deepcopy(requirements),
        "observed_property_ids": properties,
        "navigation": links,
        "original_result": copy.deepcopy(row),
    }


def build(rows, requirements=None):
    requirements = requirements or {}
    items = [annotate(row, requirements.get(row.get("id"), {})) for row in rows]
    counts = Counter(flag for item in items for flag in item["review_flags"])
    return {
        "assurance": "Untrusted review annotations. No answer is certified; navigation links have not been fetched. Original replies are preserved.",
        "counts": {"cases": len(items), "flag_counts": dict(sorted(counts.items()))},
        "items": items,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", type=Path, required=True)
    parser.add_argument("--requirements", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    rows = [json.loads(line) for line in args.results.read_text().splitlines() if line.strip()]
    requirements = json.loads(args.requirements.read_text()) if args.requirements else {}
    dossier = build(rows, requirements)
    # Never overwrite the runner's original evidence, even by a mistaken path.
    with args.out.open("x", encoding="utf-8") as handle:
        json.dump(dossier, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(json.dumps(dossier["counts"], sort_keys=True))


if __name__ == "__main__":
    main()
