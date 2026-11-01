# Stores completion, 18 October 2026

Cooking now preserves ordinary question frames and fractional amounts, and checks
whether the displayed amount fits every supplied plausible food and serving.
Unpinned warehouse evaluation can inspect a possible reply without changing a
session or placing an order. The binary accepts explicit locations for its
fetcher, both databases, and writable session file, so packaging can relocate it.

## What was wrong

The old two held-out cooking-v3 errors were not bad arithmetic. “Brain cooked
beef” omitted pan-fried versus simmered. The panel expected 3.33 mg, the chosen
simmered row gave 3.45 mg, and one-decimal display moved that to 3.5, outside the
scorer tolerance. Two-decimal display gives 3.45 and passes a check against both
rows. The jackfruit question omitted canned versus raw and cup preparation;
the panel expected the canned 178 g serving, whereas raw has 151 g and 165 g
cup definitions. Cornmeal and the fresh-seed rye-flour case have the same
serving ambiguity. Their honest result is now a clarifying question.

The generator selects food words by agreement per 100 g, then sometimes asks
about the target food's household weight without checking agreement between
household weights. Therefore some formerly correct answers were lucky choices;
the new rule gives fewer answers on those splits. It does not choose a hidden
panel target or replace a USDA constant to make a score green.

## Changes and assumptions

- All lexical food matches remain alternatives; the previous penalty-near list
  and six-row truncation no longer silently erase them. Preference still picks
  the named source row, but HOL checks the displayed result against alternatives.
- The fetcher reads portion rows for all alternatives in one immutable query.
  For household measures, every matching portion label contributes a value.
  Count queries retain the documented medium/large/whole portion preference.
- All four cooking versions share the repaired polite/content-frame handling.
  Only the first measure-word frame is removed; “total” is preserved in food
  names such as “total can contents”. Proper and mixed integer fractions work.
  Negative and leading-dot amounts decline rather than reading a trailing integer;
  zero denominators withhold with an error. They do not become numeric answers.
- `--fetch FILE --nutrition FILE --site FILE --state FILE` make runtime locations
  explicit. The Python child runs with `-I -B`; SQLite uses escaped immutable URIs.
- `--preview` suppresses warehouse persistence. Family mode defaults to preview;
  explicitly pinned warehouse mode commits unless preview was requested. Every
  taken warehouse reply states `provenance.preview`. Preview reloads committed
  state for each read, and a proposed speculative state is never retained.
  Preview is untrusted driver/fetch behavior, not a new persistence theorem.
- The build script consumes an immutable successful remote receipt, checks that
  its Stores theories/ROOT match current source and its export hash, then compiles
  and replaces the binary atomically. It does not erase or reuse a stale local
  export merely because one exists.

No fetch bit is claimed to prove omission-free data. `nq_complete` and
`ev_complete`, food matching, source identity, row association with a food, and
SQLite results remain external assumptions. In particular, missing or duplicate
`nq_other_portions` groups are not rejected by `rows_ok`; completeness and unique
food-to-portion-group delivery are external premises. `map_of` otherwise takes
one group and the displayed-value theorem only checks the resulting finite list. The new theorem quantifies over
supplied alternatives, not every food in the world. Missing nutrient values
remain missing. The per-item count-size preference remains a limitation.

## Theorem statements and build

New `nutrient_serving_alternatives`:

```
nkernel e = NAnswer g p v pl
w in set (possible_values e)
==> abs(stated_num (nutrient_unit (nq_nutrient e)) v - w)
      <= max (w / 20) (15 / 100)
```

`possible_values` scales each supplied alternative nutrient row by its possible
serving weights in HOL. The same `stated_num` rounding is used by the returned
reply. Existing `nutrient_answer_sound` still proves that the selected answer
is its selected stored per-100-g amount times its selected grams divided by 100,
with coverage and consistency guards. Existing `stated_within_tolerance` now
uses the stronger two-decimal bound of 1/200. Warehouse confirmation/once-only
state-machine theorems are unchanged; they do not prove external file atomicity.

First remote build passed: `VERI7VN_STORES PASS theorems=43 oracles=0`.
Receipt: `var/stores/remote-attempts/20261018T063139Z-3ed0b8a11b05/receipt.json`.
The marker is still the last theory command and the new theorem is in its scan.
MLton then built the current driver and recognizer. Current binary is
`var/stores/bin/stores`, 582,024 bytes on Darwin.

## Scores

Each cell is **right / wrong / false yes / valid withheld**. Right includes
correct refusals of invalid questions. These are standalone measurements using
the shipped scorer, not a claim that all six head-composition criteria passed.

### Shipped panels

