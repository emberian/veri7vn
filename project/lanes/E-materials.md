# Completing CT arithmetic, 18 October 2026

Status: corrective native passed; source frozen for runtime capture and
root integration. Initial E was integrated as b4a0699; its native is delivery-held. Hbox attempt `20261018T075206Z-27ab84a25c41` passed with
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


## Dimensional correction after initial integration

The initial E reader accepted “CT 60 mg/L and contact time 30 min” as if CT
had units mg-min/L and returned concentration 2. That candidate is rejected;
its actual input snapshot and binary remain preserved. Evidence is
`var/E-materials/rejected-ct-unit-candidate.json`. The initial measurements and
hash above describe that rejected candidate, not the delivery selection.

The correction binds units to dimensions before assigning quantity roles.
Explicit CT, residual and time labels must agree with the supplied units;
compound units cannot be truncated to mg/L or minutes. Bare labelled CT retains
the established mg-min/L convention. Explicit requested targets also take
priority over trailing input labels. This changes only the untrusted reader,
not the proven request algebra or the 74-root export.

Thirteen new dimensional/role probes give 79/79 right in both modes, with zero
wrong, false yes or valid withheld. The invalid cases have contradictory
physical dimensions; they are not unsupported valid conversions relabelled
as successes. Auditing preceding material probe labels found malformed,
contradictory, missing or physically impossible input cases, not unsupported
unit requests. Final shipped mapped panels remain 440/440; official 347/347
remain complete at the panel level (water-r3 still NO PANEL; overall scoped
harness INCOMPLETE). Untouched seed 20270919 gives 448/448. Earlier fresh seed
20270518 remains a pre-correction measurement; it is not claimed as final.

Corrected native SHA256:
`41eb7ac26ff0d0e3c922616ec016608f7e6e888c16a23158e19a031b927f3a41`.
It is 825,032 bytes; five measured launches take 3.26–4.25 ms.
Actual-input receipt:
`var/materials/native-attempts/20261018T082033Z-f6ee7b94dbf9/compile-inputs.json`.
Proof/export remain the passed 20261018T075206Z-27ab84a25c41 attempt listed above.
Final source hashes: `var/E-materials/corrective-final-hashes.json`.
Final checks: `corrective-final.json`, `corrective-untouched.json`,
`corrective-probes.json`, and `corrective-parity` under `var/E-materials/`.
Consumer composition and Linux capture must select this corrective native.
