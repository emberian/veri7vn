#!/usr/bin/env python3
"""Verify a native-compile input manifest without invoking its binary or receipt code."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath


HEX = re.compile(r"^[0-9a-f]{64}$")
BASENAME = re.compile(r"^input-[0-9]+\.(?:sml|sig|fun|ml|ML)$")
BASIS = "$(SML_LIB)/basis/basis.mlb"
SCOPE = ("hash and manifest consistency only; does not independently establish theorem soundness, "
         "compiler/toolchain integrity, natural-language interpretation, or model truth")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def under(path: Path, root: Path, label: str, *, must_exist: bool = True) -> Path:
    """Resolve a receipt path and keep it inside the explicitly selected repository."""
    candidate = path if path.is_absolute() else root / path
    resolved = candidate.resolve(strict=must_exist)
    if not resolved.is_relative_to(root):
        raise ValueError(f"{label} escapes repository root")
    if candidate.is_symlink():
        raise ValueError(f"{label} is a symlink")
    return resolved


def read_json(path: Path, root: Path, label: str) -> dict:
    resolved = under(path, root, label)
    if not resolved.is_file():
        raise ValueError(f"{label} is not a file")
    try:
        value = json.loads(resolved.read_text(encoding="utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"{label} is not valid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{label} is not a JSON object")
    return value


def checked_map(value, label: str) -> dict[str, str]:
    if not isinstance(value, dict) or not value:
        raise ValueError(f"{label} is missing or empty")
    result = {}
    for key, value in value.items():
        if not isinstance(key, str) or not isinstance(value, str) or not HEX.fullmatch(value):
            raise ValueError(f"{label} contains a malformed SHA-256 entry")
        result[key] = value
    return result


def safe_relative(value: str, label: str) -> Path:
    path = Path(value)
    if not value or path.is_absolute() or ".." in path.parts or path == Path("."):
        raise ValueError(f"{label} must be a nonempty relative path without '..'")
    return path


def proof_sources(root: Path, session: str) -> dict[str, str]:
    """Read ROOT declarations to inventory the named session's project proof closure."""
    root = root.resolve(strict=True)
    source_root = root / "src"
    sessions: dict[str, tuple[Path, set[str]]] = {}
    for root_file in source_root.rglob("ROOT"):
        if root_file.is_symlink():
            raise ValueError("proof source tree contains a symlink: " + str(root_file))
        text = root_file.read_text(encoding="utf-8")
        text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.S)
        for block in re.split(r"(?m)^\s*(?=session\s)", text):
            header = re.match(r"\s*session\s+\"?([\w.-]+)\"?", block)
            if header:
                sessions[header[1]] = (
                    root_file.parent,
                    set(re.findall(r"Veri7vn_\w+", block[header.end():])),
                )
    todo, seen, directories = [session], set(), set()
    while todo:
        name = todo.pop()
        if name in seen:
            continue
        seen.add(name)
        if name not in sessions:
            if name == session or name.startswith("Veri7vn_"):
                raise ValueError("unknown project session in proof snapshot: " + name)
            continue
        directory, parents = sessions[name]
        directories.add(directory)
        todo.extend(parents)
    if not directories:
        raise ValueError("proof session has no project ROOT closure")
    result = {}
    for directory in directories:
        for path in directory.rglob("*"):
            if not path.is_file() or not (path.suffix in (".thy", ".ML") or path.name == "ROOT"):
                continue
            if path.is_symlink() or not path.resolve().is_relative_to(root):
                raise ValueError("proof source escapes snapshot: " + str(path))
            # A nested ROOT belongs only to the session directories selected above.
            nearest_root = next((p for p in path.parents if (p / "ROOT").is_file()), None)
            if nearest_root in directories:
                result[str(path.relative_to(root))] = digest(path)
    return result


def export_inventory(directory: Path, root: Path) -> dict[str, str]:
    directory = under(directory, root, "proof export directory")
    if not directory.is_dir():
        raise ValueError("proof export directory is missing")
    found = {}
    for path in directory.rglob("*"):
        if path.is_symlink():
            raise ValueError("proof export contains a symlink: " + str(path))
        if path.is_file():
            found[path.relative_to(directory).as_posix()] = digest(path)
    return found


