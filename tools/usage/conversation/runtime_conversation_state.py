"""Untrusted reconciliation of legacy conversation caches with delivered replies.

This is Python bookkeeping, not a proof or an answer authority. The runtime
serializes chat calls. Module-global v2 context is borrowed only for one turn;
committed contexts belong to a runtime instance and a conversation ID.
"""
from copy import deepcopy
import math
import re
import sys

_TOPIC = re.compile(r"^\s*(?:new topic|switching topics|change of topic)\s*:", re.I)
_SCALAR = re.compile(r"^\s*\[ev:derived\]\s+([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)\. In steps:")


def begin(runtime, text, sid):
    cc = sys.modules.get("chat_context_v2")
    stores = getattr(runtime, "_conversation_contexts", None)
    if stores is None:
        stores = runtime._conversation_contexts = {}
    prior = deepcopy(stores.get(sid))
    frame = {"cc": cc, "prior": prior, "sid": sid}
    if cc is not None:
        frame["ambient"] = (sid in cc._STATES, cc._STATES.get(sid))
        cc._STATES[sid] = deepcopy(prior) if prior is not None else cc.Turn()
    values = getattr(runtime, "_last_value", {})
    frame["value"] = (sid in values, values.get(sid))
    if _TOPIC.match(str(text)):
        if cc is not None:
            cc._STATES[sid] = cc.Turn()
        frame["prior"] = None
        values.pop(sid, None)
        getattr(runtime, "_v4_disc", {}).pop(sid, None)
    return frame


def scalar(reply, speculative, previous):
    """Only the two known scalar arithmetic routes can populate w29's cache."""
    prov = reply.get("provenance")
    prov = prov if isinstance(prov, dict) else {}
    path = str(reply.get("path", ""))
    if prov.get("kind") == "computation" and prov.get("verified") is True and path in ("compute:verified", "chat:resolved>compute:verified"):
        # The final closed arithmetic route wrote this value itself.
        return speculative
    if path == "organ:math>evaluate" and prov.get("kind") == "organ_math" and prov.get("directive") == "evaluate":
        match = _SCALAR.match(str(reply.get("response", "")))
        if match:
            value = float(match.group(1))
            return value if math.isfinite(value) else None
    if path.startswith("act:"):
        return previous
    return None


def finish(runtime, text, reply, frame, supported):
    sid, cc = frame["sid"], frame["cc"]
    values = getattr(runtime, "_last_value", None)
    if values is None:
        values = runtime._last_value = {}
    previous = frame["value"][1] if frame["value"][0] else None
    value = scalar(reply, values.get(sid), previous) if supported else None
    values.pop(sid, None)
    if value is not None:
        values[sid] = value
    if cc is None:
        return
    prior = frame["prior"]
    cc._STATES[sid] = deepcopy(prior) if prior is not None else cc.Turn()
    if not supported:
        cc._STATES[sid] = cc.Turn()
    elif not str(reply.get("path", "")).startswith("act:"):
        # Direct questions legitimately carry chat_resolved: null. Only a
        # typed rewrite record with a string question overrides the input.
        prov = reply.get("provenance")
        resolved = prov.get("chat_resolved") if isinstance(prov, dict) else None
        question = resolved.get("read_as") if isinstance(resolved, dict) else None
        question = question if isinstance(question, str) and question.strip() else text
        # Clear numerical slots before recognition so an unrecognized final
        # correction cannot silently retain an older number or solved variable.
        cc._STATES[sid].result = None
        cc._STATES[sid].solved = {}
        cc.update(sid, question, reply)
        if value is not None:
            cc._STATES[sid].result = (value, "")
    stores = runtime._conversation_contexts
    if sid not in stores and len(stores) >= cc.STATE_CAP:
        stores.pop(next(iter(stores)))
    stores[sid] = deepcopy(cc._STATES[sid])


def release(frame):
    cc = frame["cc"]
    if cc is not None:
        had, value = frame["ambient"]
        if had:
            cc._STATES[frame["sid"]] = value
        else:
            cc._STATES.pop(frame["sid"], None)