| Specialist | Split | n | Shipped organ | Current kernel |
|---|---|---:|---|---|
| cooking | dev | 202 | 200 / 1 / 0 / 1 | 200 / 0 / 0 / 2 |
| cooking | heldout | 218 | 158 / 0 / 0 / 60 | 214 / 0 / 0 / 4 |
| cooking-v2 | dev | 210 | 209 / 0 / 0 / 1 | 207 / 0 / 0 / 3 |
| cooking-v2 | heldout | 210 | 155 / 0 / 0 / 55 | 205 / 0 / 0 / 5 |
| cooking-v3 | dev | 192 | 191 / 1 / 0 / 0 | 190 / 0 / 0 / 2 |
| cooking-v3 | heldout | 228 | 224 / 2 / 0 / 2 | 223 / 0 / 0 / 5 |
| cooking-v3-r2 | dev | 192 | 191 / 1 / 0 / 0 | 190 / 0 / 0 / 2 |
| cooking-v3-r2 | heldout | 228 | 224 / 2 / 0 / 2 | 223 / 0 / 0 / 5 |

### Fresh seed 18101 (development)

| Specialist | Split | n | Shipped organ | Current kernel |
|---|---|---:|---|---|
| cooking | dev | 203 | 203 / 0 / 0 / 0 | 198 / 0 / 0 / 5 |
| cooking | heldout | 217 | 151 / 1 / 0 / 65 | 212 / 0 / 0 / 5 |
| cooking-v2 | dev | 220 | 218 / 1 / 0 / 1 | 215 / 0 / 0 / 5 |
| cooking-v2 | heldout | 200 | 150 / 1 / 0 / 49 | 195 / 0 / 0 / 5 |
| cooking-v3 | dev | 208 | 208 / 0 / 0 / 0 | 206 / 0 / 0 / 2 |
| cooking-v3 | heldout | 212 | 209 / 1 / 0 / 2 | 204 / 0 / 0 / 8 |
| cooking-v3-r2 | dev | 208 | 208 / 0 / 0 / 0 | 206 / 0 / 0 / 2 |
| cooking-v3-r2 | heldout | 212 | 209 / 1 / 0 / 2 | 204 / 0 / 0 / 8 |

### Fresh seed 18102 (untouched until implementation froze)

| Specialist | Split | n | Shipped organ | Current kernel |
|---|---|---:|---|---|
| cooking | dev | 213 | 213 / 0 / 0 / 0 | 212 / 0 / 0 / 1 |
| cooking | heldout | 207 | 146 / 0 / 0 / 61 | 201 / 0 / 0 / 6 |
| cooking-v2 | dev | 203 | 200 / 1 / 0 / 2 | 199 / 0 / 0 / 4 |
| cooking-v2 | heldout | 217 | 172 / 0 / 0 / 45 | 214 / 0 / 0 / 3 |
| cooking-v3 | dev | 224 | 224 / 0 / 0 / 0 | 223 / 0 / 0 / 1 |
| cooking-v3 | heldout | 196 | 192 / 1 / 0 / 3 | 190 / 0 / 0 / 6 |
| cooking-v3-r2 | dev | 224 | 224 / 0 / 0 / 0 | 223 / 0 / 0 / 1 |
| cooking-v3-r2 | heldout | 196 | 192 / 1 / 0 / 3 | 190 / 0 / 0 / 6 |

