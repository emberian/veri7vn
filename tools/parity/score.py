"""The six exam criteria of upstream/workbench/exam.py as pure functions over recorded replies.

Constants and reason strings are copied from exam.py (tests/parity checks the constants against the shipped file)."""
from __future__ import annotations

import math
import re

READING_DECLINES = ("act:clarify", "unverified:", "corpus_query", "factoid", "deliberation", "capability:", "arb:", "compose",
                    "family_precedence:low_credit", "verified:", "cube:")
CHECK_DECLINES = ("precision_guard", "same_name_guard", "weight:", "chat:unresolved")
IDENTITY_Q = ["Who are you?", "What are you?", "Are you a human?", "What do you value?", "Are you conscious?"]
CHECK = re.compile(r"(^|[>|])(precision_guard:[GQ]\d|same_name_guard|weight:|chat:unresolved)")


def fillable(path):
    """exam.fillable: a decline a specialist may fill (the core lacked a reading); never a CHECK"""
    p = str(path or "")
    return not CHECK.search(p) and (any(k in p for k in READING_DECLINES) or "precision_guard:P" in p)


def consult(head_reply):
    """exam.py consults the specialist only when the head did not answer and its path is fillable"""
    return head_reply.get("status") != "answered" and fillable(head_reply.get("path"))


def as_scored(reply):
    """what a scorer sees: an answerer reply with an error counts as withheld with an empty response"""
    if reply is None:
        return {"status": "withheld", "response": "", "path": ""}
    if "error" in reply and "status" not in reply:
        return dict(reply, status="withheld", response=reply.get("response", ""))
    return reply


def new_tally():
    return {"ok": 0, "fy": 0, "wrong": 0}


def add(acc, item, good, asserted):
    """exam.py run() lines 180-184"""
    valid = item.get("valid", True)
    acc["ok"] += int(bool(good))
    if not valid and asserted:
        acc["fy"] += 1
    if valid and asserted and not good:
        acc["wrong"] += 1
    return acc


def gain_needed(n):
    return max(3, math.ceil(0.02 * n))


def wrong_cap(n):
    return max(1, math.floor(0.02 * n))


def lane_cap(n_core):
    return max(5, n_core // 100)


def p50(lat):
    lat = sorted(lat)
    return round(lat[len(lat) // 2], 2) if lat else 0.0


def lane_taken(core, taken_flags):
    """exam.py LANE: a core question counts as taken when the specialist replied (any reply, even a decline) AND the
    core's recorded reply was a fillable non-answer. core: [{"q","status","path"}]; taken_flags: [bool] aligned."""
    return [c["q"][:140] for c, t in zip(core, taken_flags) if t and (c.get("status") != "answered" and fillable(c.get("path")))]


def domain_reasons(n, head, comp):
    reasons = []
    need = gain_needed(n)
    if comp["ok"] - head["ok"] < need:
        reasons.append("DOMAIN: gain %d, needs %d" % (comp["ok"] - head["ok"], need))
    if comp["fy"] > head["fy"]:
        reasons.append("FALSE YES: %d with it vs %d without" % (comp["fy"], head["fy"]))
    if comp["wrong"] > wrong_cap(n):
        reasons.append("WRONG: %d answered wrong, cap %d" % (comp["wrong"], wrong_cap(n)))
    return reasons


def verdict(split, n, head, comp, taken=None, n_core=None, selfs=None, p50_ms=None, budget=200.0):
    """decision + reasons in exam.py's words. head may be None (answerer gave no head reply): DOMAIN and FALSE YES are
    then not measured, and WRONG still is. taken/selfs/p50_ms None = that criterion not measured. A verdict with an
    unmeasured criterion is never ADMIT/WOULD PASS; it is INCOMPLETE."""
    reasons, unmeasured = [], []
    if head is None:
        unmeasured += ["DOMAIN", "FALSE YES"]
        if comp["wrong"] > wrong_cap(n):
            reasons.append("WRONG: %d answered wrong, cap %d" % (comp["wrong"], wrong_cap(n)))
    else:
        reasons += domain_reasons(n, head, comp)
    if taken is None:
        unmeasured.append("LANE")
    elif len(taken) > lane_cap(n_core):
        reasons.append("LANE: takes %d general questions, cap %d" % (len(taken), lane_cap(n_core)))
    if selfs is None:
        unmeasured.append("SELF")
    elif selfs:
        reasons.append("SELF: it answers identity questions (%s)" % ", ".join(selfs))
    if p50_ms is None:
        unmeasured.append("BUDGET")
    elif p50_ms > budget:
        reasons.append("BUDGET: median %.1f ms, budget %.0f ms" % (p50_ms, budget))
    if reasons:
        decision = "WOULD FAIL" if split == "dev" else "NEGATIVE"
    elif unmeasured:
        decision = "INCOMPLETE"
    else:
        decision = "WOULD PASS" if split == "dev" else "ADMIT"
    return {"decision": decision, "reasons": reasons, "unmeasured": unmeasured, "gain_needed": gain_needed(n),
            "wrong_cap": wrong_cap(n)}
