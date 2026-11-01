"""Untrusted, source-bound conversation bridge; never a pickle or effect recovery.

All calls run on Engine._ex. The source pin binds the admitted receipt, invoked
source modules, the reconciler and chat_context_v2. Missing reconciliation is unsupported, not empty
state. Owners outside this read-only profile (documents, teaching, tools, ego)
are explicitly uncovered; the host must keep their generation/reset boundary.
"""
from __future__ import annotations

from collections import deque
from copy import deepcopy
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import sys

PROTOCOL = "oracle-conversation-v1"
ADAPTER = "oracle-readonly-context-v1"
VERSION = 1
OWNERS = {"runtime_dialogue": "dialogue", "runtime_an_transition": "transitions",
          "runtime_an_paths": "_paths", "runtime_v4_disc": "_v4_disc"}
EXTENSIONS = tuple(OWNERS) + ("oracle_readonly_adapter", "runtime_an_conversion")
UNCOVERED = ["teaching", "documents", "files", "external_tools", "w572_ego_mood", "unknown_runtime_owners"]
MAX_BYTES = 512 * 1024


class SemanticWithheld(Exception):
    """A known bounded no-answer, distinct from source/state/operational failure."""
    def __init__(self, reason, response):
        super().__init__(reason)
        self.reason = reason
        self.response = response


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False)


def extension(owner, payload):
    return {"owner": owner, "version": VERSION,
            "payload_bytes": len(compact(payload).encode()), "payload": payload}


def pack(value, depth=0):
    """Lossless inert owner data: sets/deques/tuples and float origin survive."""
    if depth > 32:
        raise ValueError("conversation nesting limit")
    if value is None or type(value) is bool:
        return value
    if type(value) is int:
        if len(str(value)) > 256:
            raise ValueError("conversation integer limit")
        return {"$integer": str(value)}
    if type(value) is str:
        if len(value.encode()) > 16384:
            raise ValueError("conversation string limit")
        return value
    if type(value) is float:
        if not math.isfinite(value):
            raise ValueError("nonfinite conversation number")
        return {"$float": value.hex()}
    if type(value) is dict:
        if len(value) > 4096:
            raise ValueError("conversation collection limit")
        if any(type(k) is not str for k in value):
            raise ValueError("conversation dictionary key")
        return {"$dict": {k: pack(v, depth + 1) for k, v in value.items()}}
    if type(value) in (tuple, set, list, deque):
        if len(value) > 4096:
            raise ValueError("conversation collection limit")
        items = [pack(v, depth + 1) for v in value]
        if type(value) is set:
            items.sort(key=compact)
        return {"$sequence": type(value).__name__, "items": items,
                "maxlen": value.maxlen if type(value) is deque else None}
    raise ValueError("unsupported conversation object: " + type(value).__name__)


def unpack(value, depth=0):
    if depth > 32:
        raise ValueError("conversation nesting limit")
    if value is None or type(value) in (bool, int, str):
        return value
    if type(value) is not dict:
        raise ValueError("invalid owner encoding")
    if set(value) == {"$integer"}:
        literal = value["$integer"]
        if type(literal) is not str or len(literal) > 256:
            raise ValueError("conversation integer limit")
        return int(literal)
    if set(value) == {"$float"}:
        number = float.fromhex(value["$float"])
        if not math.isfinite(number):
            raise ValueError("nonfinite conversation number")
        return number
    if set(value) == {"$dict"}:
        if type(value["$dict"]) is not dict or len(value["$dict"]) > 4096:
            raise ValueError("conversation dictionary limit")
        return {k: unpack(v, depth + 1) for k, v in value["$dict"].items()}
    if set(value) != {"$sequence", "items", "maxlen"}:
        raise ValueError("invalid owner encoding")
    if type(value["items"]) is not list or len(value["items"]) > 4096:
        raise ValueError("conversation sequence limit")
    items = [unpack(v, depth + 1) for v in value["items"]]
    kind = value["$sequence"]
    if kind == "deque":
        return deque(items, maxlen=value["maxlen"])
    constructors = {"list": list, "tuple": tuple, "set": set}
    if kind not in constructors or value["maxlen"] is not None:
        raise ValueError("invalid owner sequence")
    result = constructors[kind](items)
    if kind == "set" and len(result) != len(items):
        raise ValueError("duplicate encoded set member")
    return result


