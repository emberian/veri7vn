# W5-15 guards: silence on the head's own replies

Question: the guards kernel (`src/extract/guards/`) was tested only on 114 replies
synthesized to make the guards fire. Does it stay silent where the real head
answered, and does it still fire on the real replies the head withheld?

## Numbers

One run of the shipped head (w540) over the 924 core questions, one process,
sequential, state under `var/guards/head/state`. Each item's status, path and
reply text is recorded in `var/guards/head_core_w540.jsonl`, with a committed
copy at `src/extract/guards/head_core_w540.jsonl` (527 KB). The guards binary was
fed (question, real path, real reply) for every reply the head let through, and
(question, withheld organ path, withheld organ reply) for every reply the head
guarded.

| set (panel = head w538 as recorded; run = head w540 here) | n | before fixes | after fixes |
|---|---|---|---|
| neither guarded: binary firings on the head's own replies | 801 (454 answered) | 0 firings, **2 crashes** (Overflow) | **0 firings, 0 crashes** |
| run guarded, panel did not: binary gives the run's code | 9 | 9/9 | 9/9 |
| both guarded: binary gives the panel's code on the real withheld reply | 108 | **105/108** | **108/108** |
| panel guarded, run did not: binary on the run's own reply | 6 (4 answered) | 4 fire G3_date_premise | 4 fire G3_date_premise |

The real Python guard functions (`replay.layers`, imported read-only) agree
with the binary on every one of the 924 inputs after the fixes: 0 on the 801,
108/108, 9/9, and the same 4 on the last row.

**The 810** (panel path with no `precision_guard`) are the first two rows:
801 + 9. On the 801, 0 firings. The 9 were guarded by the w540 head itself, so
its final reply there is a withheld one, on which no guard can fire. Fed the
organ reply that w540 withheld, the binary gives w540's code all 9 times:
Q3_subject_missing ×3, G3_evidence_misses_question ×5, G3s_qualifier_dropped ×1.

**The 114:** 108 held with the real organ replies, all 20 codes except
G3_date_premise. The other 6 are all of the panel's G3_date_premise items. This
run did not guard them (see Limits): 4 were answered, and the binary fires
G3_date_premise on the head's own answer each time, which is the panel's code;
2 were clarifications, where no guard can fire and the reply the shipped guard
judged is unrecoverable. So 112/114 are confirmed against real text, and 2 are
untestable here.

## Findings, each classified

All three were faults in the recognizer, which is untrusted SML. None was in the
kernel; no theory file changed.

1. **P1_declines_in_words never matched a real reply.** This is a recognizer
   error. w511's `NO_ENTRY` uses the classes `[\"“]` and `[^\"”]{1,120}`, which
   are codepoint classes in Python. The shared `Regex` matches bytes, so a curly
   quote (3 bytes in UTF-8) inside a class matched only its first byte. The real
   replies read `I have no admitted entry for “my passport number”`, while the
   synthesized ones used ASCII quotes. As a result #586 got G2_private_state
   (w534) instead of P1, and #736 and #891 got no guard at all. A second
   divergence sat in the same feature: the recognizer read the first 300
   characters, but w511 matches the whole collapsed reply. The fix is a hand
   scanner, `noEntryGroup`: the regex matches the prefix, and the quotes and the
   1-to-120-codepoint group are scanned by hand.
2. **The same byte-class bug, plus lost capitals, in w510's quoted titles.**
   This is a recognizer error that no core question exercises, because none has
   curly quotes. `quoted` had the same class problem. Its words were also taken
   with `[a-z0-9]+` on the raw text, so "Mona" became "ona". Python uses
   `[A-Za-z0-9]+`. The fix: `quotedSpans` scans by codepoint, and words are
   split on ASCII letters of both cases.
3. **Overflow on a 10-digit scaled number.** This is a recognizer error.
   `parseNum` used MLton's 32-bit `int`, so "26.09759007" (2,609,759,007 once
   scaled) raised Overflow. The binary then printed an error line where a
   verdict should be, on #697 and #847 (units-v3 conversions). `silence.py`'s
   first version counted those lines as "silent"; it now pairs outputs by line
   order and counts errors. The fix: `parseNum` uses `IntInf` and clamps the
   decimal exponent to ±400 (Python's float gives inf or 0 past that).

**The 4 G3_date_premise firings on replies w540 answered are not a guards
fault.** Here the guards are right and this machine's head is wrong. The upstream
drop has no `relstore/names_v1.sqlite3` (the rel-linker scout found this). The
real w532/w534 call `entity_linker_v2.link`, which raises
`unable to open database file`. `premise_years` swallows the exception and
returns None, so the guard can never fire on this machine. I checked this
directly: the real `premise_years` returns None for all 6 questions, and the
probe is `var/guards/silence/probe_premise.py`. The shipped head (the panel)
withheld all 6 with this code, and the binary agrees with the panel.

I found no stratum mistakes and no unmodelled earlier rule firing first: on
every item the binary's verdict equals the real Python chain's, including the
unmodelled w519/w521/w531/w539/w540 layers.

## Limits (what this does not show)

- **The run is not the shipped head.** Without `names_v1` the run differs from
  the panel on 142 of 924 paths (status on 120). All 112 of the panel's
  `specialist_call>specialist:rel-*` answers become clarifications, unverified
  passages, or other routes. So the 801 contain only 62 answered specialist
  replies and no answered rel-* reply. Those are the replies the family-stratum
  guards (G1, G3s, G7, the G3 date premise) judge most. Closing this needs a
  second head run with the scout's rebuilt index (`tools/linker/build_names.py`,
  then `ORACLE7_ROOT` pointing at a root that holds it). That is a decision for
  root.
