# Checked contextual refusals on equal arbitration scores

The default dispatcher returned a negative length for a physical fabric request
although Crafts had rejected it. Root captured both real candidates: each used
the one given, neither invented a value, both had zero wording scores, and both
matched context. Registration order selected the generic units reader.

The verified ranking now adds one final field before registration order:
whether the candidate is a checked refusal with matching context. The existing
five fields still take precedence. `checked_context_refusal_wins_tie` proves
that an answer and such a refusal with equal earlier readings select the refusal
in either candidate order, for arbitrary givens, wording scores and answer value.
The field classifications remain untrusted inputs; this is not a theorem that
the English model interpretation is correct.

Managed proof `20261018T113238Z-4fd02f6ee6ba` passed 43 scanned statements with
zero oracles. Managed compile `20261018T113401Z-5972276946c9` binds the current
proof closure, generated export and actual `tools/dispatch/arb_driver.sml`.
Native SHA256 is
`b1e3fa206b2edb8a5632d25441c1f4bb536409a6ed2401314aded952995dcd04`.
It is now active at `var/dispatch/bin/arb_check`. The old native is retained.
The build script now uses the shared compiler lock and immutable input receipts;
an explicit proof receipt is required. Candidate output remains selectable.

Crafts admission metadata also now covers cloth, ribbon, yarn and material,
matching the vocabulary its reader already supports. Otherwise those physical
refusals never reached arbitration. The expanded default checks pass 24/24;
the permanent `src/extract/trades/check_composition.py` passes 14/14 against the
live dispatcher. Plain negative algebraic conversion stays answered. All nine
arbitration protocol examples and 13 dispatch contract tests pass. Across 1,600
deterministic old/new native comparisons, 1,587 decisions are unchanged; all 13
changes select a checked contextual refusal at an equal prior rank.

No specialist arithmetic binary changed in this step, and no new specialist
panel score is claimed. Trades' preceding shipped 357/357 result remains the
family result. Consumer tests above measure composition separately. Evidence,
predecessor, compiler and actual consumer bindings are under
`var/root-physical-arbitration/`; its `integration.json` is the exact index.

Limits: unequal earlier scores and the multi-answer agreement shortcut are
unchanged. Broader semantic conflict handling still needs systematic review.
This updates veri7vn's dispatcher; it does not modify Oracle7's own combiner
inside the read-only upstream tree. Linux arbitration validation and a refreshed
whole-system delivery remain pending. No jobs remain from this bounded repair.
