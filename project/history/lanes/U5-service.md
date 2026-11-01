# U5: real Engine qualification of dimensional answers and grammatical “it”

The combined candidate completes the eleven targeted dimensional geometry
checks, but the full Engine exposes a separate specialist route that still
multiplies mixed-unit dimensions as raw numbers. The grammatical-it diversion
is removed; the original transfer-duration task remains unanswered.

## Candidate and execution

Runtime: `var/usage-20261027/candidate-u5-v1`.
APPLIANCE receipt SHA256:
`a7d1afb9cbdcabfe23c9f1c7b46128e1a0c2c302c4dbbbc7902be38ad8b3c5f9`.
Only w468, w488 and the word-problem module differ from U4-v2; provisioning owns
that source inventory claim. This lane changed no candidate, service source,
Mini package or specialist implementation.

One Engine ran under the shared engine lock. **39 requests and their exact
retries** all completed at the transport layer, with every replay returning the
identical complete response. All request/conversation IDs passed the harness's
ASCII letter/digit/hyphen check before sending. Owned PID **27355** exited
normally with code **0**. Before/after inventories found zero new, missing, or
changed size/mtime files, and the APPLIANCE receipt hash remained unchanged.
The owned Engine is stopped.

Full evidence:

- `var/u5-service/u5-v1-real/receipt.json`
- `var/u5-service/u5-v1-real/calls.jsonl`
- `var/u5-service/u5-v1-real/runtime-before.json`
- `var/u5-service/u5-v1-real/analysis.json`
- `var/u5-service/u5-v1-real/reliability-analysis.json`
- Runner `var/u5-service/probe-u5-v1.py`; analysis script `var/u5-service/analyze.py`.

The raw receipt's transport/replay checks pass. They do **not** imply every
semantic task passed; the separate analysis preserves the wrong answer below.
No specialist panels, proof builds, Linux qualification or native Mini admission
were run or claimed.

## What now completes

All seven previously unit-incomplete geometry answers now include their units
both in displayed text and provenance: room/identifier area 12 m², perimeter
14 m, rounded area 12.5 m², and location wording 12 m². Additional checks give
12 cm², cone volume 4π cm³ (displayed 12.5664), rounded cylinder volume 15.4 cm³,
and zero area 0 cm². All **11 independent value/unit/rendering checks pass**.
The cone's full numeric value remains in provenance; decimal display uses the
existing formatter's precision.

The original 15 reliability questions are unchanged. Results remain **nine
correct scalar answers, four appropriate refusals/clarifications, and two
needless refusals**; 7/10 pair expectations pass. Four of those scalar answers
now also have complete geometry units. Spelled “five degrees below zero” and
150 km over three hours remain unanswered. Multiple-room aggregation, requesting
both area and perimeter, and explicit output-unit conversion still receive
bounded capability explanations and remain incomplete tasks.

Austen author-to-birth reference still returns 16 December 1775. Same-session
last-question recall preserves the arithmetic question and answer; an empty
other conversation reveals no prior question. Password, compound recall/password
and other-conversation requests remain withheld; the private-thought control
clarifies without asserting a private fact.

## Actual remaining failures

The unchanged mixed-unit question is:

> A rectangle has length 3 meters and width 4 centimeters. What is its area?

The full Engine answers:

> The area is 12 (A = l × w = 3 × 4). [geometry-v4]

Path: `specialist_call>specialist:geometry-v4>rect_area`.
Provenance identifies `core_called_specialist`, with the core's earlier
`act:clarify_specific` status. The corrected word reader declines this case,
but the live specialist later supplies the raw product. The physical area is
**0.12 m² or 1200 cm²**; the reply supplies no unit or conversion contract that
would justify its bare 12. This is classified as a wrong dimensional answer,
not as useful completion or as a failure of the new unit formatter. Root and
the reliability lane received the exact live result before any further change.

The prepositional control “length 3 in the diagram and width 4 in the diagram”
also reaches that specialist and returns the same bare 12. It does not explicitly
claim inches, so this receipt does not establish a wrong scalar or a specific
inch misparse. It remains an unqualified answer without a diagram scale or
measurement unit and is not counted as dimensionally complete.

After arithmetic 42 followed by “that times 2” giving 84, the original
“How long does it take to transfer 1GB at100Mbps?” no longer asks whether “it”
means “times” or “multiplied.” It instead returns a generic clarification at
`act:clarify|vessel:receipt`. The grammar-routing repair is observed, but the
transfer-duration task is **not complete**. The generic clarification is not
counted as an answer.

