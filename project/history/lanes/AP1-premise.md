# Creator-premise correction, 26 October 2026

Root integration, 26 October: included in the tracked appliance patch and the passing real-engine candidate. Proposed upstream in [HF slim #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1), not merged. See [batch results and remaining work](../APPLIANCE-2026-10-26.md). The lane evidence below describes its scoped checks before root integration.

The upstream `premise_v3.owner` guard treated a possessive as a creator claim and
compared the possessor's last name with the answer text. It could reject Walter
Isaacson as the writer of Einstein's biography, mistake an artwork's owner for
its creator, or overlook different people sharing a surname. The old predicate
did not establish the claimed contradiction.

The replacement leaves bare possessives unproved. It can still withhold a reply
for a positively supported contradiction within this deliberately narrow form:

`Who wrote "Example Book", written solely by Jane Smith?`

Supported verb pairs are wrote/written (author, P50), composed/composed
(composer, P86), and directed/directed (director, P57); `exclusively` is also
accepted. The title must be double quoted, followed by a comma and the explicit
exclusive creator clause, ending in a question mark. The outer existing
`check` limits of 160 characters, a single direct question, and no reading
passage still apply.

Both the entire title and the entire creator name must resolve to exactly one
identity in the names index. The real index query groups by QID before `LIMIT
2`, so a second identity causes abstention rather than choosing the most popular
one. The supplied creator must have a human class row. The reply must contain
exactly one direct relation citation identifying that work and the same creator
property. A positive row naming a different creator then conflicts with the
explicit **sole** premise. The reason includes both creator IDs and the work ID;
names and surnames are not used as identity tests.

This does not infer that a missing creator row proves non-authorship. No rows,
literal-only rows, unresolved or ambiguous identities, an unrelated citation,
and non-exclusive attribution all leave the premise unproved. Existing source
rows and correct question/citation interpretation remain assumptions. A source
may be wrong or its names index incomplete; this Python check is not a proof
about the world. Without this narrow evidence, `None` preserves the earlier
reply. In particular, the old spent `Bach's Symphony No. 9` possession example
is no longer classified as a creator contradiction by this guard alone.

## Files and validation

Private upstream checkout: `var/ap1-upstream-slim`.

- `root/wander-train/premise_v3.py`: replace the owner predicate; document the
  present scope and remaining older checks.
- `tests/premise_v3/test_owner.py`: actual predicate tests with controlled
  relation-store doubles and the actual names-index SQL over a small SQLite
  fixture; the actual w571 fold with a lower-reader double.
- This lane report in veri7vn.

Command from veri7vn root:
`.venv/bin/python -I -B var/ap1-upstream-slim/tests/premise_v3/test_owner.py`.
**16 tests passed.** They exercise positive exclusive contradictions, agreement,
coauthors, absent/literal rows, biography subject and artwork owner readings,
other contributors, full names with shared surnames, whole titles, ambiguous
names, duplicate aliases, unrelated/multiple citations, and all three creator
properties. The actual w571 wrapper withholds a supported contradiction and
preserves an earlier answered reply when the premise is unproved. These tests
do not instantiate the full runtime or establish live question frequency.

**Specialist panel numbers: none measured.** No theorem, native binary or build
changed. The consumer is the existing w571 call to `premise_v3.check`. Root owns
committing, upstream contribution, and release integration.

## Remaining measured issues, outside this change

The following probes called the actual functions with controlled doubles. They
demonstrate component-boundary behavior, not live-store occurrences.

- `with_('Which band did Jane Smith form with John Smith?', 'Example Band.',
  [3])`, with the two named people linked to human IDs and no connecting rows,
  returns `Jane Smith is not connected to that answer in my records`. The
  predicate reports an absence accurately, but w571 presents every such reason
  as a premise that does not hold. No relation-coverage premise justifies that
  inference about the world. A useful repair must distinguish insufficient
  evidence from affirmative contradiction, and validate the intended relation
  rather than accepting any connection at all.
- `year('Who directed the 1948 film Hamlet?', reply)` reads the first textual
  `(Q...)`. With a reply prefixed by `Related edition (Q999)` before the actual
  `Hamlet (Q101)` citation, and date rows 1800 for Q999 and 1948 for Q101, it says
  `the question says 1948, and the work I hold is from 1800`. It has checked an
  incidental entity. A repair must bind the whole requested work and the
  relevant date role to the cited identity; publication, inception, performance
  and start dates are not interchangeable merely because they are years.

WITH and YEAR behavior is unchanged. These are explicit follow-up work, not
claims that all premise checking is now correct.
