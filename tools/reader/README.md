# Verified relation reader (lane F)

Oracle7's exact relation router answers a question from the Wikidata relation store only when an admitted
question pattern names one property and every linked candidate entity that carries that property carries the
same single value. veri7vn keeps that rule, but the rule itself is now a HOL function with proofs:
`src/isabelle/reader/Relation_Reader.thy`. Everything in this directory is glue around it and is **not
verified**.

| Piece | What it is | Trusted? |
|---|---|---|
| `src/isabelle/reader/Relation_Reader.thy` | `decide` / `decide_admitted`: routing, candidate selection, agreement, refusal reasons, the admitted table | proved |
| `var/reader/bin/decide` | MLton binary: the exported HOL code plus `decide_main.sml` (hand-rolled JSON) | the decision is exported code; the JSON layer is not verified |
| `answerer.py` | answerer-contract front end; question features via `exact_router_v1`'s own regexes | untrusted |
| `link.py` | `entity_linker_v2`'s span rules over the store's `enwiki` index | untrusted, and not the shipped index |
| `fetch.py` | read-only sqlite fetch; says `complete` only for unbounded queries | untrusted |
| `measure.py` | runs the Oracle7 head and this reader over the core-panel relation items, compares | measurement |

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Reader --session-root src/isabelle/reader \
  --expect 'VERI7VN_READER PASS' --timeout 900       # also writes var/reader/gen/Relation_Reader_Code.ML
sh tools/reader/build_decide.sh                       # var/reader/bin/decide
echo '{"id":"x","q":"What is the capital of Uganda?","session":"s"}' | .venv/bin/python tools/reader/answerer.py
```

## Measure

```sh
PYTHONHASHSEED=0 ORACLE7_STATE=var/reader/state .venv/bin/python tools/reader/measure.py head
.venv/bin/python tools/reader/measure.py run
.venv/bin/python tools/reader/measure.py report
```

Results and the theorem statements are in `project/lanes/F-reader.md`.
