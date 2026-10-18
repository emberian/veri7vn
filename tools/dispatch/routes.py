"""UNTRUSTED composition of checked math, word-problem and guard programs.

These are distinct protocols, not specialist candidates. Recognition, JSON
framing, stage order and optional relation-store facts remain untrusted. A
kernel's static theorem inventory is not a newly checked proof of a sentence.

The caller chooses route order. Math's question-only guard reconstruction is
reserved for the final fallback; it must never suppress an actual answer from
another organ. Precision guards instead inspect the actual selected reply.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from runtime_contract import enforce_reply_evidence


ROUTE_NAMES = frozenset({"mathorgan", "wordprob", "guards"})


def stage_programs(repo, var_root, enabled):
    """Return only explicitly selected programs; validate before starting any."""
    del repo  # all three stages are standalone binaries
    enabled = set(enabled)
    unknown = enabled - ROUTE_NAMES
    if unknown:
        raise ValueError("unknown route stages: " + ", ".join(sorted(unknown)))
    programs = {name: Path(var_root) / name / "bin" / name for name in sorted(enabled)}
    for name, path in programs.items():
        if not path.is_file() or not os.access(path, os.X_OK):
            raise ValueError(f"missing executable route stage {name}: {path}")
    return programs


def _terminal(reply):
    """An explicitly taken refusal stops routing; an unrecognized turn does not."""
    if "error" in reply:
        return reply
    if reply.get("status") not in ("answered", "withheld", "clarification"):
        return {"error": "route stage returned an invalid status"}
    reply = enforce_reply_evidence(reply)
    provenance = reply.get("provenance")
    taken = isinstance(provenance, dict) and provenance.get("taken") is True
    return reply if reply["status"] == "answered" or taken else None


def _contract_decline(reply, suffix, field, reason):
    rejected = dict(reply)
    rejected.update(status="withheld", response="", path=str(reply.get("path", "")) + suffix)
    rejected.pop("value", None)
    provenance = reply.get("provenance")
    rejected["provenance"] = dict(provenance) if isinstance(provenance, dict) else {}
    rejected["provenance"].update(taken=True)
    rejected["provenance"][field] = {"status": "rejected", "reason": reason}
    return rejected


class RouteStages:
    def __init__(self, repo, var_root, timeout, log_dir, Child,
                 enabled=("wordprob", "mathorgan", "guards")):
        self.programs = stage_programs(repo, var_root, enabled)
        self.children = {}
        for name, path in self.programs.items():
            if name == "mathorgan":
                for mode in ("algebra", "ops", "guards"):
                    key = "mathorgan-" + mode
                    self.children[key] = Child(key, [str(path), "--route", mode], timeout, log_dir)
            else:
                self.children[name] = Child(name, [str(path)], timeout, log_dir)

    def _ask(self, key, rid, text, session):
        child = self.children.get(key)
        if child is None:
            return None
        reply = child.ask(rid, text, session)
        if key == "mathorgan-algebra" and reply.get("status") == "answered" and reply.get("kind") != "affine_equation":
            return _contract_decline(reply, ">algebra_contract", "route_contract",
                                     "the algebra stage requires a checked affine_equation reply")
        if reply.get("kind") == "affine_equation":
            provenance = reply.get("provenance")
            if not isinstance(provenance, dict) or provenance.get("request_text") != text:
                return _contract_decline(reply, ">request_mismatch", "request_binding",
                                         "affine reply does not name the submitted request")
        return _terminal(reply)

    def answer_math(self, rid, text, session):
        for mode in ("algebra", "ops"):
            out = self._ask("mathorgan-" + mode, rid, text, session)
            if out is not None:
                return out
        return None

    def answer_wordprob(self, rid, text, session):
        return self._ask("wordprob", rid, text, session)

    def fallback_math_decline(self, rid, text, session):
        """Only after all answer-producing routes declined to take the question."""
        out = self._ask("mathorgan-guards", rid, text, session)
        if out is not None and out.get("status") == "answered":
            return {"error": "math guard fallback unexpectedly returned an answer"}
        return out

    def apply_guards(self, text, reply, facts=None):
        """Narrow an actual answer. Already withheld replies are unchanged.

        facts may contain human and premise, supplied by a trusted *caller*
        interface to an explicitly untrusted read-only store adapter. Never
        copy these fields from arbitrary user JSON. Without an adapter they
        are unknown, not false: store-dependent guards are not fully checked.
        """
        child = self.children.get("guards")
        if child is None or reply.get("status") != "answered":
            return reply
        facts = facts or {}
        payload = {"id": reply.get("id"), "q": text, "status": "answered",
                   "route": reply.get("path", ""), "reply": reply.get("response", ""),
                   "human": facts.get("human"), "premise": facts.get("premise")}
        decision = child.ask_payload(payload)
        if "error" in decision:
            return {"id": reply.get("id"), "status": "withheld", "response": "",
                    "path": "dispatch>guard_error", "error": decision["error"]}
        code = decision.get("code")
        if ((code is None and decision.get("status") != "answered") or
                (code is not None and (decision.get("status") != "withheld" or
                                       not isinstance(code, str) or not decision.get("path")))):
            return {"id": reply.get("id"), "status": "withheld", "response": "",
                    "path": "dispatch>guard_error", "error": "invalid precision-guard decision"}
        out = dict(reply)
        provenance = reply.get("provenance")
        out["provenance"] = dict(provenance) if isinstance(provenance, dict) else {}
        out["provenance"]["precision_guards"] = {
            "kernel": "Guards.decision_auto", "modelled_codes": 20, "catalogue_codes": 87,
            "code": code, "input_route": reply.get("path", ""),
            "store_facts_supplied": {"human": facts.get("human") is not None,
                                     "premise": facts.get("premise") is not None},
            "recognizer_trusted": False,
        }
        if code is not None:
            out.update(status="withheld", response="I cannot verify that answer.",
                       path=decision["path"])
            out.pop("value", None)
            out.pop("kind", None)
            out["provenance"]["taken"] = True
            out["provenance"]["precision_guards"]["layer"] = decision.get("layer")
        return out

    def close(self):
        for child in self.children.values():
            child.close()
