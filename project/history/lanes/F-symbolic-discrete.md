# Discrete F: literal payloads and signed base conversion

Ready for root integration. This follows committed games packet `71a6ba1`.
Proof, immutable native compile and the scoped actual dispatcher pass. A Linux
package capture for this exact F native is still pending.

## Concrete behavior

The preceding native hashed `a  b` as `a b`, converted a newline inside a JSON
string to a space before judging it valid, and converted `-10` to positive binary
`1010`. It also took the suffix `5` from a requested decimal `1.5`. These are
interpretation failures despite perfect shipped format templates.

The new recognizer keeps literal bytes separate from normalized command text.
Backticks and quotes delimit literal bytes; they do not introduce another JSON
unescaping pass. Empty strings, repeated spaces, tabs, newlines and UTF-8 remain
part of the payload. A raw colon body retains its interior bytes; delimit it when
leading or trailing whitespace matters. Payload words cannot select a different
operation. Multiple payloads and conflicting operations refuse decisively. Complete command
prefixes and suffixes must match the supported grammar; unexplained transformations
such as “followed by b”, “reversed”, or “twice” are not silently ignored.

JSON after a colon includes its own quote/escape syntax; backticks can delimit a
JSON document without a colon. A quoted JSON string without either convention is
ambiguous and refuses. Actual controls inside JSON strings reach the JSON checker
and are invalid; escaped controls and whitespace between tokens remain valid.
The checker is still the existing executable scanner, not a proof of RFC 8259.

Base requests consume a whole signed integer, its source base and its destination
base. Fractional, scientific and compound requests refuse instead of selecting a
numeric suffix. Prefixes must agree with an explicit source base. ASCII signs and
a Unicode mathematical minus are supported; negative zero remains `-0`.

## New mathematical statement

`signed_digits_value neg b cs` maps the existing digit value to an integer,
negating it exactly when `neg` is true. The new `f_signed_base_sound` states:

```
2 ≤ dst ⟹ dst ≤ 16 ⟹
f_kernel (F_signed_base tok src dst neg cs) =
  FBaseSigned tok' src' dst' neg' cs' out ⟹
tok' = tok ∧ src' = src ∧ dst' = dst ∧ neg' = neg ∧ cs' = cs ∧
signed_digits_value neg dst out = signed_digits_value neg src cs ∧
(∃n. signed_digits_value neg src cs = Some n)
```

The actual reply uses the sign returned in that result, prefixing the output
magnitude with `-` when negative. Recognition, UTF-8 transport, and the static
capability declaration remain untrusted. Digests remain executable definitions
with known-answer checks; no new cryptographic correctness claim is made.

## Evidence

- Passed ordinary proof attempt: `var/discrete/remote-attempts/20261018T081801Z-0142350ebd2b/receipt.json`.
  Earlier attempts `401634a38947` and `f2311b1e201f` failed on a reserved
  Isar fact label, before a completed proof/export. The successor uses
  `conversion_value` and `defined_value`; no failed receipt is proof evidence.
- Authored byte/base/JSON development cases use Python hashlib, base64, urllib,
  json and integer formatting as expected-value computations. The language was
  authored with the implementation, so this is not independent-language evidence.
- Frozen development baseline: `var/discrete/f/final-before.json`, 189/339 policy and
  value assertions pass for the preceding E binary. Of 333 meaningful requests,
  189 are answered correctly, 132 wrongly, and 12 withheld. Of 6 ambiguous
  requests, 4 are answered and 2 withheld. The expected refusal assertions do
  not turn meaningful unsupported requests into invalid inputs or capability
  successes. Fractional/scientific conversions and multi-operation requests
  remain withheld-valid if refused. The original smaller counterexample receipt
  remains `var/discrete/f/payload-baseline.json` (29/61 assertions).
- Supplied formats generator seeds 181201 and 181211: preceding E and original
  organ both 372/372, zero wrong/false yes. The new faults are absent from these
  templates. `var/discrete/f/fresh-before/report.json`.
