"""Untrusted, non-executing inspection of Oracle Workbench exam records.

The fixed runtime's exam.status/files_sha functions inspect a bounded captured
specialist folder. No specialist/scorer is imported, no exam is run, no held-out
item is disclosed, and no admission or Mini permission is granted. Saved verdicts
remain recorded claims, even when their file digest matches this snapshot.
"""
from __future__ import annotations

from contextlib import ExitStack
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import tempfile
import types

OPERATION = "workbench.specialists.inspect"
ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}\Z")
SHA = re.compile(r"[0-9a-f]{64}\Z")
MAX_FILE_BYTES = 2 * 1024 * 1024
MAX_TOTAL_BYTES = 8 * 1024 * 1024
MAX_ENTRIES = 256
MAX_DEPTH = 8
MAX_JSON_NODES = 50000


class InspectionError(ValueError):
    def __init__(self, reason, entry=None):
        self.reason, self.entry = reason, entry
        super().__init__(reason)


def _identity(st):
    return (st.st_dev, st.st_ino, st.st_mode, st.st_size, st.st_mtime_ns, st.st_ctime_ns)


def _read_regular(fd, size):
    if size > MAX_FILE_BYTES:
        raise InspectionError("file_budget_exceeded")
    chunks, total = [], 0
    while True:
        piece = os.read(fd, min(65536, MAX_FILE_BYTES + 1 - total))
        if not piece:
            break
        chunks.append(piece)
        total += len(piece)
        if total > MAX_FILE_BYTES:
            raise InspectionError("file_budget_exceeded")
    return b"".join(chunks)


