# Mythology: preserve the requested relationship

The old reader returned Jupiter for “What is the Roman name of Zeus's father?”
and Zeus's role for “Who is Zeus married to?”. It selected a familiar name or
domain from anywhere in the question. This packet replaces that search with
complete request forms for Greek/Roman counterparts, domain associations and
the role of a named figure. Other relationships, compounds, fictional settings
and historical qualifications remain unsupported instead of being discarded.

Useful additional forms include “Which deity is associated with thunder in
Norse mythology?”, “What is the mythological role of Poseidon?”, and direct
name/counterpart requests. All names and answer values still come from the
existing exported tables, not a duplicated answer dictionary in the recognizer.

A later challenge found that an explicit goddess request could select Ares,
Mars or Thor. Such requests now require the existing role description to say
goddess. The source's generic “god” question forms continue to include deities
of either sex. Missing role descriptions withhold: the previously correct
Nike answer to a goddess-of-victory question is now withheld because the source
has the domain row but no supporting role row. This is a recorded capability
regression pending fuller source attributes, not a newly correct answer.

## What the proof means

No HOL statement or table changed. The reused managed proof receipt is
`var/humanities/remote-attempts/20261018T065404Z-478dcd4ff9dd/receipt.json`:
115 scanned statements, zero oracles. Current proof dependencies match.

The consumed `yreply` calls `ykernel`. `g2r_first_match` and `r2g_first_match`
say an accepted pair is the first selected table row, with no earlier selected
row. `domain_value` says an accepted domain answer retains the supplied pantheon
and domain and equals that table's `domain_god` result. `role_value` says an
accepted role description belongs to the actual named row. `yreply_answered_iff`
connects answer status to a non-silent kernel result. The new complete grammars
construct those same requests. The goddess qualification check reads exported
role rows before admitting a request. Both English interpretation and that
classification check remain untrusted. The theorems do not establish cultural
identity, universal historical agreement, or the truth of the source assertions.

Managed native compile `20261018T122248Z-15040bac7611` binds the actual generated
export, shared regex library, rules, reader and driver. Active native SHA256:
`48d2d4f957ad9215b3ee872f0041e18ed63c9d66c024086e9f28febaf7e613fc`.
Its current-source verifier reports zero proof/runtime differences. The previous
native and initial failed semantic observations are retained in
`var/root-mythology/`. No proof build was needed for this reader-only change.

## Measurements

| Check | Result |
|---|---|
| Mythology shipped own panels | 13/13 dev, 13/13 heldout, isolated and family |
| All seven Humanities own panels | 394/394 in isolated and family modes; zero wrong, false yes or valid omissions |
| Fresh Mythology generator offset 20261207 | 26/26 in each mode |
| Earlier Humanities authored regression | 89/89 policy assertions |
| New 197 authored requests, old native | 71 right, 33 wrong, 93 withheld |
| Same requests, current isolated/family/full default dispatcher | 158 right, zero wrong, 39 withheld |

The 197 expected-behavior assertions pass in each consumer. The 39 refusals
remain meaningful/unknown requests without answers; they are not counted as
correct capabilities. There are 88 newly answered direct forms and one lost
Nike classification answer, for a net gain of 87 answered cases. The shipped
generator varies names/domains within its author's fixed templates. The new
cases were written by root, who also implemented the repair; they do not provide
independent linguistic coverage. The initial 179-case baseline was recorded
before editing, and eighteen further challenge cases exposed the goddess error.

Canonical probes/checker: `src/extract/humanities/mythology_probes.json` and
`check_mythology.py`. The checker retains correct-answer and withheld counts
separately from policy passes. `project/audits/mythology.audit.json` records a
partial semantic audit with before/after evidence. Other changed paths are
`src/extract/humanities/recognizer.sml`, README and project tracking.

Linux and scoped package validation are pending. Exact local evidence and
current state: `var/root-mythology/integration.json`.

## Remaining work

The source has no complete gender, genealogical, era or cultural-variant model.
Roman domain answers still use the source's Greek-to-Roman mapping, not an
independently modeled Roman pantheon. A single source row is not evidence of
exclusive association with a domain. Compound domains, dependency questions,+relationships, fictional retellings and novel phrasings need further work.
This packet is not a completed audit of Mythology or the Humanities family.
