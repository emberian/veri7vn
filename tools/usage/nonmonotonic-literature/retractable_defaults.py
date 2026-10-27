"""Untrusted reference experiment, not an Oracle organ or a verified kernel.

Signed source evidence stays open-world. A finite, acyclic positive rule graph
adds explicitly provisional conclusions guarded by snapshot-local absence.
Recompute after changes; this is not a full ATMS, WFS or ASP implementation.
"""
from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import json


@dataclass(frozen=True)
class Scope:
    tenant: str
    snapshot: str
    as_of: int


@dataclass(frozen=True)
class Fact:
    id: str
    tenant: str
    snapshot: str
    atom: str
    positive: bool
    start: int = 0
    end: int = 10**12


@dataclass(frozen=True)
class Default:
    id: str
    premise: str
    head: str
    unless: tuple[str, ...] = ()


@dataclass(frozen=True)
class Receipt:
    atom: str
    rule_ids: frozenset[str]
    support_ids: frozenset[str]
    # Each guard says only that this signed assertion is absent in the scope.
    absence_guards: frozenset[tuple[str, bool]]
    scope: Scope
    revision: str


class View:
    def __init__(self, scope: Scope, facts: list[Fact]):
        self.scope = scope
        active = [f for f in facts if (f.tenant, f.snapshot) ==
                  (scope.tenant, scope.snapshot) and f.start <= scope.as_of < f.end]
        if len({f.id for f in active}) != len(active):
            raise ValueError("duplicate active fact ID")
        self.facts = active
        self.index: dict[tuple[str, bool], set[str]] = {}
        for f in active:
            self.index.setdefault((f.atom, f.positive), set()).add(f.id)
        payload = [scope.tenant, scope.snapshot, scope.as_of,
                   sorted((f.id, f.atom, f.positive, f.start, f.end) for f in active)]
        self.revision = sha256(json.dumps(payload).encode()).hexdigest()

    def evidence(self, atom: str) -> str:
        pos = bool(self.index.get((atom, True)))
        neg = bool(self.index.get((atom, False)))
        return {(False, False): "unknown", (True, False): "true",
                (False, True): "false", (True, True): "conflict"}[pos, neg]

    def defaults(self, rules: list[Default]) -> dict[str, Receipt]:
        """Evaluate bounded DAG; defaults never write into source evidence.

        All blockers are source-only. A blocker whose source status is unknown
        permits a *provisional* default, never an explicit negative conclusion.
        Multiple default supports per head are deliberately rejected in this
        small model, rather than pretending to implement ATMS label management.
        """
        if len({r.head for r in rules}) != len(rules):
            raise ValueError("one default rule per head in this experiment")
        if len({r.id for r in rules}) != len(rules):
            raise ValueError("duplicate rule ID")
        pending = list(rules)
        ordered: list[Default] = []
        while pending:
            heads = {r.head for r in pending}
            ready = [r for r in pending if r.premise not in heads]
            if not ready:
                raise ValueError("recursive defaults unsupported; use a defined WFS/ASP semantics")
            ordered.extend(ready)
            pending = [r for r in pending if r not in ready]
        result: dict[str, Receipt] = {}
        for r in ordered:
            # A factual positive is already source-supported; an explicit
            # negative or conflict defeats this provisional positive head.
            if self.evidence(r.head) != "unknown":
                continue
            premise = self.evidence(r.premise)
            if premise == "true":
                support = frozenset(self.index[r.premise, True])
                inherited_rules: frozenset[str] = frozenset()
                guards: frozenset[tuple[str, bool]] = frozenset()
            elif premise == "unknown" and r.premise in result:
                parent = result[r.premise]
                support, inherited_rules, guards = (
                    parent.support_ids, parent.rule_ids, parent.absence_guards)
            else:
                continue
            if any(self.index.get((b, True)) for b in r.unless):
                continue
            guards |= frozenset([(r.head, True), (r.head, False)] +
                                [(b, True) for b in r.unless])
            result[r.head] = Receipt(r.head, inherited_rules | {r.id}, support,
                                     guards, self.scope, self.revision)
        return result

    def receipt_is_current(self, receipt: Receipt) -> bool:
        return receipt.scope == self.scope and receipt.revision == self.revision

    def unique_source_candidate(self, candidates: list[str], *, covered: bool) -> str | None:
        """Explicit fixture premise: candidates cover the intended universe.

        Only source evidence counts. Unknown, conflict and provisional defaults
        cannot eliminate an alternative or establish a unique eligible person.
        """
        if not covered or len(candidates) != len(set(candidates)):
            return None
        yes = [a for a in candidates if self.evidence(a) == "true"]
        if len(yes) == 1 and all(a == yes[0] or self.evidence(a) == "false"
                                 for a in candidates):
            return yes[0]
        return None
