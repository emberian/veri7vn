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


if __name__ == "__main__":
    unittest.main()
