"""Focused fixtures for the inert conversation boundary; no real Engine startup."""
import importlib.util
import os
import re
from copy import deepcopy
from tempfile import TemporaryDirectory
from unittest.mock import patch
from collections import deque
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

PATH = Path(__file__).resolve().parents[1] / "conversation_adapter.py"
spec = importlib.util.spec_from_file_location("conversation_adapter", PATH)
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)


class Turn:
    def __init__(self):
        self.q = self.subj = self.ans = self.result = self.material = self.topic = None
        self.solved = {}


class Boundary(unittest.TestCase):
    def adapter(self):
        a = A.Adapter.__new__(A.Adapter)
        a.runtime = SimpleNamespace()
        a.cc = SimpleNamespace(Turn=Turn)
        a.source = "fixture-source"
        a.manifest = {"fixture": True}
        return a

    def initial(self):
        return {"revision": 0, "oracle": None, "coverage": {"kind": "native_selection_only"}}

    def envelope(self, capture):
        return {"revision": 1, "oracle": capture["state"], "coverage": {
            "kind": "oracle_adapter", "source": capture["source"], "adapter_schema": 1}}

    def test_owner_types_and_float_bits_survive(self):
        value = {"path": deque([{"terms": {"energy", "cost"}, "tuple": (0.1, 2 ** 90)}], maxlen=64)}
        got = A.unpack(A.pack(value))
        self.assertEqual(got, value)
        self.assertEqual(got["path"].maxlen, 64)
        self.assertEqual(got["path"][0]["tuple"][0].hex(), (0.1).hex())

    def test_native_quantity_projects_and_survives_fresh_worker(self):
        a = self.adapter(); a.restore("s", self.initial())
        quantity = {"number": 20, "unit": "J", "origin": "python_float"}
        a.project("s", {"status": "answered", "path": "organ:physics60>proved",
            "conversation_projection": {"question": "energy", "result": quantity, "scalar": None}})
        captured = a.capture("s")
        self.assertEqual(captured["state"]["context"]["result"]["unit"], "J")
        self.assertIsNone(captured["state"]["last_value"])
        b = self.adapter(); b.restore("s", self.envelope(captured))
        self.assertEqual(b.runtime._conversation_contexts["s"].result, (20.0, "J"))
        self.assertEqual(b.runtime.sessions["s"], [])

    def test_entity_identity_round_trip_does_not_link_label(self):
        a = self.adapter(); a.restore("s", self.initial())
        entity = {"id": "wd:Q81438", "label": "Walt Whitman", "is_person": True, "surface": "Walt Whitman"}
        a.project("s", {"status": "answered", "conversation_projection": {
            "question": "Who wrote Leaves of Grass?", "answer": entity, "topic": entity}})
        b = self.adapter(); b.restore("s", self.envelope(a.capture("s")))
        self.assertEqual(b.runtime._conversation_contexts["s"].ans, (81438, "Walt Whitman", True))
        with self.assertRaises(ValueError):
            A.restore_entity({**entity, "id": "image:692"}, True)

    def test_displayed_quantity_precision_origin_survives_restore(self):
        a = self.adapter(); a.restore("s", self.initial())
        quantity = {"number": 0.1, "unit": "kWh", "origin": "displayed_decimal"}
        a.project("s", {"status": "answered", "conversation_projection": {"question": "energy", "result": quantity}})
        first = a.capture("s")
        b = self.adapter(); b.restore("s", self.envelope(first))
        self.assertEqual(b.capture("s")["state"]["context"]["result"], quantity)

    def test_unknown_prior_coverage_cannot_become_blank(self):
        with self.assertRaisesRegex(ValueError, "requires_reset"):
            self.adapter().restore("s", {"revision": 1, "oracle": None})

    def test_ack_and_refusal_preserve_pending(self):
        a = self.adapter(); a.restore("s", self.initial())
        a.runtime._pending_conversion["s"] = {"from": "a", "to": "b"}
        before = a.capture("s")
        a.project("s", {"conversation_projection": {"acknowledgement": True}})
        a.project("s", {"conversation_projection": {"preserve": True}})
        self.assertEqual(a.capture("s"), before)

    def test_worker_loads_admitted_sibling_despite_import_shadow(self):
        worker_path = PATH.with_name("engine_worker.py")
        worker_spec = importlib.util.spec_from_file_location("fixture_engine_worker", worker_path)
        worker = importlib.util.module_from_spec(worker_spec)
        with patch.dict(os.environ, {"PYTHONHASHSEED": "0", "PYTHONDONTWRITEBYTECODE": "1"}):
            worker_spec.loader.exec_module(worker)
        fake = SimpleNamespace(Adapter=lambda *_: self.fail("shadow module executed"), PROTOCOL="impostor")
        executor = SimpleNamespace(submit=lambda fn: SimpleNamespace(result=fn))
        eng = SimpleNamespace(_rt=SimpleNamespace(), tip="fixture", _ex=executor)
        with TemporaryDirectory() as folder:
            Path(folder, "conversation_adapter.py").write_text("raise AssertionError('shadow path executed')\n")
            with patch.object(sys, "path", [folder, *sys.path]), patch.dict(sys.modules, {"conversation_adapter": fake}):
                with self.assertRaisesRegex(ValueError, "conversation_owner_coverage_missing"):
                    worker.conversation_answer(eng, None, None, "2 + 2", "s", False,
                                              {"protocol": A.PROTOCOL, "state": self.initial()})
                self.assertEqual(Path(worker._CONVERSATION_ADAPTER.__file__).resolve(), PATH.resolve())
                # A subsequent call uses the explicitly loaded sibling cache,
                # rather than consulting either import cache or altered sys.path.
                with patch.object(worker, "_load", side_effect=AssertionError("reloaded")):
                    with self.assertRaisesRegex(ValueError, "conversation_owner_coverage_missing"):
                        worker.conversation_answer(eng, None, None, "2 + 2", "s", False,
                                                  {"protocol": A.PROTOCOL, "state": self.initial()})

    def refusal_worker(self, adapter):
        worker_spec = importlib.util.spec_from_file_location("fixture_refusal_worker", PATH.with_name("engine_worker.py"))
        worker = importlib.util.module_from_spec(worker_spec)
        with patch.dict(os.environ, {"PYTHONHASHSEED": "0", "PYTHONDONTWRITEBYTECODE": "1"}):
            worker_spec.loader.exec_module(worker)
        worker._CONVERSATION_ADAPTER = SimpleNamespace(
            Adapter=lambda *_: adapter, PROTOCOL=A.PROTOCOL, SemanticWithheld=A.SemanticWithheld)
        executor = SimpleNamespace(submit=lambda fn: SimpleNamespace(result=fn))
        return worker, SimpleNamespace(_rt=adapter.runtime, tip="fixture", _ex=executor)

    def prior_quantity(self):
        a = self.adapter(); a.restore("s", self.initial())
        a.project("s", {"status": "answered", "conversation_projection": {
            "question": "energy", "result": {"number": 0.1, "unit": "kWh", "origin": "displayed_decimal"}}})
        a.runtime._pending_conversion["s"] = {"from": "prior", "to": "retained"}
        a.runtime._paths["s"] = deque([{"turn": 7}], maxlen=64)
        a.runtime.transitions["s"] = {"out_terms": {"energy"}}
        return a, self.envelope(a.capture("s"))

    def test_known_semantic_refusals_restore_prior_and_capture(self):
        for reason in ("route_unsupported", "entity_not_unique", "subject_not_unique", "arithmetic_refused", "undefined_quantity_division"):
            with self.subTest(reason=reason):
                a, committed = self.prior_quantity()
                before = a.capture("s")
                events = []
                restore, capture = a.restore, a.capture
                def evaluate(sid, text):
                    try:
                        a.runtime._conversation_contexts.pop(sid, None)
                        a.runtime._last_value[sid] = 99
                        a.runtime._pending_conversion.pop(sid, None)
                        a.runtime._paths.pop(sid, None)
                        a.precision = {}
                        raise A.SemanticWithheld(reason, "No unique answer.")
                    finally:
                        events.append("released")
                def restoring(sid, state):
                    events.append("restore")
                    return restore(sid, state)
                def capturing(sid):
                    events.append("capture")
                    return capture(sid)
                a.evaluate, a.restore, a.capture = evaluate, restoring, capturing
                worker, eng = self.refusal_worker(a)
                result = worker.conversation_answer(eng, None, None, "new topic: unsupported", "s", False,
                    {"protocol": A.PROTOCOL, "state": committed})
                self.assertEqual(result["status"], "withheld")
                self.assertEqual(result["provenance"]["context_transition"], "preserve")
                self.assertEqual(result["conversation"], before)
                self.assertEqual(events, ["restore", "released", "restore", "capture"])

    def test_source_route_branches_emit_only_dedicated_no_answer(self):
        for question, expected in (("write a file", "route_unsupported"),
                                   ("Where was Someone born?", "entity_not_unique"),
                                   ("new topic: 1 / 0", "arithmetic_refused"),
                                   ("divide that by 0", "undefined_quantity_division")):
            with self.subTest(question=question):
                a, committed = self.prior_quantity()
                before = a.capture("s")
                a.cc._STATES = {}; a.cc.rewrite = lambda *_: None
                events = []
                def begin(runtime, text, sid):
                    a.cc._STATES[sid] = deepcopy(runtime._conversation_contexts[sid])
                    if text.startswith("new topic:"):
                        a.cc._STATES[sid] = Turn()
                        runtime._last_value.pop(sid, None)
                    return {"sid": sid}
                def release(frame):
                    a.cc._STATES.pop(frame["sid"], None)
                    events.append("released")
                def compute(_self, text):
                    return ("refuse", "undefined") if text == "1 / 0" else None
                base = SimpleNamespace(_compute=compute, _resolve_followup=lambda _self, text, _sid: (text, False),
                    _carry=lambda *_: None, _witness_compute=lambda *_: None,
                    chat=lambda *_: {"status": "withheld", "response": "Undefined.", "path": "compute:refused"})
                w29 = SimpleNamespace(OracleReleaseRuntimeW29=base, _TRAIL=re.compile(r"[\s?.!]+$"),
                                      _LEAD=re.compile(r"^what is\s+", re.I))
                store = SimpleNamespace(props_of=lambda qid: [(19, qid + 10, None)])
                rs = SimpleNamespace(_rs=lambda: store, X=SimpleNamespace(norm=lambda x: x,
                    L=SimpleNamespace(candidates=lambda *_: [(1, 1), (2, 1)])))
                a.verify_module = lambda *_: None
                worker, eng = self.refusal_worker(a)
                with patch.dict(sys.modules, {"runtime_conversation_state": SimpleNamespace(begin=begin, release=release),
                                              "oracle_release_runtime_w29": w29, "relation_spec_v1": rs}):
                    result = worker.conversation_answer(eng, None, None, question, "s", False,
                        {"protocol": A.PROTOCOL, "state": committed})
                self.assertEqual(result["path"], "adapter:withheld>" + expected)
                self.assertEqual(events, ["released"])
                self.assertEqual(result["conversation"], before)

    def test_cost_unit_case_is_dimensional_and_joule_kwh_is_explicit(self):
        cases = [("mJ", "MJ", 1, None), ("MJ", "mJ", 1, None),
                 ("J", "kwh", 3600000, None), ("j", "kWh", 3600000, None),
                 ("mJ", "mJ", 2, 0.4), ("J", "kWh", 3600000, 0.2)]
        for unit, rate_unit, value, expected in cases:
            with self.subTest(unit=unit, rate_unit=rate_unit):
                a = self.adapter(); a.restore("s", self.initial())
                a.project("s", {"status": "answered", "conversation_projection": {
                    "question": "quantity", "result": {"number": value, "unit": unit, "origin": "displayed_decimal"}}})
                before = a.capture("s"); committed = self.envelope(before)
                a.cc._STATES = {}; a.cc.rewrite = lambda *_: None
                def begin(runtime, _text, sid):
                    a.cc._STATES[sid] = deepcopy(runtime._conversation_contexts[sid]); return {"sid": sid}
                def release(frame):
                    a.cc._STATES.pop(frame["sid"], None)
                base = SimpleNamespace(_compute=lambda *_: None, _resolve_followup=lambda _self, text, _sid: (text, False),
                    _carry=lambda *_: None, _witness_compute=lambda *_: None)
                w29 = SimpleNamespace(OracleReleaseRuntimeW29=base, _TRAIL=re.compile(r"[\s?.!]+$"), _LEAD=re.compile(r"^what is\s+", re.I))
                a.verify_module = lambda *_: None
                worker, eng = self.refusal_worker(a)
                with patch.dict(sys.modules, {"runtime_conversation_state": SimpleNamespace(begin=begin, release=release),
                                              "oracle_release_runtime_w29": w29}):
                    result = worker.conversation_answer(eng, None, None, "What does that cost at $0.20 per " + rate_unit + "?", "s", False,
                        {"protocol": A.PROTOCOL, "state": committed})
                if expected is None:
                    self.assertEqual(result["path"], "adapter:withheld>quantity_unit_mismatch")
                    self.assertEqual(result["conversation"], before)
                else:
                    self.assertEqual(result["status"], "answered")
                    self.assertEqual(result["value"], expected)
                    self.assertEqual(result["unit"], "$")
                    self.assertEqual(result["provenance"]["input"]["unit"], unit)
                    self.assertEqual(result["provenance"]["rate_unit"], rate_unit)

    def test_physics_known_declines_preserve_and_bad_results_fail(self):
        cases = [({"status": "declined", "kind": kind, "why": "No supported result."}, "physics_" + kind)
                 for kind in ("form", "no_part", "no_value", "disagree")]
        cases += [(None, None), ({"status": "error", "kind": "no_part", "why": "failure"}, None),
                  ({"status": "declined", "kind": "unknown", "why": "unknown"}, None),
                  ({"status": "declined", "kind": "no_part"}, None),
                  ({"status": "answered", "plan": []}, None)]
        for raw, reason in cases:
            with self.subTest(raw=raw):
                a, committed = self.prior_quantity()
                before = a.capture("s")
                a.cc._STATES = {}; a.cc.rewrite = lambda *_: None
                def begin(runtime, _text, sid):
                    a.cc._STATES[sid] = deepcopy(runtime._conversation_contexts[sid]); return {"sid": sid}
                def release(frame):
                    a.cc._STATES.pop(frame["sid"], None)
                base = SimpleNamespace(_compute=lambda *_: None, _resolve_followup=lambda _self, text, _sid: (text, False),
                    _carry=lambda *_: None, _witness_compute=lambda *_: None)
                w29 = SimpleNamespace(OracleReleaseRuntimeW29=base, _TRAIL=re.compile(r"[\s?.!]+$"), _LEAD=re.compile(r"^what is\s+", re.I))
                growth = SimpleNamespace(read=lambda *_: (("energy", []), None), ask=lambda *_: raw,
                                         R=SimpleNamespace(), systems=SimpleNamespace())
                a.runtime._organs = {"physics": SimpleNamespace(G=growth, state="/fixture",
                                                               planner=SimpleNamespace(by_out={}))}
                a.verify_module = lambda *_: None; a.verify_file = lambda *_: None
                worker, eng = self.refusal_worker(a)
                with patch.dict(sys.modules, {"runtime_conversation_state": SimpleNamespace(begin=begin, release=release),
                                              "oracle_release_runtime_w29": w29}):
                    request = {"protocol": A.PROTOCOL, "state": committed}
                    if reason is None:
                        with self.assertRaises((ValueError, KeyError, IndexError)):
                            worker.conversation_answer(eng, None, None, "What is the energy?", "s", False, request)
                    else:
                        result = worker.conversation_answer(eng, None, None, "What is the energy?", "s", False, request)
                        self.assertEqual(result["path"], "adapter:withheld>" + reason)
                        self.assertEqual(result["conversation"], before)

    def test_operational_failures_are_never_semantic_refusals(self):
        for stage in ("evaluate", "restore", "capture"):
            with self.subTest(stage=stage):
                a, committed = self.prior_quantity()
                a.evaluate = lambda *_: (_ for _ in ()).throw(A.SemanticWithheld("route_unsupported", "Unsupported."))
                if stage == "evaluate":
                    a.evaluate = lambda *_: (_ for _ in ()).throw(ValueError("source pin failure"))
                elif stage == "restore":
                    restore = a.restore
                    calls = []
                    def failed_restore(sid, state):
                        calls.append(sid)
                        if len(calls) == 2:
                            raise ValueError("restore failure")
                        return restore(sid, state)
                    a.restore = failed_restore
                else:
                    a.capture = lambda *_: (_ for _ in ()).throw(ValueError("capture failure"))
                worker, eng = self.refusal_worker(a)
                with self.assertRaises(ValueError):
                    worker.conversation_answer(eng, None, None, "unsupported", "s", False,
                        {"protocol": A.PROTOCOL, "state": committed})

    def test_exact_decimal_refuses_rounding(self):
        with self.assertRaises(ValueError):
            A.restore_number({"number": 0.1, "unit": "", "origin": "exact_decimal"})
        self.assertEqual(A.restore_number({"number": 0.1, "unit": "", "origin": "python_float"}), 0.1)
        with self.assertRaises(ValueError):
            A.pack(float("nan"))
        with self.assertRaises(ValueError):
            A.pack(SimpleNamespace(secret="not data"))

    def test_verify_file_caches_unchanged_file_reads_and_detects_modifications(self):
        import hashlib
        import json
        with TemporaryDirectory() as folder:
            checkout = Path(folder).resolve()
            mod_path = checkout / "mod.py"
            mod_bytes = b"x = 1\n"
            mod_path.write_bytes(mod_bytes)
            mod_sha = hashlib.sha256(mod_bytes).hexdigest()
            a = self.adapter()
            a.checkout = checkout
            a.inventory = {"mod.py": {"sha256": mod_sha}}
            a._verified_files = {}
            A._FILE_HASH_CACHE.clear()
            reads = []
            orig_read_bytes = Path.read_bytes
            def counting_read_bytes(p):
                reads.append(Path(p).resolve())
                return orig_read_bytes(p)
            with patch.object(Path, "read_bytes", counting_read_bytes):
                a.verify_file(mod_path)
                a.verify_file(mod_path)
                a.verify_file(mod_path)
            self.assertEqual(reads, [mod_path])
            mod_path.write_bytes(b"x = 222\n")
            with self.assertRaisesRegex(ValueError, "conversation_source_pin_mismatch:mod.py"):
                a.verify_file(mod_path)

    def test_last_physics_survives_restore_and_supports_teach_me_and_evict(self):
        import json
        with TemporaryDirectory() as folder:
            state_dir = Path(folder).resolve()
            spec_dir = state_dir / "specialists" / "Q1#p1"
            spec_dir.mkdir(parents=True)
            (state_dir / "swarm").mkdir(parents=True)
            (state_dir / "swarm" / "parts.json").write_text("{}")
            (spec_dir / "program.py").write_text("def solve(m, a): return m * a\n")
            (spec_dir / "spec.json").write_text(json.dumps({
                "output": "force (N)",
                "inputs": ["mass (kg)", "acceleration (m/s^2)"],
                "expression": "m * a",
                "system": {"out_symbol": "F"},
            }))
            a = self.adapter()
            a.restore("s", self.initial())
            a.cc._STATES = {}
            a.cc.rewrite = lambda *_: None
            def begin(runtime, _text, sid):
                a.cc._STATES[sid] = deepcopy(runtime._conversation_contexts.get(sid) or Turn())
                return {"sid": sid}
            def release(frame):
                a.cc._STATES.pop(frame["sid"], None)
            base = SimpleNamespace(_compute=lambda *_: None, _resolve_followup=lambda _self, text, _sid: (text, False),
                                   _carry=lambda *_: None, _witness_compute=lambda *_: None)
            w29 = SimpleNamespace(OracleReleaseRuntimeW29=base, _TRAIL=re.compile(r"[\s?.!]+$"), _LEAD=re.compile(r"^what is\s+", re.I))
            growth = SimpleNamespace(
                read=lambda q: (("force", [("mass", 2.0, (1, 0, 0)), ("acceleration", 3.0, (0, 1, -2))]), None) if "force" in q else (None, None),
                ask=lambda _planner, q: {"status": "answered", "value": 6.0, "plan": ["Q1#p1"], "plans": 1} if "force" in q else {"status": "declined", "kind": "form", "why": "no"},
                R=SimpleNamespace(),
                systems=SimpleNamespace(),
            )
            planner = SimpleNamespace(
                by_out={("force", (1, 1, -2)): []},
                plans=lambda *_: [[{"id": "Q1#p1"}]],
                parts={"Q1#p1": {"in_keys": [("mass", (1, 0, 0)), ("acceleration", (0, 1, -2))],
                                 "scale_in": [1.0, 1.0], "scale_out": 1.0, "out_key": ("force", (1, 1, -2)),
                                 "fn": lambda m, acc: m * acc}},
            )
            a.runtime._organs = {"physics": SimpleNamespace(
                G=growth, state=str(state_dir), planner=planner,
                raw={"Q1#p1": {"inputs": ["mass (kg)", "acceleration (m/s^2)"], "output": "force (N)"}},
            )}
            a.verify_module = lambda *_: None
            a.verify_file = lambda *_: None
            worker, eng = self.refusal_worker(a)
            with patch.dict(sys.modules, {"runtime_conversation_state": SimpleNamespace(begin=begin, release=release),
                                          "oracle_release_runtime_w29": w29}):
                ans = worker.conversation_answer(eng, None, None, "What is the force for mass 2 kg and acceleration 3 m/s^2?", "s", False,
                                                 {"protocol": A.PROTOCOL, "state": self.initial()})
                self.assertEqual(ans["status"], "answered")
                self.assertEqual(ans["path"], "organ:physics60>proved")
                self.assertEqual(ans["conversation"]["state"]["last_physics"],
                                 {"question": "What is the force for mass 2 kg and acceleration 3 m/s^2?", "answer": None})
                committed = self.envelope(ans["conversation"])
                lesson = worker.conversation_answer(eng, None, None, "Teach me how you got that.", "s", False,
                                                    {"protocol": A.PROTOCOL, "state": committed})
                self.assertEqual(lesson["status"], "answered")
                self.assertEqual(lesson["path"], "adapter:physics_lesson")
                self.assertIn("F = m * a", lesson["response"])
                self.assertIn("Wikidata Q1", lesson["response"])
                evicted = worker.conversation_answer(eng, None, None, "", "s", False,
                                                     {"protocol": A.PROTOCOL, "op": "evict"})
                self.assertEqual(evicted["status"], "evicted")
                self.assertNotIn("s", a.runtime._conversation_contexts)
                self.assertNotIn("s", a.runtime._last_physics)

    def test_relation_spec_v2_forward_and_inverse_followups_resolve(self):
        a = self.adapter()
        a.restore("s", self.initial())
        a.cc._STATES = {}
        def begin(runtime, _text, sid):
            a.cc._STATES[sid] = deepcopy(runtime._conversation_contexts.get(sid) or Turn())
            return {"sid": sid}
        def release(frame):
            a.cc._STATES.pop(frame["sid"], None)
        base = SimpleNamespace(_compute=lambda *_: None, _resolve_followup=lambda _self, text, _sid: (text, False),
                               _carry=lambda *_: None, _witness_compute=lambda *_: None)
        w29 = SimpleNamespace(OracleReleaseRuntimeW29=base, _TRAIL=re.compile(r"[\s?.!]+$"), _LEAD=re.compile(r"^what is\s+", re.I))
        labels = {35: "Denmark", 1748: "Copenhagen", 254: "DKK"}
        props = {35: [(36, 1748, None), (38, 254, None)], 1748: []}
        store = SimpleNamespace(props_of=lambda qid: props.get(qid, []), label=lambda qid: labels.get(qid))
        rs = SimpleNamespace(
            _rs=lambda: store,
            _q=lambda _sql, args: [35] if args == (36, 1748) else [],
            classes_of=lambda _qid: ((6256,), ()),
            X=SimpleNamespace(norm=lambda x: x.lower(),
                              L=SimpleNamespace(candidates=lambda norm, _k: [(35, 10)] if norm == "denmark" else ([(1748, 10)] if norm == "copenhagen" else []))),
        )
        compiled_map = {
            "36": {"prop": 36, "fwd": [re.compile(r"^what is the capital of (?P<X>.+?)$")],
                   "inv": [re.compile(r"^which country has (?P<X>.+?) as its capital$")]},
            "38": {"prop": 38, "fwd": [re.compile(r"^what is the currency of (?P<X>.+?)$")], "inv": []},
        }
        s2 = SimpleNamespace(
            RD=SimpleNamespace(PROPS={"36": {}, "38": {}}),
            normalise=lambda q: (q.rstrip("?.! "), q.rstrip("?.! ").lower()),
            compiled=lambda key: compiled_map[key],
            _slot=lambda s, _low, m: s[m.start("X"):m.end("X")].strip(),
        )
        a.verify_module = lambda *_: None
        worker, eng = self.refusal_worker(a)
        with patch.dict(sys.modules, {"runtime_conversation_state": SimpleNamespace(begin=begin, release=release),
                                      "oracle_release_runtime_w29": w29, "relation_spec_v1": rs, "relation_spec_v2": s2}):
            a.cc.rewrite = lambda *_: None
            t1 = worker.conversation_answer(eng, None, None, "What is the capital of Denmark?", "s", False,
                                            {"protocol": A.PROTOCOL, "state": self.initial()})
            self.assertEqual(t1["status"], "answered")
            self.assertEqual(t1["response"], "Copenhagen.")
            self.assertEqual(t1["provenance"]["property"], "wd:P36")
            c1 = self.envelope(t1["conversation"])
            a.cc.rewrite = lambda _sid, _q: "What is the currency of Denmark?"
            t2 = worker.conversation_answer(eng, None, None, "And its currency?", "s", False,
                                            {"protocol": A.PROTOCOL, "state": c1})
            self.assertEqual(t2["status"], "answered")
            self.assertEqual(t2["response"], "DKK.")
            self.assertEqual(t2["path"], "chat:resolved>adapter:relation_store")
            self.assertEqual(t2["provenance"]["property"], "wd:P38")
            a.cc.rewrite = lambda *_: None
            t3 = worker.conversation_answer(eng, None, None, "Which country has Copenhagen as its capital?", "s", False,
                                            {"protocol": A.PROTOCOL, "state": self.initial()})
            self.assertEqual(t3["status"], "answered")
            self.assertEqual(t3["response"], "Denmark.")
            self.assertEqual(t3["provenance"]["property"], "wd:P36")

    def test_air_and_facts_organs_answer_and_reject_ungrounded_readings(self):
        a = self.adapter()
        a.restore("s", self.initial())
        a.cc._STATES = {}
        a.cc.rewrite = lambda *_: None
        def begin(runtime, _text, sid):
            a.cc._STATES[sid] = deepcopy(runtime._conversation_contexts.get(sid) or Turn())
            return {"sid": sid}
        def release(frame):
            a.cc._STATES.pop(frame["sid"], None)
        base = SimpleNamespace(_compute=lambda *_: None, _resolve_followup=lambda _self, text, _sid: (text, False),
                               _carry=lambda *_: None, _witness_compute=lambda *_: None)
        w29 = SimpleNamespace(OracleReleaseRuntimeW29=base, _TRAIL=re.compile(r"[\s?.!]+$"), _LEAD=re.compile(r"^what is\s+", re.I))
        store = SimpleNamespace(props_of=lambda _qid: [], label=lambda _qid: None)
        rs = SimpleNamespace(_rs=lambda: store, X=SimpleNamespace(norm=lambda x: x, L=SimpleNamespace(candidates=lambda *_: [])))
        air = SimpleNamespace(
            WORDS=("co2", "carbon"),
            v=SimpleNamespace(),
            ask=lambda q: {"status": "answered", "answer": "422.1 ppm in 2024",
                           "show": {"cited": [{"file": "co2_annmean_mlo.csv", "line": 66}]}} if "co2" in q.lower() else None,
        )
        def facts_ask(q):
            if "how much is the rent" in q.lower():
                return {"status": "answered", "answer": "1",
                        "show": {"read": "whole wording", "program": [{"function": "Find", "inputs": ["Rent"]}, {"function": "Count", "inputs": []}],
                                 "steps": ["found Rent -> 1", "counted them -> 1"]}}
            if "how many moons" in q.lower():
                return {"status": "answered", "answer": "2",
                        "show": {"read": "whole wording",
                                 "program": [{"function": "Find", "inputs": ["Mars"]}, {"function": "Relate", "inputs": ["child astronomical body", "forward"]}, {"function": "Count", "inputs": []}],
                                 "steps": ["found Mars -> 1", "followed 'child astronomical body' -> 2", "counted them -> 2"]}}
            return None
        facts = SimpleNamespace(R7=SimpleNamespace(), K=SimpleNamespace(), ask=facts_ask)
        a.runtime._organs = {"air": air, "facts": facts}
        a.verify_module = lambda *_: None
        worker, eng = self.refusal_worker(a)
        with patch.dict(sys.modules, {"runtime_conversation_state": SimpleNamespace(begin=begin, release=release),
                                      "oracle_release_runtime_w29": w29, "relation_spec_v1": rs}):
            air_res = worker.conversation_answer(eng, None, None, "What was atmospheric CO2 in 2024?", "s", False,
                                                 {"protocol": A.PROTOCOL, "state": self.initial()})
            self.assertEqual(air_res["status"], "answered")
            self.assertEqual(air_res["path"], "organ:air>cited")
            self.assertIn("co2_annmean_mlo.csv", air_res["response"])
            facts_res = worker.conversation_answer(eng, None, None, "How many moons does Mars have?", "s", False,
                                                   {"protocol": A.PROTOCOL, "state": self.initial()})
            self.assertEqual(facts_res["status"], "answered")
            self.assertEqual(facts_res["path"], "organ:reader90>whole_wording")
            self.assertIn("2. From the knowledge base", facts_res["response"])
            ungrounded = worker.conversation_answer(eng, None, None, "How much is the rent?", "s", False,
                                                    {"protocol": A.PROTOCOL, "state": self.initial()})
            self.assertEqual(ungrounded["status"], "withheld")
            self.assertEqual(ungrounded["path"], "adapter:withheld>facts_ungrounded_reading")
            a.runtime._native_image = SimpleNamespace(
                read_whole=lambda _tenant, q: A.json.dumps({
                    "status": "answered",
                    "response": "Saturn",
                    "provenance": {"program": ["Find(Saturn)"]},
                }) if "rings" in q.lower() else A.json.dumps({"status": "withheld"})
            )
            native_res = worker.conversation_answer(eng, None, None, "Which planet has prominent rings?", "s", False,
                                                    {"protocol": A.PROTOCOL, "state": self.initial()})
            self.assertEqual(native_res["status"], "answered")
            self.assertEqual(native_res["path"], "native:image>read_whole")
            self.assertEqual(native_res["response"], "Saturn")


if __name__ == "__main__":
    unittest.main()
