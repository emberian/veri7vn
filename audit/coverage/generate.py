"""Deterministic source inventory, not a behavioral coverage or verification claim.

Run from any directory: python audit/coverage/generate.py [--check].
Requires the pinned upstream checkout; never imports or runs upstream Python.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
UP = ROOT / "upstream"
OUT = ROOT / "audit/coverage"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build() -> dict:
    revision = subprocess.check_output(
        ["git", "-C", str(UP), "rev-parse", "HEAD"], text=True
    ).strip()
    availability_path = ROOT / "audit/results/availability.json"
    availability = json.loads(availability_path.read_text())
    if availability["revision"] != revision:
        raise SystemExit("Availability evidence belongs to a different upstream revision; regenerate it first.")
    missing_domains = {x["specialist"] for x in availability["unregistered_domains"]}
    rows = []
    for path in sorted((UP / "root/specialists").glob("*/manifest.json")):
        manifest = json.loads(path.read_text())
        organ = manifest["organ"]
        module = path.parent / (organ["module"] + ".py")
        cls = organ["class"]
        if cls in {"RelationOrganV2", "RelationOrganV2G"}:
            family = "relation-readers"
        elif cls in {"FactsOrgan", "FactsOrganBoundary"}:
            family = "ordered-fact-rules"
        elif cls in {"SiteOrgan", "SiteOrganV3"}:
            family = "stateful-site"
        elif cls == "SpringsOrgan":
            family = "quantity-computation"
        else:
            family = "needs-semantic-classification"
        rows.append({
            "id": path.parent.name,
            "declared_id": manifest.get("id"),
            "manifest": str(path.relative_to(ROOT)),
            "manifest_sha256": digest(path),
            "module": str(module.relative_to(ROOT)),
            "module_sha256": digest(module) if module.exists() else None,
            "class": cls,
            "family": family,
            "declared_kinds": manifest.get("accept", {}).get("kinds", []),
            "domain_missing_from_registry": path.parent.name in missing_domains,
            "migration_record": "audit/coverage/decisions.json#" + path.parent.name,
        })
    classes = collections.Counter(row["class"] for row in rows)
    families = collections.Counter(row["family"] for row in rows)
    # Retain the entire Python denominator, including old folds, utilities, panels,
    # and training code. Membership alone says nothing about runtime reachability.
    sources = [{"path": str(p.relative_to(ROOT)), "sha256": digest(p),
                "disposition": "needs_reachability_and_role_review",
                "work_package": "coverage-disposition"}
               for p in sorted(UP.rglob("*.py"))]
    index = subprocess.check_output(["git", "-C", str(UP), "ls-files", "--stage", "-z"])
    tracked = []
    for entry in index.decode().split("\0"):
        if not entry:
            continue
        metadata, name = entry.split("\t", 1)
        mode, blob, stage = metadata.split()
        tracked.append({"path": "upstream/" + name, "git_blob": blob,
                        "mode": mode, "stage": int(stage),
                        "disposition": "needs_role_review",
                        "work_package": "coverage-disposition"})
    inventory_path = ROOT / "audit/results/inventory.json"
    inventory = json.loads(inventory_path.read_text())
    if inventory["revision"] != revision:
        raise SystemExit("Source inventory evidence belongs to a different upstream revision; regenerate it first.")
    return {
        "schema_version": 1,
        "upstream_revision": revision,
        "scope": "Source inventory; statuses do not certify full audits, reachability, or implemented lifts.",
        "availability_evidence": {
            "path": str(availability_path.relative_to(ROOT)),
            "sha256": digest(availability_path),
            "required_missing_at_audit": availability["required_missing"],
        },
        "inventory_evidence": {
            "path": str(inventory_path.relative_to(ROOT)),
            "sha256": digest(inventory_path),
            "fold_count": inventory["fold_count"],
            "runtime_reachability": "not_exhaustively_classified",
        },
        "counts": {
            "specialist_manifests": len(rows),
            "distinct_class_names": len(classes),
            "python_files": len(sources),
            "tracked_files": len(tracked),
            "families": dict(sorted(families.items())),
            "class_names_are_not_distinct_semantics": True,
        },
        "specialists": rows,
        "python_sources": sources,
        "tracked_files_note": "Git index identities, not hashes of materialized LFS payloads or generated/unpacked files. Python list separately hashes working-copy source content. Every indexed path remains a role-review item until explicitly disposed.",
        "tracked_files": tracked,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if recorded inventory is stale")
    args = parser.parse_args()
    data = build()
    encoded = json.dumps(data, indent=2, sort_keys=True) + "\n"
    target = OUT / "inventory.json"
    if args.check:
        if not target.exists() or target.read_text() != encoded:
            raise SystemExit("Coverage inventory is stale; run audit/coverage/generate.py and inspect the diff.")
    else:
        target.write_text(encoded)
    print(json.dumps(data["counts"], sort_keys=True))


if __name__ == "__main__":
    main()
