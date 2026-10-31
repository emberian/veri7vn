"""Untrusted, owner-limited bridge for delivered w29 dimensionless scalars.

Call capture_after_finish only on Engine's serialized executor after the outer
runtime_final_outcome reconciliation and after choosing its delivered answer.
This exports one observed owner, never the Engine or module-global Turn. It
does not enable tenant switching, restore effects, or make Python durable.
"""
from __future__ import annotations

import math
import re
from fractions import Fraction

OWNER = "native_delivered_scalar"
OWNER_VERSION = 1


def _fraction(number):
    if (type(number) is not str or len(number) > 512
            or sum(character.isdigit() for character in number) > 128):
        raise ValueError("scalar literal limit")
    if "/" in number:
        if not re.fullmatch(r"[+-]?[0-9]+/[+-]?[0-9]+", number):
            raise ValueError("invalid rational scalar")
    else:
        if not re.fullmatch(r"[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?", number):
            raise ValueError("invalid decimal scalar")
        exponent = re.search(r"[eE]([+-]?[0-9]+)$", number)
        if exponent and abs(int(exponent[1])) > 128:
            raise ValueError("scalar exponent limit")
    return Fraction(number)


def capture_after_finish(runtime, session_id, delivered_reply, *, supported):
    """Produce a typed command from finalized `_last_value`, including absence.

    The caller supplies the exact delivery boundary; this helper cannot discover
    arbitration winners or distinguish a candidate reply by introspection.
    Unsupported final corrections explicitly clear the native scalar.
    """
    if type(delivered_reply) is not dict or type(supported) is not bool:
        raise ValueError("explicit delivered reply/support required")
    if not supported or delivered_reply.get("status") != "answered":
        return {"op": "clear"}
    path = delivered_reply.get("path")
    provenance = delivered_reply.get("provenance")
    provenance = provenance if type(provenance) is dict else {}
    known_compute = (path in ("compute:verified", "chat:resolved>compute:verified")
                     and provenance.get("kind") == "computation"
                     and provenance.get("verified") is True)
    known_organ = (path == "organ:math>evaluate" and provenance.get("kind") == "organ_math"
                   and provenance.get("directive") == "evaluate")
    if not (known_compute or known_organ or isinstance(path, str) and path.startswith("act:")):
        return {"op": "clear"}
    values = getattr(runtime, "_last_value", None)
    if type(values) is not dict:
        raise ValueError("w29 scalar owner was not observed")
    value = values.get(session_id)
    if value is None:
        return {"op": "clear"}
    if type(value) not in (int, float) or type(value) is float and not math.isfinite(value):
        raise ValueError("unsupported w29 scalar")
    number = repr(value)
    _fraction(number)
    return {"op": "observe", "value": {"number": number,
            "origin": "python_float" if type(value) is float else "exact_decimal"}}


def restore_w29_scalar(runtime, session_id, scalar):
    """Project one committed scalar onto a tenant-bound serialized Python owner.

    No other context is touched. Exact values that would round in Python are
    refused; imports already marked PythonFloat retain that declared limitation.
    Call only with a host-validated committed scalar for this Engine/session.
    """
    values = getattr(runtime, "_last_value", None)
    if type(values) is not dict:
        raise ValueError("w29 scalar owner was not observed")
    if scalar is None:
        values.pop(session_id, None)
        return
    if type(scalar) is not dict or type(scalar.get("value")) is not dict:
        raise ValueError("invalid committed scalar")
    value = scalar["value"]
    number, origin = value.get("number"), value.get("origin")
    if type(number) is not str or len(number) > 512 or origin not in ("exact_decimal", "python_float"):
        raise ValueError("invalid scalar value")
    fraction = _fraction(number)
    result = float(fraction)
    if not math.isfinite(result):
        raise ValueError("scalar cannot enter Python float cache")
    if origin == "exact_decimal" and Fraction.from_float(result) != fraction:
        raise ValueError("exact scalar would round in legacy cache")
    values[session_id] = result
