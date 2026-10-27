# Upstream follow-up — 27 October 2026

The maintainer replied to the [appliance discussion #5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5)
at 20:18 UTC. They confirm the first PR's incorporation in 10.0, describe
amendments to #2–4 in a 10.1 candidate, and request feedback on a proposed
operation-discovery contract for 10.2. No new qualified appliance upgrade is
implied.

All 13 tracked threads were read at approximately 21:24 UTC, together with
complete discussion listings for slim and the five sibling repositories. No
additional threads appeared. All 12 HF threads remain open; #5 contains the
only new maintainer reply since our previous check. GitHub PR metadata and comment/review timeline were
read through the GitHub connector.

| Contribution | Current state |
| --- | --- |
| [GitHub Oracle7 PR #1](https://github.com/psiloceyeben/oracle7/pull/1) | Open, unmerged, no comments; unchanged head `ec26c0b2040e10bb36c1a3fc192266b628c6db3c`. HF incorporation does not imply a GitHub merge. |
| [Slim PR #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1) | Open; maintainer confirms manual incorporation into 10.0 as 4.9.1. |
| [Slim PR #2](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/2) | Maintainer reports integration into a 10.1 candidate; composer regressions found by v37c were amended, with v37d pending. |
| [Mars years #3](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/3) | Maintainer reports the 5.64-Mars-years case passed; release with #2/#4 depends on v37d. |
| [Date precision #4](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/4) | Candidate includes the sidecar plus a new digit-based fallback; the latter needs evidence-boundary feedback. |
| [Appliance #5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5) | Answer the operation-schema proposal and contribution-process requests. |
| [Inverse relations #6](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/6) | Assigned to 10.2; no released fix claimed. |
| [Kind/composer guard #7](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/7) | Assigned to 10.2; #2's amendment overlaps this issue without establishing its general resolution. |
| [Trafficcop #1](https://huggingface.co/psiloceyeben/oracle7-trafficcop/discussions/1) | Open, no maintainer comments; main unchanged from reviewed base. |
| [DeepSpace #1](https://huggingface.co/psiloceyeben/oracle7-deepspace/discussions/1) | Open, no maintainer comments; main unchanged from reviewed base. |
| [Infrastructure #1](https://huggingface.co/psiloceyeben/oracle7-infrastructure/discussions/1) | Open, no maintainer comments; main unchanged from reviewed base. |
| [Vision #1](https://huggingface.co/psiloceyeben/oracle7-vision/discussions/1) | Open, no maintainer comments; main unchanged from reviewed base. |
| [Artist #1](https://huggingface.co/psiloceyeben/oracle7-artist/discussions/1) | Open, no maintainer comments; main unchanged from reviewed base. |

Live slim main remains `0e0e858238cb028b751a85a23f4690a0b0d48483`; its pinned
README identifies 10.0 / w573. The reply's example 10.1 / w574 descriptor is
a proposal, not evidence that 10.1 or discovery has shipped.

## Feedback and adoption

Accept the maintainer's requests for earlier answering-route inventories,
interface-matching fixtures, and unaffected whole-head questions. Their sealed
test caught our explicit composer reader selecting a film composer for an
unqualified symphony title and losing possessive/false-premise handling. Carry
these controls into review of the published amendment, including refusal
versus fallthrough. They also report another A3 volume-as-length correction.

The described date fallback renders non-first days from 1583 as exact dates,
first days as months and 1 January as years. Digits cannot reconstruct discarded
precision, calendar, qualifiers or rank. Keep the [source-bound importer](../../tools/usage/dates/README.md)
contract and extend its coverage. Raw-literal inspection can be useful with
metadata explicitly unknown; it must not silently establish date ordering or
publication-year premises. This is policy feedback; unpublished v37d was not
inspected or executed.

The three proposed routes fit our service, but the schema is not wire-compatible:

- `tools/appliance/operations.py:18` excludes colons, so proposed
  `physics60:solved-power` fails current validation in that module,
  `serve.py:458/675` and `tenant_pool.py:304`. Use an explicit versioned grammar
  or identity mapping, not punctuation substitution.
- Our input schemas declare types, required fields, bounds and unknown-key
  handling. Request a JSON Schema dialect, numeric/unit semantics, stable
  argument keys separate from labels, and structured outputs.
- Our callable native `answer(text, session)` still interprets language and
  bypasses whole-head routing/guards. Upstream `call: text` means query-only.
  Separate invocation support, input form and execution scope.
- Descriptor evidence advertises possible claims; each reply must retain its
  actual scope, premises and outcome, including unfamiliar fields. Distinguish
  domain refusal, infrastructure failure and uncertain execution.
- Our bounded pages use `offset`/`next_offset`. Request stable catalog identity
  and paging semantics, byte bounds and explicit unknown totals while deferred.
  Bind recorded exam verdicts to implementation/panel identities and distinguish
  failed, missing and not-applicable exams from unavailable implementations.

Keep runtime, data and dependency identities explicit. The
[published 10.0 README](https://huggingface.co/psiloceyeben/oracle7-slim/blob/0e0e858238cb028b751a85a23f4690a0b0d48483/README.md)
states reader modules and route files are outside its anchored root; an anchor
does not establish coverage of every packaged file. Conversation restoration
also remains unsupported upstream: retain durable exact-request replay and
explicit reset after retirement, rather than reconstructing state by replay.

Draft replies for #5 and #4 and public inspection snapshots are in ignored
`var/upstream-followup-20261027/`. No duplicate status pings are recommended
on the other threads. Nothing was posted, and no tests, builds, release
verification or appliance runs were launched. Runtime and signed candidate
remain unchanged.