Across all 39 requests, the task classification is **23 completed, eight
appropriate refusals/clarifications, seven valid or underspecified tasks
incomplete, and one wrong dimensional answer**. This bounded replay neither
establishes whole-system correctness nor conceals the specialist override.
Root owns the next source repair and any later candidate replay.

## Final U5-v2 convergence checkpoint

Root integrated a separate geometry-specialist repair and a locally enabled
transfer extension into `var/usage-20261027/candidate-u5-v2`.
APPLIANCE receipt SHA256:
`3d0e2c804c7c76f7a683e564053ccb5474bf3f1e97d30246c70f52f33dbd1338`.
The earlier v1 failures above remain retained evidence; this section records the
new candidate's behavior rather than rewriting them.

One coordinated Engine replay repeated all 39 v1 cases, added the 16 fixed U5
transfer controls, and invoked the direct transfer specialist for a positive
and a refusal: **57 requests, all exact retries identical**. Operation discovery
also confirmed the new specialist is live. Recorded PID **88848** exited normally
with code **0**. Approximate elapsed time from the owned-PID file to finalized
receipt was **31.3 seconds**, including startup, calls/retries and shutdown.
Runtime inventory again shows zero new, missing or changed size/mtime files;
the APPLIANCE receipt hash stayed unchanged. No Engine remains running.

Final evidence:

- `var/u5-service/u5-v2-real/{receipt.json,calls.jsonl,runtime-before.json}`
- `var/u5-service/u5-v2-real/analysis.json`
- `var/u5-service/u5-v2-real/reliability-analysis.json`
- `var/u5-service/probe-u5-v2.py` and `analyze-v2.py`.

### Actual repairs now reach consumers

The earlier wrong mixed-unit rectangle now answers **0.12 m²**, showing
`3 × 0.04` through the real `geometry-v4` specialist route. The prepositional
“in the diagram” case now answers **12 square units**, without inventing inches
or a physical scale. This completes the abstract diagram calculation; it does
not assert a measured physical area. All eleven original value/unit/rendering
checks still pass. The specialist-route wrapper does not retain the organ's
raw `unit` field, so the repaired mixed-unit result is checked in the full answer
text, while the word-reader checks also inspect provenance units.

After the original arithmetic context, “How long does it take to transfer
1GB at100Mbps?” now answers **Ideal transfer time: 80 seconds**, explicitly
assuming 100% utilization and excluding startup delay. Its path is
`local_extension>specialist_call>specialist:data-transfer-v1>transfer_seconds`.
All **16 integration controls pass their bounded expectations**: ten valid
requests return the expected ideal/estimated seconds and six unsupported,
invalid or underspecified requests decline or clarify. These are development
integration controls, not a fresh held-out admission panel. The fractional case
retains the intended 4/3-second result to the text formatter's stated precision.
The direct positive additionally preserves the exact rational 80/1 calculation.

The catalog now reports **351 live direct, one text-only and nine unavailable**
operations. `specialist.data-transfer-v1.answer` is discoverable and directly
callable. Catalog metadata, full-head provenance and direct raw results retain
`locally_enabled_unqualified`, `untrusted_python`,
`fresh_heldout_admission: false` and `formal_proof: false`. The successful
calculation does not silently acquire an upstream admission, proof or Mini
permission. The direct unsupported-startup-delay request remains withheld and
preserves the complete qualification object.

Austen birth follow-up, arithmetic continuation, same-session recall, empty
other-session recall and privacy controls remain correct within this replay.
The original 15 reliability cases retain nine correct scalar results, four
appropriate refusals and two needless refusals, with 7/10 pairs passing.

### What remains after this checkpoint

The final 57-request classification is **37 completed, 13 appropriate
refusals/clarifications, seven valid tasks incomplete, and zero wrong answers
observed**. The seven incomplete records are the spelled-negative-temperature
request, valid speed request, three unsupported geometry-scope calculations,
and startup-delay transfer through both head and direct invocation. The latter
requests pass the bounded rejection controls but still do not complete those
valid calculations; they are not counted as answered tasks.

No further source repair or candidate iteration was launched during convergence.
This lane changed no runtime source or immutable candidate. Root owns Git and
any subsequent work. These are local full-Engine checks; no specialist admission
score, new theorem, Linux result or native Mini admission is claimed.
