# Anatomy/agriculture E: seed purchases and quantity scope

The committed D artifact remains available in the historical C-anatomyagri report. Concrete follow-up examples
showed that a target of 101 plants at 80% germination produced “126.25 seeds per
acre” without any acre context; negative -80% became positive, and malformed
1.2.3% was read as 2.3%. A negative target already withheld. Receipts are under
`var/anatomyagri/e-next/`.

E carries total/per-acre scope in the request, distinguishes rational expected
seeding rates from whole-seed purchases, and binds complete target/germination
tokens through shared ExactNumeric. Whole and minimum counts use the ceiling
of target divided by germination fraction. The intended binding theorem says
the returned natural count meets the expected stand and every smaller natural
count falls short. It does not guarantee realized germination. Ordinary
per-acre rate questions retain the rational expected requirement. Mixed
quantity scopes, unsupported hectare conversion, malformed tokens and duplicate
roles decline explicitly.

The first E attempt exposed a stale enumeration of compute-level declines
and proof tactics that no longer eliminated the extended domain checks. The
source now states the stable invariant that every compute-level decline is
underspecified; numeric proofs derive their value from the shared kernel
invariant. A superseded retry was cancelled and its terminal receipt rejected.
Final hbox attempt `20261018T082620Z-b322520f50b2` passed 62 scanned theorems
with zero oracles. The seed theorem establishes, for positive germination
fraction p at most one and nonnegative target t, a natural n with n*p >= t and
m*p < t for every natural m<n. The rational expected requirement satisfies
v*p=t, and its numeric value is unchanged by the total/per-acre scope label.

The common native compiler receipt is
`var/anatomyagri/native-attempts/20261018T082931Z-7cb6628902ae/compile-inputs.json`.
It binds the full successful theory closure to actual generated ML, commons,
shared exact numeric lexer, recognizer and main inputs. The numeric parser hash
is `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
The binary is 462712 bytes, SHA-256
`b5e5ea468768485bc20e599162d7915b4046e802f6c39cb81890c8782a39f0d9`.

Shipped evaluation is 156/156 in both pinned and family dispatch, zero wrong,
false yes or withheld. Development offsets 10181001/10182003 and new untouched
10185011 each score 156/156. All source-table checks pass. Five process starts
were 77.60, 4.05, 4.64, 7.73 and 3.90 ms; median 4.64 ms, including the visible
first filesystem-cold load. Fresh seeds change template samples, not language.

The 66 same-author policy assertions all pass, including response unit checks.
Capability counts are **49 right, 0 wrong, 0 false yes, 17 withheld-valid**.
These include twelve developmental counts outside the table, cat and dog
anatomy, a factual question embedded in symptom context, hectare scope and a
multi-acre total. They are not credited as supported capabilities. For the
same questions, frozen D scores 38 right, 5 wrong, 3 false yes, 19 withheld-valid
and one unassessed assertion; the organ scores 19 right, 11 wrong, 3 false yes,
20 withheld-valid and 13 unassessed assertions. No single scalar biological
reference was invented for developmental cases: answering those is unassessed,
not automatically correct or false yes. Historical probe totals in C-anatomyagri
are policy assertions; official scorer numbers are unchanged.

Receipts: `var/anatomyagri/e-next/{shipped-bound,probes-bound,probes-d-classified}.json`
and `var/anatomyagri/c-beyond/{e-bound-10181001,e-bound-10182003,e-bound-untouched-10185011}.json`.
The immutable artifact and named source manifest is `var/anatomyagri/e-delivery/ready.json`.
Runtime gains agriculture-v2 kinds `seeds_expected` and `seeds_minimum` through
the family-owned sidecar. The reader now consumes the frozen shared numeric
lexer. The remaining per-specialist limits are in `semantic-gaps.md`.