def number(value, unit=""):
    if type(value) is int and not -(2 ** 63) <= value < 2 ** 64:
        raise ValueError("canonical prior integer range")
    if type(value) not in (int, float) or type(value) is float and not math.isfinite(value):
        raise ValueError("unsupported prior number")
    return {"number": value, "unit": unit,
            "origin": "python_float" if type(value) is float else "exact_decimal"}


def restore_number(value):
    n = value["number"]
    if type(n) not in (int, float) or type(n) is float and not math.isfinite(n):
        raise ValueError("invalid prior number")
    if value["origin"] in ("python_float", "displayed_decimal"):
        # displayed_decimal preserves the delivered token's declared limitation;
        # capture retains its origin while unchanged via explicit precision data.
        return n if value["origin"] == "displayed_decimal" else float(n)
    if value["origin"] != "exact_decimal":
        raise ValueError("unknown precision origin")
    # Preserve integers; refuse inexact projection rather than silently round.
    if type(n) is int:
        return n
    if Fraction.from_float(n) != Fraction(str(n)):
        raise ValueError("exact decimal cannot enter Python owner without rounding")
    return n


def entity(value, surface):
    if value is None:
        return None
    if type(value) not in (tuple, list) or len(value) != (4 if surface else 3):
        raise ValueError("invalid entity owner")
    qid, label, person = value[:3]
    if type(qid) is not int or qid <= 0 or type(label) is not str or type(person) is not bool:
        raise ValueError("invalid Wikidata entity")
    return {"id": "wd:Q" + str(qid), "label": label, "is_person": person,
            "surface": value[3] if surface else None}


def restore_entity(value, surface):
    if value is None:
        return None
    qid = value["id"]
    if type(qid) is not str or not qid.startswith("wd:Q") or not qid[4:].isdigit() or int(qid[4:]) <= 0:
        raise ValueError("entity namespace unsupported; no label-based identity conversion")
    result = (int(qid[4:]), value["label"], value["is_person"])
    return result + (value["surface"],) if surface else result


