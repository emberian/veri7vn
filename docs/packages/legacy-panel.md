# Original panels and LegacyScore

`LegacyPanel.scala` preserves exact `panel.json` bytes, decoded `q/a/valid/kind`, split/index, and inspection metadata without running an organ or scorer. The paint panel has seven development and eleven held-out rows, five marked must-decline. These are sender expectations, not recipient freshness or admission.

**LegacyScore** identifies `upstream/workbench/examples/paint-coverage/scorer.py`, SHA-256 `a723ac247dc906d7610d25db07ce0d7abd35f0bd018e324fe26249d9ffcfbcd5`. Changed/missing scorer code remains unresolved. Its criteria are:

- An answer is asserted exactly when `str(status) == "answered"`; invalid rows pass any non-answer status.
- Numeric gold/response substrings match `-?\d+(?:,\d{3})*(?:\.\d+)?`, remove commas, and convert to Python float. Every gold number needs some response within `0.01 * max(1.0, abs(gold))`. Units, position, and extra wrong numbers are unchecked.
- Without gold numbers, lowercase substring inclusion suffices; `kind` is ignored. Blank gold therefore passes vacuously. Scientific notation is only regex substrings.

The importer requires actual string questions/answers and Boolean validity; missing validity defaults true. Blank/missing gold becomes an unknown native proposal with a repair diagnostic, while originals preserve the old behavior. Unknown is never scored correct.

`v7_test_data name = "[(request, expectation), ...]"` creates source-owned controlled definitions. Expectations distinguish unknown, answer, decline, and undefined; rejected execution is unscored. Actual registered family requests/results and installed matchers supply execution. Equality, tolerance/enclosure, and LegacyScore are distinct policies: rounded `"2.03"` cannot silently become exact equality with `81/40`.

Completion requires actual interpretation with original bytes/ambiguity, retained conversion/scorer provenance, full result-status matching, and governed membership/exposure. Compatibility additionally requires the implemented regex/float/status semantics, not merely passing examples. Composed recognizer/decline/interference and resource-cost checks remain separate from mathematical kernel admission. The typed importer/producer additions are not qualified by the older model11 receipt.
