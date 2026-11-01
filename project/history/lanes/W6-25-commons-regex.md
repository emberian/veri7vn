# W6-25 commons-regex: the shared regex engine reads UTF-8

## What was wrong

`src/extract/commons/commons.sml`'s `Regex` matched byte by byte. A curly quote
is three bytes, so `[“”]` was a class of six bytes: it matched one byte of a
quote, and `[^"”]` could consume half a character. A literal `“` matched, but a
quantifier after it applied to its last byte only, and `.` consumed one byte.
Python's `re` works on codepoints; the recognizers copy Python patterns. Lane
W5-15 found two live failures (w511 `NO_ENTRY`, w510 quoted titles) and worked
around them with hand scanners in the guards recognizer.

## What changed (only `commons.sml`, plus the test files)

- Text and pattern are decoded as UTF-8 codepoints. Invalid sequences (lone
  continuation bytes, truncated, overlong, surrogates, above U+10FFFF) decode as
  one character per byte that equals no codepoint and lies in no range, so bad
  input behaves like the old byte engine.
- `Lit` and class members are codepoints. A multi-byte literal matches as a
  unit and takes a quantifier as a unit. `[...]` takes multi-byte members and
  ranges (`[à-ÿ]`). A negated class and `.` consume one whole character.
- `search`, `findall` and lookbehind only start on character boundaries.
  `start`, `stop` and group positions are still byte offsets.
- Case folding stays ASCII-only, in all three modes (`compile`, `compileI`,
  `compileCS`): only A-Z and a-z change case. `É` does not match `é`. Documented
  in the file header. `\w \d \s \b` stay ASCII-only too: every non-ASCII
  character is non-word, non-digit, non-space (Python's are Unicode-aware; that
  difference is unchanged by this lane).
- No family recognizer was edited. The guards hand scanners of W5-15 are not
  needed any more but were left in place (guards still has its own `regex.sml`).

## Tests

`sh src/extract/quantity/regex_test.sh` prints `REGEX_TEST PASS` (45 checks: the
14 old ones and 31 new ones for curly quotes, en/em dashes, `°`, `×`, `÷`,
literals and classes, positive and negated, `.`, quantifiers, alternation,
backreference, lookbehind, byte offsets, findall, invalid bytes, ASCII-only
folding). The same test file run against the previous `commons.sml` fails 18 of
the new checks, so the tests do discriminate. The test script now compiles with
`allowExtendedTextConsts` so the test source can hold UTF-8 text.

## Nothing changed where it should not

Binaries for quantity, acoustics and facts were built with MLton from the
existing generated kernels (`var/<slug>/build/*_generated.sml`; no theory was
touched, so no Isabelle build) and the working-tree recognizers, once with the
previous `commons.sml` (HEAD) and once with the new one. Both were scored with
`tools/parity/harness.py --split both` on every specialist of the family, and
the per-item records compared modulo timing fields:

| family | replies compared | changed |
|---|---|---|
| quantity (densities, fluids, fuels, springs, units, units-v3) | 641 | 0 |
| acoustics | 139 | 0 |
| facts (22 specialists) | 428 | 0 |

The three counts equal those of W5-12's table. Scratch (binaries, parity
output) is under `var/w6-25/`.

## What remains

Families with their own `regex.sml` (earth, finance, guards) do not get the fix
until they move to commons. Other families' binaries were not rebuilt or
re-scored here; they will pick the change up at their next build and should be
re-scored then. A family whose pattern leaned on `.` or a negated class eating
single bytes of non-ASCII text could change; the three families checked did not.
