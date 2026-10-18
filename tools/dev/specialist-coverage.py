#!/usr/bin/env python3
"""Inventory shipped specialists and cite available semantic, measurement, and receipt evidence."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
REGISTRY = REPO / "src/extract/families.json"
UPSTREAM = REPO / "upstream"
LANE_ROOT = REPO / "project/lanes"
REL_RE = re.compile(r"^rel-")
COUNTEREXAMPLE_RE = re.compile(
    r"\b(counterexample|misread|misparsed|misinterpret\w*|wrongly|incorrectly|"
    r"wrong (?:answer|result|value|output)|incorrect (?:answer|result|value|output)|"
    r"(?:answer|result|value|output) (?:is|was|became|returned) (?:wrong|incorrect)|"
    r"treated as|(?:was|is) read as|silently (?:accept\w*|return\w*|treat\w*)|"
    r"instead of|rather than)\b", re.I)
CHANGE_RE = re.compile(r"\b(fix(?:ed|es)?|repair(?:ed|s)?|implemented|now computes|restored|added|supports)\b", re.I)
LIMIT_RE = re.compile(r"\b(remain(?:s|ing)?|unsupported|not implemented|outside|limit(?:s|ation)?|withhold)\b", re.I)
DELTA_RE = re.compile(r"(?:\bfrom\b.{0,60}\bto\b|\b(?:before|after)\b|→|\bimprov\w*\b|\brecover\w*\b)", re.I)
MEASURE_RE = re.compile(r"\b(?:shipped|heldout|dev|seed|probes?|cases?)\b.{0,50}\b\d+\s*/\s*\d+|\b\d+\s*/\s*\d+.{0,50}\b(?:shipped|heldout|dev|seed|probes?|cases?)\b", re.I)
SEMANTIC_RE = re.compile(r"semantic|counterexample|examined|frontier|known next|gap|remaining|limit|model boundary", re.I)

# Mirrors the current deputy-family areas in project/CODEX-2026-10-18.md.
OWNER_BY_FAMILY = {
    "acoustics": "physical", "emoptics": "physical", "energy": "physical",
    "geostats": "physical", "mechanics": "physical", "quantity": "physical",
    "space": "physical", "variants": "physical",
    "anatomyagri": "natural", "chemistry": "natural", "climate": "natural",
    "earth": "natural", "finance": "natural", "life": "natural",
    "materials": "natural", "trades": "natural",
    "computing": "symbolic", "discrete": "symbolic", "facts": "symbolic",
    "humanities": "symbolic", "stores": "symbolic",
}
OWNER_MAPPING_SOURCE = "project/CODEX-2026-10-18.md#Ownership for the next wave"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None


def load_verifier():
    """Load the fixed in-repository verifier, never a path supplied by a receipt."""
    path = Path(__file__).with_name("verify-native-inputs.py")
    spec = importlib.util.spec_from_file_location("coverage_native_input_verifier", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load tools/dev/verify-native-inputs.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def panel_counts(folder: Path, upstream_root: Path, manifest: dict) -> dict:
    panel_meta = manifest.get("panel") or {}
    raw_path = panel_meta.get("path", "panel.json")
    if not isinstance(raw_path, str):
        return {"status": "invalid_manifest_panel_path", "dev_items": None, "heldout_items": None}
    resolved_path = raw_path.replace("__ORACLE7_ROOT__", str(upstream_root / "root"))
    candidate = Path(resolved_path)
    if not candidate.is_absolute():
        candidate = folder / candidate
    try:
        panel_path = candidate.resolve(strict=True)
        allowed = upstream_root.resolve(strict=True)
        if not panel_path.is_relative_to(allowed) or not panel_path.is_file():
            raise ValueError("panel path outside upstream")
    except (OSError, ValueError):
        return {"status": "panel_missing_or_outside_upstream", "dev_items": None, "heldout_items": None}
    panel = read_json(panel_path)
    if isinstance(panel, dict):
        dev = panel.get("dev") or []
        heldout = panel.get("heldout") or []
    elif isinstance(panel, list):
        dev = [item for item in panel if isinstance(item, dict) and item.get("split") == "dev"]
        heldout = [item for item in panel if isinstance(item, dict) and item.get("split") == "heldout"]
    else:
        return {"status": "panel_unreadable", "dev_items": None, "heldout_items": None}
    if not isinstance(dev, list) or not isinstance(heldout, list):
        return {"status": "panel_malformed", "dev_items": None, "heldout_items": None}
    return {"status": "available", "dev_items": len(dev), "heldout_items": len(heldout),
            "path": str(panel_path.relative_to(upstream_root))}


def capability_declaration(repo: Path, family: str, specialist: str, is_relation: bool, manifest: dict) -> dict:
    if is_relation:
        accept = manifest.get("accept") or {}
        return {"kind": "shared_relation_reader_declaration", "source": f"upstream/root/specialists/{specialist}/manifest.json",
                "accepted_kinds": accept.get("kinds", []), "declines_in_domain": accept.get("declines_in_domain", []),
                "reader_entries": len(manifest.get("readers") or [])}
    path = repo / "src/extract" / family / "capabilities.json"
    if not path.is_file():
        return {"kind": "unavailable", "source": str(path.relative_to(repo))}
    data = read_json(path)
    entry = (((data or {}).get("specialists") or {}).get(specialist))
    if not isinstance(entry, dict):
        return {"kind": "no_per_specialist_entry", "source": str(path.relative_to(repo))}
    accept = entry.get("accept") or {}
    evidence = entry.get("evidence") or {}
    return {
        "kind": "declaration_only",
        "source": str(path.relative_to(repo)),
        "accepted_kinds": accept.get("kinds", []),
        "declines_in_domain": accept.get("declines_in_domain", []),
        "assumptions": evidence.get("assumptions", []),
        "untrusted_inputs": evidence.get("untrusted", []),
    }


def collect_lane_evidence(repo: Path, lane_root: Path, semantic_files: list[Path], specialist_ids: list[str]) -> dict:
    docs = {}
    for path in sorted(lane_root.glob("*.md")):
        if path.name != "E-coverage-tool.md":
            docs[path] = "lane_report"
    for path in semantic_files:
        docs[path] = "semantic_gap_ledger"
    evidence = {sid: [] for sid in specialist_ids}
    for path, source_type in docs.items():
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError):
            continue
        heading = ""
        for line_number, line in enumerate(lines, 1):
            if line.startswith("#"):
                heading = line.lstrip("# ").strip()
            if not line.strip() or line.lstrip().startswith("|---"):
                continue
            for sid in specialist_ids:
                if not re.search(r"(?<![\w-])" + re.escape(sid) + r"(?![\w-])", line):
                    continue
                audit = source_type == "semantic_gap_ledger" or bool(SEMANTIC_RE.search(heading + " " + line))
                counterexample = bool(COUNTEREXAMPLE_RE.search(line))
                change = bool(CHANGE_RE.search(line))
                limitation = bool(LIMIT_RE.search(line))
                measurement = bool(MEASURE_RE.search(line))
                delta = bool(DELTA_RE.search(line))
                # Avoid counting result-only panel rows as a semantic audit.
                if not any((audit, counterexample, change, limitation, measurement)):
                    continue
                tags = []
                if audit:
                    tags.append("semantic_record")
                if counterexample:
                    tags.append("counterexample_text")
                if change:
                    tags.append("reported_change")
                if limitation:
                    tags.append("limitation_text")
                if measurement:
                    tags.append("scoped_measurement_text")
                if change and measurement and delta:
                    tags.append("measured_delta_text")
                rel = path.relative_to(repo).as_posix()
                entry = {"source": rel, "line": line_number, "heading": heading,
                         "tags": tags, "excerpt": line.strip()[:420]}
                if entry not in evidence[sid]:
                    evidence[sid].append(entry)
    return evidence


def receipt_association(repo: Path, family: str, binary_rel: str, verifier) -> dict:
    family_root = repo / "var" / family
    alias = family_root / "build/compile-inputs.json"
    if alias.is_file():
        selected, source_type = alias, "build_alias"
    else:
        candidates = sorted(family_root.glob("native-attempts/*/compile-inputs.json"),
                            key=lambda p: (p.stat().st_mtime_ns, str(p)), reverse=True)
        if not candidates:
            return {"status": "unknown_no_compile_manifest", "manifest": None,
                    "binary": binary_rel, "source": None}
        selected, source_type = candidates[0], "latest_native_attempt"
    report = verifier.verify(selected, repo, check_current_source=True)
    current_binary = repo / binary_rel
    binary_matches = bool(report.get("ok") and current_binary.is_file()
                          and sha256(current_binary) == report.get("verified", {}).get("binary_sha256"))
    source_matches = report.get("current_source", {}).get("status") == "match"
    source_status = report.get("current_source", {}).get("status", "unknown")
    if not report.get("ok"):
        status = "immutable_mismatch"
    elif binary_matches and source_status == "match":
        status = "current_verified"
    elif not binary_matches and source_status == "different":
        status = "binary_mismatch_and_source_drift"
    elif not binary_matches and source_status == "unavailable":
        status = "registered_binary_mismatch_and_source_unavailable"
    elif not binary_matches:
        status = "registered_binary_mismatch"
    elif source_status == "different":
        status = "verified_source_drift"
    else:
        status = "current_source_unavailable"
    return {
        "status": status,
        "manifest": str(selected.relative_to(repo)),
        "source": source_type,
        "current_binary_path": binary_rel,
        "current_binary_matches": binary_matches,
        "current_source_status": source_status,
        "current_source_differences": {
            "runtime": report.get("current_source", {}).get("runtime_differences", []),
            "proof": report.get("current_source", {}).get("proof_differences", []),
        },
        "current_source_error": report.get("current_source", {}).get("error"),
        "receipt_proof_context": report.get("proof_source_context"),
        "errors": report.get("errors", []),
    }


def semantic_audit_backlog(records: list[dict]) -> dict:
    """Return ID-level leads where no exact-ID semantic/gap reference was found."""
    items = []
    for record in records:
        evidence = record["semantic_evidence"]
        if evidence["semantic_reference"] != "unknown":
            continue
        missing = ["semantic_audit_or_gap_reference"]
        cue_fields = ("counterexample_text", "reported_change_text", "measured_delta_text", "limitation_text")
        missing.extend(field for field in cue_fields if evidence[field] == "unknown")
        items.append({
            "id": record["id"],
            "kind": record["kind"],
            "family": record["family"],
            "owner_group": record["owner_group"],
            "missing_evidence_references": missing,
            "existing_text_cues": {field: evidence[field] for field in cue_fields
                                    if evidence[field] == "found"},
            "source_records": evidence["records"],
        })
    by_owner = {}
    for item in items:
        owner = item["owner_group"]
        by_owner[owner] = by_owner.get(owner, 0) + 1
    return {
        "format": "veri7vn.semantic-audit-backlog/1",
        "interpretation": "retrieval leads with no exact-ID semantic/gap reference in searched lane reports or ledgers; not a completed audit and not proof that no work exists",
        "owner_mapping_source": OWNER_MAPPING_SOURCE,
        "summary": {"id_count": len(items), "by_owner_group": by_owner},
        "items": items,
    }


AUDIT_RECORD_FIELDS = {
    "schema_version", "specialist_id", "family", "examined_surface", "cases",
    "actual_receipt", "native_binding", "current_unresolved_limits", "reviewer",
    "owner", "author_claims",
}


def resolve_repo_file(repo: Path, value, label: str) -> Path:
    if not isinstance(value, str) or not value:
        raise ValueError(f"{label} must be a repository-relative path")
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or path == Path("."):
        raise ValueError(f"{label} must be a repository-relative path without '..'")
    candidate = repo / path
    try:
        resolved = candidate.resolve(strict=True)
    except FileNotFoundError as exc:
        raise ValueError(f"{label} does not exist: {value}") from exc
    if not resolved.is_relative_to(repo) or not resolved.is_file():
        raise ValueError(f"{label} must name a file inside the repository")
    current = candidate
    while current != repo:
        if current.is_symlink():
            raise ValueError(f"{label} may not use symlinks")
        current = current.parent
    return resolved


def validate_audit_record(repo: Path, record: dict, known: dict[str, str], verifier) -> dict:
    """Validate record shape and referenced artifacts; keep author claims separate."""
    errors = []
    sid = record.get("specialist_id")
    missing_fields = sorted(AUDIT_RECORD_FIELDS - set(record))
    if missing_fields:
        errors.append("missing record fields: " + ", ".join(missing_fields))
    if type(record.get("schema_version")) is not int or record.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    unknown_fields = sorted(set(record) - AUDIT_RECORD_FIELDS)
    if unknown_fields:
        errors.append("unknown record fields: " + ", ".join(unknown_fields))
    if "validation" in record:
        errors.append("validation is tool-generated and cannot be supplied by the author")
    if not isinstance(sid, str) or not sid:
        errors.append("specialist_id is required")
    elif sid not in known:
        errors.append("unknown specialist_id")
    elif record.get("family") != known[sid]:
        errors.append("family does not match the current registry/manifest mapping")

    surface = record.get("examined_surface")
    if (not isinstance(surface, dict)
            or not isinstance(surface.get("request_types"), list)
            or not surface["request_types"]
            or not all(isinstance(item, str) and item.strip() for item in surface["request_types"])
            or not isinstance(surface.get("model_scope"), str)
            or not surface["model_scope"].strip()):
        errors.append("examined_surface needs request_types and model_scope")
    elif set(surface) - {"request_types", "model_scope"}:
        errors.append("examined_surface has unknown fields")

    cases = record.get("cases")
    if not isinstance(cases, list) or not cases:
        errors.append("cases must contain a counterexample or independently checked case")
    else:
        for index, case in enumerate(cases):
            label = f"cases[{index}]"
            if not isinstance(case, dict):
                errors.append(f"{label} must be an object")
                continue
            if case.get("kind") not in ("counterexample", "independently_checked_case"):
                errors.append(f"{label}.kind must be counterexample or independently_checked_case")
            allowed_case_fields = {"case_id", "kind", "request", "expected_boundary", "observed_behavior"}
            if case.get("kind") == "independently_checked_case":
                allowed_case_fields.add("independent_check")
            if set(case) - allowed_case_fields:
                errors.append(f"{label} has unknown fields")
            required = ("case_id", "request", "expected_boundary", "observed_behavior")
            if any(not isinstance(case.get(field), str) or not case[field].strip() for field in required):
                errors.append(f"{label} needs case_id, request, expected_boundary, and observed_behavior")
            if case.get("kind") == "independently_checked_case" and (
                    not isinstance(case.get("independent_check"), str)
                    or not case["independent_check"].strip()):
                errors.append(f"{label}.independent_check is required for independently checked cases")

    limits = record.get("current_unresolved_limits")
    if not isinstance(limits, list) or not all(isinstance(item, str) for item in limits):
        errors.append("current_unresolved_limits must be a list of strings")
    for field in ("reviewer", "owner"):
        if not isinstance(record.get(field), str) or not record[field].strip():
            errors.append(f"{field} is required")
    if not isinstance(record.get("author_claims"), dict):
        errors.append("author_claims must be an object")

    receipt_path = None
    receipt_digest = None
    try:
        receipt_path = resolve_repo_file(repo, record.get("actual_receipt"), "actual_receipt")
        receipt_digest = sha256(receipt_path)
    except (OSError, ValueError) as exc:
        errors.append(str(exc))

    native_validation = None
    native = record.get("native_binding")
    if native is not None:
        if not isinstance(native, dict):
            errors.append("native_binding must be null or an object")
        else:
            manifest_path = None
            binary_path = None
            try:
                manifest_path = resolve_repo_file(
                    repo, native.get("compile_inputs_manifest"), "native_binding.compile_inputs_manifest")
            except (OSError, ValueError) as exc:
                errors.append(str(exc))
            if native.get("registered_binary") is not None:
                try:
                    binary_path = resolve_repo_file(
                        repo, native["registered_binary"], "native_binding.registered_binary")
                except (OSError, ValueError) as exc:
                    errors.append(str(exc))
            unknown_native = sorted(set(native) - {"compile_inputs_manifest", "registered_binary"})
            if unknown_native:
                errors.append("unknown native_binding fields: " + ", ".join(unknown_native))
            if manifest_path is not None:
                native_report = verifier.verify(manifest_path, repo, binary_path=binary_path,
                                                check_current_source=True)
                native_validation = {
                    "compile_inputs_manifest": str(manifest_path.relative_to(repo)),
                    "manifest_sha256": sha256(manifest_path),
                    "registered_binary": str(binary_path.relative_to(repo)) if binary_path else None,
                    "immutable_receipt_valid": bool(native_report.get("ok")),
                    "verified_binary_sha256": native_report.get("verified", {}).get("binary_sha256"),
                    "current_source_status": native_report.get("current_source", {}).get("status", "unknown"),
                    "current_source_differences": {
                        "runtime": native_report.get("current_source", {}).get("runtime_differences", []),
                        "proof": native_report.get("current_source", {}).get("proof_differences", []),
                    },
                    "receipt_proof_context": native_report.get("proof_source_context"),
                    "errors": native_report.get("errors", []),
                }
                if not native_report.get("ok"):
                    errors.append("native binding receipt failed immutable/hash validation")

    return {
        "author_claims": record,
        "validation": {
            "status": "record_shape_and_receipt_valid" if not errors else "record_invalid",
            "errors": errors,
            "actual_receipt_path": str(receipt_path.relative_to(repo)) if receipt_path else None,
            "actual_receipt_sha256": receipt_digest,
            "native_binding": native_validation,
        },
    }


def read_audit_records(repo: Path, audit_dir: Path, records: list[dict], verifier) -> dict:
    by_id = {record["id"]: record for record in records}
    expected_family = {record["id"]: record["family"] for record in records}
    empty_by_kind = {
        title: {"ids_with_records": 0, "ids_with_shape_and_receipt_valid_records": 0,
                "ids_with_invalid_records": 0}
        for title in ("non_relation", "relation")
    }
    for record in records:
        record["explicit_audit_records"] = []
        record["explicit_audit_record_status"] = "not_recorded"
    if not audit_dir.exists():
        return {"directory": str(audit_dir.relative_to(repo)), "record_count": 0,
                "specialist_ids_with_records": 0, "record_shape_and_receipt_valid": 0,
                "invalid_records": 0, "by_kind": empty_by_kind, "unknown_ids": [],
                "duplicate_ids": [], "file_errors": [], "unmatched_records": []}
    if not audit_dir.is_dir():
        return {"directory": str(audit_dir.relative_to(repo)), "record_count": 0,
                "specialist_ids_with_records": 0, "record_shape_and_receipt_valid": 0,
                "invalid_records": 0, "by_kind": empty_by_kind, "unknown_ids": [],
                "duplicate_ids": [], "file_errors": [{"path": str(audit_dir.relative_to(repo)),
                                                        "error": "audit directory is not a directory"}],
                "unmatched_records": []}

    parsed = []
    file_errors = []
    for path in sorted(audit_dir.glob("*.audit.json")):
        try:
            if path.is_symlink() or not path.resolve(strict=True).is_relative_to(repo):
                raise ValueError("audit record path must remain inside the repository and cannot be a symlink")
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
            file_errors.append({"path": str(path.relative_to(repo)), "error": str(exc)})
            continue
        if not isinstance(value, dict):
            file_errors.append({"path": str(path.relative_to(repo)), "error": "record must be a JSON object"})
            continue
        parsed.append((path, value))

    id_counts = {}
    for _, value in parsed:
        sid = value.get("specialist_id")
        if isinstance(sid, str):
            id_counts[sid] = id_counts.get(sid, 0) + 1
    duplicate_ids = sorted(sid for sid, count in id_counts.items() if count > 1)
    unknown_ids = []
    unmatched_records = []
    for path, value in parsed:
        sid = value.get("specialist_id")
        result = validate_audit_record(repo, value, expected_family, verifier)
        if isinstance(sid, str) and id_counts.get(sid, 0) > 1:
            result["validation"]["errors"].append("duplicate specialist_id in audit directory")
            result["validation"]["status"] = "record_invalid"
        result["record_path"] = str(path.relative_to(repo))
        if isinstance(sid, str) and sid in by_id:
            by_id[sid]["explicit_audit_records"].append(result)
        else:
            unknown_ids.append(sid if isinstance(sid, str) else "<missing>")
            unmatched_records.append({
                "record_path": str(path.relative_to(repo)),
                "author_claims": value,
                "validation": result["validation"],
            })

    for record in records:
        entries = record["explicit_audit_records"]
        record["explicit_audit_record_status"] = (
            "not_recorded" if not entries else
            "record_present_valid" if len(entries) == 1 and entries[0]["validation"]["status"] == "record_shape_and_receipt_valid"
            else "record_present_invalid")
    flat = [entry for record in records for entry in record["explicit_audit_records"]]
    by_kind = {}
    for kind, title in (("specialist", "non_relation"), ("relation_reader", "relation")):
        group = [record for record in records if record["kind"] == kind]
        by_kind[title] = {
            "ids_with_records": sum(record["explicit_audit_record_status"] != "not_recorded" for record in group),
            "ids_with_shape_and_receipt_valid_records": sum(
                record["explicit_audit_record_status"] == "record_present_valid" for record in group),
            "ids_with_invalid_records": sum(
                record["explicit_audit_record_status"] == "record_present_invalid" for record in group),
        }
    return {
        "directory": str(audit_dir.relative_to(repo)),
        "record_count": len(parsed),
        "specialist_ids_with_records": sum(bool(record["explicit_audit_records"]) for record in records),
        "record_shape_and_receipt_valid": sum(entry["validation"]["status"] == "record_shape_and_receipt_valid"
                                               for entry in flat),
        "invalid_records": (sum(entry["validation"]["status"] == "record_invalid" for entry in flat)
                            + sum(entry["validation"]["status"] == "record_invalid"
                                  for entry in unmatched_records)),
        "by_kind": by_kind,
        "unknown_ids": sorted(set(unknown_ids)),
        "duplicate_ids": duplicate_ids,
        "file_errors": file_errors,
        "unmatched_records": unmatched_records,
    }


def build_report(repo: Path = REPO, upstream: Path | None = None, registry_path: Path | None = None,
                 lane_root: Path | None = None, include_receipts: bool = True,
                 audit_dir: Path | None = None) -> dict:
    repo = repo.resolve(strict=True)
    upstream = (upstream or repo / "upstream").resolve(strict=True)
    registry_path = Path(registry_path or repo / "src/extract/families.json").resolve(strict=True)
    lane_root = Path(lane_root or repo / "project/lanes").resolve(strict=True)
    audit_dir = Path(audit_dir or "var/coverage/audits")
    if not audit_dir.is_absolute():
        audit_dir = repo / audit_dir
    audit_dir = audit_dir.resolve(strict=False)
    if not audit_dir.is_relative_to(repo):
        raise ValueError("audit directory must be inside the repository")
    registry = read_json(registry_path)
    if not isinstance(registry, dict) or not isinstance(registry.get("families"), list):
        raise ValueError("family registry is missing or malformed")

    family_by_id = {}
    family_meta = {}
    registry_id_occurrences = []
    for family in registry["families"]:
        if family.get("role", "specialist") == "specialist":
            family_meta[family["family"]] = family
            for sid in family.get("specialists", []):
                registry_id_occurrences.append(sid)
                family_by_id[sid] = family["family"]

    specialists_root = upstream / "root/specialists"
    manifests = {}
    manifest_issues = []
    for folder in sorted(specialists_root.iterdir()):
        if not folder.is_dir():
            continue
        path = folder / "manifest.json"
        if not path.is_file():
            # upstream also has non-specialist support directories such as _cards and _gate.
            continue
        manifest = read_json(path)
        if not isinstance(manifest, dict) or not isinstance(manifest.get("id"), str):
            manifest_issues.append(f"unreadable specialist manifest: {folder.name}")
            continue
        sid = manifest["id"]
        if sid in manifests:
            manifest_issues.append(f"duplicate upstream specialist id: {sid}")
            continue
        manifests[sid] = (folder, manifest)

    nonrelation_ids = sorted(sid for sid in manifests if not REL_RE.match(sid))
    relation_ids = sorted(sid for sid in manifests if REL_RE.match(sid))
    registry_ids = sorted(family_by_id)
    if set(registry_ids) != set(nonrelation_ids):
        manifest_issues.append("registry and upstream non-relation specialist identity sets differ")
    if len(registry_id_occurrences) != len(set(registry_id_occurrences)):
        manifest_issues.append("duplicate specialist in family registry")
    if any(sid not in manifests for sid in registry_ids):
        manifest_issues.append("registry names a specialist without an upstream manifest")

    semantic_files = sorted((repo / "src/extract").glob("*/semantic-gaps.md"))
    all_ids = sorted(set(nonrelation_ids) | set(relation_ids))
    evidence = collect_lane_evidence(repo, lane_root, semantic_files, all_ids)
    verifier = load_verifier() if include_receipts else None
    receipt_cache = {}

    def family_receipt(family: str, binary: str) -> dict:
        key = (family, binary)
        if key not in receipt_cache:
            receipt_cache[key] = receipt_association(repo, family, binary, verifier)
        return receipt_cache[key]

    records = []
    for sid in all_ids:
        folder, manifest = manifests[sid]
        is_relation = bool(REL_RE.match(sid))
        family = "relations" if is_relation else family_by_id.get(sid)
        baseline = panel_counts(folder, upstream, manifest)
        dev_verdict = (folder / "verdict_dev.json").is_file()
        heldout_verdict = (folder / "verdict_heldout.json").is_file()
        baseline["dev_verdict_file"] = dev_verdict
        baseline["heldout_verdict_file"] = heldout_verdict
        if baseline["status"] == "available":
            baseline["status"] = ("files_complete" if dev_verdict and heldout_verdict
                                  else "panel_available_verdict_incomplete")
        generator_files = sorted(p.name for p in folder.glob("*_panel_v*.py") if p.is_file())

        rows = evidence[sid]
        tags = {tag for row in rows for tag in row["tags"]}
        semantic_status = "reference_found" if "semantic_record" in tags else "unknown"
        ev = {
            "semantic_reference": semantic_status,
            "counterexample_text": "found" if "counterexample_text" in tags else "unknown",
            "reported_change_text": "found" if "reported_change" in tags else "unknown",
            "measured_delta_text": "found" if "measured_delta_text" in tags else "unknown",
            "limitation_text": "found" if "limitation_text" in tags else "unknown",
            "records": rows[:8],
            "additional_record_count": max(0, len(rows) - 8),
        }
        binary = ("var/relations/bin/decide" if is_relation else
                  family_meta.get(family, {}).get("binary", ""))
        association = (family_receipt(family, binary)
                       if include_receipts and family and binary else
                       {"status": "not_checked"})
        records.append({
            "id": sid,
            "kind": "relation_reader" if is_relation else "specialist",
            "family": family,
            "owner_group": "symbolic" if is_relation else OWNER_BY_FAMILY.get(family, "unmapped"),
            "upstream_manifest": str((folder / "manifest.json").relative_to(upstream)),
            "shipped_baseline": baseline,
            "upstream_generator_source_available": bool(generator_files),
            "upstream_generator_files": generator_files,
            "capability_declaration": capability_declaration(repo, family or "", sid, is_relation, manifest),
            "semantic_evidence": ev,
            "receipt_association": association,
        })

    audit_files = list(audit_dir.glob("*.audit.json")) if audit_dir.is_dir() else []
    audit_verifier = verifier if include_receipts else (load_verifier() if audit_files else None)
    audit_summary = read_audit_records(repo, audit_dir, records, audit_verifier)

    def count(field, expected):
        return sum(1 for row in records if row["kind"] == expected and row[field])

    def axis_count(kind, axis, value):
        return sum(1 for row in records if row["kind"] == kind and row["semantic_evidence"][axis] == value)

    summary = {}
    for kind, title in (("specialist", "non_relation"), ("relation_reader", "relation")):
        group = [row for row in records if row["kind"] == kind]
        summary[title] = {
            "unique_id_count": len(group),
            "shipped_panel_files_complete": sum(row["shipped_baseline"]["status"] == "files_complete" for row in group),
            "shipped_baseline_status_counts": {
                status: sum(row["shipped_baseline"]["status"] == status for row in group)
                for status in sorted({row["shipped_baseline"]["status"] for row in group})
            },
            "upstream_generator_source_available": sum(row["upstream_generator_source_available"] for row in group),
            "semantic_reference_found": axis_count(kind, "semantic_reference", "reference_found"),
            "semantic_reference_unknown": axis_count(kind, "semantic_reference", "unknown"),
            "counterexample_text_found": axis_count(kind, "counterexample_text", "found"),
            "reported_change_text_found": axis_count(kind, "reported_change_text", "found"),
            "measured_delta_text_found": axis_count(kind, "measured_delta_text", "found"),
            "limitation_text_found": axis_count(kind, "limitation_text", "found"),
        }
    family_receipts = {}
    if include_receipts:
        family_receipts = {family: family_receipt(
            family, meta.get("binary", "")) for family, meta in sorted(family_meta.items())}
        family_receipts["relations(shared kernel)"] = family_receipt(
            "relations", "var/relations/bin/decide")
    return {
        "format": "veri7vn.specialist-coverage/1",
        "generated_from": {"registry": str(registry_path.relative_to(repo)),
                           "upstream_specialists": "upstream/root/specialists",
                           "lane_reports": str(lane_root.relative_to(repo))},
        "interpretation": {
            "identity": "one record per upstream specialist manifest id; repeated panel or probe runs are not added together",
            "baseline": "file availability and shipped panel split sizes only; no scorer is executed and counts are not a veri7vn result",
            "semantic": "exact-id text references in all Markdown lane reports except this generated report and in semantic-gap ledgers; evidence tags are retrieval cues, not proof of correctness or exhaustive audits",
            "capabilities": "declarations from capabilities.json or upstream relation manifests; declarations are not executed evidence",
            "receipts": "family-level immutable input/binary association; current_verified means valid receipt, registered binary, and current sources all match; mismatch statuses name binary and/or source drift separately; proof snapshot context is reported independently",
        },
        "summary": {
            "total_unique_ids": len(records),
            "identity_reconciliation": {
                "registry_nonrelation_ids": len(registry_ids),
                "upstream_nonrelation_manifests": len(nonrelation_ids),
                "upstream_relation_manifests": len(relation_ids),
                "issues": manifest_issues,
            },
            "by_kind": summary,
            "family_receipts": family_receipts,
            "explicit_audit_records": audit_summary,
        },
        "specialists": records,
        "semantic_audit_backlog": semantic_audit_backlog(records),
    }


def markdown(report: dict) -> str:
    summary = report["summary"]
    identity = summary["identity_reconciliation"]
    def md_cell(value):
        return str(value).replace("|", "\\|").replace("\n", " ")

    lines = [
        "# Specialist surface coverage inventory",
        "",
        f"Generated from the registry and shipped manifests: **{summary['total_unique_ids']} unique IDs** "
        f"({identity['registry_nonrelation_ids']} non-relation, {identity['upstream_relation_manifests']} relation readers).",
        "",
        "This inventory records available files and cited reports. It does not rerun panels or scorers. Repeated panels, "
        "fresh seeds, and authored probes are listed as evidence references, never summed as independent surface coverage. "
        "A build receipt or capability declaration does not mean a specialist is semantically complete.",
        "",
        "| Surface | IDs | Shipped panel files | Semantic reference | Explicit audit records | Counterexample text | Change text | Measured delta text | Limits text |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for kind, label in (("non_relation", "Non-relation specialists"), ("relation", "Relation readers")):
        row = summary["by_kind"][kind]
        explicit = summary["explicit_audit_records"]["by_kind"][kind]
        lines.append("| %s | %d | %d | %d | %d | %d | %d | %d | %d |" % (
            label, row["unique_id_count"], row["shipped_panel_files_complete"],
            row["semantic_reference_found"], explicit["ids_with_records"],
            row["counterexample_text_found"],
            row["reported_change_text_found"], row["measured_delta_text_found"],
            row["limitation_text_found"]))
    lines.extend(["", "## Per-specialist inventory", "",
                  "`reference_found` means matching specialist-ID text appears in a semantic/gap section or ledger; it does not mean the audit is complete. "
                  "`found` values for change, counterexample, delta, and limits are text cues with file/line citations, not independently reviewed classifications.",
                  "",
                  "| ID | Family | Owner group | Baseline files | Semantic ref | Explicit audit record | Counterexample | Change | Delta | Limits | Receipt association |",
                  "|---|---|---|---|---|---|---|---|---|---|---|"])
    for item in report["specialists"]:
        baseline = item["shipped_baseline"]
        panel = baseline.get("status", "unknown")
        if baseline.get("dev_items") is not None:
            panel += f" ({baseline['dev_items']} dev / {baseline['heldout_items']} heldout)"
        ev = item["semantic_evidence"]
        receipt = item["receipt_association"].get("status", "not_checked")
        lines.append(f"| `{item['id']}` | {item.get('family') or 'unmapped'} | {item['owner_group']} | {panel} | "
                  f"{ev['semantic_reference']} | {item['explicit_audit_record_status']} | "
                  f"{ev['counterexample_text']} | {ev['reported_change_text']} | "
                  f"{ev['measured_delta_text']} | {ev['limitation_text']} | {receipt} |")
    audit_summary = summary["explicit_audit_records"]
    lines.extend(["", "## Explicit audit records", "",
                  f"Found {audit_summary['specialist_ids_with_records']} ID records in `{audit_summary['directory']}`. "
                  f"{audit_summary['record_shape_and_receipt_valid']} pass record-shape/artifact checks; "
                  f"{audit_summary['invalid_records']} are invalid. Tool validation checks paths and hashes; "
                  "it does not validate author claims, semantic conclusions, or completion.", ""])
    explicit_rows = [(item, entry) for item in report["specialists"]
                     for entry in item["explicit_audit_records"]]
    if explicit_rows:
        lines.extend(["| ID | Owner | Record path | Author model scope | Cases | Receipt path/hash | Validation | Unresolved limits |",
                      "|---|---|---|---:|---|---|---|---|"])
        for item, entry in explicit_rows:
            claims = entry["author_claims"]
            surface = claims.get("examined_surface", {})
            scope = surface.get("model_scope", "") if isinstance(surface, dict) else ""
            validation = entry["validation"]
            receipt = validation.get("actual_receipt_path") or claims.get("actual_receipt", "missing")
            digest = validation.get("actual_receipt_sha256") or "unverified"
            cases = claims.get("cases")
            case_count = len(cases) if isinstance(cases, list) else "?"
            raw_limits = claims.get("current_unresolved_limits", [])
            limits = "; ".join(str(limit) for limit in raw_limits) if isinstance(raw_limits, list) else str(raw_limits)
            lines.append(f"| `{item['id']}` | {md_cell(item['owner_group'])} | `{md_cell(entry['record_path'])}` | "
                         f"{md_cell(scope)} | {case_count} | `{md_cell(receipt)}` / `{md_cell(digest)}` | "
                         f"{md_cell(validation['status'])} | {md_cell(limits)} |")
    else:
        lines.append("No explicit audit records were supplied.")
    lines.extend(["", "## Receipt association by family", ""])
    if report["summary"].get("family_receipts"):
        lines.extend(["| Family | Status | Selected manifest | Binary matches | Current source |",
                      "|---|---|---|---:|---|"])
        for family, receipt in report["summary"]["family_receipts"].items():
            lines.append(f"| `{family}` | {receipt['status']} | {receipt.get('manifest') or '—'} | "
                         f"{receipt.get('current_binary_matches', '—')} | {receipt.get('current_source_status', '—')} |")
    else:
        lines.append("Receipt checks were disabled.")
    lines.extend(["", "## Limits", "",
                  "Panel sizes and verdict-file presence show that an Oracle7 baseline is available; they are not a fresh run of veri7vn. "
                  "Text retrieval can miss implicit evidence and can retrieve historical notes. Unknown means this generator found no qualifying record, not that no work exists. "
                  "Receipt status separates immutable verification, registered-binary matching, current-source drift, and unavailable sources; proof snapshot context is separate. These hash checks do not establish theorem truth, natural-language correctness, or full dispatcher behavior.", ""])
    if identity["issues"]:
        lines.extend(["Identity inventory issues:", ""])
        lines.extend(f"- {issue}" for issue in identity["issues"])
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=REPO)
    parser.add_argument("--upstream", type=Path, help="Oracle7 root containing root/specialists")
    parser.add_argument("--registry", type=Path, help="family registry (default src/extract/families.json)")
    parser.add_argument("--lanes", type=Path, help="lane report directory (default project/lanes)")
    parser.add_argument("--no-receipts", action="store_true", help="skip native manifest/binary association checks")
    parser.add_argument("--format", choices=("json", "markdown"), default="json")
    parser.add_argument("--json-out", type=Path, help="write machine-readable inventory to this file")
    parser.add_argument("--markdown-out", type=Path, help="also write concise Markdown inventory to this file")
    parser.add_argument("--backlog-out", type=Path,
                        help="write ID-level semantic-reference backlog as a separate JSON file")
    parser.add_argument("--audit-dir", type=Path,
                        help="read optional <specialist-id>.audit.json records from this directory (default var/coverage/audits)")
    args = parser.parse_args()
    repo = args.repo.resolve(strict=True)
    upstream = (args.upstream or repo / "upstream").resolve(strict=True)
    registry = args.registry or repo / "src/extract/families.json"
    lanes = args.lanes or repo / "project/lanes"
    report = build_report(repo, upstream, registry, lanes,
                          include_receipts=not args.no_receipts, audit_dir=args.audit_dir)
    encoded = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    rendered = encoded if args.format == "json" else markdown(report)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(encoded, encoding="utf-8")
    if args.markdown_out:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(markdown(report), encoding="utf-8")
    if args.backlog_out:
        args.backlog_out.parent.mkdir(parents=True, exist_ok=True)
        args.backlog_out.write_text(json.dumps(report["semantic_audit_backlog"], ensure_ascii=False,
                                               indent=2, sort_keys=True) + "\n", encoding="utf-8")
    output_paths = [path for path in (args.json_out, args.markdown_out, args.backlog_out) if path]
    if output_paths:
        identity = report["summary"]["identity_reconciliation"]
        backlog_count = report["semantic_audit_backlog"]["summary"]["id_count"]
        audit_summary = report["summary"]["explicit_audit_records"]
        destinations = ", ".join(str(path) for path in output_paths)
        status = "; identity issues: " + "; ".join(identity["issues"]) if identity["issues"] else ""
        audit_count = audit_summary["specialist_ids_with_records"]
        if audit_summary["invalid_records"] or audit_summary["unknown_ids"] or audit_summary["duplicate_ids"] or audit_summary["file_errors"]:
            status += (f"; audit-record issues: {audit_summary['invalid_records']} invalid, "
                      f"{len(audit_summary['unknown_ids'])} unknown IDs, "
                      f"{len(audit_summary['duplicate_ids'])} duplicate IDs, "
                      f"{len(audit_summary['file_errors'])} file errors")
        sys.stdout.write(f"Inventory: {report['summary']['total_unique_ids']} IDs; "
                         f"semantic-reference backlog: {backlog_count} IDs; "
                         f"explicit audit records: {audit_count}; wrote {destinations}{status}\n")
    else:
        sys.stdout.write(rendered)
    audit_summary = report["summary"]["explicit_audit_records"]
    audit_has_errors = bool(audit_summary["invalid_records"] or audit_summary["unknown_ids"]
                            or audit_summary["duplicate_ids"] or audit_summary["file_errors"])
    return 1 if report["summary"]["identity_reconciliation"]["issues"] or audit_has_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
