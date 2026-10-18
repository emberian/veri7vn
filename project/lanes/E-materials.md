# Completing CT arithmetic, 18 October 2026

Status: proof and final native passed; source frozen for runtime capture and
root integration. Hbox attempt `20261018T075206Z-27ab84a25c41` passed with
74 theorem roots and zero oracles (build/log/export exit zero).
D is integrated as 4e51593 and its final native is preserved at
`var/E-materials/before-bin`.

The water specialists previously computed only concentration times contact
time, and could misread signed, fractional or scientific inputs. The current
source also computes contact time from CT and residual concentration, and
residual concentration from CT and contact time. Requested targets remain
separate typed requests. Shared exact numeral spans preserve signs and
fractions; minutes, hours and seconds convert exactly to minutes.

CT, residual concentration and contact time must be nonnegative. Each inverse
needs a strictly positive divisor, so zero concentration does not imply an
arbitrary contact time and zero time does not imply an arbitrary concentration.

The checked independent laws state that an exact inverse time has time kind,
nonnegative CT/time, positive residual and residual times time equal to CT;
an exact inverse concentration has concentration kind, nonnegative CT and
concentration, positive time, and the same balance. The forward law now also
records its nonnegative input guards.

The model assumes the supplied constant residual concentration throughout the
stated contact time. ppm follows the inherited dilute-water mg/L convention;
no solution density is inferred. It neither chooses a regulatory CT target nor decides
whether water is safe to drink. English role/unit binding, exact numeral
lexing and framing remain untrusted.

Twenty new probes join the preceding 46. The D baseline scores 55 right,
1 wrong, 2 false yes and 8 valid withheld in both modes. Final E scores 66/66,
zero wrong, false yes or valid withheld. A target-recognition regression in
“concentration times time” was found during review, repaired, and added as the
last probe before the untouched sample.

Final mapped shipped panels remain 440/440 in both modes. Official panels have
347 cases; water-r3 has no own panel and inherits water's cases in the mapped
total. Fresh seed 20270518 scores 442/442, matching D; untouched seed 20270619
scores 450/450, also matching D. The official scoped harness confirms 347/347
with zero wrong or false yes; its verdict remains INCOMPLETE because full-head
criteria were not run, and water-r3 is explicitly NO PANEL. Fresh sampling uses the original generator pools and templates,
not independent question design. Fresh was measured before the last target-phrase
repair; final shipped, probes and untouched checks followed it.

The final native is 807,592 bytes. Its first measured launch took 166.26 ms;
the next four took 3.18–3.71 ms. Specialist in-binary median replies took
0.069–0.253 ms. Source-to-table checks pass.

Native SHA256: `5feedcfa8fcaeb036c9bfe9359e0847ece0edb8fb1540cee7a2979752cf8c9eb`.
Export SHA256: `10d00ef01d669bfcba2aed95e6b15250c3be26e3a07cc4727492bfa874816a55`.
Actual-input receipt:
`var/materials/native-attempts/20261018T080533Z-9f177d8ba998/compile-inputs.json`.
Final source hashes: `var/E-materials/final-hashes.json`.
The source uses shared numeric hash
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
Checks live under `var/E-materials/`: `final.json`, `fresh.json`,
`untouched.json`, saved-D comparisons, and scoped `parity`.

New dispatch kinds are `ct_time` and `ct_concentration` for water and water-r3,
retaining their existing CT domain context. Root repeated all 66 probes in both
modes and checked both new targets through actual specialist dispatch: CT 60
with residual 2 gives 30 minutes; CT 60 with half an hour gives concentration 2.
Both are decisive answers from the specialist stage alone. The exact command,
replies and binary hash are in `var/E-materials/root-consumer.json`.
Linux/package capture remains separate; no platform pass is claimed here.
