# Oracle7's precision guards, as a verified decline

On the 924-question core panel (`upstream/workbench/data/core_panel.json`), 114
answers end in a withheld reply whose path starts `precision_guard:`. Those
declines are made by 14 Python folds (w510-w540) whose guard functions decide,
from the question, the organ reply's route and text, and - for three guards -
facts from the relation store, that the answer must not be asserted. This
directory is that decision with a proof: one HOL kernel (`Guards.thy`) that
decides from a feature record, an untrusted SML recognizer
(`recognizer.sml`) that computes the features from the raw text, and the
recorded items replayed through both (`replay.py`, `gen_vectors.py`).

What is proved (the session builds green with `VERI7VN_GUARDS PASS ... oracles=0`):

- one theorem per modelled guard that its predicate fires exactly on the
  documented condition (the equations of `firesL`, initially taken from the
  Python sources, with the P2 presence and G6 route repairs described here);
- what a firing means where there is mathematics to state: the date-premise
  guard fires only when the asked year lies outside every recorded date with
  the fold's five-before/two-after tolerance, and a year inside it never
  fires; P2 fires only if neither numeric values nor number words were
  recognized in the reply. Any recognized numeric value, including zero or a
  value equal to a given, prevents P2; the units guard means the reply's value letters are among the
  question's unit letters; the person guard means the store did not resolve
  the offered name to a human;
- the decision takes the first guard that fires in the chain's checking
  order (`decision_iff`), never fires on a reply that was already withheld,
  and every modelled code is one the Python chain can really emit
  (`modelled_codes_in_catalogue`, against the generated catalogue).

What is checked, not proved: the recognizer mirrors the Python regex work
fold by fold (each pattern carries its source in a comment); the ground
truth is the real Python guard functions themselves - `replay.py` imports
them read-only from `upstream/` and reproduces all 114 recorded codes on
synthesized replies - and the compiled binary
(`var/guards/bin/guards`, ~430 KB) reproduces the same 114 codes and fold
layers through the exported kernel. `Guards_Vectors.thy` (generated) pins
the kernel's verdict on the recognizer's exact feature vector for each of
the 114 items, proved by `code_simp` (no oracle) before the export theory,
so the PASS marker's oracle scan covers it. `Guards_Narrow.thy` states the
guards as a `Narrow` fold of the routing cascade (`Veri7vn_Routing.Fold_Cascade`):
a guard only ever turns an answer into a withheld reply.

Honest limits: the model covers the 20 codes that fire on the 114 recorded
items over nine layers (w510-w517, w532-w534); the other 67 catalogue codes
(w519, w521, w531, w539, w540 and the rest of the modelled folds' rules)
are not modelled, so a reply on which one of them fires first would be
decided differently; the relstore facts (the S1 person check, the G3
premise dates) are recognizer-side inputs, not read from the store inside
the kernel; the replies on the recorded items are synthesized minimal
replies (the panel records only question, status and path - the organ reply
the guard judged is not in the drop), so the replay exercises the guards'
decisions, not the organ pipeline that produced those replies.

Silence on real replies (lane W5-15, `silence.py`): one run of the shipped head
w540 over the 924 core questions (`head_record.py`, lane A's answerer plus the
engine's provenance, which carries the organ reply a guard withheld) is recorded
in `head_core_w540.jsonl`. On the 801 items that neither the panel nor this run
guarded, the binary fires 0 times on the head's own replies (the real Python
guards also 0). On the 108 items both guarded, fed the withheld organ reply, it
gives the recorded code 108 times; on the 9 that only this run guarded, 9 of 9.
Limit: this machine's upstream drop lacks `relstore/names_v1.sqlite3`, so the
run's head differs from the shipped one (all 112 rel-* specialist answers fall
silent, and the real G3 date-premise guard cannot link). Answered rel-* replies
are therefore not in the silent set; see `project/lanes/W5-15-guards-silence.md`.

Build: `tools/dev/remote-build <host> src/extract/guards Veri7vn_Guards --expect 'VERI7VN_GUARDS PASS'` (or `check-native` with the same session and marker), then
`/Users/ember/dev/o7vn/.venv/bin/python -I src/extract/guards/tables_check.py`,
`sh src/extract/guards/build.sh`,
`/Users/ember/dev/o7vn/.venv/bin/python -I src/extract/guards/replay.py --emit-inputs`,
`python3 src/extract/guards/gen_vectors.py` (after a binary rebuild, then rebuild the session).

The dispatcher now calls this program as a final check of the actual selected
answer: question, route, reply text and status travel together. It never asks
the guard binary to act as an ordinary question-answering specialist. A guard
can only turn an answered reply into a refusal; an existing refusal is left
unchanged. A guard process error also withholds the answer and reports the
error. Replies disclose the 20-of-87 coverage and whether the caller supplied
human/date facts. Without a store adapter those facts remain unknown, so the
store-dependent checks are incomplete. `tools/dispatch/test_routes.py` checks
the composition boundary, including all 114 recorded synthetic inputs.


Guard predicates remain heuristics about recognized features. G3s checks
whether a qualifier phrase is absent from the response; that theorem does
not establish that the answer is semantically wrong. For example, a correct
painter/author row rendered only as “It is by ...” can lose the subject needed
to make the answer self-contained. The Facts repair retains the actual
matched row's subject in the reply. It does not copy an arbitrary qualifier
from the question or weaken the guard.

G5 now permits a complete recognized equation-solving request to return a
root already present in its equation. It still rejects an answer that simply
repeats the evaluation point in a derivative question. G6 now applies to the symbolic evaluator, whose letters may be mistaken unit names.
A typed word-problem result such as “432000 km” should retain its output unit;
those letters alone do not make it a symbolic expression. The G6 proof passed with 50 theorem checks and zero oracles; its native
consumer passes the existing 114 synthetic inputs and new unit-bearing reply
checks. The update is tracked in `project/lanes/D-runtime-routes.md`. Coverage remains
20 of 87 catalogue codes.

P2 checks number presence only. The former numeric-novelty requirement
rejected valid zero results and computations equal to their givens. Presence
is necessary for these numeric requests, but is not proof that the value is
correct or answers the question. G5 still checks its separate assignment-echo
condition; no route or provenance flag exempts a reply from the guards.