Both warehouse versions remain **199 / 0 / 0 / 0** on dev and held-out
(193 / 0 / 0 / 0 under the manifest's composed off-site exclusion), with unchanged correctness; the final driver makes the six off-site cases per
split fall through rather than return the old out-of-domain message.

Old-kernel baseline on seed 18101 exactly matched the shipped organs' score in
the table (`var/stores/beyond-before/`). Old shipped-panel baseline is in
`var/stores/parity6/`. The old kernel was not rerun on18102; the organ comparator
was measured directly there after freezing. Fresh seeds reuse the original
generator and its author's food/word assumptions; they are not independent
language or data models.

The 20 committed probes pass; they were authored alongside this implementation,
so are not independent. They cover frames, whole/proper/mixed fractions, zero,
invalid quantities, unknown food, ambiguous portions and explicit gram weights.
The same `verify.py` also checks no new state file in preview, byte-identical
existing state after preview proposal and confirmation, exactly one committed
order, no second order on repeated yes, isolation across sessions, and cooking
answers through family preview. A long-lived preview process is checked against
one live committing process: it sees the newly persisted proposal, does not
save its simulated confirmation, and sees pending state disappear after commit.
A deliberately blocked temporary-file path makes an actual confirmation save
fail; the reply withholds, existing file bytes remain unchanged, and the shim's
cache retains the pending proposal. Corrupt session JSON likewise withholds and
is not replaced. These checks exposed and fixed previously ignored shim errors;
state writes now publish the cache only after successful file replacement.

Final scorer receipt: `var/stores/codex-final-score.json`; full cooking replies:
`var/stores/beyond-final-shipped/`, `beyond-final18101/`, `beyond-final18102/`.
`tables_check.py` passes with the documented intentional removal of “total”
from filler words. `verify.py` passes on the published binary.

Cold first reply (three samples) is about 79 ms cooking,33ms warehouse;
20ms cold-start goal remains unmet because the external Python fetcher and
food-name load are still involved. Steady p50 is 0.41–0.48ms cooking and
1.18–1.37ms warehouse, below one tenth of the respective 150/50 ms budgets.
These timings are observations, not proof that every deployment meets a budget.

## Consumer integration and remaining

Runtime dispatch owns selecting a preview through arbitration/guards, then
committing the exact selected request through a sole committing child sharing
one private state file with the preview child. The producer supports this
serialized design: preview rereads disk every turn, never keeps speculative
state, and the sole committer keeps its own successfully saved state. This does
not authorize sharing the state file with other writers. Runtime packaging
must default speculative Oracle7 Combo wrappers to preview, because Combo can
query candidates and counterfactual sessions before selecting a reply; explicit
committing mode is for a serialized single-owner caller. No automatic retries.
The relocated committing-mode package and the default preview package both
match direct standalone cooking-v3 plus warehouse scores: **811/818 right,
0 wrong, 0 false yes, 7 valid withheld**. The preview receipt reports 55 total
withheld replies because it includes 48 correctly refused invalid questions.
Default preview receipt: `var/C-runtime-package/stores-preview/smoke-selected.json`.
Outside-checkout relocation probes are in
`var/C-runtime-package/stores-current/relocation-probes.json`.

The warehouse panels contain no proposal, confirmation or cancellation commands,
so these unchanged scores do not test effects. The package owner separately
reports seven checks against the actual Oracle7 Combo speculative caller using
`stores-preview-v2`; preview wrappers withhold effect candidates and explicit
serialized-owner mode is separate. Runtime dispatch additionally tests selection
and guards before one commit. Pure reads can update conversation references in
committing mode: “M4 valve count?” followed by “Where is it?” locates bin A5-05;
a fresh session cannot resolve “it”. This is why a retained pinned read needs
its one commit too, while an unpinned preview read remains stateless.

Root caught another integration issue: even a committed pinned call wrote a
session file before deciding whether it owned the question. Persistence now
happens only after `site_taken`, narrowing and off-site acceptance. Additional
checks prove byte-identical existing state and no new file for an unrelated
question, a narrowed-away long item question, and yes without a pending proposal.
The last is off-site per both manifests and now falls through. These are runtime
checks, not a new HOL theorem. Final published Darwin SHA256:
`c719f82f6e975e954dc9c2581b846c3a3d0785b6a505e9a83443ba27e7d64e4a`.
Warehouse final scorer receipt: `var/stores/codex-warehouse-final.json`.
Nutrition implementation and its fresh-seed results were unchanged by this fix.

Changed source: `src/extract/stores/{Stores.thy,Stores_Export.thy,recognizer.sml,
main.sml,fetch.py,build.sh,tables_check.py,README.md,beyond.py,probes.json,verify.py}`
and this report. No upstream files, data, corpora, transient artifacts or heaps
are committed by this lane. Root integrates and commits.

## Final Linux receipt

`var/linux/receipt-stores-hbox-stores-codex-9316b86385.json` records the frozen
runtime source hashes, unchanged checked HOL theory hashes, original successful
HOL receipt, generated SML hash and native binary hash. Compilation used hbox's
managed global build lock, an 8 GiB cap and a 1200-second timeout; no Isabelle
rebuild was needed. The fresh test stage needed its own `var/stores` parent
created before the state tests; checks then resumed without recompiling.

- Linux binary: `var/stores/stores-codex-9316b86385/stores-linux`.
- Linux SHA256: `39b9ca68101d94b936bdc1c3d999182b4d556aa2ed9a61ef1dea61317a3680e3`.
- Generated SML SHA256, identical on both platforms:
  `af3f22dda243de66fd110eb8632420268411c99e4de0cd162339ff0e17383887`.
- All **2,476 shipped-panel replies are identical** between Linux and Darwin
  after removing timing, including status, text, kind, value and other provenance.
- All 20 quantity probes and the preview, live-committer, session, corrupt-read
  and failed-write checks pass on Linux.
- Linux binary size is **1,380,816 bytes**, exceeding the 1 MB goal. Darwin is
  582,024 bytes. Cold-start performance and Linux binary size remain explicit
  efficiency work; neither is reported as completed.

Package ownership has the exact Linux binary and receipt. Packaging rejects old
Linux stores artifacts whose source hashes predate the new CLI and preview API.