- **Relation-store inputs are still shims.** S1's `human` comes from replay.py's
  `FakeRS`, which knows only "Buckingham Palace" (one item, #422, uses it).
  G3's premise years come from `FakeEL`, which matches labels against
  `relations_v1`. It links the wrong entity: Mona Lisa gives [2013] and Hamlet
  gives [1940]. The decisions on the 6 items still coincide with the shipped
  ones, because every asked year also lies outside the true dates.
- **Recognizer limits that remain** (now listed in its header): text is collapsed
  and lower-cased byte by byte (Unicode whitespace and non-ASCII letters are not
  folded as Python folds them), and the Unicode minus is read as ASCII.
- The grant was one head run. I stopped a first start after 50 items (by its
  PID): lane A's answerer drops the engine's provenance, and the guards keep the
  withheld organ reply there. I restarted it through `head_record.py`, a thin
  wrapper that changes nothing but keeps `provenance.engine`. The aborted
  prefix matched the restarted run on all 50 items (status, path, text).
- Upstream was only read. `find upstream -newer <request file>` shows no files
  changed, and every sqlite open in the path is `immutable=1`; replay.py's two
  `mode=ro` opens were changed to `immutable=1`.

## Kernel receipt (W6-16's, verified, not redone)

No theory file changed in this lane (`git diff 0118a7f -- src/extract/guards/*.thy ROOT` is empty).
- `var/guards/remote-build.log`: `Finished Veri7vn_Guards (0:03:51 elapsed)`,
  `VERI7VN_GUARDS PASS theorems=49 oracles=0`.
- The marker is the last command of `Guards_Export.thy`, and the theory order
  in ROOT is Vectors, Narrow, Export. `vectors_pin` and `vectors_count` are in
  the scanned list. There is no `by eval`, `sorry`, `oops` or `axiomatization`
  in any guards theory.
- The kernel export is unchanged (`guards.ML` sha256 `221d0ccb…`).
- The binary was rebuilt from that export with the fixed recognizer:
  431,944 bytes, sha256 `ed3bde91…`, and `--selftest` prints `self_test=true`.
- Regenerating `Guards_Vectors.thy` from the new binary gives a byte-identical
  file, so the pinned feature vectors for the 114 did not move.
- On the committed `inputs114.jsonl`, the new binary's output is byte-identical
  to the old one's.
- `tables_check.py`: PASS 48. `replay.py`: reproduced 114/114, with
  `fixtures114.json` unchanged.

`regex.sml` is still the family's own copy (W6-16 left it, and so did this lane).
The P1 and quoted-title bugs are a reason to fix byte classes in the shared
engine, or to give it a codepoint mode. Other families that port Python classes
containing non-ASCII characters will hit the same bug.

## Changed files

- `src/extract/guards/recognizer.sml`: `noEntryGroup` (P1), `quotedSpans` and
  `utf8Chars` (w510 quoted titles), `parseNum` on IntInf; the header's limits
  updated.
- `src/extract/guards/main.sml`: the `--dump-feats` pair printer for IntInf.
- `src/extract/guards/silence.py` (new, UNTRUSTED): the measurement.
- `src/extract/guards/head_record.py` (new, UNTRUSTED): the recording shim.
- `src/extract/guards/head_core_w540.jsonl` (new, data): the recorded replies.
- `src/extract/guards/replay.py`: sqlite opened `immutable=1`.
- `src/extract/guards/gt_import.py`: the state dir now resolves to the repo's
  `var/`; it had resolved to `src/var/`.
- `src/extract/guards/README.md`: a silence paragraph.

## Reproduce

```
cd /Users/ember/dev/o7vn
python3 -c "import json;its=json.load(open('upstream/workbench/data/core_panel.json'))['items'];open('var/guards/head/core924.req.jsonl','w').writelines(json.dumps({'id':j,'q':i['q'],'session':'core-%d'%j},ensure_ascii=False)+'\n' for j,i in enumerate(its))"
PYTHONHASHSEED=0 PYTHONDONTWRITEBYTECODE=1 nohup .venv/bin/python src/extract/guards/head_record.py \
  --state var/guards/head/state < var/guards/head/core924.req.jsonl > var/guards/head/raw.jsonl \
  2> var/guards/head/stderr.log & echo $! > var/guards/head/head.pid      # about 15 minutes
sh src/extract/guards/build.sh
PYTHONDONTWRITEBYTECODE=1 .venv/bin/python -I src/extract/guards/silence.py
```

Consumer: root (the decision on a second head run with `names_v1`); the parked
lane "guards to all 87 codes". This run shows no unmodelled code firing first on
the core panel, so this panel gives no evidence that any unmodelled code
matters. The parked lane "guards behind the live head" is gated on the
`names_v1` gap more than on the guards.
