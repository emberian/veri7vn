# Scout report: code-organ (2026-10-17)

Target: the code organ (`upstream/root/wander-train/code_organ_v3.py`, 488
lines) and its conversational front end `organ_code_chat_v2.py`, wired into
the serving tip by `oracle_release_runtime_w486.py` as the `organ:code` route.

## 1. What I built

`src/extract/codeorgan/` — a HOL model of the organ's typing with the
composition theorem, exported to SML and compiled with MLton into an
executable type checker.

- `Codeorgan.thy`: the type algebra (9 base types; slots exact/num/seq/coll/
  any; `connects` = the organ's `fits(t, want) or t == "any"` pool admission),
  a 31-move transcription of the library (every slot shape, all nine any-slot
  moves), programs as `Arg | Konst | App`, `tys` (candidate output types;
  empty = rejected), `slots_ok` (pool admission, slot by slot), `enum` (the
  composition rule as an inductive predicate), and the theorems:
  - `enum_well_typed`: `enum sig u ⟹ tys sig u ≠ []`
  - `enum_nodes_typed`: the same for every subterm of `u`
  - `tys_app`: a formed application is typed ⟺ the pools admitted its
    children slot by slot
  - rejections as instances (`upper(3)`, `sorted(3)` are never formable)
- `Codeorgan_Export.thy`: export + self test + `VERI7VN_CODEORGAN PASS
  theorems=13 oracles=0` marker (built on hbox and persvati, both PASS).
- `main.sml` (untrusted driver), `build.sh`, `tables_check.py`.

Run:

    tools/dev/remote-build hbox src/extract/codeorgan Veri7vn_Codeorgan --expect 'VERI7VN_CODEORGAN PASS'
    sh src/extract/codeorgan/build.sh
    var/codeorgan/bin/codeorgan --self                       # self_test PASS
    var/codeorgan/bin/codeorgan --check list '(app at (app sorted_desc (arg 0)) (const 1))'
    PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/codeorgan/tables_check.py

## 2. What works, with numbers

- Build: PASS on hbox and persvati, 13 theorems, 0 oracles, no `sorry`.
- Binary: 181 KB, `--self` instant; the checker answers in well under 1 ms.
- Checker vs the shipped organ's own outputs (captured read-only, see §3):
  the organ's `add` program types `OK int,float`; its `second_biggest`
  (`sorted(a0, True)[1]`) types `OK any-set`; its strict-mode `reverses`
  types `OK list,tuple,str`; `upper(3)`, `sorted(3)`, wrong arity, absent
  argument: all REJECT. 8/8 of my checks behave as intended.
- Table parity: `tables_check.py` — 31 moves and 4 groups agree with the
  organ's own `P_`/`GROUP` (the drift guard).
- Core-panel route measurement: **0 of 924 core-panel items are `code` route
  answers.** No path contains `code` at all; and 0/924 questions match the
  chat organ's `CODE_ASK` predicate or its example regex `EX`. The core panel
  is knowledge questions; the code organ serves "write me a function"
  conversation, which never lands there. **A lifted code organ cannot move
  the parity board's core numbers.**
- The organ's own measurement (docstring of w486, frozen, data not in the
  drop): on MBPP TEST posed as a person writes, 174 programs released, 121
  pass the hidden example; graded by the coverage rule, 81 confidently
  asserted (65 right / 16 wrong), 93 tentative (56/37).

## 3. The shipped organ, run read-only on three requests

`CodeChat()` with no library path (nothing read or written; `PYTHONDONTWRITEBYTECODE=1`):

1. "write a function add that adds two numbers: add(2, 3) == 5, add(-1, 1) == 0"
   → `def add(a0, a1): return (a0 + a1)`, confident (cover 1/1), 80 ms.
2. "write a function second_biggest that returns the second largest number:
   second_biggest([5,2,8,3]) == 5, second_biggest([1,9,4]) == 4"
   → `def second_biggest(a0): return sorted(a0, reverse=True)[1]`,
   confident (cover 2/4), 90 ms.
3. "write a function that reverses a string, so 'oracle' becomes 'elcaro'."
   → strict (one prose example; every move must be named by the request)
   `def reverses(a0): return a0[::-1]`, confident, <10 ms.
   (Negative: "…, so shout('hi') becomes 'HI'" — DECLINED: a function call
   inside the prose example fails `literal_eval`, so no assert is built.)

## 4. What I learned that was not obvious

- **The search never uses a move's declared output type.** Terms are typed by
  observation (`tyof(outs[0])` on the example values); `p.out` is only read
  by `learn` to stamp the signature of a STORED program, where it is an
  observed base type. A faithful static model must therefore give moves
  output-type SETS: 9 of the 48 distinct (ins,out) shapes (26 of 146 moves)
  declare a group or `any` output.
- **The pool rule is `fits(t, want) or t == "any"`** — a term of unknown type
  is admitted everywhere. My `connects` captures this exactly.
