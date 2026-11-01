# Biology polarity in the compiled consumer — 29 October 2026

The existing extracted kernel already normalizes strand role and direction
correctly. The real English consumer passes the original upstream polarity
counterexample, its reversed spelling, coding-strand equivalents, and frame-2
translation equivalents. An extra typography probe found one reader error:
`3’-TACGGA-5’` uses U+2019 apostrophes, which the reader ignores and then
silently treats as the default 5′→3′ orientation. It answers `UCCGUA` instead
of `AUGCCU`. Root authorized a narrow reader repair. U+2019 was added to the existing
direction character classes, with 16 Unicode transcript/protein regressions
and two contradictory-end regressions. The central native validator compiled
against the existing extracted I ML; the isolated candidate passes below.
No kernel or Isabelle theory changed.

## Actual path and evidence boundary

`src/extract/families.json` points life at `var/life/bin/life`. Its JSON driver
in `src/extract/life/main.sml` calls `Recognizer.recognize`; the `biology`
reader in `gen/part1.sml` (generated into `recognizer.sml`) extracts the
sequence, strand role, direction and frame, then calls exported `Life.bio_input`.
Transcription calls `b_reply (Bio (Op_transcribe false) normalized_sequence)`;
translation calls `b_frame_reply` on that same normalized coding sequence.
Thus the old template branch in `b_answer` is not used by this reader.

The existing statements establish:

- `bio_input True True xs = map comp xs`: a template explicitly written
  3′→5′ becomes its complement in coding orientation.
- `bio_input False True xs = rev xs`: a coding strand written 3′→5′ is reversed.
- `bio_input template (not backwards) (rev xs) = bio_input template backwards xs`:
  swapping the spelling and its declared direction preserves normalization.
- `frame_orientation_invariance` carries that same equality into `b_frame_kernel`.
- `frame_translation_value` says a returned protein is `prot_of` the selected
  suffix, whose length is a multiple of three, contains no stop symbol, and
  has at most `(length xs - (frame - 1)) div 3` amino acids.

Those laws do not prove English interpretation, genetic-code source correctness,
or that any arbitrary input has a meaningful biological model. The current
reader bug is outside their claim.

The pre-fix executable is SHA-256
`ace611e373885b77928a289e70368616d922c396dd97354903f1dd1515401b9a`, identical to
`var/life/i-delivery/life`. Before the reader edit, the source recognizer,
main and biology theory matched I's recorded hashes. The old compile manifest
binds those sources and its frozen generated ML. The new reader compile is
recorded below; no proof rebuild was run.

## Bounded execution

`var/upstream-domain-20261029/check-veri7vn-polarity.py` drives the actual
executable as both `--specialist biology` and whole family. Results are in
`veri7vn-polarity-before.json`; command output is
`veri7vn-polarity-baseline.txt`. The checker exits nonzero on wrong assertions.
The expanded before/after run executes 586 questions per mode. Before:

- Shipped biology panel, scored by its own scorer: dev 15/15, heldout 15/15;
  each split contains 14 right answers and one correct decline. Zero wrong,
  false yes or withheld valid.
- All 256 four-base DNA templates, written in both orientations: 512 correct.
- Four ASCII transcript vectors, four ASCII protein equivalents, four frame-2
  equivalents, two unlabelled defaults and one unrelated output-direction
  control: all 15 correct. Sixteen U+2032/U+2019 transcript/protein variants
  give 12 correct and four wrong; the U+2019 3′→5′ cases fail for both roles.
- Six contradictory endpoint labels: four ASCII/U+2032 cases decline, but two
  U+2019 cases falsely answer. Three invalid frames decline.
- Boundary probes: two incomplete endpoint declarations and one en-dash form
  decline; one U+2019-apostrophe form answers incorrectly as described above.

After the central compile, both modes have zero wrong and zero false yes:
all 512 exhaustive templates, all typed transcript/protein/frame examples,
all 16 Unicode variants, all nine contradictory-label/invalid-frame refusals,
and the original 30 panel rows are correct. Three incomplete/en-dash requests
still decline conservatively. The only seven changed replies per mode are
five corrected U+2019 values (including one separately worded duplicate) and
two contradictory-end refusals. Every other reply's status, kind, value,
response and path is unchanged; per-request timing is excluded.

The complete current biology probe subset, including the 18 new persistent
regressions, passes **51/51 policy assertions** in both modes. Capability
accounting is **47 right, zero wrong, zero false yes, four withheld valid**;
the four unsupported-model refusals are not called implemented capabilities.
Results: `veri7vn-biology-probes.json`.

The grammar-boundary refusals are bounded behavior, not capability successes.
These are specialist/family consumer results, not full Engine or appliance
qualification. The only changed source paths are `gen/part1.sml`, generated `recognizer.sml`,
and `probes.json`. No theorem or packaged appliance changed.
The isolated compile recipe and exact inputs are recorded in
`var/upstream-domain-20261029/life-polarity-compile-request.json`.


## Compiled and promoted consumer

Candidate: `var/upstream-domain-20261029/life-polarity`, SHA-256
`593bcffd918fd917ef2f4b8c58e2e58a2a86335fadf20669372c9c3ab75c08dd`.
Central native compile receipt:
`var/life/native-attempts/20261029T054518Z-e3f18e56e53b/compile-inputs.json`.
Its frozen generated ML is the existing I export, SHA-256
`496f731715f87f17ef4bf7f7e3843601f25555b50d56fb8d8ba2d9dd64fed81a`;
commons, numeric parser and main match the old I inputs byte-for-byte.
The only changed compiler input is the recognizer. The new compile receipt
binds the actual frozen application inputs; it is not a new Isabelle proof.

Post-fix rows and before/after comparison are in
`veri7vn-polarity-after.json` and `veri7vn-polarity-comparison.json` under the
owned scratch directory. `git diff --check` passes. After checking the current
source hashes, unchanged proof closure and exact compiled binary hash, root
atomically promoted the candidate to the registered consumer `var/life/bin/life`.
The previous binary is preserved at
`var/life/promotions/20261029-polarity/previous-life`; the adjacent
`promotion.json` records both hashes and the immutable compile receipt.
Existing packaged appliances have not been rebuilt with this reader change.
No further public comment or upstream PR change was made.
