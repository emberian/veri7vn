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
