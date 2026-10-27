#!/usr/bin/env python3
"""UNTRUSTED finite experiment for open-world relation eligibility, not a proof.

This deliberately does not import or modify the runtime. A closure witness must
refer to the requested predicate and the claimed universe (snapshot or world).
An unbounded SQLite scan is not such a witness for real-world facts.
"""
from enum import Enum
from itertools import product


class Truth(Enum):
    FALSE = 0
    UNKNOWN = 1
    TRUE = 2


def membership(*, positive=False, negative=False, closed=False):
    """Evaluate one fact. `closed` is an externally justified local premise.

    Another positive value never excludes this value: no functionality or
    disjointness is assumed. Conflicting signed evidence must be repaired.
    """
    if positive and negative:
        raise ValueError("conflicting evidence")
    if positive:
        return Truth.TRUE
    if negative or closed:
        return Truth.FALSE
    return Truth.UNKNOWN


def conjunction(*values):
    if Truth.FALSE in values:
        return Truth.FALSE
    if Truth.UNKNOWN in values:
        return Truth.UNKNOWN
    return Truth.TRUE


def unique_identity(candidates, *, universe_complete):
    """Return a QID only when every consistent completion has that singleton.

    candidates maps canonical identity -> eligibility. Labels do not enter this
    decision. `universe_complete` is relative to the claim's stated scope.
    """
    if not universe_complete or any(v is Truth.UNKNOWN for v in candidates.values()):
        return None
    matches = [qid for qid, value in candidates.items() if value is Truth.TRUE]
    return matches[0] if len(matches) == 1 else None


def completions(candidates):
    """All two-valued completions inside this finite, supplied universe."""
    unknown = [qid for qid, value in candidates.items() if value is Truth.UNKNOWN]
    for assigned in product((Truth.FALSE, Truth.TRUE), repeat=len(unknown)):
        world = dict(candidates)
        world.update(zip(unknown, assigned))
        yield frozenset(qid for qid, value in world.items() if value is Truth.TRUE)


def certain_singleton(candidates):
    worlds = set(completions(candidates))
    if len(worlds) != 1:
        return None
    result = next(iter(worlds))
    return next(iter(result)) if len(result) == 1 else None