def difference(expected: dict[str, str], actual: dict[str, str]) -> list[str]:
    return sorted(key for key in set(expected) | set(actual) if expected.get(key) != actual.get(key))


def verify(manifest_path: Path, repo: Path, *, binary_path: Path | None = None,
           check_current_source: bool = False) -> dict:
    repo = repo.resolve(strict=True)
    manifest_path = under(manifest_path, repo, "manifest")
    record = read_json(manifest_path, repo, "manifest")
    failures: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            failures.append(message)

    require(record.get("schema_version") == 1, "unsupported native-input manifest schema")
    require(record.get("compile_ok") is True and record.get("compiler_exit") == 0,
            "native compiler did not record a successful compile")
    session = record.get("session")
    require(isinstance(session, str) and bool(session), "session is missing")
    if failures:
        return {"ok": False, "manifest": str(manifest_path), "scope": SCOPE, "errors": failures}

    try:
        raw_snapshot = Path(record["snapshot_dir"])
        snapshot = under(raw_snapshot if raw_snapshot.is_absolute() else manifest_path.parent / raw_snapshot,
                         repo, "snapshot_dir")
        canonical_manifest = snapshot / "compile-inputs.json"
        canonical_record = read_json(canonical_manifest, repo, "snapshot manifest")
        require(canonical_record == record, "selected manifest differs from immutable snapshot manifest")

        inputs = checked_map(record.get("inputs_sha256"), "inputs_sha256")
        frozen = checked_map(record.get("frozen_inputs_sha256"), "frozen_inputs_sha256")
        input_map = record.get("input_snapshot_map")
        if not isinstance(input_map, dict) or not input_map:
            raise ValueError("input_snapshot_map is missing or empty")
        if any(not isinstance(k, str) or not isinstance(v, str) for k, v in input_map.items()):
            raise ValueError("input_snapshot_map contains a malformed path")
        if set(input_map) - set(inputs):
            raise ValueError("input_snapshot_map names an input absent from inputs_sha256")
        original_mlbs = [key for key in inputs if Path(key).suffix.lower() == ".mlb"]
        if len(original_mlbs) != 1 or set(inputs) != set(input_map) | set(original_mlbs):
            raise ValueError("inputs_sha256 must cover mapped sources and exactly one original MLB")
        if any(not HEX.fullmatch(value) for value in inputs.values()):
            raise ValueError("inputs_sha256 contains a malformed SHA-256")

        frozen_names = list(input_map.values())
        if len(set(frozen_names)) != len(frozen_names):
            raise ValueError("input_snapshot_map has duplicate frozen destinations")
        for name in frozen_names:
            if not BASENAME.fullmatch(name):
                raise ValueError("frozen input path is not a safe input basename: " + name)
        rewritten_name = Path(record.get("rewritten_mlb", "")).name
        if rewritten_name != "input.mlb" or not Path(record["rewritten_mlb"]).is_absolute():
            raise ValueError("rewritten_mlb must name the absolute snapshot input.mlb")
        if set(frozen) != set(frozen_names) | {rewritten_name}:
            raise ValueError("frozen_inputs_sha256 does not exactly cover the MLB closure")
        if set(inputs) != set(input_map) | set(original_mlbs):
            raise ValueError("original inputs do not exactly match the frozen input map")
        for original, name in input_map.items():
            if inputs[original] != frozen[name]:
                raise ValueError("original/frozen input hashes differ: " + name)

        for name, expected in frozen.items():
            if name != rewritten_name and not BASENAME.fullmatch(name):
                raise ValueError("frozen input path is unsafe: " + name)
            path = under(snapshot / name, repo, "frozen input")
            require(path.is_file(), "frozen input is missing: " + name)
            if path.is_file():
                require(digest(path) == expected, "frozen input hash mismatch: " + name)

        mlb = under(snapshot / rewritten_name, repo, "rewritten MLB")
        require(Path(record["rewritten_mlb"]).resolve() == mlb,
                "rewritten_mlb is not the snapshot input.mlb")
        entries = [line.strip() for line in mlb.read_text(encoding="utf-8").splitlines() if line.strip()]
        application = [line for line in entries if line != BASIS]
        require(entries.count(BASIS) == 1, "rewritten MLB must contain one standard basis entry")
        require(len(application) == len(frozen_names) and sorted(application) == sorted(frozen_names),
                "rewritten MLB entries do not match input_snapshot_map")

        canonical = record.get("canonical_source_map", {})
        source_hashes = checked_map(record.get("source_sha256", {}), "source_sha256") if canonical else {}
        if not isinstance(canonical, dict):
            raise ValueError("canonical_source_map is malformed")
        derived_sources: dict[str, str] = {}
        for original, relative in canonical.items():
            if original not in input_map:
                raise ValueError("canonical source is not an actual frozen input: " + str(original))
            rel = safe_relative(relative, "canonical source")
            key = rel.as_posix()
            if key in derived_sources:
                raise ValueError("canonical source map has duplicate repository paths")
            derived_sources[key] = inputs[original]
        require(source_hashes == derived_sources, "source_sha256 differs from actual canonical inputs")

        generated = record.get("generated_sha256")
        if not isinstance(generated, str) or not HEX.fullmatch(generated):
            raise ValueError("generated_sha256 is malformed")
        generated_inputs = [name for original, name in input_map.items() if inputs[original] == generated]
        require(len(generated_inputs) == 1, "generated export is not consumed exactly once")

        binary = under(Path(record.get("binary", "")), repo, "compiled binary")
        expected_binary = record.get("binary_sha256")
        if not isinstance(expected_binary, str) or not HEX.fullmatch(expected_binary):
            raise ValueError("binary_sha256 is malformed")
        require(binary.is_file(), "compiled binary is missing")
        if binary.is_file():
            require(digest(binary) == expected_binary, "compiled binary hash mismatch")
        if binary_path is not None:
            selected_binary = under(binary_path, repo, "selected binary")
            require(selected_binary.is_file(), "selected binary is missing")
            if selected_binary.is_file():
                require(digest(selected_binary) == expected_binary, "selected binary hash differs from manifest")

        session_receipt = record.get("session_receipt")
        if not isinstance(session_receipt, dict):
            raise ValueError("session_receipt is missing")
        receipt_path = under(Path(session_receipt.get("path", "")), repo, "proof receipt")
        receipt_record = read_json(receipt_path, repo, "proof receipt")
        expected_receipt_hash = session_receipt.get("sha256")
        require(isinstance(expected_receipt_hash, str) and digest(receipt_path) == expected_receipt_hash,
                "proof receipt hash differs from manifest")
        require(receipt_record == session_receipt.get("record"),
                "embedded proof receipt differs from retained receipt")
        require(receipt_record.get("session") == session, "proof receipt session differs from native manifest")
        require(receipt_record.get("status") == "passed" and receipt_record.get("exit_code") == 0,
                "proof receipt is not a passed build")
        require(receipt_record.get("exports_published") is True,
                "proof receipt did not publish exports")
        remote = receipt_record.get("remote")
        if not isinstance(remote, dict):
            raise ValueError("proof receipt has no remote result")
        require(remote.get("cancelled", False) is False and remote.get("exit_code") == 0,
                "proof receipt records cancellation or a failed remote build")
        if "build_completed" in remote:
            require(remote.get("build_completed") is True and remote.get("build_exit") == 0,
                    "proof receipt lacks successful in-service completion evidence")
        source_inventory = read_json(receipt_path.with_name("source-sha256.json"), repo,
                                     "proof source inventory")
        source_digest = hashlib.sha256(
            json.dumps(source_inventory, sort_keys=True).encode("utf-8")).hexdigest()
        require(source_digest == receipt_record.get("source_digest"),
                "proof receipt source inventory digest mismatch")
        require(remote.get("source_digest") == receipt_record.get("source_digest"),
                "proof receipt local and remote source digests differ")

        export_hashes = checked_map(receipt_record.get("export_sha256"), "proof receipt export_sha256")
        export_rel = record.get("generated_export")
        if not isinstance(export_rel, str):
            raise ValueError("generated_export is missing")
        safe_export = PurePosixPath(export_rel)
        if safe_export.is_absolute() or ".." in safe_export.parts or not safe_export.parts:
            raise ValueError("generated_export path is unsafe")
        export_key = safe_export.as_posix()
        require(export_key in export_hashes, "generated export is absent from proof receipt")
        proof_export_dir = receipt_path.parent / "results" / "export" / session
        require(export_inventory(proof_export_dir, repo) == export_hashes,
                "actual proof exports differ from proof receipt")
        actual_generated = under(proof_export_dir / Path(*safe_export.parts), repo, "generated export")
        require(actual_generated.is_file(), "generated export file is missing")
        if actual_generated.is_file():
            require(digest(actual_generated) == generated == export_hashes.get(export_key),
                    "generated export hashes do not agree")

        proof_hashes = checked_map(record.get("proof_dependency_sha256"), "proof_dependency_sha256")
        context = record.get("proof_source_context")
        proof_snapshot = record.get("proof_snapshot_dir")
        if context == "receipt_snapshot":
            if not isinstance(proof_snapshot, str):
                raise ValueError("retained proof context has no proof_snapshot_dir")
            proof_root = under(Path(proof_snapshot), repo, "proof snapshot")
            require(proof_root == receipt_path.parent,
                    "proof snapshot does not match the retained proof receipt directory")
        elif context in ("current_checkout", None):
            require(proof_snapshot is None, "current proof context unexpectedly names a retained snapshot")
            proof_root = receipt_path.parent
        else:
            raise ValueError("unknown proof_source_context")
        recorded_proofs = proof_sources(proof_root, session)
        require(recorded_proofs == proof_hashes,
                "proof dependency hashes do not match receipt source snapshot")

        current = {"status": "not_checked", "proof_context": context or "unspecified"}
        if check_current_source:
            runtime_differences = []
            for relative, expected in derived_sources.items():
                try:
                    source = under(repo / safe_relative(relative, "canonical source"), repo,
                                   "current canonical source")
                    if not source.is_file() or digest(source) != expected:
                        runtime_differences.append(relative)
                except (OSError, ValueError):
                    runtime_differences.append(relative)
            try:
                live_proofs = proof_sources(repo, session)
                proof_differences = difference(proof_hashes, live_proofs)
                current_status = "match" if not runtime_differences and not proof_differences else "different"
                current_error = None
            except (OSError, UnicodeError, ValueError) as exc:
                proof_differences = []
                current_status = "unavailable"
                current_error = str(exc)
            current = {
                "status": current_status,
                "proof_context": context or "unspecified",
                "runtime_differences": runtime_differences,
                "proof_differences": proof_differences,
                "error": current_error,
                "recorded_at_compile": {
                    "proof_differences": record.get("current_proof_differences"),
                    "error": record.get("current_proof_error"),
                    "matches": record.get("current_proofs_match"),
                },
            }

        return {
            "ok": not failures,
            "manifest": str(manifest_path),
            "snapshot_dir": str(snapshot),
            "family": record.get("family"),
            "session": session,
            "proof_source_context": context or "unspecified",
            "scope": SCOPE,
            "verified": {
                "frozen_inputs": len(frozen),
                "generated_export": export_key,
                "binary_sha256": expected_binary,
                "proof_dependencies": len(proof_hashes),
            },
            "current_source": current,
            "errors": failures,
        }
    except (KeyError, OSError, UnicodeError, ValueError, TypeError) as exc:
        failures.append(str(exc))
        return {"ok": False, "manifest": str(manifest_path), "scope": SCOPE, "errors": failures}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", required=True, type=Path,
                        help="compile-inputs.json or its successful build/ convenience copy")
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2],
                        help="checkout root containing the snapshots (default: this checkout)")
    parser.add_argument("--binary", type=Path,
                        help="optional selected binary to compare with the immutable compile hash")
    parser.add_argument("--check-current-source", action="store_true",
                        help="separately report current runtime/proof differences; retained proof snapshots may differ")
    args = parser.parse_args()
    report = verify(args.receipt, args.repo, binary_path=args.binary,
                    check_current_source=args.check_current_source)
    print(json.dumps(report, sort_keys=True, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
