# The conversation conversion layer (scout)

Oracle7's conversation behaviour lives in three places, and this directory
models the third:

1. **Dialogue state** — runtime E introduced the per-session slot
   (`last_result`, `last_topic`, `last_offset`) with the ACTS routes
   (`act:provenance_replay`, `act:continue_topic`, `act:acknowledge`);
   runtime AM rewrites the slot from the FINAL result at the top of the chain
   ("acts are conversions OVER the last answer; they must not overwrite it");
   runtime AN records the LiminalTransition per turn (the log the referent
   walk reads).
2. **The converse organ** (`organ_converse_v1.py`, wired by fold w494) — a
   FALLBACK organ for turns the chain could not parse: wrappers normalized
   first, then feelings/opinions/jokes/recipes/statements moves, every
   substantive sentence cited. Route tag `organ:converse><move>`.
3. **The rewrite layer** — runtime AO (the M53 meta-fold,
   `oracle_release_runtime_ao.py`): four constructions
   (REFERENT_SUBSTITUTION, ELLIPSIS_COMPLETION, OPENER_ALIAS, REPAIR_ACCEPT)
   that rewrite a turn the chain cannot read into one it can, then
   RE-DISPATCH through the unchanged chain. The released head carries the
   same shape as fold w529 over `chat_context_v2.py` (route tag
   `chat:resolved>...`), grounding on reply receipts where AO grounds on
   opener forms.

## What is here

- `Converse.thy` — the verified kernel: a datatype of readings (one per AO
  guard, produced by the untrusted recognizer), the four constructions, the
  rewrite as a function over dialogue state, `form` (which surface gets
  dispatched: raw / conversion / grounded fallback), `conv_step` (one turn =
  exactly one dispatch through the chain), `note_of` (the conversion note AO
  records on the transition). The chains stay abstract (probe entry below the
  instrument, dispatch entry through it). Theorems:
  - `conv_step_is_one_dispatch`, `probe_state_discarded` — the turn is one
    chain dispatch; the probes' state writes never survive (AO's
    snapshot-then-restore);
  - `warrant_stays_with_route` — an answered reply of the layer IS the
    unchanged chain's reply to the dispatched form ("nothing here answers");
  - `form_cases`, `gate_no_new_answer`, `no_silent_substitution` — a rewrite
    fires only when the probe on the raw turn declined, and the dispatched
    form is always a conversion's output or the documented fallback;
  - `probe_leaves_log_unchanged` — however many probes ran, the turn adds
    exactly ONE transition (AO's first version doubled them and the gate
    rejected it);
  - `note_iff_conversion` — the note exists only for a real conversion and
    its unserved flag is set only for referent substitutions whose specific
    form the chain declined;
  - `conv_step_deterministic` — determinism transfers from the chains.
- `Converse_Export.thy` — export to SML plus an executable self test over
  mock chains that exercises every branch (gate, served predicate, unserved
  fallback, referential NPs, note flags, one-transition log growth).
- `tables_check.py` — asserts `predicate_of`, `referential_nps` and the
  summarize wording against the organ's own literals (parsed from
  `upstream`, read-only).
- `regex.sml` (copied from lane G), `recognizer.sml` (UNTRUSTED port of the
  AO regexes; verbatim including the case-flag quirk below), `main.sml`
  (UNTRUSTED driver: a stateful line protocol over the kernel, for feeding
  recorded dialogues), `build.sh`, `score.py`.

## Known quirk, ported not fixed

In the organ, REPAIR and OPENER are compiled WITHOUT `re.I` while the other
guards carry it: `"I meant volcanoes"` converts but `"I meant Volcanoes"`
does not, and `"Tell me about earthquakes."` — one of the very examples in
the M53 cluster support table — never matches OPENER. The recognizer
reproduces this verbatim (documented in its header) rather than silently
fixing it; the report names it as a defect a real lane should decide about.

## Running

    # 1. build the session remotely (marker in the log):
    /Users/ember/dev/o7vn/tools/dev/remote-build hbox src/extract/converse \
        Veri7vn_Converse --expect 'VERI7VN_CONVERSE PASS'
    # 2. compile the binary:
    sh src/extract/converse/build.sh           # -> var/converse/bin/converse
    # 3. tables:
    python3 src/extract/converse/tables_check.py
    # 4. score on the shipped sealed dialogue recordings:
    python3 src/extract/converse/score.py

The binary speaks one JSON object per line: in
`{"id","session","q","probe_raw","probe_form"?,"result_status"}`, out
`{"id","session","decision","reading","form","construction"?,"unserved"?}`.
The probe/result fields stand for the chain (the layer has no chain of its
own in this prototype); `score.py` derives them from Oracle7's recordings.

## What this is not

This is a scout prototype, not a panel-scored family. The specialists'
panels are single-turn; the conversation measurements are the sealed
dialogue tests (`upstream/research/sealed_history/conv_sealed_v*.json` and
their run recordings), and what can be scored offline is (a) the scoring
rules themselves — `score.py`'s rules check reproduces 236/237 recorded
verdicts and 3/4 published summaries exactly — and (b) the layer's
pass/rewrite decisions against the recorded `chat:*` path tags. Reply-level
parity on dialogues needs the whole chain behind the layer.
