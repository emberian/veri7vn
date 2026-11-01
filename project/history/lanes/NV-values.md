# Native typed values, 28 October 2026

Owner: native_values. Consumer: the native query predicates, structured-program
compiler, dialogue value storage and explicit answer-agreement policies.

There are **no specialist-panel numbers and no new theorem statements** in this
lane. This is handwritten Rust serving code; it does not replace an extracted
verified kernel. Root integrates and runs the scoped Linux checks.

## Changed files

- `native/oracle-core/src/value.rs`: bounded exact quantities, units, validated
  Gregorian dates, year precision and comparison outcomes.
- `native/oracle-core/tests/value_contract.rs`: eighteen independent executable
  scalar contracts.
- `project/lanes/NV-values.md`: this report.

Root owns module exports, dependency manifests and the lockfile. Dependencies
requested are `num-bigint`, `num-rational` and `num-traits`; serde JSON already
has arbitrary precision enabled in the workspace.

## What the module does

`ExactNumber::parse(text, limits)` accepts decimal/scientific numbers and ratios
of signed integers. Its reduced rational controls equality, order and hashing;
the original admitted exact text is retained for persistence. It never converts
through a binary float. Thus `0.1` equals `1/10`, while
`9007199254740992` and `9007199254740993` differ. Display emits an exact decimal
for terminating expansions and a reduced ratio otherwise.

`TypedValue::from_kqa` and its `from_json` alias accept the source `string`,
`quantity`, `year` and `date` tags. Unknown kinds, booleans masquerading as
numbers, malformed whole literals and invalid dates fail. `parse_literal`
requires an explicit `ValueKind`; date literals can carry a whole year when a
day was not supplied. Source `date` tags require full dates. January 1 is never
silently interpreted as a whole year.

`CalendarYear` uses the full checked signed 64-bit range. All years use
astronomical numbering: 0 means 1 BCE and -1 means 2 BCE.
`from_common_era(Era, year_of_era)` converts historical CE/BCE labels explicitly,
rejecting historical year zero and overflow. Its intermediate calculation uses
128 bits. Gregorian leap validation uses remainders, and date ordering uses
fields rather than multiplying the year into a day count. Even the minimum
signed year formats safely. Signed source dates remain signed astronomical
dates; the parser does not guess another calendar convention.

`TypedValue::compare` returns `Less`, `Equal`, `Greater`, `Unequal`, `Overlap` or
`Incomparable`. A date within a whole-year value overlaps it; comparison never
asserts that the actual day is equal. `compare_at_year` is the explicit year
projection used by year predicates. `ValueComparison::test(ComparisonOp)`
returns `Option<bool>`: missing precision or incompatible values remain unknown.
Strings compare case-insensitively; unequal strings have no admitted order.
The query/compiler consumer validates which operators apply to strings.

Quantities require a clean, nonempty unit label. `UnitPolicy::ExactLabel` is
the default and compares only identical labels. `KnownSi` explicitly enables a
small table of exact linear conversions for length, mass, duration, area and
speed, including `foot = 0.3048 metre` and `kilometre per hour = 5/18 metre per
second`. Unknown units never acquire guessed dimensions or aliases. The policy
has serde names `exact_label` and `known_si`; choosing it belongs to the caller.
Offsets, currencies and context-dependent durations have no conversion table.

`ExactNumber::within_relative` implements the explicit agreement condition
`abs(a-b) <= tolerance * max(abs(a), abs(b), floor)`. It requires
`0 <= tolerance < 1` and `floor >= 0`, and rechecks each original bounded literal
under the caller's limits. No general public arithmetic can repeatedly grow
an unbounded intermediate number.

`TypedValue` serialization uses the KQA object shape. Quantity amounts are
exact source strings, which retain small scientific literals without expanding
them during persistence. Deserialization uses default `ValueLimits`; consumers
with other admission bounds should call `from_kqa` explicitly. Provenance,
including whether a legacy Python float already lost digits, belongs in the
consumer's surrounding record.

## Resource limits

Default per-value limits are 4096 input bytes, 256 numeric digits including
exponent digits, exponent magnitude 1024 and 256 unit bytes. Absolute ceilings
are 16384 bytes, 1024 numeric digits, exponent magnitude 2048 and 1024 unit
bytes. Checked exponent accumulation fails before allocating a power of ten.
Ratios count numerator and denominator digits together. Callers must also
charge row counts, bytes and work across a request; these per-scalar caps do not
replace the runtime budget or host containment.

## Source diagnosis and correction

Root's first central Linux run passed the sixteen initial scalar tests. A
233-case structured-program comparison then exposed seven requests failing
because broad `FindAll` year filters encountered Earth and other geologic
inception years before a narrower concept filter.

Bounded, read-only inspection of the hbox source
`/tank/lanes/o7-native-20261028/data/kb.json` found 56,550 typed year occurrences:
all were ordinary JSON integers, none were decimal spellings or malformed
years, and all fit signed 64 bits. Ten exceeded the initial arbitrary
+/-999999 bound: six attributes and four qualifier values. Attributes included
Earth/Mars -4540000000, Moon -4527000000, Sun -4570000000, bird -66000000 and
Jainism -84000000000. Qualifiers included -4000000 twice and 30000000 twice.
The module now admits the full signed 64-bit range. Two new regressions cover
the real old years, year comparisons, extrema and checked BCE conversion.

A separate read-only source date audit found 91,664 date occurrences: all
matched a full signed date, fit the year representation and passed Gregorian
month/day validation. There were zero malformed or invalid-calendar date
occurrences in that source. The audit used integer arithmetic and did not
modify the data.

Seven other program mismatches involved unequal unit labels. The source Python
forces `no` for every unequal quantity unit, including `!=`. That convention
cannot be used as a physical comparison: the source's Chrono Crusade duration
is 25 minutes, so `!= 2300 seconds` is true after conversion, although its gold
answer is `no`. The Indiana Delaware County source area is 1025 square
kilometres, which exceeds 2300000 square feet, although gold says `no`.
The default native unknown result preserves the missing unit policy; it must
not be changed to false just to match those gold labels. Explicit known-unit
conversion can answer compatible cases, while currencies and academic terms
still need further source premises.

## Checks and remaining limits

The lane ran `rustfmt --edition 2021` successfully. It ran no builds or tests,
as instructed. Root reported sixteen initial central tests passing. The final
eighteen-test version, including the source-year correction, was handed to root
for its next central check; that result is not claimed here.

Tests cover exact distinctions beyond binary float precision; numeric syntax,
zero denominators and resource bounds; JSON booleans and invalid kinds; exact
unit conversions and dimension mismatches; leap centuries, invalid dates and
BCE conventions; precision overlap and explicit year projection; source dates
on January 1; semantic string inequality; exact serialization; and explicit
relative agreement.

The module does not support month-only dates, uncertainty intervals beyond
year/day precision, arbitrary unit algebra, offset conversion, exchange rates
or a historical-calendar inference. It does not restore digits already lost
before import. Its source compatibility and runtime checks are not proofs of
the KB's real-world claims.
