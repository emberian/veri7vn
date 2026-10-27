"""Untrusted supplied-data operations using the pinned Oracle7 Workbench.

This module computes answers, not Mini permissions or proofs. It never polls a
sensor, connects to a server, installs code, or treats caller paths as authority.
Invoke on the appliance's single worker thread. The runtime and workspace are
operator-selected; all per-call document files are temporary workspace copies.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import sys
import tempfile
import threading

MAX_TEXT = 32768
MAX_FILES = 8
MAX_VALUES = 2048
_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,79}\Z")
_LOCK = threading.RLock()


def _object(properties, required):
    return {"type": "object", "properties": properties, "required": required, "additionalProperties": False}


def _string(limit=MAX_TEXT, **extra):
    return {"type": "string", "minLength": 1, "maxLength": limit, **extra}


_FILE = _object({"name": _string(80), "text": _string()}, ["name", "text"])
_INPUTS = {
    "workbench.tables.lookup": _object({
        "file": _FILE, "selector_column": _string(256), "selector_value": _string(1024),
        "result_column": _string(256)}, ["file", "selector_column", "selector_value", "result_column"]),
    "workbench.documents.query": _object({
        "files": {"type": "array", "items": _FILE, "minItems": 1, "maxItems": MAX_FILES},
        "question": _string(2048)}, ["files", "question"]),
    "workbench.sensors.analyze": _object({
        "values": {"type": "array", "items": {"anyOf": [{"type": "number", "minimum": -1e12, "maximum": 1e12}, {"type": "null"}]}, "minItems": 3, "maxItems": MAX_VALUES},
        "history_count": {"type": "integer", "minimum": 32, "maximum": MAX_VALUES - 1},
        "interval_seconds": {"type": "integer", "const": 900},
        "ideal": {"type": "array", "items": {"type": "number", "minimum": -1e12, "maximum": 1e12}, "minItems": 2, "maxItems": 2},
        "unit": _string(80), "label": _string(160)},
        ["values", "history_count", "interval_seconds", "ideal", "unit"]),
    "workbench.prose.compose": _object({
        "topic": _string(160),
        "records": {"type": "array", "minItems": 1, "maxItems": 8,
                    "items": _object({"id": _string(80), "sentence": _string(1024),
                                      "source": _string(1024)}, ["id", "sentence", "source"])},
        "voice": _string(8192)}, ["topic", "records"]),
}
_META = {
    "workbench.tables.lookup": ("Read a table cell", "Look up one uniquely selected CSV/TSV row and return a named column with its row reference.", "sources.py", {"file": {"name": "stock.csv", "text": "item,price\nhoney,8\n"}, "selector_column": "item", "selector_value": "honey", "result_column": "price"}),
    "workbench.documents.query": ("Search supplied documents", "Quote a matching passage from supplied text or Markdown; equally relevant differing passages require clarification.", "sources.py", {"files": [{"name": "notes.txt", "text": "The boiler pressure limit is two bar."}], "question": "What do my notes say about the boiler pressure limit?"}),
    "workbench.sensors.analyze": ("Analyze a sensor series", "Run Oracle's retrospective spike, step, drift, stuck, dropout and oscillation tests on supplied 15-minute readings.", "sensors_baseline_v4.py", {"values": [10, 11] * 20, "history_count": 32, "interval_seconds": 900, "ideal": [9, 12], "unit": "C"}),
    "workbench.prose.compose": ("Compose attributed sentences", "Arrange caller-supplied attributed sentences with Oracle's ProseFold, preserving source references and reporting its lexical fidelity check.", "prosefold/core.py", {"topic": "Coffee", "records": [{"id": "r1", "sentence": "Coffee is a beverage made from roasted seeds.", "source": "supplied note"}, {"id": "r2", "sentence": "Coffee contains caffeine and other compounds.", "source": "supplied note"}]}),
}


def _keys(value, required, optional=()):
    if not isinstance(value, dict) or set(value) - set(required) - set(optional) or set(required) - set(value):
        raise ValueError("arguments have missing or unknown fields")


def _text(value, name, limit=MAX_TEXT):
    if not isinstance(value, str) or not value.strip() or len(value) > limit or "\x00" in value:
        raise ValueError(f"{name} must be nonempty text of at most {limit} characters")
    try:
        value.encode("utf-8")
    except UnicodeEncodeError as error:
        raise ValueError(f"{name} must be valid UTF-8 text") from error
    return value


def _number(value):
    if type(value) not in (int, float) or abs(value) > 1e12 or not math.isfinite(value):
        raise ValueError("readings must be finite numbers between -1e12 and 1e12, or null for missing")
    return value


class WorkbenchOperations:
    def __init__(self, runtime, workspace):
        self.runtime = Path(runtime).resolve()
        self.workspace = Path(workspace).resolve()
        if self.workspace == self.runtime or self.runtime in self.workspace.parents or self.workspace in self.runtime.parents:
            raise ValueError("runtime and workspace must be disjoint")
        self._modules = {}

    def _path(self, relative):
        path = (self.runtime / "workbench" / relative).resolve()
        if not path.is_relative_to(self.runtime):
            raise ValueError("Workbench source escapes the runtime")
        return path

    def _load(self, relative, package=False):
        if relative not in self._modules:
            path = self._path(relative)
            name = "_oracle_workbench_" + hashlib.sha256(str(path).encode()).hexdigest()[:16]
            spec = importlib.util.spec_from_file_location(name, path,
                    submodule_search_locations=[str(path.parent)] if package else None)
            if spec is None or spec.loader is None:
                raise ValueError("Workbench implementation is unavailable")
            module = importlib.util.module_from_spec(spec)
            sys.modules[name] = module
            try:
                spec.loader.exec_module(module)
            except BaseException:
                sys.modules.pop(name, None)
                raise
            self._modules[relative] = module
        return self._modules[relative]

    def catalog(self):
        entries = []
        for key, (name, description, relative, example) in _META.items():
            dependencies = (["prosefold/" + n for n in ("__init__.py", "core.py", "engine.py", "prose.py", "readback.py", "speaker.py", "voice_default.md")]
                            if key == "workbench.prose.compose" else [relative])
            available, sources, failure = True, [], None
            try:
                for dependency in dependencies:
                    path = self._path(dependency)
                    sources.append({"path": "workbench/" + dependency,
                                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
                if key == "workbench.tables.lookup":
                    if not hasattr(self._load("sources.py").FilesOrgan, "lookup"):
                        raise ImportError("structured FilesOrgan.lookup is absent")
                elif key == "workbench.documents.query":
                    if not hasattr(self._load("sources.py").FilesOrgan, "answer"):
                        raise ImportError("FilesOrgan.answer is absent")
                elif key == "workbench.sensors.analyze":
                    implementation = self._load("sensors_baseline_v4.py")
                    if not all(hasattr(implementation, item) for item in ("Channel", "read_channel", "ideal_distance")):
                        raise ImportError("sensor reader entrypoint is absent")
                else:
                    self._load("prosefold/__init__.py", package=True)
                    self._path("prosefold/voice_default.md").read_text(encoding="utf-8")
            except Exception as error:
                available = False
                failure = "Workbench dependency unavailable: " + type(error).__name__
            limitations = ["Caller-supplied sources and units are not independently verified."]
            if failure:
                limitations.append(failure)
            if key == "workbench.prose.compose":
                limitations += ["No factual verification or semantic equivalence proof; the fidelity check compares content words.", "No synonym rewriting, network acquisition, or model calls."]
            if key == "workbench.sensors.analyze":
                limitations += ["Retrospective heuristic detection; absence of flags does not establish sensor health.", "A single channel cannot distinguish a sensor fault from a change in the world.", "Input must be uniformly spaced at 900 seconds with at least 32 baseline samples; encode missing intervals as null."]
            if key == "workbench.documents.query":
                limitations.append("Keyword matching is not an exhaustive answer to a document question; no match is not evidence of absence.")
            entries.append({"id": key, "name": name, "description": description,
                "group": "workbench", "availability": "live_direct" if available else "unavailable",
                "input_schema": _INPUTS[key], "output_schema": {"type": "object", "required": ["status"]},
                "units": {"input": "caller-declared", "sample_interval_seconds": 900} if "sensors" in key else {},
                "sources": sources,
                "examples": [{"arguments": example}],
                "implementation": "Oracle7 Workbench: " + relative,
                "limitations": limitations})
        return entries

    def invoke(self, operation_id, arguments):
        if operation_id not in _INPUTS:
            raise ValueError("unknown Workbench operation")
        if not isinstance(arguments, dict):
            raise ValueError("arguments must be an object")
        # Bound the whole inline corpus as well as individual strings. No file
        # contents are read from caller-selected host paths.
        if len(json.dumps(arguments, allow_nan=False).encode()) > 65536:
            raise ValueError("Workbench input exceeds 64 KiB")
        with _LOCK:
            descriptor = next(entry for entry in self.catalog() if entry["id"] == operation_id)
            if descriptor["availability"] != "live_direct":
                return {"status": "withheld", "reason": "operation_unavailable", "limitations": descriptor["limitations"]}
            if operation_id == "workbench.tables.lookup":
                return self._table(arguments)
            if operation_id == "workbench.documents.query":
                return self._documents(arguments)
            if operation_id == "workbench.sensors.analyze":
                return self._sensor(arguments)
            return self._prose(arguments)

    def _files(self, files, suffixes):
        if not isinstance(files, list) or not 1 <= len(files) <= MAX_FILES:
            raise ValueError("provide 1..8 files")
        seen, total = set(), 0
        for item in files:
            _keys(item, ["name", "text"])
            name = _text(item["name"], "name", 80)
            if not _NAME.fullmatch(name) or Path(name).suffix.lower() not in suffixes or name in seen:
                raise ValueError("file names must be unique supported basenames")
            total += len(_text(item["text"], "text").encode())
            seen.add(name)
        if total > MAX_TEXT:
            raise ValueError("combined supplied files exceed 32 KiB")
        return files

    def _reader(self, directory):
        reader = self._load("sources.py").FilesOrgan(name="the supplied documents")
        reader.dir = Path(directory)
        return reader

    def _with_files(self, files, action):
        self.workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="workbench-", dir=self.workspace) as folder:
            for item in files:
                Path(folder, item["name"]).write_text(item["text"], encoding="utf-8")
            result = action(self._reader(folder))
        if result is None:
            result = {"status": "withheld", "reason": "question_not_supported",
                      "response": "Ask about a named row/column or a passage in the supplied documents."}
        return {**result, "input_sources": [{"name": f["name"], "sha256": hashlib.sha256(f["text"].encode()).hexdigest()} for f in files]}

    def _table(self, args):
        _keys(args, ["file", "selector_column", "selector_value", "result_column"])
        files = self._files([args["file"]], {".csv", ".tsv"})
        for key, limit in (("selector_column", 256), ("selector_value", 1024), ("result_column", 256)):
            _text(args[key], key, limit)
        if not hasattr(self._load("sources.py").FilesOrgan, "lookup"):
            return {"status": "withheld", "reason": "operation_unavailable"}
        return self._with_files(files, lambda reader: reader.lookup(files[0]["name"], args["selector_column"], args["selector_value"], args["result_column"]))

    def _documents(self, args):
        _keys(args, ["files", "question"])
        files = self._files(args["files"], {".txt", ".md"})
        question = _text(args["question"], "question", 2048)
        return self._with_files(files, lambda reader: reader.answer(question, "supplied-documents"))

    def _sensor(self, args):
        _keys(args, ["values", "history_count", "interval_seconds", "ideal", "unit"], ["label"])
        values = args["values"]
        if not isinstance(values, list) or not 3 <= len(values) <= MAX_VALUES:
            raise ValueError("values must contain 3..2048 readings")
        for value in values:
            if value is not None:
                _number(value)
        count = args["history_count"]
        if type(count) is not int or not 32 <= count < len(values):
            raise ValueError("history_count must be at least 32 and leave a nonempty observation suffix")
        if sum(v is not None for v in values[:count]) < 2:
            raise ValueError("baseline needs at least two actual readings")
        if type(args["interval_seconds"]) is not int or args["interval_seconds"] != 900:
            raise ValueError("this reader requires 900-second uniformly spaced samples")
        ideal = args["ideal"]
        if not isinstance(ideal, list) or len(ideal) != 2 or _number(ideal[0]) > _number(ideal[1]):
            raise ValueError("ideal must contain ascending lower and upper bounds")
        unit = _text(args["unit"], "unit", 80)
        label = _text(args.get("label", "supplied channel"), "label", 160)
        module = self._load("sensors_baseline_v4.py")
        channel = module.Channel(values, ideal, history_n=count, label=label)
        return {"status": "answered", "label": label, "unit": unit,
                "interval_seconds": 900, "history_count": count,
                "flags": module.read_channel(channel), "latest_ideal_distance": module.ideal_distance(values[-1], ideal),
                "baseline_robust_spread": channel.sp,
                "interpretation": "Retrospective heuristic flags; a single channel cannot distinguish sensor faults from world changes."}

    def _prose(self, args):
        _keys(args, ["topic", "records"], ["voice"])
        topic = _text(args["topic"], "topic", 160)
        records = args["records"]
        if not isinstance(records, list) or not 1 <= len(records) <= 8:
            raise ValueError("records must contain 1..8 attributed sentences")
        units, ids = [], set()
        for record in records:
            _keys(record, ["id", "sentence", "source"])
            rid = _text(record["id"], "id", 80)
            sentence = _text(record["sentence"], "sentence", 1024)
            source = _text(record["source"], "source", 1024)
            if rid in ids or sentence[-1] not in ".!?" or "\n" in sentence:
                raise ValueError("records need unique IDs and one terminated line each")
            ids.add(rid)
            units.append({"claim": rid, "sentence": sentence, "source": source, "title": topic})
        voice = args.get("voice")
        if voice is not None:
            _text(voice, "voice", 8192)
        else:
            voice = self._path("prosefold/voice_default.md").read_text(encoding="utf-8")
        if importlib.util.find_spec("numpy") is None:
            return {"status": "withheld", "reason": "numpy_unavailable"}
        package = self._load("prosefold/__init__.py", package=True)
        core = sys.modules[package.__name__ + ".core"]
        old_toy, old_lower = core.TOY, set(core.LOWER_SEEN)
        try:
            # The original fold has module-local voice/context state. Confine it
            # to this invocation, restoring it even when computation fails.
            core.TOY = core.ProseFoldToy.from_corpus(voice)
            core.LOWER_SEEN.clear()
            for unit in units:
                core.LOWER_SEEN.update(re.findall(r"(?<=\s)([a-z][a-z'-]+)", unit["sentence"]))
            target = core.voice_of(voice)
            folded, distance, moves = core.fold_paragraph(units, topic, target, [], rewrite=False)
            sentences = []
            for item in folded:
                ok, extra = core.SP.decomposes(item["text"], [part["sentence"] for part in item["parts"]], core.VERBS)
                sentences.append({"text": item["text"], "source_ids": [part["claim"] for part in item["parts"]],
                                  "lexical_fidelity_passed": bool(ok), "extra_content_words": sorted(extra)})
            passed = all(s["lexical_fidelity_passed"] for s in sentences)
            return {"status": "answered" if passed else "withheld",
                    "reason": None if passed else "lexical_fidelity_failed", "topic": topic,
                    "text": core.render([folded]) if passed else None,
                    "sentences": sentences, "sources": records, "moves": moves, "voice_distance": distance,
                    "evidence": "Caller-attributed sentences with an upstream lexical decomposition check; not a proof of facts or semantic equivalence."}
        finally:
            core.TOY = old_toy
            core.LOWER_SEEN.clear()
            core.LOWER_SEEN.update(old_lower)
