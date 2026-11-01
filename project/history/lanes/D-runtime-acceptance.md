# Specialist acceptance coverage, 18 October 2026

Owner: Codex runtime/dispatch. This packet adds a diagnostic consumer, not a
theorem or a new specialist. No Isabelle build or full-head run was performed.
There are **no new shipped-panel scores** from this packet. The report retains
each existing receipt's own right/wrong/false-yes numbers separately from
whether the current dispatcher would accept its reply.

## What the report measures

`tools/dispatch/acceptance_coverage.py` finds direct family receipts whose
question fingerprint and length exactly match each shipped panel. It excludes
partial panels, fresh-seed panels, and composed/head/reference commands. It
replays those replies through the dispatcher's actual candidate gate, exposing
answers, normal-operation refusals, context-dependent refusals, dropped kinds,
dropped context, and `taken=false` or missing-marker replies per specialist and
split. Every nonanswer remains distinct from a claim that a kernel refused.

The report covers **143 of 144 registered specialist IDs, 286 panel splits,
15,743 recorded replies**. `water-r3` has no shipped panel declaration and is
shown as **NO_PANEL**, not zero failures. The newest compatible receipt is
chosen by modification time; this does not identify its binary with the current
implementation. Family-mode receipts sometimes answer under another owned ID:
955 such replies across seven IDs are displayed separately. Replaying them
against a specialist pin does not measure a fresh pinned execution.

The captured replay contains 14,548 accepted answers, 743 context refusals,
426 not-taken replies, 24 rejected kinds, and two context rejections. Of the
426 not-taken rows, 248 are marked valid and 178 invalid by their shipped panels. These are
diagnostic counts, not correctness scores. The recorded normal-operation
refusal count is zero; focused consumer tests separately exercise that boundary.

## Actual scoped checks and repairs

The final capture reran **76 selected questions**, directly against their
registered binaries and through pinned front composition with their family and
fusion. Other routes were disabled to expose acceptance and fallthrough.
No policy file or tested binary changed during this capture.
This capture predates the subsequently published GeoStats binary and other
later producer updates. Per-probe hashes identify the tested artifacts; the
remaining-silence list is historical evidence, not their current completion status.

- 33 previously dropped domain refusals now survive as terminal specialist
  replies after shared boundary-regex repair and family capability corrections.
- Both warehouse unknown-item cases remain rejected by unpinned family context
  and are terminal refusals under an explicit specialist pin. The pin supplies
  context only for a nonanswered declared decline; it cannot admit an answered
  decline-only kind without the original question context.
- Twelve historical warehouse off-site cases now return not-taken. The old
  receipts' 24 rejected kinds cover both splits and predate this producer fix.
- One valid historical not-taken question per affected ID was rerun: 17 now
  answer and 12 still return not-taken. The latter are six computing IDs,
  electrical and two optics IDs, and three geometry/statistics IDs. Their owners
  confirmed at capture time that repaired exports were pending managed proof builds;
  scratch successes are not recorded here as published behavior.

The pin change retains ownership, declared-kind and taken checks. Thirteen
focused dispatcher tests pass, including answered decline-only kinds with no
context being rejected both pinned and unpinned, and the original relevant-
context behavior being preserved. Actual stores checks pass: pinned unknown
items are terminal, unpinned generic counts fall through, and unknown-item
requests create no file or leave meaningful existing state byte-identical.

The state check also exposed a producer error: an explicit unknown noun could
inherit a known prior item. The stores owner repaired it in candidate SHA-256
`c23f3dd5b675cd7f656de255cfbc32212ac956fc29773d3c3a6d5745e03012bc`
(`var/stores/counts/bound`, compiled by the shared immutable helper).
Actual composed checks against that candidate pass this same-session chain:
M4 valve count 107; purple widgets withheld without changing state; “Where is
it?” still resolves bin A5-05; bare “count” still returns 107. Six cooking
checks on the same candidate pass: ambiguous apple count asks for clarification,
two small apples give 39.20 g carbohydrate, two large apples 56.07 g, and two
raw chayotes 18.31 g; a Unicode-minus count and a comma-grouped count both
withhold without becoming fallback answers. These numbers depend on the producer's USDA source data
and portion interpretation; dispatch does not prove those premises.

## Reproduction and receipts

```sh
python3 -B tools/dispatch/acceptance_coverage.py --probe-issues \
  --probe-untaken-representatives \
  --prior-issues var/dispatch/acceptance-coverage/orientation.json \
  --out var/dispatch/acceptance-coverage/final-consumer
```

The prior-issues file retains the initial dropped questions after their metadata
is repaired. Without it, the tool probes only current recorded rejections and
the optional not-taken representatives. It records receipt fingerprints, exact
commands and replies, source-policy hashes, and before/after binary hashes.

Reply-file coverage is checked independently of the scorer summary: every
expected request ID must occur exactly once, with the exact expected record
count. Malformed records, duplicate IDs, missing IDs and extra IDs reject the
split as `INVALID_RECEIPT`; that split receives no acceptance counts or inherited
panel score. Six focused fixture tests pass, including equal-count substitution
and duplicate records that would otherwise hide missing requests. A read-only
integrity check of the 286 already captured reply files found all 286 valid and
all 286 hashes unchanged. This check did not rerun any producer or acceptance
probe and does not refresh the earlier capture's artifact date.

Local evidence, excluded from Git:

- `var/dispatch/acceptance-coverage/final-consumer/coverage.json` and `.md`:
  every specialist row, every dropped/not-taken question, and all 76 live probes.
- `var/dispatch/acceptance-coverage/final-consumer/receipt-integrity.json`:
  exact ID/count validation and unchanged hashes for those 286 stored receipts.
- `var/dispatch/c-runtime-final/state-transaction.json`: actual published-store
  state checks, including fresh-session unknown-item preservation.
- `var/dispatch/stores-unknown-reference.json`: repaired candidate's same-session
  unknown noun and retained-reference checks.
- `var/dispatch/stores-counts-composition.json`: candidate cooking checks.

The reusable tool, its six-test fixture file and this report are the three new
files in this packet. The focused
pin implementation and tests live in the separately reviewed C-runtime-dispatch
packet. Root owns integration. Producer families own remaining recognition and
model repairs; registry registration and consumer acceptance establish neither
source truth nor mathematical correctness of an interpretation.
