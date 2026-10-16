# C02 — Native admission and assurance

Semantic revision 1; descriptor `veri7vn.package/0`. Status belongs to the
[validation ledger](../../project/VALIDATION.md).

## Native interface

Input: approved native context, exact certified target, declared parameters/premises,
policy and candidate theorem or implementation. Output: opaque gate-owned accepted
record, or diagnostics. Authors/search cannot construct accepted records.

```text
admit_consequence(context, target: cterm, policy, candidate: thm)
  -> AcceptedConsequence | Diagnostics
attach_implementation(contracts, native_definition, representation,
                      code_setup, execution_boundary)
  -> AcceptedImplementation | Diagnostics
```

These are conceptual signatures. Accepted records retain actual native objects.
Names, pretty printing, hashes and receipts cannot replace them; restart reconstructs
under pinned lineage and checks the association again.

## Required checks

Audit exact proposition/instantiation, hypotheses, premises, types/sorts, unresolved
flex-flex pairs, theory ancestry, context export, pending derivations, transitive
oracles and declaration policy. Zero subgoals/oracles does not exclude unauthorized
hypotheses or axioms. Conversely, legitimate definitional facts cannot be rejected
merely because an axiom-table entry is new. Export makes assumptions explicit; it
does not establish them. Source reports remain data/scoped premises.

Implementation attachment binds contract, actual executable definition,
representation, code setup and runtime artifact. A theorem about a reference
operation cannot license an unrelated callback.

## Assurance routes

| Route | Meaning and retained evidence |
|---|---|
| `kernel_consequence` | Authorized native consequence; exact theorem/target, premises, sorts, lineage and complete dependency audit |
| `refined_execution` | Actual input/output covered by admitted implementation/representation relation, conditions and pinned execution boundary; no per-call theorem implied |
| `oracle_consequence` | Native consequence with specifically authorized, recorded computational oracles plus the normal consequence audit |

Routes are not a total strength ordering. A failed strict request cannot silently
fall back to an oracle. Tests/scores are not a fourth proof route. Scope (C03),
qualification and activation (C01) remain independent: a proved test observation
is not universal program correctness or world truth. Metadata is an inspection
view, never author-granted authority. Authentication remains separate from proof.

Reject wrong targets, assumed false targets, undeclared premises, forbidden ancestry,
hidden oracles, skipped/partial proofs, unresolved constraints/exports and unrelated
execution artifacts. Accept legitimate conditional consequences without stripping
conditions. Exercise actual context/name transport. The acceptance relation must
connect by generation/refinement/replay to the authoritative implementation, not a
handwritten lookalike validator.
