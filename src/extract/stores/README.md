# The store-backed family, end to end

This folder carries six shipped Oracle7 specialists as one program. They are the only ones among the
non-relation specialists that read a database and, for the warehouse, remember a conversation:

- `cooking`, `cooking-v2`, `cooking-v3`, `cooking-v3-r2` answer "how much protein is in 2 oz of raw chayote?"
  from the USDA nutrition table (`upstream/root/specialists/cooking/nutrition_v1.sqlite3`, about 7 MB). The
  four versions read the same table; they differ in how they strip the polite frame of a question ("Could you
  tell me the calcium content of ...") and in which questions they leave to the core.
- `warehouse` and `warehouse-r2` answer questions about one site: stock counts, bins, run-out days, what is low,
  sensor readings and their age, and reorders that wait for a yes (`site_fresh.sqlite3`).

## How it is split

| Part | File | Trusted? |
|---|---|---|
| The decision over fetched rows: which nutrient row, whether the readings in play disagree, which household portion, grams, the value and its rounding; stock, run-out, freshness, the low list, the session state machine (propose, confirm, cancel); the reply text | `Stores.thy` | HOL, proved; exported to SML |
| Export, self test, oracle check | `Stores_Export.thy` | the build fails if a listed theorem uses an oracle or the self test fails |
| Tables: nutrient keys and units, gram factors, cup/tbsp/tsp names, sensor kinds, unit suffixes | `Stores.thy` | HOL constants; `tables_check.py` compares them with the organs and the store |
| Reading the question: the organs' patterns, the USDA food match (every question word present, then the organ's penalties), pronouns, follow-ups and ellipsis against the session | `recognizer.sml`, `regex.sml` | **untrusted**, hand-ported; every pattern is checked verbatim against the organ by `tables_check.py` |
| Store access and the session file | `fetch.py` | **untrusted**; opens the stores read-only, says `complete` only for queries without a limit |
| JSON, the child process, timestamps | `json.sml`, `main.sml` | **untrusted** |
| Isabelle code generator, MLton, Python's sqlite3 | toolchain | trusted |

The binary `var/stores/bin/stores` speaks the [answerer contract](../../../docs/contracts/answerer.md). It
starts `fetch.py` as a child process and asks it for rows over a pipe, one JSON line each way; the stores are
never copied and never written. The kernel declines (`incomplete`) whenever the shim did not claim to have
returned every row it was asked for.

What is proved is stated in the [lane handoff](../../../project/lanes/O18-cooking-warehouse.md): for cooking,
the answer is the stored amount per 100 g times the grams over 100, the grams come from the asked mass or from a
stored portion row of the asked measure (the shortest such label) or the organ's per-item preference, any two
readings in play differ by at most 15% of the largest when it answers, every decline is exactly its condition,
and the stated number is within the scorer's tolerance of the value. For the site, an order is placed only on a
yes to the pending proposal of the same session, for exactly the proposed quantity and item, and only once; a
reorder only proposes and is idempotent; a sensor value is reported only from the latest reading and only when
it is no older than the freshness bound; stock is the sum of the stock events; run-out days are the whole days
the count lasts at the last seven days' rate; the low list is exactly the items at or below their reorder level.

Values are exact fractions. The organs compute with binary floats: on two store items (none on the panels) the
organ's run-out days are one less than the exact quotient (135 units at 9 a week: 105 days exactly, 104 in the
organ). Printed numbers round an exact tie up; the organs round the float.

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Stores --session-root src/extract/stores \
  --expect 'VERI7VN_STORES PASS' --timeout 900
python3 src/extract/stores/tables_check.py
sh src/extract/stores/build.sh
echo '{"id": "1", "q": "How much protein is in 2 oz of raw chayote?", "session": "s"}' \
  | var/stores/bin/stores --specialist cooking-v3
python3 src/extract/stores/score.py
```

The binary is not committed; it lives under `var/stores/bin/`.

## Current result (2026-10-17)

Scored with `tools/parity/harness.py` (each specialist's own panel and scorer), right / wrong / false yes:

| Specialist | dev | held-out | shipped held-out |
|---|---|---|---|
| cooking | 200 / 1 / 0 of 202 | 158 / 0 / 0 of 218 | 158 of 218 |
| cooking-v2 | 209 / 0 / 0 of 210 | 155 / 0 / 0 of 210 | 155 of 210 |
| cooking-v3 | 191 / 1 / 0 of 192 | 224 / 2 / 0 of 228 | 224 of 228 |
| cooking-v3-r2 | 191 / 1 / 0 of 192 | 224 / 2 / 0 of 228 | none shipped (same panel as cooking-v3) |
| warehouse | 199 / 0 / 0 (193 of 193 without `off_site`) | 199 / 0 / 0 (193 of 193) | 193 of 193 |
| warehouse-r2 | 199 / 0 / 0 (193 of 193) | 199 / 0 / 0 (193 of 193) | 193 of 193 |

Every reply makes the same decision as the shipped organ on the same question (answered or not, same kind, same
value within the scorer's tolerance): 0 disagreements on all 2,476 panel items. The misses are the organs' own
(v1's question frame leaking into the food name, v2's stripped question word, four USDA entries without the value
or a portion that differs from the panel's). The reply text is the organ's byte for byte except 87 cooking replies
whose value is an exact decimal tie (150 g at 1.3 g per 100 g is 1.95 g): the kernel rounds the tie up, the organ
rounds the binary float, which here lies just below. The binary is 564 KB; the first question takes 120 to 145 ms
for cooking (starting the shim and reading the 7,793 food names) and about 55 ms for the warehouse; after that the
median is 0.5 to 0.8 ms per cooking question (budget 150 ms) and 1.3 ms per warehouse question (budget 50 ms).
