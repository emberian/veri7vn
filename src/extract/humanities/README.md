# The humanities family, end to end

Seven shipped Oracle7 specialists as verified HOL kernels: `music-v2`, `music-v2-r2`, `grammar`, `mythology`,
`ushistory`, `library`, `government`. Same recipe as the quantity family (`../quantity/README.md`): tables are HOL
constants checked against the organ files, the kernel is exported to Standard ML and compiled with the MLton inside
Isabelle into one binary (`var/humanities/bin/humanities`) that speaks the answerer contract.

Music is modular arithmetic: pitch classes mod 12 and letters mod 7 give key signatures (the circle of fifths),
relative keys, scales whose accidentals match the signature, spelled intervals and MIDI numbers; frequency and
cents are enclosed by Isabelle's verified interval arithmetic. Library check digits are proved against their
defining congruences. The lookup families take the first set bit of an ordered rule list, proved (`pick_some`).

Result: every shipped panel, both splits, 0 wrong and 0 false yes; held-out equals the shipped number on all seven
(music 64/64 twice, grammar 15/15, mythology 13/13, ushistory 12/12, library 14/15, government 10/14). Details,
statements and limits: `../../project/lanes/S16-humanities.md`.

Build: see the handoff's reproduce section. The recognizer (`recognizer.sml`, `../commons/commons.sml`, `rules.sml`) and
`main.sml` are untrusted.


The 18 October continuation completes the existing ISBN conversion and government
structural-count question forms. It keeps the values in the same HOL kernels.
The MIDI round-trip statement accounts for enharmonic octave crossings: Cb4
comes back as B3, while B#4 comes back as C5. Grammar silence covers every active
lookup kind. These statements are checked by the family export's final oracle scan.

`beyond_check.py` runs the shipped generators at caller-selected seed offsets
under `var`, using the specialists' own scorers. These generators share their
author's assumptions and fixed phrasings. `check_probes.py` runs the separate
implementation-author probes in `beyond_probes.json`; these do not establish
independent language coverage. Current evidence and outstanding work are in
`project/lanes/C-symbolic-facts-humanities.md`.

A second continuation narrows US-history requests to complete president-role
and historical-event clauses. A foreign president, someone who defeated a
president, or a destruction/commemoration question no longer receives a US
ordinal or an unrelated event year. All 19 event rows have positive and
unrelated-event probes. The HOL lookup statements are unchanged; English
interpretation remains untrusted. The shared native compiler binds the actual
consumed input snapshot to the passed proof export. Current checks: 197/197
dev and heldout in specialist and family modes, 70/70 native/dispatcher/family
probes, and US-history 12/12 on both splits at two untouched generator offsets.


The third Humanities packet restricts all 13 government fact rows to complete
requests for structural membership, electoral totals/thresholds, amendment count,
term length or minimum eligibility age. Attendance, vacancies, quorum and actual
person ages are different fields and remain unsupported. The existing checked
source-row selector is unchanged; English interpretation remains untrusted.
All seven panels and family mode remain 197/197 dev and 197/197 heldout, with no
wrong answers, false yeses or valid omissions. All 89 authored assertions pass
natively, through the dispatcher and in family mode: 46 supported answers and
43 valid requests withheld. These refusal checks do not count as answered
capabilities. Exact proof/native bindings are in the continuation report.

Mythology now recognizes complete requests for a counterpart, a deity associated
with a domain, or a named figure's role. A question about Zeus's father no longer
selects Zeus's own Roman name; questions about a spouse, a film or several figures
do not silently become a single table lookup. Direct association and role
questions have additional supported forms. An explicit goddess qualification
must also be supported by the existing role description. Missing descriptions
remain a coverage gap: even Nike's otherwise known victory association withholds
when the question explicitly requires a goddess classification.

The 197 authored mythology requests have 158 correct answers, zero wrong answers
and 39 meaningful/unknown requests withheld. The previous native had 71 correct,
33 wrong and 93 withheld on the same requests. These are partial interpretation
checks, not proof of the cultural identifications or exhaustive language coverage.
The unchanged checked kernel binds each answer to its selected source row;
English interpretation and the source-based qualification check remain untrusted.
See `project/lanes/M-humanities-mythology.md` for bindings and remaining limits.
