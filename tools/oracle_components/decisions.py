"""Untrusted, bounded adapters for pinned Oracle sibling computations.

These are proposals and simulations, not Mini authority or host-control tools.
Only operator-provisioned sources named by APPLIANCE.json may be imported.
"""
from __future__ import annotations

import copy
from contextlib import closing
import hashlib
import importlib
import importlib.util
import json
import math
from pathlib import Path, PurePosixPath
import re
import sqlite3
import sys

PINS = {
    "trafficcop": ("08a9f1e70b8e78d9078b4bd9f308b99b9800bcb0", ("trafficcop/__init__.py", "trafficcop/model.py")),
    "deepspace": ("3538060dbb55f287d060820f7b7c42fe3487632d", ("deepspace/__init__.py", "deepspace/sim.py", "deepspace/runtime.py", "deepspace/fdir.py")),
    "infrastructure": ("74456ba7db9172f5822433308943647ecd67cdf0", ("agent.py",)),
}


def obj(properties, required=None):
    return {"type": "object", "properties": properties, "required": list(properties) if required is None else required,
            "additionalProperties": False}


def integer(low, high):
    return {"type": "integer", "minimum": low, "maximum": high}


def string(limit=256):
    return {"type": "string", "minLength": 1, "maxLength": limit}


def array(items, low, high):
    return {"type": "array", "items": items, "minItems": low, "maxItems": high}


def _json_bounded(value, depth=0, count=None):
    count = [0] if count is None else count
    count[0] += 1
    if depth > 12 or count[0] > 12000:
        raise ValueError("arguments exceed structural limit")
    if isinstance(value, dict):
        if not all(isinstance(k, str) and len(k) <= 256 for k in value):
            raise ValueError("object keys must be short strings")
        for v in value.values():
            _json_bounded(v, depth + 1, count)
    elif isinstance(value, list):
        for v in value:
            _json_bounded(v, depth + 1, count)
    elif isinstance(value, str):
        if len(value) > 8192:
            raise ValueError("string exceeds 8192 characters")
    elif isinstance(value, float):
        if not math.isfinite(value) or abs(value) > 1e100:
            raise ValueError("number is not finite and bounded")
    elif type(value) is int:
        if abs(value) > 10**100:
            raise ValueError("integer exceeds numeric limit")
    elif value is not None and type(value) is not bool:
        raise ValueError("arguments must be JSON values")


def _fields(value, names, optional=()):
    if not isinstance(value, dict) or set(value) - set(names) - set(optional) or set(names) - set(value):
        raise ValueError("unexpected or missing argument fields")


def _int(value, low, high):
    if type(value) is not int or not low <= value <= high:
        raise ValueError("integer outside permitted range")
    return value


def _text(value, limit=256):
    if not isinstance(value, str) or not 1 <= len(value) <= limit:
        raise ValueError("expected a nonempty bounded string")
    return value


def _number(value):
    if type(value) not in (int, float) or not math.isfinite(value) or abs(value) > 1e12:
        raise ValueError("expected a finite number with magnitude at most 1e12")
    return value


def _rows(value, low, high):
    if not isinstance(value, list) or not low <= len(value) <= high:
        raise ValueError("array outside permitted size")
    return value


