#!/usr/bin/env python3
"""Untrusted, Engine-free reference exporter for explicitly bounded public rows.

No upstream imports, dynamic programs, name linking, or Engine construction.
Every subject/property scope is queried without LIMIT; the artifact is a finite
projection, not an admission receipt for the full source or its other facts.
Receipt hashes/declared store hashes are reported separately from uncomputed
full-store hashes. Use --verify-store-hashes for independent whole-file checks.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sqlite3

U8_RECEIPT_SHA = "97286fb824bb102a24ac9e7458fc8d8426212ad0bff2b585bd00d6e0462d00a5"
RELATIONS = "root/relstore/relations_v2.sqlite3"


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def readonly(path):
    return sqlite3.connect(Path(path).resolve().as_uri() + "?mode=ro&immutable=1", uri=True)


def source_label(db, qid):
    row = db.execute("SELECT label,enwiki FROM entity WHERE qid=?", (qid,)).fetchone()
    return None if row is None else row[0] or row[1]


def export_u8(checkout, subjects, properties, verify_hash):
    checkout = Path(checkout)
    receipt_path = checkout / "APPLIANCE.json"
    receipt_hash = sha256(receipt_path)
    if receipt_hash != U8_RECEIPT_SHA:
        raise ValueError("unsupported U8 source receipt")
    receipt = json.loads(receipt_path.read_text())
    declared = next(item for item in receipt["stores"] if item["path"] == RELATIONS)
    store = checkout / RELATIONS
    if store.stat().st_size != declared["size"]:
        raise ValueError("declared U8 store size mismatch")
    observed = sha256(store) if verify_hash else None
    if observed is not None and observed != declared["sha256"]:
        raise ValueError("declared U8 store hash mismatch")
    scopes, entities = [], set(subjects)
    with readonly(store) as db:
        for subject in subjects:
            for prop in properties:
                rows = db.execute("SELECT p,o,lit FROM fact INDEXED BY fact_sp WHERE s=? AND p=? ORDER BY o,lit", (subject, prop)).fetchall()
                objects = sorted({obj for _p, obj, _literal in rows if obj})
                entities.update(objects)
                scopes.append({"subject": "wd:Q" + str(subject), "property": "wd:P" + str(prop),
                               "query": "SELECT p,o,lit FROM fact INDEXED BY fact_sp WHERE s=? AND p=? ORDER BY o,lit",
                               "parameters": [subject, prop], "limit": None,
                               "rows": [{"property": p, "object": obj, "literal": lit} for p, obj, lit in rows],
                               "object_ids": ["wd:Q" + str(obj) for obj in objects],
                               "unique_object_status": "unique" if len(objects) == 1 else "absent" if not objects else "ambiguous"})
        metadata = []
        for qid in sorted(entities):
            classes = db.execute("SELECT o,lit FROM fact INDEXED BY fact_sp WHERE s=? AND p=31 ORDER BY o,lit", (qid,)).fetchall()
            metadata.append({"id": "wd:Q" + str(qid), "label": source_label(db, qid),
                             "p31_rows": [{"object": obj, "literal": literal} for obj, literal in classes],
                             "is_person_direct_p31_q5": any(obj == 5 for obj, _literal in classes)})
    return {"source": "oracle7-slim-10.1/U8/relations_v2", "namespace": "wikidata",
            "receipt_sha256": receipt_hash, "store_relative_path": RELATIONS,
            "store_declared_sha256": declared["sha256"], "store_observed_sha256": observed,
            "store_bytes": store.stat().st_size, "coverage": "complete_rows_for_enumerated_subject_property_scopes_only",
            "scopes": scopes, "entities": metadata}


def export_native(image, receipt_path, subjects, verify_hash):
    receipt = json.loads(Path(receipt_path).read_text())
    image = Path(image)
    observed = sha256(image) if verify_hash else None
    if image.stat().st_size != receipt["bytes"] or observed is not None and observed != receipt["image_sha256"]:
        raise ValueError("native image size/hash mismatch")
    scopes = []
    with readonly(image) as db:
        for qid in subjects:
            subject = "Q" + str(qid)
            rows = db.execute("SELECT predicate,direction,object,qualifiers FROM edges WHERE subject=? AND predicate=? AND direction=? ORDER BY object,qualifiers",
                              (subject, "place of birth", "forward")).fetchall()
            objects = sorted({row[2] for row in rows})
            labels = [{"id": oid, "name": db.execute("SELECT name FROM nodes WHERE id=?", (oid,)).fetchone()[0]} for oid in objects]
            scopes.append({"subject": subject, "predicate": "place of birth", "direction": "forward", "limit": None,
                           "query": "SELECT predicate,direction,object,qualifiers FROM edges WHERE subject=? AND predicate=? AND direction=? ORDER BY object,qualifiers",
                           "parameters": [subject, "place of birth", "forward"],
                           "rows": [{"predicate": p, "direction": d, "object": obj, "qualifiers": json.loads(q)} for p, d, obj, q in rows],
                           "objects": labels, "unique_object_status": "unique" if len(objects) == 1 else "absent" if not objects else "ambiguous"})
    return {"source": "reader-image-v3", "namespace": "wikidata_declared_for_this_comparison",
            "receipt_sha256": sha256(receipt_path), "image_declared_sha256": receipt["image_sha256"],
            "image_observed_sha256": observed, "coverage": "complete_rows_for_enumerated_place_of_birth_scopes_only", "scopes": scopes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkout", type=Path, required=True)
    parser.add_argument("--qid", type=int, action="append", required=True, help="Explicit numeric source ID; never a label")
    parser.add_argument("--property", type=int, action="append", default=None)
    parser.add_argument("--native-image", type=Path)
    parser.add_argument("--native-receipt", type=Path)
    parser.add_argument("--verify-store-hashes", action="store_true")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    subjects, properties = sorted(set(args.qid)), sorted(set(args.property or [19]))
    if any(qid <= 0 for qid in subjects) or any(prop not in (19, 50) for prop in properties):
        parser.error("positive explicit IDs and finite properties P19/P50 required")
    if bool(args.native_image) != bool(args.native_receipt):
        parser.error("native image and receipt must be supplied together")
    result = {"format": "oracle_finite_relation_reference_v1", "exporter_sha256": sha256(__file__), "assurance": "untrusted_readonly_sql_export_not_full_source_admission",
              "u8": export_u8(args.checkout, subjects, properties, args.verify_store_hashes)}
    if args.native_image:
        result["native_image_comparison"] = export_native(args.native_image, args.native_receipt, subjects, args.verify_store_hashes)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