class Adapter:
    def __init__(self, runtime, tip):
        self.runtime = runtime
        self.cc = sys.modules.get("chat_context_v2")
        reconcile = sys.modules.get("runtime_conversation_state")
        final = sys.modules.get("runtime_final_outcome")
        if self.cc is None or reconcile is None or final is None:
            raise ValueError("conversation_owner_coverage_missing: finalized reconciliation")
        # Never synthesize _conversation_contexts from ambient module _STATES.
        if type(getattr(runtime, "_conversation_contexts", {})) is not dict:
            raise ValueError("conversation owner shape")
        root = Path(reconcile.__file__).resolve()
        checkout = next((p for p in root.parents if (p / "APPLIANCE.json").is_file()), None)
        if checkout is None:
            raise ValueError("conversation_admitted_materialization_required")
        receipt = (checkout / "APPLIANCE.json").read_bytes()
        receipt_hash = hashlib.sha256(receipt).hexdigest()
        if receipt_hash != "97286fb824bb102a24ac9e7458fc8d8426212ad0bff2b585bd00d6e0462d00a5" or tip != "oracle_release_runtime_w574":
            raise ValueError("conversation_source_profile_unsupported")
        sources = {"runtime_conversation_state": "bd59010ba45df5bbbfec39a71cb9dcdbc6a1eed9df2337db0eb0e5e1c3751be8",
                   "runtime_final_outcome": "9851cdcfac26f9ee0901d9c700f0ad6f18b2a52881f415b127ce203d926e8e2b",
                   "chat_context_v2": "271b62bf8e9c7228c30b7ac5bb00a5b2d2e0e7b9ba97a7976dd33bdeb404b514"}
        for name, expected in sources.items():
            if hashlib.sha256(Path(sys.modules[name].__file__).read_bytes()).hexdigest() != expected:
                raise ValueError("conversation_source_pin_mismatch")
        self.checkout = checkout
        self.inventory = json.loads(receipt)["files"]
        self.manifest = {"adapter": ADAPTER, "version": VERSION, "tip": tip,
                         "appliance_sha256": receipt_hash, "sources": sources,
                         "adapter_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        self.source = ADAPTER + ":sha256:" + hashlib.sha256(compact(self.manifest).encode()).hexdigest()

    def verify_file(self, path):
        path = Path(path).resolve()
        try:
            key = str(path.relative_to(self.checkout))
        except ValueError:
            raise ValueError("conversation_source_outside_admitted_release") from None
        expected = self.inventory.get(key, {}).get("sha256")
        if not expected or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("conversation_source_pin_mismatch:" + key)

    def verify_module(self, module):
        self.verify_file(module.__file__)


    def restore(self, sid, envelope):
        if type(envelope) is not dict or type(envelope.get("revision")) is not int:
            raise ValueError("explicit_committed_envelope_required")
        state = envelope.get("oracle")
        if len(compact(envelope).encode()) > MAX_BYTES:
            raise ValueError("conversation_restore_too_large")
        if state is None and envelope and envelope.get("revision") != 0:
            raise ValueError("conversation_unknown_owner_coverage_requires_reset")
        if state is not None:
            coverage = envelope.get("coverage", {})
            # The canonical host enforces release, tenant and revision binding.
            if coverage.get("source") != self.source or coverage.get("adapter_schema") != VERSION:
                raise ValueError("conversation_source_pin_mismatch")
            ext = state["extensions"]["oracle_readonly_adapter"]["payload"]
            if ext["source"] != self.source:
                raise ValueError("conversation_source_pin_mismatch")
        # Install every covered owner, including observed absence, before reuse.
        values = {} if state is None else state
        unknown = set(values.get("extensions", {})) - set(EXTENSIONS)
        if unknown or any(values.get(k) is not None for k in ("last_answer", "last_physics", "last_effect")):
            raise ValueError("conversation_uncovered_owner_requires_reset")
        self.precision = {"context": deepcopy((values.get("context") or {}).get("result")),
                          "scalar": deepcopy(values.get("last_value"))}
        pending = values.get("pending_interpretation")
        for owner, attr in OWNERS.items():
            table = getattr(self.runtime, attr, None)
            if table is None:
                table = {}; setattr(self.runtime, attr, table)
            if type(table) is not dict:
                raise ValueError("conversation owner shape: " + attr)
            item = values.get("extensions", {}).get(owner)
            table.pop(sid, None)
            if item is not None:
                if item["owner"] != owner or item["version"] != VERSION:
                    raise ValueError("conversation_owner_version")
                table[sid] = unpack(item["payload"])
        for attr, item in (("sessions", values.get("history", [])),
                           ("_last_value", values.get("last_value")),
                           ("_pending_conversion", pending),
                           ("_conversation_contexts", values.get("context"))):
            table = getattr(self.runtime, attr, None)
            if table is None:
                table = {}; setattr(self.runtime, attr, table)
            if type(table) is not dict:
                raise ValueError("conversation owner shape: " + attr)
            table.pop(sid, None)
            if item is None:
                continue
            if attr == "_last_value":
                if item["unit"]:
                    raise ValueError("dimensioned scalar cache projection")
                item = restore_number(item)
            elif attr == "_pending_conversion":
                item = unpack(item["conversion"]["payload"])
            elif attr == "_conversation_contexts":
                turn = self.cc.Turn()
                turn.q = item["question"]
                turn.subj = restore_entity(item["subject"], True)
                turn.ans = restore_entity(item["answer"], False)
                turn.topic = restore_entity(item["topic"], True)
                turn.result = None if item["result"] is None else (restore_number(item["result"]), item["result"]["unit"])
                turn.solved = deepcopy(item["solved"]); turn.material = item["material"]
                item = turn
            table[sid] = deepcopy(item)
        # These canonical lineage owners were explicitly absent in the supplied
        # profile state; safe routes never call their consumers (_lesson/_done).
        for attr in ("_last_answer", "_last_physics"):
            table = getattr(self.runtime, attr, None)
            if table is not None:
                if type(table) is not dict:
                    raise ValueError("conversation owner shape: " + attr)
                table.pop(sid, None)
        # Base _history otherwise resurrects uncommitted session files: sessions
        # always contains an explicit list (including empty) after restore.

    def capture(self, sid):
        rt = self.runtime
        contexts = getattr(rt, "_conversation_contexts", {})
        turn = contexts.get(sid)
        context = None
        if turn is not None:
            if set(vars(turn)) != {"q", "subj", "ans", "result", "solved", "material", "topic"}:
                raise ValueError("unknown Turn owner fields")
            context = {"question": turn.q, "subject": entity(turn.subj, True),
                       "answer": entity(turn.ans, False), "topic": entity(turn.topic, True),
                       "result": None if turn.result is None else self.prior_number(*turn.result, owner="context"),
                       "solved": deepcopy(turn.solved), "material": turn.material}
        extensions = {}
        for owner, attr in OWNERS.items():
            table = getattr(rt, attr, {})
            if type(table) is not dict:
                raise ValueError("conversation owner shape: " + attr)
            if sid in table:
                extensions[owner] = extension(owner, pack(table[sid]))
        extensions["oracle_readonly_adapter"] = extension("oracle_readonly_adapter", {"source": self.source, "manifest": self.manifest,
            "coverage": "enumerated_readonly_owners", "uncovered": UNCOVERED})
        pending = getattr(rt, "_pending_conversion", {}).get(sid)
        pending = None if pending is None else {"from": pending.get("from", ""), "to": pending.get("to", ""),
                   "conversion": extension("runtime_an_conversion", pack(pending))}
        value = getattr(rt, "_last_value", {}).get(sid)
        state = {"history": deepcopy(getattr(rt, "sessions", {}).get(sid, [])),
                 "context": context, "last_value": None if value is None else self.prior_number(value, owner="scalar"),
                 "pending_interpretation": pending, "last_answer": None,
                 "last_physics": None, "last_effect": None, "extensions": extensions}
        if len(compact(state).encode()) > MAX_BYTES:
            raise ValueError("conversation_capture_too_large")
        return {"protocol": PROTOCOL, "source": self.source, "adapter_schema": VERSION,
                "coverage": {"complete": True, "scope": "supported_adapter_routes", "owners": list(OWNERS) + ["sessions", "_conversation_contexts", "_last_value", "_pending_conversion"], "unsupported": UNCOVERED}, "state": state}

    def prior_number(self, value, unit="", *, owner):
        prior = getattr(self, "precision", {}).get(owner)
        if prior is not None and prior["number"] == value and prior["unit"] == unit:
            return deepcopy(prior)
        return number(value, unit)


    def project(self, sid, delivered):
        """Install only host-supplied typed delivered facts, never parse prose IDs."""
        projection = delivered.get("conversation_projection")
        if type(projection) is not dict:
            raise ValueError("typed_delivery_projection_required")
        if projection.get("preserve") is True or projection.get("acknowledgement") is True:
            return
        turn = self.cc.Turn()
        turn.q = projection.get("question")
        for field, key, surface in (("subj", "subject", True), ("ans", "answer", False), ("topic", "topic", True)):
            ref = projection.get(key)
            if ref is not None and ref.get("is_person") is None:
                ref = dict(ref)
                parsed = restore_entity({**ref, "is_person": False}, surface)
                rs = __import__("relation_spec_v1")
                ref["is_person"] = 5 in rs.classes_of(parsed[0])[0]
            setattr(turn, field, restore_entity(ref, surface))
        prior = projection.get("result")
        self.precision = {"context": deepcopy(prior), "scalar": deepcopy(projection.get("scalar"))}
        turn.result = None if prior is None else (restore_number(prior), prior["unit"])
        self.runtime._conversation_contexts[sid] = turn
        scalar = projection.get("scalar")
        self.runtime._last_value.pop(sid, None)
        if scalar is not None:
            if scalar["unit"]:
                raise ValueError("dimensioned scalar cache projection")
            self.runtime._last_value[sid] = restore_number(scalar)
        self.runtime._pending_conversion.pop(sid, None)
        self.runtime._v4_disc.pop(sid, None)
        self.runtime.dialogue[sid] = {"last_result": {k: deepcopy(delivered.get(k)) for k in ("status", "path", "provenance")}}

    def evaluate(self, sid, text):
        """Preflight a finite source-audited route; never call arbitrary eng.chat.

        w29 arithmetic is invoked only after its own total parser succeeds.
        Physics uses the admitted organ's whole-question reader. Entity reads
        use explicit Wikidata IDs from the unique store edge, never reply text.
        """
        import re
        from importlib import import_module
        reconcile = sys.modules["runtime_conversation_state"]
        frame = reconcile.begin(self.runtime, text, sid)
        try:
            question = re.sub(r"^\s*(?:new topic|switching topics|change of topic)\s*:\s*", "", text, flags=re.I)
            st = self.cc._STATES[sid]
            if re.fullmatch(r"\s*(?:ok|okay|got it|thanks|thank you)[.!]?\s*", question, re.I):
                self.runtime._conversation_contexts[sid] = deepcopy(st)
                return {"status": "answered", "response": "Got it.", "path": "act:acknowledge",
                        "provenance": {"adapter": ADAPTER, "kind": "acknowledgement", "context_transition": "preserve"}}
            rewritten = self.cc.rewrite(sid, question)
            resolved = rewritten if type(rewritten) is str else question
            w29 = import_module("oracle_release_runtime_w29")
            self.verify_module(w29)
            # Restrict virtual dispatch to a facade whose methods are exactly
            # this pinned fold. No descendant may add behavior to these calls.
            from types import SimpleNamespace, MethodType
            base = w29.OracleReleaseRuntimeW29
            loan = SimpleNamespace(**{name: getattr(self.runtime, name) for name in ("_last_value", "_paths", "_pending_conversion")})
            for name in ("_compute", "_resolve_followup", "_carry", "_witness_compute"):
                setattr(loan, name, MethodType(getattr(base, name), loan))
            probe, carried = loan._resolve_followup(resolved, sid)
            arithmetic = probe if carried else resolved
            lexical = w29._TRAIL.sub("", w29._LEAD.sub("", arithmetic))
            spans = list(re.finditer(r"[0-9]+(?:\.[0-9]*)?|[A-Za-z]+|\*\*|[+\-*/()^×÷]", lexical))
            cursor = 0
            whole = len(spans) <= 256 and len(lexical) <= 2048
            for span in spans:
                whole = whole and not lexical[cursor:span.start()].strip()
                cursor = span.end()
            whole = whole and not lexical[cursor:].strip()
            parsed = loan._compute(arithmetic) if whole else None
            if parsed is not None:
                reply = base.chat(loan, resolved, sid)
                if reply.get("status") == "withheld":
                    raise SemanticWithheld("arithmetic_refused", reply.get("response", "That arithmetic expression has no defined value."))
                if reply.get("status") == "answered":
                    self.precision = {}
                    st.q = resolved; st.result = (self.runtime._last_value[sid], "")
                    st.subj = None; st.ans = None; st.topic = None; st.solved = {}; st.material = None
                    self.runtime._conversation_contexts[sid] = deepcopy(st)
                    self.runtime._pending_conversion.pop(sid, None)
                return self._resolved(reply, question, resolved)
            scale = re.fullmatch(r"(?:[Mm]ultiply|[Dd]ivide) (?:that|this|it) by ([0-9]+(?:\.[0-9]+)?)[?.!]?", question)
            if scale and st.result and st.result[1]:
                value, unit = st.result
                factor = Fraction(scale[1])
                if question.lower().startswith("divide"):
                    if factor == 0:
                        raise SemanticWithheld("undefined_quantity_division", "A quantity cannot be divided by zero.")
                    factor = 1 / factor
                output = float(Fraction(str(value)) * factor)
                number(output, unit)
                reply = {"status": "answered", "response": "%s %s." % (format(output, ".12g"), unit),
                         "path": "adapter:quantity_scale", "value": output, "unit": unit,
                         "provenance": {"kind": "quantity_scale", "input": self.prior_number(value, unit, owner="context"),
                                        "factor": str(factor), "origin": "python_float"}}
                self.precision = {}; st.q = question; st.result = (output, unit); st.solved = {}
                self.runtime._conversation_contexts[sid] = deepcopy(st)
                self.runtime._last_value.pop(sid, None); self.runtime._pending_conversion.pop(sid, None)
                return reply
            # A cost request has one quantity and a rate with that same unit.
            cost = re.fullmatch(r"What does (?:that|this) cost at \$([0-9]+(?:\.[0-9]+)?) per ([A-Za-z]+)\?", question)
            if cost and st.result:
                value, unit = st.result
                rate_unit = cost[2]
                # Unit symbols are case-sensitive: mJ and MJ differ by 10^9.
                # Only this audited cross-unit conversion is admitted here.
                ratios = {("J", "kWh"): Fraction(1, 3600000)}
                ratio = Fraction(1) if unit == rate_unit else ratios.get((unit, rate_unit))
                if ratio is None:
                    raise SemanticWithheld("quantity_unit_mismatch", "That rate unit does not match the retained quantity.")
                amount = Fraction(str(value)) * ratio * Fraction(cost[1])
                v = float(amount)
                if not math.isfinite(v):
                    raise ValueError("nonfinite cost")
                reply = {"status": "answered", "response": "The cost is $%s." % format(v, ".12g"),
                         "path": "adapter:quantity_cost", "value": v, "unit": "$",
                         "provenance": {"kind": "quantity_cost", "input": self.prior_number(value, unit, owner="context"), "rate": cost[1],
                                        "rate_unit": rate_unit, "conversion_factor": str(ratio), "origin": "python_float"}}
                self.precision = {}
                st.q = question; st.result = (v, "$"); st.solved = {}
                self.runtime._conversation_contexts[sid] = deepcopy(st)
                self.runtime._last_value.pop(sid, None)
                self.runtime._pending_conversion.pop(sid, None)
                return reply
            physics = getattr(self.runtime, "_organs", {}).get("physics")
            if physics is not None:
                for module in (physics.G, physics.G.R, physics.G.systems, sys.modules[type(physics).__module__]):
                    self.verify_module(module)
            if physics is not None and physics.G.read(resolved)[0] is not None:
                self.verify_file(Path(physics.state) / "swarm" / "parts.json")
                want, givens = physics.G.read(resolved)[0]
                given = {(name, dims) for name, _value, dims in givens}
                plans = []
                for key in physics.planner.by_out:
                    if key[0] == want:
                        plans.extend(physics.planner.plans(key, given))
                if len(plans) > 256:
                    raise ValueError("physics plan limit")
                for plan in plans:
                    for part in plan:
                        self.verify_file(Path(physics.state) / "specialists" / part["id"] / "program.py")
                # Use grow60's typed result before voice10's thin wrapper drops
                # its decline kind. Unknown/malformed results remain failures.
                raw = physics.G.ask(physics.planner, resolved)
                if type(raw) is not dict:
                    raise ValueError("conversation_physics_invalid_reply")
                if raw.get("status") == "declined":
                    if raw.get("kind") in ("form", "no_part", "no_value", "disagree") and type(raw.get("why")) is str:
                        raise SemanticWithheld("physics_" + raw["kind"], raw["why"])
                    raise ValueError("conversation_physics_unknown_decline")
                if raw.get("status") != "answered":
                    raise ValueError("conversation_physics_unknown_status")
                parts = []
                for pid in raw["plan"]:
                    part = physics.raw[pid]
                    source = pid.split("#")[0]
                    program = Path(physics.state) / "specialists" / pid / "program.py"
                    self.verify_file(program)
                    parts.append({"part": pid, "inputs": part.get("inputs"), "output": part.get("output"),
                                  "source": "https://www.wikidata.org/wiki/" + source if source.startswith("Q") else "derived inside Oracle7",
                                  "program_sha256": hashlib.sha256(program.read_bytes()).hexdigest()})
                unit = re.search(r"\(([^()]*)\)\s*$", parts[-1]["output"])
                if unit is None:
                    raise ValueError("physics quantity unit missing")
                v, u = raw["value"], unit[1]
                number(v, u)
                show = {"parts": parts, "plans_agreeing": raw["plans"], "units": "SI"}
                reply = {"status": "answered", "response": "%.6g %s" % (v, u), "path": "organ:physics60>proved",
                         "value": v, "unit": u, "provenance": {"organ": "physics60", "show": show,
                         "adapter": ADAPTER, "quantity_origin": "python_float"}}
                self.precision = {}
                st.q = resolved; st.result = (v, u); st.solved = {}
                self.runtime._conversation_contexts[sid] = deepcopy(st)
                self.runtime._last_value.pop(sid, None)
                self.runtime._pending_conversion.pop(sid, None)
                return self._resolved(reply, question, resolved)
            rs = import_module("relation_spec_v1")
            self.verify_module(rs)
            self.verify_module(rs.X)
            self.verify_module(sys.modules[type(rs._rs()).__module__])
            author = re.fullmatch(r"Who wrote (.+)\?", resolved)
            birthplace = re.fullmatch(r"Where was (.+) born\?", resolved)
            prop = 50 if author else 19 if birthplace else None
            if prop is not None:
                label = (author or birthplace)[1]
                # A rewrite names a retained ID; preserve it, not a fresh link.
                known = [e for e in (st.ans, st.subj, st.topic) if e and e[1] == label]
                if known:
                    ids = {e[0] for e in known}
                else:
                    norm = rs.X.norm(label)
                    ids = {int(c[0]) for c in rs.X.L.candidates(norm, 6)}
                rows = {qid: {obj for pp, obj, _literal in rs._rs().props_of(qid) if pp == prop and obj} for qid in ids}
                if not rows or any(len(values) != 1 for values in rows.values()) or len({next(iter(v)) for v in rows.values()}) != 1:
                    raise SemanticWithheld("entity_not_unique", "The source does not give one unambiguous answer to that question.")
                raw = next(iter(next(iter(rows.values()))))
                if type(raw) is int:
                    qid = raw
                elif type(raw) is str and re.fullmatch(r"Q?[0-9]+", raw):
                    qid = int(raw.removeprefix("Q"))
                else:
                    raise ValueError("conversation_entity_value_not_identifier")
                answer_label = rs._rs().label(qid)
                # Multiple subjects with one answer are not one subject identity.
                if len(ids) != 1 or not answer_label:
                    raise SemanticWithheld("subject_not_unique", "That question does not identify one subject in the source.")
                subject_id = next(iter(ids))
                subject_label = rs._rs().label(subject_id) or label
                st.q = resolved; st.subj = (subject_id, subject_label, 5 in rs.classes_of(subject_id)[0], label)
                st.ans = (qid, answer_label, prop == 50); st.topic = st.subj; st.result = None; st.solved = {}
                self.runtime._conversation_contexts[sid] = deepcopy(st)
                self.runtime._last_value.pop(sid, None)
                self.runtime._pending_conversion.pop(sid, None)
                reply = {"status": "answered", "response": answer_label + ".", "path": "adapter:relation_store",
                         "provenance": {"kind": "typed_relation", "subject": entity(st.subj, True), "answer": entity(st.ans, False), "property": "wd:P" + str(prop), "adapter": ADAPTER}}
                return self._resolved(reply, question, resolved)
            raise SemanticWithheld("route_unsupported", "This conversation profile cannot answer that request.")
        finally:
            reconcile.release(frame)

    @staticmethod
    def _resolved(reply, original, resolved):
        if original != resolved:
            reply = deepcopy(reply)
            reply["provenance"]["chat_resolved"] = {"turn": original, "read_as": resolved}
            reply["path"] = "chat:resolved>" + reply["path"]
        return reply