- **Declared outs are sometimes wrong** (e.g. `fdiv: (num,num)→num` returns
  float on floats; `max: (coll)→any` is really element-type-preserving).
  Harmless in the organ (typing is observational); a HOL transcription should
  derive outs from semantics, not transcribe the column, in the real lane.
- **Strict mode** (one example) is the interesting verified-adjacent
  behaviour: every move must be named by the request's words, and a fit that
  doesn't read all its inputs is rejected as coincidence. This is a
  provenance/evidence rule (`cover ≥ half the request's words` = confident),
  not a typing rule — it lives at the gate, not the kernel.
- **The RECALL path re-executes stored programs** on new examples rather
  than re-deriving; the persistent library
  (`self_loop/code_library_v1.json`, 15 programs) holds exact base-type
  signatures — i.e. STORE entries are exactly the singleton-out, exact-slot
  prims my model predicts.
- **No panel exists for the code organ in the drop.** MBPP itself,
  `code_chat_ab_v1.py` and `code_evidence_v1.py` did not ship; the only
  evidence is the w486 docstring numbers and the stored library. Any parity
  claim for a lifted code organ needs a reconstructed measurement, which is
  not "the specialists' own shipped panels" and so sits outside the
  scoreboard's current definition.
- Proof mechanics: the natural `fun` with recursion under `∀j < length ts`
  defeats the termination prover; factoring the pool check into a pairwise
  `slots_ok` over the zip (also closer to the organ) fixes it and removes
  every `nth`-juggling lemma. Total: 6 remote builds (2 hosts), 3 fix cycles.

## 5. Dependencies for excellence

- **MBPP data + the AB protocol** (`code_chat_ab_v1.py`, `code_evidence_v1.py`)
  are not in the drop. Owner: root decides whether to reconstruct the
  measurement (and accept a non-shipped-panel number) or score the code organ
  only on conversations. Without this decision no lane should start.
- **The value universe.** Verifying the execution CHECK (and the
  observational typing it actually uses) needs a HOL value datatype with the
  organ's `tyof`, ~146 move semantics, and partiality-as-`option`
  (`1/0`-style guards, `_big` bounds, `_oversize`). This is the opus-sized
  core; nothing in the tree covers it yet (S12-discrete is the nearest in
  spirit). The SET/STORE layers then ride on it (STORE signatures = observed
  types).
- **Full move table**: mechanical transcription of the remaining 115 rows
  (data; my 31 rows + groups check pattern via `tables_check.py`).
- **Regexes** (`CODE_ASK`, `EX`, `PROSE`): untrusted SML recognizer, same
  pattern as every lane.

## 6. Proposed follow-up lanes

1. **L-codecheck (S, sonnet)** — finish the typing kernel: all 146 moves
   transcribed with outs derived from the group table, string constants
   added, the checker wired as a post-hoc certificate for the organ's
   rendered programs (feed `(app …)` trees parsed from the organ's `expr`).
   Number: `tables_check.py` green on 146/146; checker agrees with the
   organ's own acceptance/rejection on 100 sampled MBPP-style requests.
2. **L-codevalues (M/L, opus)** — the value universe and the execution
   check: HOL values with `tyof`, a `eval :: prog ⇒ value list ⇒ value
   option` over the full library, and the theorem that a well-typed program
   that evaluates returns a value of a declared type (the organ's
   observational typing, made sound). Number: `eval` exported and agreeing
   with the organ's `_emit` execution results on the 15 stored programs plus
   50 fresh requests.
3. **L-codegate (M, opus)** — the strict/coverage evidence rule as a HOL
   decision (`named`, `reads`, `cover ≥ 1/2`), checked against w486's
   confident/tentative grading on the stored library. Number: 15/15 stored
   programs graded identically to the shipped rule.
4. **Route measurement only (S, sonnet)** — a small addition to lane A's
   harness that reports route distribution per answerer (the 0/924 number
   here was measured by hand; making it a board column costs a day).

## 7. Honest status

- No `sorry`, no oracles (13 theorems, verified on two remote hosts).
- `enum` is the model of the search's construction rule, not the search
  itself; nothing claims the organ enumerates exactly `enum` — the theorem is
  one-directional by design (everything buildable is typed).
- The static checker is conservative where the organ is observational
  (admits a child only when ALL candidate types connect); noted in the README.
- The organ was run strictly read-only (no library path, `-B`); nothing was
  written under `upstream/`.
- Nothing here is scored on a shipped panel, because none exists for this
  organ in the drop.

Feasibility verdict: **the typed-move composition is sonnet-sized** (lane
L-codecheck: data transcription plus one theorem, the pattern exists in this
branch). **The execution check is opus-sized** (L-codevalues: a small
verified interpreter over a 146-function library with Python-flavoured
semantics — bounded, well-understood work, but not mechanical). **Nothing
here is research-sized.** The blocking question is not difficulty but
measurement: without a panel, no code-organ lane can produce a scoreboard
number; root must decide what the number is before any lane starts.