def _json(raw, entry):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate key")
            result[key] = value
        return result
    def integer(value):
        if len(value) > 64:
            raise ValueError("oversized integer")
        return int(value)
    def floating(value):
        result = float(value)
        if not math.isfinite(result):
            raise ValueError("nonfinite number")
        return result
    try:
        value = json.loads(raw, object_pairs_hook=pairs, parse_int=integer,
                           parse_float=floating,
                           parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite number")))
        pending, nodes = [(value, 0)], 0
        while pending:
            current, depth = pending.pop()
            nodes += 1
            if depth > 32 or nodes > MAX_JSON_NODES:
                raise ValueError("JSON structure budget")
            if isinstance(current, dict):
                for key in current:
                    key.encode("utf-8")
                pending.extend((v, depth + 1) for v in current.values())
            elif isinstance(current, list):
                pending.extend((v, depth + 1) for v in current)
            elif isinstance(current, str):
                current.encode("utf-8")
        return value
    except (ValueError, UnicodeError, RecursionError) as error:
        raise InspectionError("invalid_json", entry) from error


def _small(value, maximum=256):
    return value if isinstance(value, str) and len(value) <= maximum else None


def _metrics(value):
    """Only numeric measurement fields; failure rows may contain held-out answers."""
    if not isinstance(value, dict):
        return {}
    allowed = {"ok", "correct", "fy", "false_yes", "wrong", "n", "taken", "cap",
               "swept_in", "p50_ms", "budget_ms", "gain_needed", "store_mb"}
    return {key: number for key, number in value.items() if key in allowed
            and type(number) in (int, float) and 0 <= number <= 1e15
            and math.isfinite(number)}


def _verdict_summary(verdict, origin, sha256):
    if verdict is None:
        return None
    if not isinstance(verdict, dict):
        raise InspectionError("invalid_verdict_object")
    groups = {}
    for key in ("head", "with_specialist", "core"):
        if isinstance(verdict.get(key), dict):
            groups[key] = _metrics(verdict[key])
    domain = verdict.get("domain")
    if isinstance(domain, dict):
        groups["domain"] = {key: _metrics(domain[key]) for key in ("head", "spec") if key in domain}
    return {"origin": origin, "record_sha256": sha256, "id": _small(verdict.get("id"), 80),
            "split": _small(verdict.get("split"), 32), "decision": _small(verdict.get("decision"), 32),
            "recorded_at": _small(verdict.get("time"), 80),
            "runtime_tip": _small(verdict.get("core_head")) or _small(verdict.get("head")),
            "metrics": _metrics(verdict), "groups": groups,
            "identity_checks_passed": verdict.get("self_ok") if type(verdict.get("self_ok")) is bool else None,
            "recorded_reason_count": len(verdict.get("reasons", [])) if isinstance(verdict.get("reasons"), list) else None,
            "recorded_failure_count": len(verdict.get("fails", [])) if isinstance(verdict.get("fails"), list) else None,
            "execution_observed_by_inspector": False}


class ExamInspection:
    def __init__(self, runtime, workspace):
        self.runtime = Path(runtime).resolve()
        self.workspace = Path(workspace).resolve()
        if self.runtime == self.workspace or self.runtime in self.workspace.parents or self.workspace in self.runtime.parents:
            raise ValueError("runtime and workspace must be disjoint")

    def catalog(self):
        return [{"id": OPERATION, "name": "Inspect specialist exam records",
            "description": "Read declarations and recorded exam results; check snapshot file binding without executing specialist code or consuming held-out tests.",
            "group": "workbench", "availability": "live_direct" if (self.runtime / "workbench/exam.py").is_file() else "unavailable",
            "input_schema": {"type": "object", "additionalProperties": False,
                "properties": {"specialist_id": {"type": "string", "pattern": "^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$", "minLength": 1, "maxLength": 80},
                               "location": {"type": "string", "enum": ["packaged", "workspace"], "default": "packaged"},
                               "dev_examples": {"type": "integer", "minimum": 0, "maximum": 3, "default": 0}},
                "required": ["specialist_id"]},
            "output_schema": {"type": "object", "required": ["status"]}, "units": {},
            "sources": [{"path": "workbench/exam.py", "functions": ["status", "files_sha"]}],
            "implementation": "Fixed Oracle7 workbench/exam.py inspection functions on a captured folder",
            "examples": [{"arguments": {"specialist_id": "meteorology-v2", "location": "packaged"}}],
            "limitations": ["Recorded results are not newly measured or independently authenticated.",
                            "Workbench admission does not establish live runtime registration or Mini permission.",
                            "At most 256 entries, 2 MiB per file, 8 MiB total, and eight directory levels.",
                            "No held-out question or answer is returned; dev examples are declarations."]}]

    def invoke(self, operation_id, arguments):
        if operation_id != OPERATION:
            raise ValueError("unknown exam inspection operation")
        if not isinstance(arguments, dict) or set(arguments) - {"specialist_id", "location", "dev_examples"} or "specialist_id" not in arguments:
            raise ValueError("invalid inspection arguments")
        sid = arguments["specialist_id"]
        location = arguments.get("location", "packaged")
        example_count = arguments.get("dev_examples", 0)
        if not isinstance(sid, str) or not ID.fullmatch(sid):
            raise ValueError("specialist_id must be a simple ASCII identifier")
        if location not in ("packaged", "workspace") or type(example_count) is not int or not 0 <= example_count <= 3:
            raise ValueError("invalid inspection location or dev_examples")
        try:
            return self._inspect(sid, location, example_count)
        except InspectionError as error:
            return {"status": "withheld", "reason": error.reason, "entry": error.entry,
                    "specialist_id": sid, "location": location, "exam_executed": False}
        except (OSError, UnicodeError) as error:
            return {"status": "withheld", "reason": "inspection_io_refused", "error_type": type(error).__name__,
                    "specialist_id": sid, "location": location, "exam_executed": False}

    def _open(self, stack, path, flags, parent=None):
        fd = os.open(path, flags | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent)
        stack.callback(os.close, fd)
        return fd

    def _capture(self, base, parts, destination):
        checks, captured = [], {}
        count, total = 0, 0
        with ExitStack() as stack:
            parent = self._open(stack, str(base), os.O_RDONLY | os.O_DIRECTORY)
            for part in parts:
                try:
                    child = self._open(stack, part, os.O_RDONLY | os.O_DIRECTORY, parent)
                except FileNotFoundError as error:
                    raise InspectionError("specialist_not_found") from error
                checks.append((child, parent, part, _identity(os.fstat(child))))
                parent = child
            root_fd = parent
            def walk(fd, relative, depth):
                nonlocal count, total
                if depth > MAX_DEPTH:
                    raise InspectionError("directory_depth_exceeded")
                initial = _identity(os.fstat(fd))
                names = []
                with os.scandir(fd) as entries:
                    for entry in entries:
                        if count + len(names) >= MAX_ENTRIES:
                            raise InspectionError("entry_budget_exceeded")
                        names.append(entry.name)
                for name in sorted(names):
                    count += 1
                    if count > MAX_ENTRIES:
                        raise InspectionError("entry_budget_exceeded")
                    rel = relative / name
                    label = rel.as_posix()
                    if len(label.encode("utf-8")) > 512:
                        raise InspectionError("path_budget_exceeded")
                    st = os.stat(name, dir_fd=fd, follow_symlinks=False)
                    if stat.S_ISLNK(st.st_mode):
                        raise InspectionError("symlink_refused", label)
                    if stat.S_ISDIR(st.st_mode):
                        child = self._open(stack, name, os.O_RDONLY | os.O_DIRECTORY, fd)
                        if _identity(os.fstat(child)) != _identity(st):
                            raise InspectionError("snapshot_changed", label)
                        checks.append((child, fd, name, _identity(st)))
                        (destination / rel).mkdir()
                        walk(child, rel, depth + 1)
                    elif stat.S_ISREG(st.st_mode):
                        child = self._open(stack, name, os.O_RDONLY | os.O_NONBLOCK, fd)
                        if _identity(os.fstat(child)) != _identity(st):
                            raise InspectionError("snapshot_changed", label)
                        if total + st.st_size > MAX_TOTAL_BYTES:
                            raise InspectionError("aggregate_budget_exceeded")
                        raw = _read_regular(child, st.st_size)
                        if len(raw) != st.st_size:
                            raise InspectionError("snapshot_changed", label)
                        total += len(raw)
                        checks.append((child, fd, name, _identity(st)))
                        captured[label] = raw
                        (destination / rel).write_bytes(raw)
                    else:
                        raise InspectionError("nonregular_entry_refused", label)
                if _identity(os.fstat(fd)) != initial:
                    raise InspectionError("snapshot_changed", relative.as_posix())
            walk(root_fd, PurePosixPath(), 0)
            for fd, parent_fd, name, expected in checks:
                if _identity(os.fstat(fd)) != expected or _identity(os.stat(name, dir_fd=parent_fd, follow_symlinks=False)) != expected:
                    raise InspectionError("snapshot_changed")
        return captured, {"entries": count, "bytes": total}

    def _load_exam(self):
        # Only this operator-selected runtime module is executed. In particular,
        # neither manifest organ/scorer names nor specialist Python are imported.
        with ExitStack() as stack:
            root = self._open(stack, str(self.runtime), os.O_RDONLY | os.O_DIRECTORY)
            workbench = self._open(stack, "workbench", os.O_RDONLY | os.O_DIRECTORY, root)
            fd = self._open(stack, "exam.py", os.O_RDONLY | os.O_NONBLOCK, workbench)
            before = os.fstat(fd)
            if not stat.S_ISREG(before.st_mode):
                raise InspectionError("exam_source_not_regular")
            raw = _read_regular(fd, before.st_size)
            if _identity(os.fstat(fd)) != _identity(before) or _identity(os.stat("exam.py", dir_fd=workbench, follow_symlinks=False)) != _identity(before):
                raise InspectionError("exam_source_changed")
        module = types.ModuleType("_pinned_workbench_exam")
        module.__file__ = str(self.runtime / "workbench/exam.py")
        try:
            exec(compile(raw, module.__file__, "exec"), module.__dict__)
        except Exception as error:
            raise InspectionError("exam_inspector_unavailable") from error
        if not callable(getattr(module, "status", None)) or not callable(getattr(module, "files_sha", None)):
            raise InspectionError("exam_inspector_unavailable")
        return module, hashlib.sha256(raw).hexdigest()

    def _inspect(self, sid, location, example_count):
        base, parts = ((self.runtime, ["root", "specialists", sid]) if location == "packaged"
                       else (self.workspace, ["workbench-local", "specialists", sid]))
        exam, exam_sha = self._load_exam()
        self.workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="exam-inspection-", dir=self.workspace) as directory:
            snapshot = Path(directory)
            captured, budget = self._capture(base, parts, snapshot)
            manifest = _json(captured["manifest.json"], "manifest.json") if "manifest.json" in captured else None
            if manifest is not None and not isinstance(manifest, dict):
                raise InspectionError("invalid_manifest_object", "manifest.json")
            if manifest is not None and "expires" in manifest:
                expires = manifest["expires"]
                if type(expires) not in (int, float) or not math.isfinite(expires) or abs(expires) > 1e15:
                    raise InspectionError("invalid_manifest_expiry", "manifest.json")
            verdicts = {}
            for split in ("dev", "heldout"):
                name = "verdict_" + split + ".json"
                verdicts[split] = _json(captured[name], name) if name in captured else None
                if verdicts[split] is not None and not isinstance(verdicts[split], dict):
                    raise InspectionError("invalid_verdict_object", name)
            panel = self._panel(sid, manifest or {}, captured, example_count)
            try:
                upstream = exam.status(snapshot)
                current_sha = exam.files_sha(snapshot)
            except Exception as error:
                raise InspectionError("upstream_inspection_failed") from error
            heldout = verdicts["heldout"] or {}
            claimed = heldout.get("files_sha")
            if claimed is None:
                binding = {"matches": None, "reason": "missing_files_sha", "recorded_sha256": None,
                           "detail": "The retained verdict has no file digest; this does not show that any file changed."}
            elif not isinstance(claimed, str) or not SHA.fullmatch(claimed):
                binding = {"matches": None, "reason": "invalid_files_sha", "recorded_sha256": None,
                           "detail": "The retained verdict does not contain a lowercase SHA-256 file digest."}
            else:
                binding = {"matches": claimed == current_sha,
                           "reason": "files_match" if claimed == current_sha else "files_changed",
                           "detail": "Compared using upstream files_sha, including its documented file exclusions.",
                           "recorded_sha256": claimed}
            binding["snapshot_sha256"] = current_sha
            recorded_panel_sha = heldout.get("panel_sha")
            panel["recorded_sha256"] = recorded_panel_sha if isinstance(recorded_panel_sha, str) and SHA.fullmatch(recorded_panel_sha) else None
            panel["matches_recorded_sha256"] = (panel["computed_heldout_sha256"] == panel["recorded_sha256"]
                                                 if panel["computed_heldout_sha256"] and panel["recorded_sha256"] else None)
            journal = self._journal(captured, panel["computed_heldout_sha256"])
            origin = "publisher_retained" if location == "packaged" else "workspace_retained"
            measurements = {split: _verdict_summary(value, origin, hashlib.sha256(captured["verdict_" + split + ".json"]).hexdigest())
                            if value is not None else None for split, value in verdicts.items()}
            accept = (manifest or {}).get("accept", {})
            kinds = accept.get("kinds", []) if isinstance(accept, dict) else []
            decl = {"present": manifest is not None, "id": _small((manifest or {}).get("id"), 80),
                    "name": _small((manifest or {}).get("name")),
                    "id_matches_selection": (manifest or {}).get("id") == sid,
                    "kinds": [k for k in kinds[:128] if _small(k, 80)] if isinstance(kinds, list) else [],
                    "sha256": hashlib.sha256(captured["manifest.json"]).hexdigest() if manifest is not None else None}
            return {"status": "answered", "specialist_id": sid, "location": location,
                    "declaration": decl, "recorded_exams": measurements,
                    "workbench_admission": {"upstream_state": upstream.get("state"),
                        "recorded_decision": _small(heldout.get("decision"), 32),
                        "files_binding": binding, "scope": "Upstream exam.status on these captured bytes, not a fresh exam or an authenticated admission."},
                    "panel": panel, "heldout_usage": journal,
                    "snapshot": budget, "inspector": {"source": "workbench/exam.py", "sha256": exam_sha},
                    "exam_executed": False, "specialist_code_executed": False,
                    "runtime_registered": None, "mini_permission": "not_assessed",
                    "limitations": ["Recorded scores are claims in retained files; this inspector did not observe their execution.",
                                    "A matching file digest binds recorded bytes, not the accuracy of their claims or external dependencies.",
                                    "Workbench status does not establish live runtime registration or permission to install or invoke a specialist.",
                                    "No held-out question or answer is returned; examples, if requested, are declared dev questions.",
                                    "The result describes the captured snapshot, not subsequent filesystem changes."]}

    def _panel(self, sid, manifest, captured, example_count):
        result = {"availability": "unavailable", "reason": "panel_missing", "format": None,
                  "counts": {}, "dev_examples": [], "computed_heldout_sha256": None}
        config = manifest.get("panel", {})
        name = config.get("path", "panel.json") if isinstance(config, dict) else None
        if not isinstance(name, str):
            return {**result, "reason": "invalid_panel_path"}
        prefix = "__ORACLE7_ROOT__/specialists/" + sid + "/"
        if name.startswith(prefix):
            name = name[len(prefix):]
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "__ORACLE7_ROOT__" in path.parts or "\\" in name:
            return {**result, "reason": "panel_outside_inspected_folder"}
        raw = captured.get(path.as_posix())
        if raw is None:
            return result
        panel = _json(raw, path.as_posix())
        if isinstance(panel, dict) and all(key not in panel or isinstance(panel[key], list) for key in ("dev", "heldout")):
            groups = {split: panel.get(split, []) for split in ("dev", "heldout")}
            result["format"] = "workbench_split_object"
            result["computed_heldout_sha256"] = hashlib.sha256(json.dumps(groups["heldout"], sort_keys=True).encode()).hexdigest()
        elif isinstance(panel, list):
            if not all(isinstance(row, dict) for row in panel):
                return {**result, "reason": "invalid_panel_items"}
            groups = {split: [row for row in panel if isinstance(row, dict) and row.get("split") == split] for split in ("dev", "heldout")}
            result["format"] = "published_split_rows"
        else:
            return {**result, "reason": "unsupported_panel_shape"}
        for split, items in groups.items():
            if not all(isinstance(item, dict) for item in items):
                return {**result, "reason": "invalid_panel_items", "computed_heldout_sha256": None}
            result["counts"][split] = {"items": len(items), "must_decline": sum(item.get("valid") is False for item in items)}
        result["dev_examples"] = [{"question": item["q"], "evidence": "declared_dev_example"}
                                   for item in groups["dev"] if _small(item.get("q"), 400)][:example_count]
        result.update(availability="available", reason=None, sha256=hashlib.sha256(raw).hexdigest())
        return result

    def _journal(self, captured, heldout_sha):
        raw = captured.get("exam_log.jsonl")
        if raw is None:
            return {"present": False, "records": 0, "matching_heldout_uses": 0 if heldout_sha else None,
                    "scope": "No use recorded in this captured journal; not proof that the panel was never used."}
        lines = raw.splitlines()
        if len(lines) > 512 or len(raw) > 131072:
            raise InspectionError("exam_log_budget_exceeded", "exam_log.jsonl")
        records = [_json(line, "exam_log.jsonl") for line in lines if line.strip()]
        if not all(isinstance(record, dict) for record in records):
            raise InspectionError("invalid_exam_log_record", "exam_log.jsonl")
        return {"present": True, "records": len(records),
                "matching_heldout_uses": sum(record.get("heldout_sha") == heldout_sha for record in records) if heldout_sha else None,
                "scope": "Recorded use count only; no exam was executed or panel consumption recorded by this call."}
