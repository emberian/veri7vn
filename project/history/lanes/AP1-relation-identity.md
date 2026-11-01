# Relation clarification identity labels, 26 October 2026

The relation front door could describe a person using the value of that person's
asked property. When one reader asked for clarification and another answered
that Q2 was born in London, it could offer `London (Q2)` as a subject choice.
Terra reproduced this at the aggregation boundary with reader-result doubles.
No live-store occurrence or frequency was established.

The reader now carries `provenance.subject_label`, taken from the same immutable
relation-store handle already used to render the subject in its citation. The
front door uses that field when adding an answered subject to clarification
choices. It never uses the relation value as an identity label. Older replies
without that field still contribute the subject QID. Choices are deduplicated
by QID; conflicting labels for one ID render the ID instead of selecting a name
according to reader order. A clarification remains a clarification even when
another reader has an answer.

Changed files:

- `tools/relations/answerer.py`: retain the subject label on answer and decline
  provenance, separately from the property value.
- `tools/relations/frontdoor.py`: aggregate subject identities and labels.
- `tools/relations/test_frontdoor.py`: counterexamples and reply-rendering checks.
- This report.

Check: `.venv/bin/python -I -B tools/relations/test_frontdoor.py` completed with
**16 tests passed**. These include the original refusal/agreement controls,
mixed clarify/answer responses in both reader orders, absent/invalid labels,
repeated subjects, and conflicting labels. Three tests call the real
`Answerer.reply` with explicit kernel-result fixtures and the real read-only
`RelStore` over a small temporary SQLite database. They check forward subject
versus relation value, inverse subject versus target, missing labels, and
declines. They do not exercise native selection, linking, or source coverage.
`git diff --check -- tools/relations` passed.

**Specialist panel numbers: none measured for this change.** No Isabelle theory,
theorem statement, native binary, or selection rule changed, and no build ran.
The existing conditional relation theorems continue to depend on correct
recognition and source coverage; this Python aggregation is untrusted. The new
field is additive provenance, not a new identity proof. Existing structured
conversation metadata continues to derive identity from native IDs and source
rows; it does not consume this display label.

The consumer is the default relation front door, including its dispatcher
integration. This bounded correction is ready for root integration. Broader
relation coverage and packaging remain separate work.
