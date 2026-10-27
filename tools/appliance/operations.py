"""Untrusted direct-operation adapter, not proof or Mini capability authority.

Only registered/loadable implementations and fixed extension providers execute.
No caller-controlled import, pathname, URL, or Python expression is accepted.
"""
from __future__ import annotations

import ast
import hashlib
import importlib.util
import inspect
import json
import math
from pathlib import Path
import re
import sys

ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,159}\Z")
TEXT_SCHEMA = {"type": "object", "properties": {"text": {"type": "string", "minLength": 1, "maxLength": 12000}},
               "required": ["text"], "additionalProperties": False}
OUTPUT_SCHEMA = {"type": "object", "description": "Complete implementation result, including evidence and refusal fields."}


class OperationError(Exception):
    def __init__(self, code, status=400, **details):
        self.code, self.status, self.details = code, status, details
        super().__init__(code)


def encoded(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")


def json_value(value):
    """Lossless tagged representation for real organs' non-JSON scalar values."""
    if value is None or type(value) in (str, bool, int):
        return value
    if type(value) is float:
        if not math.isfinite(value):
            raise ValueError("non-finite implementation output")
        return value
    if isinstance(value, dict):
        if all(isinstance(key, str) for key in value):
            return {key: json_value(item) for key, item in value.items()}
        return {"$oracle_type": "mapping", "entries": [[json_value(key), json_value(item)] for key, item in value.items()]}
    if isinstance(value, (list, tuple)):
        return [json_value(item) for item in value]
    # Symbolic math organs return SymPy expressions and Symbol-keyed solutions.
    # Preserve expressions and their constructors rather than losing the value
    # or pretending that a display string is a newly checked numeric answer.
    if type(value).__module__.startswith("sympy."):
        import sympy
        if isinstance(value, sympy.Basic):
            if value.has(sympy.nan) or (value.is_number and value.is_finite is False):
                raise ValueError("non-finite symbolic numeric output")
            return {"$oracle_type": "sympy", "expression": sympy.sstr(value), "representation": sympy.srepr(value)}
    raise TypeError("implementation returned an unsupported JSON value")


def read_json(path, cap=4 * 1024 * 1024):
    with Path(path).open("rb") as stream:
        raw = stream.read(cap + 1)
    if len(raw) > cap:
        raise ValueError("metadata file exceeds limit")
    return json.loads(raw)


def validate(value, schema, where="arguments"):
    """Bounded JSON-schema subset used by our declarations; providers check semantics."""
    kind = schema.get("type")
    allowed = kind if isinstance(kind, list) else [kind]
    checks = {"object": lambda: isinstance(value, dict), "array": lambda: isinstance(value, list),
              "string": lambda: isinstance(value, str), "number": lambda: type(value) is int or (type(value) is float and math.isfinite(value)),
              "integer": lambda: type(value) is int, "boolean": lambda: type(value) is bool, "null": lambda: value is None}
    if kind is not None and not any(k in checks and checks[k]() for k in allowed):
        raise OperationError("invalid_arguments", field=where)
    if "const" in schema and (type(value) is not type(schema["const"]) or value != schema["const"]):
        raise OperationError("invalid_arguments", field=where)
    if "enum" in schema and value not in schema["enum"]:
        raise OperationError("invalid_arguments", field=where)
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        if not set(schema.get("required", [])) <= value.keys() or (schema.get("additionalProperties") is False and not value.keys() <= properties.keys()):
            raise OperationError("invalid_arguments", field=where)
        for key, item in value.items():
            if key in properties:
                validate(item, properties[key], where + "." + key)
            elif isinstance(schema.get("additionalProperties"), dict):
                validate(item, schema["additionalProperties"], where + "." + key)
    elif isinstance(value, str):
        if not schema.get("minLength", 0) <= len(value) <= schema.get("maxLength", 1000000):
            raise OperationError("invalid_arguments", field=where)
        if schema.get("pattern") and not re.search(schema["pattern"], value):
            raise OperationError("invalid_arguments", field=where)
    elif isinstance(value, list):
        if not schema.get("minItems", 0) <= len(value) <= schema.get("maxItems", 100000):
            raise OperationError("invalid_arguments", field=where)
        for item in value:
            validate(item, schema.get("items", {}), where + "[]")
    elif type(value) in (int, float):
        if (type(value) is float and not math.isfinite(value)) or value < schema.get("minimum", -math.inf) or value > schema.get("maximum", math.inf):
            raise OperationError("invalid_arguments", field=where)
    if "anyOf" in schema:
        for choice in schema["anyOf"]:
            try:
                validate(value, choice, where)
                break
            except OperationError:
                pass
        else:
            raise OperationError("invalid_arguments", field=where)


def descriptor(op_id, name, **fields):
    result = {"id": op_id, "name": name, "description": name, "availability": "unavailable",
              "input_schema": TEXT_SCHEMA, "output_schema": OUTPUT_SCHEMA, "units": {"input": "explicit in text", "output": "declared by implementation"},
              "sources": [], "examples": [], "implementation": {}, "limitations": []}
    result.update(fields)
    return result


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    try:
        spec.loader.exec_module(module)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    return module


class Operations:
    """Construct and call only on the same thread that owns Engine's runtime."""
    def __init__(self, engine, config):
        self.engine, self.config = engine, config
        self.items, self.calls, self.organs = {}, {}, {}
        self.root = config.data_root / "specialists"
        if not hasattr(engine, "_rt"):
            return  # transport-test fake launchers have no runtime registrations
        self._specialists()
        self._numeric()
        self._core()
        self._extensions()
        self._declarations()

    def add(self, item, call=None):
        item["transport_limits"] = {"request_body_bytes": getattr(self.config, "max_request_bytes", 16384),
                                    "reply_bytes": self.config.max_reply_bytes,
                                    "scope": "Whole JSON envelope; input-schema ceilings do not override transport bounds."}
        if not ID.fullmatch(item["id"]) or item["id"] in self.items:
            raise ValueError("invalid/duplicate operation identity")
        if item["availability"] == "live_direct" and not callable(call):
            raise ValueError("live operation has no callable")
        if len(encoded(item)) > 24000:
            raise ValueError("operation descriptor exceeds 24 KiB")
        self.items[item["id"]] = item
        if call is not None:
            self.calls[item["id"]] = call

    def _registered(self):
        # Read list references in modules actually present in this Engine's MRO.
        # This does not turn every directory or historical manifest into a route.
        standing = {}
        runtime = getattr(self.engine, "_rt", None)
        if runtime is None:
            return {}, []
        for cls in type(runtime).__mro__:
            module = sys.modules.get(cls.__module__)
            path = getattr(module, "__file__", None)
            if not path or not cls.__name__.startswith("OracleReleaseRuntime"):
                continue
            try:
                tree = ast.parse(Path(path).read_text())
            except (OSError, SyntaxError, UnicodeError):
                continue
            for node in ast.walk(tree):
                if isinstance(node, ast.Constant) and isinstance(node.value, str):
                    name = node.value.rsplit("/", 1)[-1]
                    if re.fullmatch(r"standing_[a-z0-9_]+(?:\.txt)?", name):
                        name = name if name.endswith(".txt") else name + ".txt"
                        standing.setdefault(name, set()).add(cls.__module__)
        ids, failures = {}, []
        for name, modules in sorted(standing.items()):
            path = self.root / "_gate" / name
            try:
                raw = path.read_text()
                if len(raw) > 65536:
                    raise ValueError("standing list too large")
                for entry in raw.split():
                    for sid in entry.split("+"):
                        if not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", sid):
                            raise ValueError("invalid standing specialist id")
                        ids.setdefault(sid, []).append({"list": name, "runtime_modules": sorted(modules)})
            except (OSError, ValueError) as error:
                failures.append({"list": name, "error_type": type(error).__name__})
        return ids, failures

    def _specialists(self):
        ids, self.registration_failures = self._registered()
        if not ids:
            return
        combo_path = self.root / "_gate/combo_runtime_v1.py"
        combo = load_module(combo_path, "appliance_direct_combo")
        self.combo = combo
        for sid, registrations in sorted(ids.items()):
            op_id = "specialist." + sid + ".answer"
            item = descriptor(op_id, sid, implementation={"entrypoint": "organ.answer", "registrations": registrations},
                              limitations=["Direct specialist call bypasses the head's routing and global guards.",
                                           "Native text input; no structured formula binding is claimed.",
                                           "Loadability and manifest acceptance do not establish answer correctness."])
            try:
                manifest_path = self.root / sid / "manifest.json"
                manifest = read_json(manifest_path, 1024 * 1024)
                if manifest.get("id") != sid:
                    raise ValueError("manifest id differs from registered id")
                organ = combo._Organ(str(manifest_path), str(self.root / sid))
                if not callable(getattr(organ.organ, "answer", None)):
                    raise ValueError("organ has no answer method")
                self.organs[sid] = organ
                item.update(name=manifest.get("name", sid), description=manifest.get("name", sid), availability="live_direct",
                            sources=manifest.get("sources", []), accepted_kinds=sorted(organ.kinds),
                            declined_kinds=sorted(organ.declines), routing_cues=manifest.get("routing_cues", []))
                item["implementation"].update(module=manifest["organ"]["module"], class_name=manifest["organ"]["class"],
                                              manifest_sha256=hashlib.sha256(manifest_path.read_bytes()).hexdigest())
                item["examples"] = self._examples(sid, manifest)
                self.add(item, lambda args, session, o=organ: self._organ_call(o, args["text"], session))
            except Exception as error:
                item.update(availability="unavailable", unavailable_reason="implementation_load_failed", error_type=type(error).__name__)
                self.add(item)

    def _examples(self, sid, manifest):
        path = manifest.get("panel", {}).get("path")
        if not isinstance(path, str):
            return []
        # Only package-local examples, and only development questions, never run.
        path = self.root / sid / Path(path).name
        try:
            rows = read_json(path)
            if not isinstance(rows, list):
                return []
            return [{"arguments": {"text": row["q"]}, "source": "shipped development panel; not executed by discovery"}
                    for row in rows if isinstance(row, dict) and row.get("split") == "dev" and isinstance(row.get("q"), str)
                    and len(row["q"]) < 500][:2]
        except (OSError, ValueError):
            return []

    def _organ_call(self, organ, text, session):
        if self.combo.READING.search(text):
            return {"status": "withheld", "reason": "reading_input_not_supported", "specialist": organ.id}
        with self.combo.CALL_LOCK, organ._env():
            method = organ.organ.answer
            signature = inspect.signature(method)
            try:
                signature.bind(text, organ.id + ":" + session)
                with_session = True
            except TypeError:
                signature.bind(text)
                with_session = False
            raw = method(text, organ.id + ":" + session) if with_session else method(text)
        if raw is None:
            return {"status": "withheld", "reason": "outside_specialist_domain", "specialist": organ.id}
        if not isinstance(raw, dict):
            raise TypeError("specialist answer is not an object")
        kind = raw.get("kind")
        admitted = kind in organ.kinds or (kind in organ.declines and bool(organ.ctx.search(text)))
        # Preserve the raw dictionary instead of _Organ.reply's five-field view.
        return {"status": ("withheld" if kind in organ.declines else raw.get("status", "answered")) if admitted else "withheld",
                "specialist": organ.id, "manifest_accepted": admitted,
                "reason": None if admitted else "manifest_did_not_accept", "result": json_value(raw)}

    def _numeric(self):
        # These functions already exist in loaded specialist implementations.
        # Never manufacture a question string or copy a formula into the adapter.
        sid = next((name for name in ("meteorology-v2", "meteorology") if name in self.organs), None)
        organ = self.organs.get(sid)
        if organ:
            module = organ.mods.get(organ.m["organ"]["module"])
            definitions = [
                ("heat_index_f", "Heat index in Fahrenheit", {"temperature_f": {"type": "number", "minimum": -459.67, "maximum": 200}, "relative_humidity_percent": {"type": "number", "minimum": 0, "maximum": 100}}, ["temperature_f", "relative_humidity_percent"], {"temperature_f": 84, "relative_humidity_percent": 40}, {"temperature_f": "degF", "relative_humidity_percent": "% RH"}, "degF"),
                ("f2c", "Fahrenheit to Celsius", {"temperature_f": {"type": "number", "minimum": -459.67, "maximum": 1e9}}, ["temperature_f"], {"temperature_f": 32}, {"temperature_f": "degF"}, "degC"),
                ("c2f", "Celsius to Fahrenheit", {"temperature_c": {"type": "number", "minimum": -273.15, "maximum": 1e9}}, ["temperature_c"], {"temperature_c": 20}, {"temperature_c": "degC"}, "degF"),
            ]
            for method, name, props, order, example, units, output_unit in definitions:
                fn = getattr(module, method, None)
                if not callable(fn):
                    continue
                schema = {"type": "object", "properties": props, "required": order, "additionalProperties": False}
                def call(args, session, fn=fn, order=order, unit=output_unit, organ=organ):
                    with self.combo.CALL_LOCK, organ._env():
                        result = fn(*(args[key] for key in order))
                    return {"status": "answered", "result": result, "unit": unit,
                            "evidence_scope": "Existing Python function result; no theorem claim."}
                self.add(descriptor("specialist." + sid + "." + method, name, availability="live_direct", input_schema=schema,
                                    units={"input": units, "output": output_unit}, sources=organ.m.get("sources", []),
                                    examples=[{"arguments": example}], implementation={"module": organ.m["organ"]["module"], "function": method},
                                    limitations=["Formula result within published model assumptions; not a forecast or individualized safety advice."]), call)
        # Only expose a parsed formula method when its registered organ really has it.
        for sid in ("chemistry-v3", "chemistry"):
            organ = self.organs.get(sid)
            if not organ or not callable(getattr(organ.organ, "molar_mass", None)):
                continue
            def molar(args, session, organ=organ):
                try:
                    with self.combo.CALL_LOCK, organ._env():
                        value, counts = organ.organ.molar_mass(args["formula"])
                except (ValueError, KeyError, IndexError):
                    return {"status": "withheld", "reason": "formula_not_supported"}
                if not counts or not all(type(n) is int and n > 0 for n in counts.values()) or not math.isfinite(value) or value <= 0:
                    return {"status": "withheld", "reason": "formula_not_supported"}
                return {"status": "answered", "value": value, "unit": "g/mol", "element_counts": counts,
                        "evidence_scope": "Existing specialist parser and periodic table; no independent formula proof."}
            self.add(descriptor("specialist." + sid + ".molar_mass", "Molar mass from a chemical formula", availability="live_direct",
                                input_schema={"type": "object", "properties": {"formula": {"type": "string", "minLength": 1, "maxLength": 128,
                                              "pattern": r"^[A-Za-z0-9().*·]+$"}}, "required": ["formula"], "additionalProperties": False},
                                units={"input": {"formula": "chemical formula"}, "output": "g/mol"}, sources=organ.m.get("sources", []),
                                examples=[{"arguments": {"formula": "H2O"}}], implementation={"class_name": type(organ.organ).__name__, "method": "molar_mass"},
                                limitations=["Uses the specialist's existing formula grammar and element table."]), molar)

    def _core(self):
        rt = getattr(self.engine, "_rt", None)
        if callable(getattr(rt, "chat", None)):
            self.add(descriptor("core.query", "Ask the complete Oracle runtime", availability="live_direct",
                                description="Run the full head with its routing, guards, dialogue and specialist/network composition.",
                                input_schema={"type": "object", "properties": {"text": {"type": "string", "minLength": 1, "maxLength": 60000}},
                                              "required": ["text"], "additionalProperties": False},
                                examples=[{"arguments": {"text": "Who wrote Leaves of Grass?"}}],
                                implementation={"entrypoint": "Engine._rt.chat", "thread": "Engine's existing dedicated thread"},
                                state_effects="Reads and updates the supplied conversation_id in this workspace, exactly like POST /query.",
                                limitations=["Full upstream reply retained; upstream assurance labels remain claims, not Mini authority.",
                                             "Do not repeat a successful turn under a new request ID unless another conversation turn is intended."]),
                     lambda args, session: rt.chat(args["text"], session_id=session))
        for op_id, factory, name in (("core.math.answer", "_c480_math", "Core symbolic mathematics organ"),
                                      ("core.relations.answer", "_c480_rel", "Core sourced relation organ")):
            if not callable(getattr(rt, factory, None)):
                continue
            item = descriptor(op_id, name, implementation={"runtime_factory": factory, "method": "answer"},
                              limitations=["Direct organ computation bypasses head routing and global guards; provenance is retained as supplied.",
                                            "Symbolic values use tagged SymPy expression/constructor records; non-string-keyed maps use tagged entry lists."])
            try:
                organ = getattr(rt, factory)()
                if not organ or not callable(getattr(organ, "answer", None)):
                    raise ValueError("core organ unavailable")
                def call(args, session, organ=organ):
                    reply = organ.answer(args["text"])
                    return {"status": reply.get("status", "answered") if isinstance(reply, dict) else "answered", "result": json_value(reply)} if reply is not None else {"status": "withheld", "reason": "outside_organ_domain"}
                item["availability"] = "live_direct"
                item["examples"] = [{"arguments": {"text": "Factor x^2 - 5*x + 6" if op_id == "core.math.answer" else "Who wrote Leaves of Grass?"},
                                     "source": "usage example; not a panel result"}]
                self.add(item, call)
            except Exception as error:
                item.update(unavailable_reason="implementation_load_failed", error_type=type(error).__name__)
                self.add(item)

    def _extensions(self):
        providers = [("workbench_operations.py", "tools/oracle_workbench/operations.py", "WorkbenchOperations"),
                     ("exam_inspection.py", "tools/oracle_workbench/exam_inspection.py", "ExamInspection"),
                     ("component_operations.py", "tools/oracle_components/decisions.py", "DecisionOperations"),
                     ("visual_operations.py", "tools/oracle_components/visual.py", "VisualOperations"),
                     ("builder_operations.py", "tools/oracle_components/builder.py", "BuilderOperations")]
        for packaged, development, class_name in providers:
            path = Path(__file__).resolve().with_name(packaged)
            if not path.exists():
                here = Path(__file__).resolve()
                if here.parent.name != "appliance" or here.parent.parent.name != "tools":
                    continue  # deployed adapters never search outside their package
                path = here.parents[2] / development
            if not path.is_file():
                continue
            try:
                provider = getattr(load_module(path, "appliance_" + class_name), class_name)(self.config.runtime, self.config.workspace)
                declarations = provider.catalog()
            except Exception as error:
                self.add(descriptor("provider." + class_name, class_name, unavailable_reason="provider_load_failed",
                                    error_type=type(error).__name__, limitations=["Optional provider failed to load; unrelated operations remain available."]))
                continue
            for declaration in declarations:
                item = descriptor(declaration["id"], declaration.get("name", declaration["id"]), **{k: v for k, v in declaration.items() if k not in ("id", "name")})
                def invoke_provider(args, session, provider=provider, op_id=item["id"]):
                    try:
                        return provider.invoke(op_id, args)
                    except ValueError as error:
                        # Provider contract: ValueError is bounded input validation,
                        # before capability work, never a deliberate domain refusal.
                        raise OperationError("invalid_arguments", 400) from error
                self.add(item, invoke_provider if item["availability"] == "live_direct" else None)

    def _declarations(self):
        # These are visible boundaries, not callable filesystem/network powers.
        for op_id, name, needed in (("workbench.files.external", "Files from the host filesystem", "host file capability"),
                                   ("workbench.sensors.poll", "Poll live sensors", "host network/device capability"),
                                   ("workbench.builder.run", "Build or run new specialist code", "separate build/execution capability")):
            self.add(descriptor(op_id, name, unavailable_reason="separate_capability_required",
                                input_schema={"type": "object", "properties": {}, "additionalProperties": False},
                                required_capability=needed, limitations=["Not granted by query or direct computation access."]))
        path = self.root / "_gate/specfold_ops_v1.json"
        if path.is_file():
            data = read_json(path)
            self.add(descriptor("network.learned_templates", "Learned specialist text templates", availability="text_only",
                                implementation={"declarations": len(data.get("ops", [])), "source": "specialists/_gate/specfold_ops_v1.json"},
                                limitations=["These declarations interpolate text within the upstream planner, not structured direct functions.",
                                             "Use the ordinary query route for head-directed composition; this declaration cannot be invoked."]))

    def discover(self, offset=0, limit=10, q="", availability=None, operation_id=None):
        if operation_id is not None:
            if operation_id not in self.items:
                raise OperationError("unknown_operation", 404)
            result = self.items[operation_id]
            if len(encoded(result)) > min(self.config.max_reply_bytes - 128, 32768):
                raise OperationError("discovery_reply_too_large", 413)
            return result
        rows = [item for _, item in sorted(self.items.items()) if (availability is None or item["availability"] == availability)
                and (not q or q.casefold() in (item["id"] + " " + item["name"] + " " + item["description"]).casefold())]
        page = {"protocol": "oracle-operations-v1", "total": len(rows), "offset": offset, "next_offset": None, "operations": [],
                "limits": {"request_body_bytes": self.config.max_request_bytes, "reply_bytes": min(self.config.max_reply_bytes - 128, 32768)}}
        for index in range(offset, min(offset + limit, len(rows))):
            candidate = dict(page, operations=page["operations"] + [rows[index]], next_offset=index + 1 if index + 1 < len(rows) else None)
            if len(encoded(candidate)) > min(self.config.max_reply_bytes - 128, 32768):
                if not page["operations"]:
                    raise OperationError("discovery_reply_too_large", 413)
                break
            page = candidate
        return page

    def invoke(self, operation_id, arguments, session):
        item = self.items.get(operation_id)
        if item is None:
            raise OperationError("unknown_operation", 404)
        if item["availability"] != "live_direct":
            raise OperationError("operation_unavailable", 409, availability=item["availability"])
        validate(arguments, item["input_schema"])
        return self.calls[operation_id](arguments, session)
