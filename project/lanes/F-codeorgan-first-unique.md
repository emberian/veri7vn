# F — first-occurrence deduplication in code requests

Owner: codeorgan_sol. This succeeds the initial code route integrated in
`db8f1c7`; its report is `E-codeorgan.md`. Shared consumer changes belong to
runtime. **No shipped code-organ specialist panel exists.** The numbers below
are scoped code-route checks, not a specialist scoreboard result.

## Behavior

A request to remove duplicates while preserving original order, or explicitly
keeping first occurrences, now gets a candidate that composes the existing
Reverse, Unique and Reverse moves. The primitive Unique still keeps last
occurrences. Explicit last-occurrence requests retain that policy. Unqualified
requests consider both policies; if matching programs differ on additional
observations, the route asks for examples that distinguish them. Conflicting
first/last instructions and examples inconsistent with the stated policy refuse.

This matches the intended operation in the actual stored upstream request
`removes_duplicates_keeping_order`, whose example maps `[3,1,3,2,1]` to
`[3,1,2]` in
`upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/code_library_v1.json`.
That source record supplies one prose example; this packet still requires two
structured examples. Supporting the actual one-example prose protocol and
other finite integer/list requests remains active successor work.

Description normalization covers singular/plural duplicate, ordinary sums,
counts and keeps, and the removal construction “while removing”. It retains
unsupported qualifiers as refusals. Function names are removed only from the
declaration, so naming a function `cube` no longer erases the operation word
from its description. Globals used by the rendered templates remain reserved.

The response describes a first-occurrence sequence only when every Unique
move is contained in a greedily recognized contiguous Reverse/Unique/Reverse
macro. If a bare Unique remains, the conservative last-occurrence primitive
note remains. Runtime reconstructs that wording independently and rejects
altered notes or source. AST, packet schema and source templates are unchanged.

## Statements and trust boundary

This adapter-only extension adds **no new theorem or primitive**. It uses the
same generated evaluator and 16 oracle-free roots as the integrated packet.
In particular, the universally quantified statements are:

- `check_program p cases ==> cases ~= []`.
- `check_program p cases ==> (args,want) : set cases ==> run p args = Some want`.
- `steps (xs@ys) v = (case steps xs v of None => None | Some w => steps ys w)`.
- A Unique result is distinct and has exactly the input's set of members.
- Two Reverse moves return their original integer list.

For the new macro the actual generated evaluator computes
`rev (remdups (rev xs))`; its exact supplied-example results are checked before
release. This packet does not add a separate universal theorem characterizing
first-occurrence order. English interpretation, search, rendering and Python
consumer replay remain untrusted. Additional observations establish neither
program equivalence nor intended behavior on unobserved inputs. The actual
response retains that finite-example limitation.

## Exact checks

`python3 src/extract/codeorgan/check_first_unique.py` passes:

- 23 authored controls: **14 supported, 2 withheld valid, 7 invalid refused**;
- 60 reserved requests with independently calculated first-occurrence lists:
  **60 supported, zero wrong and zero false yes**;
- all 83 requests through the actual dispatcher with Computing and guards:
  every answer receives `consumer_validation: consistent`.

The reserved seed was not used to tune the recognizer. Its arithmetic/list
values are new, while its description templates share the author's bounded
recognizer model; this is not an independent English benchmark. Runtime's
independent six ordinary prompts initially found three valid descriptor
refusals. Canonical singular/plural and verb normalization repairs them; those
six are now explicitly in the authored regression set, not called held out.

The full default dispatcher, with every family, stage and dialogue enabled,
passes eight narrow requests: five code answers and three proper refusals,
zero wrong/false yes. These include runtime's independent ordinary descriptors,
ambiguity, contradictory instructions and false examples, plus the stored
upstream operation's two-example adaptation and the named-cube repair.

The integrated 56-request corpus retains **35 supported, 11 withheld valid,
10 invalid refused**, all IDs matching and all answer packets independently
replayed. No broad fleet or head score is inferred. Runtime's 10 consumer tests
cover macro wording and mutations; it also checked actual packets independently.

## Files and receipts

Changed producer files: `src/extract/codeorgan/answerer.py`, `README.md`, new
`probes_first_unique.json`, new `check_first_unique.py`, and this report. No
HOL, generated export, native framing or compiler input changed.

- Frontdoor SHA-256:
  `8f3285d7a0a45a60de5df0842852bb666f15a42ad11ef1250024ac1f547f064b`.
- Native SHA-256:
  `d781175bec2637a13ad9b2a26843d8c2cd7857899072719d1571a4e28f2f6fae`.
- Proof: `var/codeorgan/remote-attempts/20261018T084300Z-b323751ec5fc/receipt.json`.
- Native input capture:
  `var/codeorgan/native-attempts/20261018T084706Z-ad14887c769b/compile-inputs.json`.
- `var/codeorgan-sol/first-unique-closure.json` checks every recorded proof
  dependency and native source against current files: all match. No new build
  is claimed or needed for an unchanged generated computation.
- `var/codeorgan-sol/first-unique.json`: native producer, independent consumer,
  reserved values and 83 actual composed replies.
- `var/codeorgan-sol/first-unique-default.json`: eight full-default replies.
- `var/codeorgan-sol/consumer.json`: repeated integrated 56-request corpus.
- Historical integrated input inventory, captured before reopening:
  `var/codeorgan-sol/integrated-db8f1c7-inventory.json`.

## Next capability work

The stored upstream library has 15 descriptions. Its integer/list requests
include doubled lists, merging sorted lists, factorial, greatest common divisor
and second-largest selection, as well as the already supported sums and maxima.
Their one-example prose protocol needs safe literal parsing and explicit
candidate ambiguity discipline. String operations are a separate typed-domain
extension. No request text, user definition or stored source will be executed.
