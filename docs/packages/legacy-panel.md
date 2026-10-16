# Original panel import and scorer policy

`LegacyPanel.scala` imports the shipped `panel.json` data shape without executing
`scorer.py` or an organ. It preserves the exact panel bytes and the decoded `q`, `a`,
`valid` and `kind` fields, split/index and remaining inspection metadata. The current
paint panel contains 7 development and 11 held-out rows, including 5 must-decline
rows. Those are sender labels and expectations; import grants no recipient freshness,
native semantic admission or activation.

The known scorer source is
`upstream/workbench/examples/paint-coverage/scorer.py`, SHA-256
`a723ac247dc906d7610d25db07ce0d7abd35f0bd018e324fe26249d9ffcfbcd5`.
The importer names this characterized source policy **LegacyScore**. A modified or
missing scorer remains unresolved. Recognizing this source pin does not execute
Python or prove a native implementation equivalent.

The actual original scorer has these criteria:

- A reply asserts an answer exactly when `str(status) == "answered"`.
- A false `valid` item succeeds whenever it did not assert an answer. It does not
  distinguish a deliberate decline from other non-answer statuses.
- An asserted valid item extracts every numeric substring from gold and response
  using `-?\d+(?:,\d{3})*(?:\.\d+)?`, removes commas and converts to Python floats.
  Every gold number needs some response number within
  `0.01 * max(1.0, abs(gold))`. Numbers need not occur in the answer position or have
  the correct units, and extra incorrect numbers are not penalized.
- With no gold numbers, the lowercase gold string only needs to occur in lowercase
  response text. `kind` is ignored by this scorer.

The docstring's “within 1%” description is therefore incomplete for magnitudes below
one, where the absolute tolerance is 0.01. Scientific notation and malformed grouping
are interpreted as regex substrings, not a general numeric grammar. Blank/missing
gold on a valid answered row vacuously passes the word-substring branch. Merely listing
several possible numbers can pass; correct units, interpretation and route choice are
not established. These behaviors are preserved as LegacyScore policy facts, not
quietly promoted to desirable native scoring rules.

The controlled importer accepts actual string questions/answers and Boolean validity;
it does not silently reproduce Python truthiness for an unexpected JSON string such
as `"false"`. Missing validity records the original default `true`. Missing/blank gold
becomes an **unknown native proposal**, with an explicit repair diagnostic describing
the original vacuous-match behavior. The raw original still retains that behavior's
source and data. Unknown expectations are never scored correct by the native scorer.

## Native typed bridge

The first native producer is `v7_test_data name = "[(request, expectation), ...]"`
in canonical `.thy` source. It retains the exact original source owner/slice and uses
controlled native definitions. Expected answers are data, not world axioms. The native
meaning distinguishes unknown, answer, decline and undefined expectations; observed
rejected operations are unscored and undefined does not mean a deliberate decline.
The actual registered family request/result and installed matcher profiles determine
which finite data can execute. Equality, enclosure/tolerance criteria and LegacyScore
are different matcher policies, never interchangeable labels.

The paint panel's `"2.03"` is a rounded string, while the corresponding exact scalar
calculation can be `81/40`. Converting that gold to exact equality would change the
criterion. An explicit native enclosure/tolerance expectation may be useful, but that
is a repair/new policy, not evidence of LegacyScore parity.

Remaining actual bridge obligations are:

1. Map each original question through the actual native interpretation/request profile,
   preserving its question bytes and any ambiguity or missing-input diagnosis.
2. Retain original fields and scorer provenance alongside the canonical generated
   `.thy` proposal and conversion recipe; do not edit two semantic sources thereafter.
3. Bind actual result status/rendering and installed matcher code. A profile declaration
   alone grants no executable authority. Do not collapse undefined/rejected into decline.
4. If compatibility is claimed, connect the implemented regex, floating conversion,
   tolerance and word/status behavior to this exact original policy, with scope and
   unsupported inputs explicit. Finite examples alone do not prove general parity.
5. Bind actual dataset/resource membership, governed audiences and original exposure
   history. Imported held-out labels do not become fresh recipient evaluation.
6. Qualify the composed recognizer/decline/interference behavior and measured resource
   costs, independently of any admitted mathematical kernel, before publication.

The real importer/receipt model checks and native typed producer tests are queued;
the existing model11 receipt predates these additions. This report does not claim the
entire original paint organ, parser, scorer or panel execution has been formally lifted.