class DecisionOperations:
    """Read-only component computations using supplied data and isolated imports."""

    def __init__(self, runtime: Path, workspace: Path):
        self.runtime, self.workspace = Path(runtime).resolve(), Path(workspace).resolve()
        self.loaded, self.identities, self.unavailable = {}, {}, {}
        try:
            path = self.runtime / "APPLIANCE.json"
            with path.open("rb") as f:
                raw = f.read(4 * 1024 * 1024 + 1)
            if len(raw) > 4 * 1024 * 1024:
                raise ValueError("receipt too large")
            receipt = json.loads(raw)
            components = receipt.get("components", {})
            if not isinstance(components, dict):
                raise ValueError("invalid components receipt")
        except (OSError, ValueError, TypeError):
            components = {}
        for name in PINS:
            try:
                root, identity = self._source(name, components.get(name))
                self.loaded[name] = self._load(name, root, identity)
                self.identities[name] = identity
            except (OSError, ValueError, ImportError, KeyError, TypeError) as error:
                self.unavailable[name] = type(error).__name__ + ": component source or receipt unavailable"
        self.operations = self._descriptors()

    def _source(self, name, receipt):
        if not isinstance(receipt, dict):
            raise ValueError("component not provisioned")
        relative = "components/" + name + "/source"
        if receipt.get("source_root") != relative:
            raise ValueError("unexpected source root")
        source = receipt["source"]
        if not isinstance(source, dict):
            raise ValueError("invalid component source receipt")
        revision, required = PINS[name]
        if source.get("revision") != revision:
            raise ValueError("unsupported source revision")
        repository = "https://huggingface.co/psiloceyeben/oracle7-" + name
        if source.get("repository") != repository:
            raise ValueError("unexpected source repository")
        files = source.get("files")
        if not isinstance(files, dict) or len(files) > 128 or not set(required).issubset(files):
            raise ValueError("source closure missing")
        root = self.runtime / relative
        if root.resolve() != root or not root.is_dir():
            raise ValueError("source root is not a real directory")
        total = 0
        for filename, row in files.items():
            if not isinstance(filename, str) or not isinstance(row, dict):
                raise ValueError("invalid source file receipt")
            p = PurePosixPath(filename)
            if p.is_absolute() or not p.parts or any(x in (".", "..") for x in p.parts) or str(p) != filename:
                raise ValueError("invalid source file path")
            target = root.joinpath(*p.parts)
            if target.resolve() != target or not target.is_file():
                raise ValueError("source file is not a regular file")
            size = row.get("size")
            digest = row.get("sha256")
            if type(size) is not int or not 0 <= size <= 2 * 1024 * 1024 or not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise ValueError("invalid file receipt")
            total += size
            if total > 8 * 1024 * 1024 or target.stat().st_size != size:
                raise ValueError("source file size mismatch")
            if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                raise ValueError("source file hash mismatch")
        identity = {"repository": repository, "revision": revision,
                    "source_files": copy.deepcopy(files), "patches": copy.deepcopy(source.get("patches", [])),
                    "scope": "Receipt-listed source bytes checked at load; trusted immutable deployment required thereafter."}
        return root, identity

    def _load(self, name, root, identity):
        cache_key = str(root) + json.dumps(identity["source_files"], sort_keys=True)
        alias = "_oracle_decision_" + name + "_" + hashlib.sha256(cache_key.encode()).hexdigest()[:16]
        path = root / ("agent.py" if name == "infrastructure" else name + "/__init__.py")
        spec = importlib.util.spec_from_file_location(alias, path,
                submodule_search_locations=None if name == "infrastructure" else [str(path.parent)])
        module = importlib.util.module_from_spec(spec)
        sys.modules[alias] = module
        try:
            spec.loader.exec_module(module)
            if name == "deepspace":
                return {part: importlib.import_module(alias + "." + part) for part in ("sim", "runtime", "fdir")}
            return module
        except BaseException:
            for key in list(sys.modules):
                if key == alias or key.startswith(alias + "."):
                    del sys.modules[key]
            raise

    def _descriptors(self):
        record = obj({"timestamp": integer(0, 4102444800), "entity": string(), "signal": string(),
                      "value": {"type": "number", "minimum": -1e12, "maximum": 1e12}, "source": string(2048)})
        forecast = obj({"made": integer(0, 4102444800), "target": integer(0, 4102444800),
                        "entity": string(), "signal": string(), "method": {"type": "string", "enum": ["naive", "trend6h", "damped"]},
                        "value": {"type": "number", "minimum": -1e12, "maximum": 1e12},
                        "actual": {"type": "number", "minimum": -1e12, "maximum": 1e12}})
        rows = [
            ("trafficcop.decide", "Choose or abstain from supplied options", "Propose a next step from supplied observations and option labels; equal bindings abstain.",
             obj({"state": {"type": "object"}, "questions": {"type": "object"}}),
             [{"arguments": {"state": {"observation": "button click returns wrong result"}, "questions": {"next": {"options": [["repair", "repair button behavior"], ["observe", "collect evidence"]]}}}}]),
            ("deepspace.profiles", "List spacecraft simulation profiles", "Show supported simulator profiles, assumptions and fault classes.", obj({}), [{"arguments": {}}]),
            ("deepspace.simulate", "Simulate spacecraft fault response", "Run the actual seeded spacecraft simulator and FDIR decision loop; return actions, receipts and simulator score.",
             obj({"profile": string(64), "fault": string(64), "seed": integer(0, 2147483647), "ticks": integer(81, 640)}),
             [{"arguments": {"profile": "europa_clipper", "fault": "sensor_bias", "seed": 1, "ticks": 320}}]),
            ("infrastructure.analyze", "Analyze supplied infrastructure readings", "Apply upstream status, trend and anomaly readers to supplied time-stamped measurements without polling the host.",
             obj({"readings": array(record, 1, 512)}), [{"arguments": {"readings": [{"timestamp": 1700000000, "entity": "disk:example", "signal": "used_pct", "value": 98, "source": "caller measurement"}]}}]),
            ("infrastructure.forecast_gate", "Compare paired forecast results", "Compare forecast methods with naive predictions on matching entity, signal, origin, horizon and actual observation; supplied records are caller assertions.",
             obj({"forecasts": array(forecast, 1, 512)}), []),
        ]
        result = []
        for operation_id, title, description, schema, examples in rows:
            component = operation_id.split(".")[0]
            result.append({"id": operation_id, "name": title, "description": description,
                "availability": "live_direct" if component in self.loaded else "unavailable",
                "input_schema": schema, "output_schema": {"type": "object"},
                "units": {"deepspace.simulate": {"tick": "60 seconds", "latency_min": "minutes"},
                          "infrastructure.analyze": {"timestamp": "Unix seconds", "slope_per_second": "input signal units per second"}}.get(operation_id, {}),
                "sources": [self.identities[component]] if component in self.identities else [],
                "examples": examples, "implementation": {"component": component, "entrypoint": operation_id},
                "limitations": ["Untrusted computation, not Mini authority.",
                    "No host polling, network access or real action execution is exposed.",
                    "Simulations and supplied measurements do not establish real-world safety."] + ([self.unavailable[component]] if component in self.unavailable else [])})
        return result

    def catalog(self):
        return copy.deepcopy(self.operations)

    def invoke(self, operation_id, arguments):
        if operation_id not in {row["id"] for row in self.operations}:
            raise ValueError("unknown operation")
        _json_bounded(arguments)
        if len(json.dumps(arguments, allow_nan=False).encode()) > 131072:
            raise ValueError("arguments exceed 128 KiB")
        component = operation_id.split(".")[0]
        if component not in self.loaded:
            return {"status": "withheld", "reason": "component_unavailable", "operation_id": operation_id}
        module = self.loaded[component]
        if operation_id == "trafficcop.decide":
            _fields(arguments, ("state", "questions"))
            if not isinstance(arguments["state"], dict) or not isinstance(arguments["questions"], dict) or not 1 <= len(arguments["questions"]) <= 16:
                raise ValueError("state/questions must be objects; 1..16 questions")
            for key, question in arguments["questions"].items():
                _text(key, 80)
                _fields(question, ("options",))
                options = question["options"]
                pairs = list(options.items()) if isinstance(options, dict) else options
                for pair in _rows(pairs, 1, 64):
                    if not isinstance(pair, (list, tuple)) or len(pair) != 2:
                        raise ValueError("each option must be a key/label pair")
                    _text(pair[0], 80); _text(pair[1], 2048)
                if len({pair[0] for pair in pairs}) != len(pairs):
                    raise ValueError("duplicate option keys")
            value = module.decide(arguments)
            status = "withheld" if all(a["abstained"] for a in value["answers"].values()) else "answered"
        elif operation_id == "deepspace.profiles":
            _fields(arguments, ())
            value = {"profiles": copy.deepcopy(module["sim"].PROFILES), "tick_seconds": module["sim"].DT,
                     "scope": "Simplified spacecraft simulation profiles, not engineering-fidelity vehicle models."}
            status = "answered"
        elif operation_id == "deepspace.simulate":
            _fields(arguments, ("profile", "fault", "seed", "ticks"))
            profile, fault = _text(arguments["profile"], 64), _text(arguments["fault"], 64)
            if profile not in module["sim"].PROFILES or fault not in module["sim"].PROFILES[profile]["faults"]:
                raise ValueError("unsupported profile/fault combination")
            params = module["runtime"].scenario(fault, _int(arguments["seed"], 0, 2147483647), profile)
            ticks = _int(arguments["ticks"], 81, 640)
            trace = module["runtime"].run(params, module["fdir"].FDIR().decide, ticks=ticks)
            value = {"scenario": params, "ticks": ticks, "trace": trace, "score": module["runtime"].score(params, trace),
                     "scope": "Simulated actions only; score describes this scenario, not real spacecraft safety."}
            status = "answered"
        elif operation_id == "infrastructure.analyze":
            value = self._analyze(module, arguments)
            status = "answered"
        else:
            value = self._gate(module, arguments)
            status = "answered"
        return {"status": status, "operation_id": operation_id, "result": value,
                "provenance": copy.deepcopy(self.identities[component]), "authority": "computation_only"}

    @staticmethod
    def _analyze(module, arguments):
        _fields(arguments, ("readings",))
        rows, seen = [], set()
        for row in _rows(arguments["readings"], 1, 512):
            _fields(row, ("timestamp", "entity", "signal", "value", "source"))
            t = _int(row["timestamp"], 0, 4102444800)
            entity, signal = _text(row["entity"]), _text(row["signal"])
            key = t, entity, signal
            if key in seen:
                raise ValueError("duplicate timestamp for entity/signal")
            seen.add(key)
            rows.append((t, entity, signal, _number(row["value"]), _text(row["source"], 2048)))
        with closing(sqlite3.connect(":memory:")) as db:
            db.executescript("CREATE TABLE fact(ts INTEGER, entity TEXT, signal TEXT, value REAL, source TEXT); CREATE TABLE agg(ts INTEGER, entity TEXT, signal TEXT, value REAL); CREATE TABLE event(ts INTEGER, entity TEXT, kind TEXT, detail TEXT);")
            db.executemany("INSERT INTO fact VALUES(?,?,?,?,?)", rows)
            trends = []
            for entity, signal in sorted({(r[1], r[2]) for r in rows}):
                series = module.series(db, entity, signal, 0)
                trends.append({"entity": entity, "signal": signal, "samples": len(series),
                               "slope_per_second": module.slope(series), "thresholds": module.thresholds(signal)})
            return {"status": module.status(db), "trends": trends,
                    "shift_observations": module.why(db, ""),
                    "scope": "Supplied observations only; anomaly shifts are associations, not causal findings or forecast admission."}

    @staticmethod
    def _gate(module, arguments):
        _fields(arguments, ("forecasts",))
        rows = []
        for row in _rows(arguments["forecasts"], 1, 512):
            _fields(row, ("made", "target", "entity", "signal", "method", "value", "actual"))
            made, target = _int(row["made"], 0, 4102444800), _int(row["target"], 0, 4102444800)
            if target <= made or target - made > 86400:
                raise ValueError("forecast horizon must be 1..86400 seconds")
            method = row["method"]
            if method not in ("naive", "trend6h", "damped"):
                raise ValueError("unknown forecasting method")
            rows.append((made, target, _text(row["entity"]), _text(row["signal"]), method, _number(row["value"]), 1, _number(row["actual"])))
        with closing(sqlite3.connect(":memory:")) as db:
            db.execute("CREATE TABLE forecast(made,target,entity,signal,method,value,scored,actual)")
            db.executemany("INSERT INTO forecast VALUES(?,?,?,?,?,?,?,?)", rows)
            return {"gate": module.gate(db), "scope": "Paired evaluation of caller-supplied results; no observation authenticity or Mini permission is established."}