- Actual proof log: `VERI7VN_DISCRETE PASS theorems=90 oracles=0` and
  `Finished Veri7vn_Discrete (0:01:26 elapsed time)`. Export SHA-256
  `54059d956bdeb3a183215847815a0e2f73eab547201e9abaf10963e52f289a23`.
- Shared helper compiler-input manifest:
  `var/discrete/native-attempts/20261018T083121Z-43625db04745/compile-inputs.json`.
  Actual input copies and current source hashes match; proof dependency binding
  passes. Immutable sibling `binary` and published `var/discrete/bin/discrete`
  SHA-256 `7ca5f4319f08f4e57000600b905bb781168590e375a53d2dde3726a6911802e6`.
- Development: **339/339 assertions**, comprising **311 answered-correct,
  0 wrong, 22 withheld-valid**, and **6 ambiguous requests all withheld**.
  `var/discrete/f/composition-after.json`. The 22 unsupported meaningful requests are
  capability limits, not invalid inputs or answered gains.
- The same 339 cases pass through the actual dispatcher both pinned and
  unpinned, `--order front --organs discrete --no-reader --no-document
  --no-routes`. All unsupported refusals retain `dispatch.decisive=true`.
  `var/discrete/f/composition-dispatch-pinned.json` and
  `composition-dispatch-unpinned.json`.
- Untouched post-freeze authored numeric/payload seed 181243: **339/339
  assertions**, again 311 answered-correct, zero wrong, 22 withheld-valid and
  6 ambiguous refusals. `var/discrete/f/final-heldout.json`. This varies data, not
  independently authored language.
- Supplied specialists' own shipped scorers: **508/508**, both specialist and
  family modes, **0 wrong, 0 false yes, 0 withheld-valid**. Games 51+18,
  logic 33+12, formats 93+93, algorithms 42+42, calculus 62+62.
  `var/discrete/f/shipped-final.json`.
- Supplied formats fresh generator seeds 181201/181211 after change:
  **372/372**, equal to E and original. Untouched final seed 181253:
  **186/186**, equal to original. All zero wrong/false yes/withheld-valid.
  `var/discrete/f/fresh-final/report.json`.
- Prior authored games assertions **213/213** and ordinal assertions **168/168**
  remain passing. Those are historical policy/value checks, not all answered
  capability claims. `var/discrete/f/games-regression.json` and
  `ordinal-regression.json`.
- Binary 942,168 bytes; formats median round trip 0.06 ms specialist, 0.05 ms
  family. First observed launch 132.5 ms, subsequent launches 4.0, 3.9, 4.2,
  3.9 ms. No uncached-start speedup claim.
- Capability contract validation and `git diff --check` pass.

Earlier candidate `7d15551d` passed a smaller 324-case set but missed a later
composition probe. Its heldout seeds 181229/181237 are development history now;
only the final seeds above were untouched after the complete-command refinement.
The theorem/export is unchanged across these native-only refinements.

## Changed paths and consumer

`src/extract/discrete/Disc_Formats.thy`, `Discrete_Export.thy`, `recognizer.sml`,
`main.sml`, `capabilities.json`, `formats_probes.py`, `README.md`, and this report.
The consumer is the `dataformats` specialist through the native family and
actual front dispatcher. No shared source or upstream path was edited.

## Per-specialist review boundary

| Exact specialist ID | Behavior examined in this packet |
|---|---|
| `dataformats` | Raw payload preservation, command/data separation, JSON controls and escaping, whole signed integer base conversion. Calendar boundary grammar and full JSON scanner semantics remain unexamined here. |
| `games-v3` | E finite dice/card implementation retained; no new games capability claim. |
| `calculus` | D complete ordinal parsing retained. Independent-variable constants and the analytic definite-integral bridge remain open. |
| `algorithms` | Concrete known suffix/drop defects remain: rational list items and signed graph edges. Next packet must consume the full list/graph and respect shortest-path preconditions. Kruskal certificate completeness remains open. |
| `logic-v3` | Concrete word-operator and turnstile substring defects remain. Truth-table variable budget and complete formula consumption need a separate coherent packet. |

No cold HOL-Analysis attempt was launched. Its draft remains under
`var/discrete/codex/integral-draft/` and is not production proof evidence.
