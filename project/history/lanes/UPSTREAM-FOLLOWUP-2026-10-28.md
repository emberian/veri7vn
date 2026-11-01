# Upstream review — 28 October 2026

Oracle7 slim 10.1 is published at
`c473d28914e480425adb29b4f7f42485b8cfb4e3` (head w574). Its
[changelog](https://huggingface.co/psiloceyeben/oracle7-slim/blob/c473d28914e480425adb29b4f7f42485b8cfb4e3/CHANGELOG_101.md)
credits our second contribution batch and publishes maintainer amendments.
Our signed v7 appliance remains the qualified 4.9-based composition; this review
does not upgrade it or qualify 10.1.

All 13 tracked contributions remain open. Complete public discussion listings
and every thread were fetched from the Hub API; GitHub PR metadata, comments
and reviews were read through the connected GitHub account. There are no new
maintainer comments since the 27 October review. Our two approved replies on
date precision and operation discovery are present. No comments were posted today.

| Contribution | Observed state |
| --- | --- |
| [GitHub PR #1](https://github.com/psiloceyeben/oracle7/pull/1) | Unmerged, no comments or reviews, unchanged head `ec26c0b2040e10bb36c1a3fc192266b628c6db3c`. |
| [Slim PR #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1) | Still open although incorporated manually in 10.0. Do not reapply it. |
| [Slim PR #2](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/2) | 10.1 credits incorporation with composer amendments. Hub now reports conflicts in the relation reader and its test. This needs reconciliation with the published amendment, not a blind rebase. |
| [Mars years #3](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/3) | 10.1 reports the counted-period repair in all nine organ copies. No independent whole-Engine rerun here. |
| [Date precision #4](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/4) | Sidecar incorporated, but the published fallback still guesses metadata from digits; see the reproduction below. |
| [Appliance #5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5) | Our schema feedback is the latest reply. The operation-discovery proposal has not become an agreed compatible contract. |
| [Inverse relations #6](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/6) | Still scheduled for 10.2 in the published changelog. |
| [Kind guard #7](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/7) | Still scheduled for 10.2; the composer amendment does not claim general resolution. |
| [Trafficcop #1](https://huggingface.co/psiloceyeben/oracle7-trafficcop/discussions/1) | No maintainer reply; main unchanged. |
| [DeepSpace #1](https://huggingface.co/psiloceyeben/oracle7-deepspace/discussions/1) | No maintainer reply; main unchanged. |
| [Infrastructure #1](https://huggingface.co/psiloceyeben/oracle7-infrastructure/discussions/1) | No maintainer reply; main unchanged. |
| [Vision #1](https://huggingface.co/psiloceyeben/oracle7-vision/discussions/1) | No maintainer reply; main unchanged. |
| [Artist #1](https://huggingface.co/psiloceyeben/oracle7-artist/discussions/1) | No maintainer reply; main unchanged. |

## Published date fallback: concrete remaining defect

Read the actual published `root/wander-train/date_precision_v1.py`, not only the
amendment script. With an absent sidecar and an uncovered synthetic entity,
these public helper calls produce:

```python
value = '2001-02-31T00:00:00Z'
DATE.available(value, 'When?', 999999999, 569)  # True
DATE.render(value, 'When?', 999999999, 569)
# '31 February 2001 (Gregorian calendar)'
DATE.interval(value, 999999999, 569)
# ('http://www.wikidata.org/entity/Q1985727', (2001, 2, 31), (2001, 2, 31))
DATE.evidence(value, 999999999, 569)['status']  # 'precision_unavailable'
```

This was executed against the pinned file with only standard-library imports;
the synthetic case does not establish that the shipped store contains this
literal or that the whole Engine emits it. The fallback checks only day 1–31,
not validity in the stated calendar. It also turns a missing/unreadable sidecar
into the same fallback as an uncovered pair. Thus availability and ordering
assert more than the evidence supports.

Calendar validity is the narrow repair. The substantive repair remains the
source-metadata boundary already described in our posted reply: unavailable
precision/calendar/qualifiers must not silently establish exact dates or order.
Increasing sidecar coverage is useful; a Gregorian cutoff and timestamp digits
cannot recover discarded source metadata. Do not adopt this fallback into v7.

The composer amendment now checks same-title cross-domain disagreement and
falls through to the older reader when the explicit reader cannot decide.
Before upgrading, check that this fallthrough preserves ambiguity and false-
premise refusals through the final head; retain the maintainer's symphony/film
controls as well as our focused fixtures. No whole-head qualification was run.

## Integration decision

Review 10.1 as a distinct candidate: inventory its new clause reader, consensus,
`handoff` and `check` interfaces; reconcile each local repair with the published
source; preserve scoped evidence; then run actual consumer controls. No new
specialist-panel numbers or theorem claims arise from this review. The upstream
claims and local appliance qualification remain separate.

Ignored `var/upstream-followup-20261028/` retains all API snapshots, pinned files,
the helper reproduction and browser-preview screenshots. The earlier review
records the already-posted schema and date feedback. The next useful upstream
reply is this precise date counterexample; duplicate status pings add nothing.
