# Lane B: routing cascade (handoff, 2026-10-16)

## What exists

| Path | Content |
|---|---|
| `audit/folds/extract.py` | Reads the fold sources with `ast` (never imports them), computes Python's C3 method resolution order for `OracleReleaseRuntimeW540` statically, classifies each class, writes `folds.json`. `--check` verifies the file is current. |
| `audit/folds/folds.json` | 361 records, tip first. Fields asked for (`index`, `module`, `class`, `base_module`, `kind`, `calls_super_first`, `guards`, `reads`, `rewrites_text`, `touches_state`, `doc_head`, `lines`, `file`) plus `hol`, `inner_calls`, `inner_text`, `skips`, `reenters`, `own_statuses_before/after`, `may_answer_on_own`, `same_question`, `overrides`, `module_patches`, `template`, `shadowed_by`, `sha256`, `bases`. |
| `audit/folds/README.md` | Counts, kinds in plain words, ten guard shapes, anomalies. |
| `audit/folds/w540_vectors.py` | Lifts w540's constants and three guard functions out of its source with `ast` (the 360-class parent chain is never loaded), runs them on 40 cases, writes `src/isabelle/routing/W540_Vectors.thy`. `--check` verifies it is current. |
| `src/isabelle/routing/ROOT` | Session `Veri7vn_Routing = HOL`, `options [document = false, threads = 2]`, imports `Main` only. |
| `src/isabelle/routing/Fold_Cascade.thy` | The cascade: `status`, `reply`, `fold`, `step`, `cascade`, and the theorems below. |
| `src/isabelle/routing/W540_Instance.thy` | w540's three guards as HOL string functions (no regex engine), the fold as three `Narrow` layers, the docstring examples. |
| `src/isabelle/routing/W540_Vectors.thy` | Generated: 40 lemmas, HOL guard verdict = shipped Python verdict, each `by code_simp`. |
| `src/isabelle/routing/Routing_Test.thy` | Checks every reported theorem depends on no oracle (`Thm_Deps.all_oracles` empty), prints each statement, prints `VERI7VN_ROUTING PASS`. |

No `sorry`, `oops`, `skip_proof`, axioms, `eval` or `normalization` anywhere in the session; concrete
checks use `code_simp` (kernel-checked rewriting), so no code-generator oracle is involved.

## Check

`python3 tools/dev/check-native --session Veri7vn_Routing --session-root src/isabelle/routing --expect 'VERI7VN_ROUTING PASS' --timeout 900`

- status `passed`, `inputs_stable: true`, marker `VERI7VN_ROUTING PASS` from `Veri7vn_Routing`; the log also
  has `VERI7VN_ROUTING_VECTORS 40 PASS` and one `VERI7VN_ROUTING_THM <name>: <statement>` line per theorem.
- Receipt: `var/native-scaffold/sessions/2e2ea5b2605525be/attempts/b5e669ebd0234a6ab4ea9b275eaa16f1/receipt.json`
- Cost: 90 s for the whole invocation, one job, two threads, bundled HOL heap, no warnings. Theory times
  from the first passing run (before `replace_cuts_below_reach` was added): Fold_Cascade 22 s, W540_Instance 27 s, W540_Vectors 212 s cumulated
  across threads (the 40 `code_simp` runs dominate), Routing_Test under 1 s.
- `python3 audit/folds/extract.py --check` and `python3 audit/folds/w540_vectors.py --check`: up to date.

## The catalogue in numbers

The brief said 346 modules and about 29.7k lines. Measured: **361 classes in 360 files, 31,296 lines**.
329 define `chat`. Following first parents by hand gives 353; the eight extra come from the multiple
inheritance in `w31`, `w46`, `w66` (pulls in `w60`, `w45`, `w44`, `w42`, `w41` and three `wander-train`
sibling classes, which land between `w1` and `ao`). The manifest's 317 `chain_tip_to_base` entries are all
on the order; the 5 `orphaned_admitted` are on none of it.

| Kind | Count | HOL |
|---|---|---|
| `pre_route` | 253 | `PreRoute` (2 wrapped in `Skip 1`) |
| `post_replace` | 40 | `Post` |
| `hook` | 21 | `Pass` |
| `post_redispatch` | 11 | `Redispatch` (`s` is `Skip 3`, `r` is `Skip 2`) |
| `narrow` | 7 | `Narrow` |
| `rewrite` | 7 | `Rewrite` (sibling v3 `Skip 2`, v2 `Skip 1`) |
| `state_only` | 5 | `Pass` |
| `empty` | 4 | `Pass` |
| `join` | 3 | `Pass` |
| `module_patch` | 3 | `Pass` |
| `transparent` | 2 | `Pass` |
| `helper` | 1 | `Pass` |
| `pre_and_post` | 1 | `PreRoute` then `Post` |
| `probe_rewrite` | 1 | `ProbeRewrite 1` (`ao`) |
| `replace` | 1 | `Replace` (`b`) |
| `base` | 1 | `Replace` |

`narrow` = calls below first and every reply it writes has a literal `"withheld"` status: `w540`, `w532`,
`w511`, `w510`, `w458`, `w456`, `w422` (the return statements of each were read by hand after
classification). Six more
(`w514`, `w513`, `w432`, `w430`, `w428`, `w420`) write only `withheld` themselves but also return a helper's
reply the extractor cannot type; they stay `post_replace`. 312 folds may answer on their own.

## Definitions the theorems use (verbatim)

```
datatype status = Answered | Withheld | Clarification
record reply = status :: status   path :: string   response :: string
definition withhold :: "string \<Rightarrow> string \<Rightarrow> reply \<Rightarrow> reply" where
  "withhold name msg r = r\<lparr>status := Withheld, path := name @ ''>'' @ path r, response := msg\<rparr>"

datatype fold =
    Narrow string "string \<Rightarrow> reply \<Rightarrow> bool" "reply \<Rightarrow> string"
  | PreRoute "string \<Rightarrow> reply option"
  | Post "string \<Rightarrow> reply \<Rightarrow> reply option"
  | Rewrite "string \<Rightarrow> string option"
  | Redispatch "(string \<Rightarrow> reply) \<Rightarrow> string \<Rightarrow> reply \<Rightarrow> reply option"
  | ProbeRewrite nat "string \<Rightarrow> string option"
  | Replace "string \<Rightarrow> reply"
  | Pass
  | Skip nat fold

fun step :: "fold \<Rightarrow> (nat \<Rightarrow> string \<Rightarrow> reply) \<Rightarrow> string \<Rightarrow> reply" where
  "step (Narrow name g msg) inner t =
     (let r = inner 0 t in if g t r then withhold name (msg r) r else r)"
| "step (PreRoute h) inner t = (case h t of Some r \<Rightarrow> r | None \<Rightarrow> inner 0 t)"
| "step (Post h) inner t = (let r = inner 0 t in case h t r of Some r' \<Rightarrow> r' | None \<Rightarrow> r)"
| "step (Rewrite rw) inner t = (case rw t of Some t' \<Rightarrow> inner 0 t' | None \<Rightarrow> inner 0 t)"
| "step (Redispatch h) inner t =
     (let r = inner 0 t in case h (inner 0) t r of Some r' \<Rightarrow> r' | None \<Rightarrow> r)"
| "step (ProbeRewrite k cv) inner t =
     (if status (inner k t) = Answered then inner 0 t
      else (case cv t of Some t' \<Rightarrow> inner 0 t' | None \<Rightarrow> inner 0 t))"
| "step (Replace g) inner t = g t"
| "step Pass inner t = inner 0 t"
| "step (Skip k f) inner t = step f (\<lambda>n. inner (n + k)) t"
```

`inner n` is the cascade with the next `n` folds passed over. `cascade fs base` is computed bottom-up
(`stack`, `cascade_def`), and `cascade_Cons` proves
`cascade (f # fs) base = step f (\<lambda>n. cascade (drop n fs) base)`, `cascade [] base = base`.
Predicates: `is_narrow` (constructor is `Narrow`); `non_adding` (`Narrow`, `Pass`, a `PreRoute` whose own
replies are never `Answered`, a `Post` that only answers where the reply below answered, `Skip` of these);
`attributing` (`Narrow`, `PreRoute`, `Rewrite`, `ProbeRewrite`, `Pass`, `Skip` of these); `core` strips
`Skip`; `same_question` (`Narrow`, `PreRoute`, `Post`, `Pass`); `local_fold` (not `Skip`, not
`ProbeRewrite`); `reach (Skip k f) = k + reach f`, `reach (ProbeRewrite k _) = k`, else 0.

## Theorem statements (verbatim from the theories)

```
theorem narrow_never_adds:
  assumes "\<forall>f \<in> set fs. is_narrow f"
    and "status (cascade fs base t) = Answered"
  shows "status (base t) = Answered"

theorem narrow_preserves_answer_text:
  assumes "\<forall>f \<in> set fs. is_narrow f"
    and "status (cascade fs base t) = Answered"
  shows "cascade fs base t = base t"

theorem narrow_withheld_path:
  assumes "\<forall>f \<in> set fs. is_narrow f"
    and "cascade fs base t \<noteq> base t"
  shows "\<exists>name g msg p. Narrow name g msg \<in> set fs
           \<and> status (cascade fs base t) = Withheld
           \<and> path (cascade fs base t) = name @ ''>'' @ p"

theorem non_adding_never_adds:
  assumes "\<forall>f \<in> set fs. non_adding f"
    and "status (cascade fs base t) = Answered"
  shows "status (base t) = Answered"

theorem answers_are_attributed:
  assumes "\<forall>f \<in> set fs. attributing f"
    and "status (cascade fs base t) = Answered"
  shows "(\<exists>t'. cascade fs base t = base t')
       \<or> (\<exists>h t'. PreRoute h \<in> core ` set fs \<and> h t' = Some (cascade fs base t))"

theorem preroute_shadowing:
  "h t = Some r \<Longrightarrow> cascade (PreRoute h # fs) base t = r"

theorem preroute_shadowing_below:
  assumes "\<forall>f \<in> set xs. same_question f"
    and "h t = Some r"
  shows "cascade (xs @ PreRoute h # ys) base t = cascade (xs @ PreRoute h # ys') base' t"

theorem preroute_dead_copy:
  assumes "\<forall>f \<in> set ys. same_question f"
    and "\<And>t. h' t \<noteq> None \<Longrightarrow> h t \<noteq> None"
  shows "cascade (PreRoute h # ys @ PreRoute h' # zs) base = cascade (PreRoute h # ys @ zs) base"

theorem skip_hides:
  assumes "length xs = k" and "length xs' = k"
  shows "cascade (Skip k f # xs @ ys) base = cascade (Skip k f # xs' @ ys) base"

theorem replace_cuts_below:
  assumes "\<forall>f \<in> set xs. local_fold f"
  shows "cascade (xs @ Replace g # ys) base = cascade (xs @ Replace g # ys') base'"

theorem replace_cuts_below_reach:
  assumes "\<forall>i < length xs. i + reach (xs ! i) < length xs"
  shows "cascade (xs @ Replace g # ys) base = cascade (xs @ Replace g # ys') base'"

lemma post_can_add:
  "status (cascade [Post (\<lambda>t r. Some answer)] (\<lambda>t. declined) ''q'') = Answered
   \<and> status ((\<lambda>t. declined) ''q'') = Withheld"

lemma rewrite_can_add:
  "status (cascade [Rewrite (\<lambda>t. Some ''r'')] (\<lambda>t. if t = ''r'' then answer else declined) ''q'') = Answered
   \<and> status ((\<lambda>t. if t = ''r'' then answer else declined) ''q'') = Withheld"
```

W540 instance (`w540 = [Narrow g3_name g3_guard (\<lambda>_. g3_msg), Narrow n2_name n2_guard (\<lambda>_. n2_msg),
Narrow d1_name d1_guard (\<lambda>_. d1_msg)]`, names `precision_guard:D1_question_direction` etc., messages the
shipped strings):

```
theorem w540_python_order:
  "cascade w540 base t =
     (let r = base t in
      if d1_guard t r then withhold d1_name d1_msg r
      else if n2_guard t r then withhold n2_name n2_msg r
      else if g3_guard t r then withhold g3_name g3_msg r
      else r)"

corollary w540_never_adds:
  "status (cascade w540 base t) = Answered \<Longrightarrow> status (base t) = Answered"
  and w540_answer_unchanged:
  "status (cascade w540 base t) = Answered \<Longrightarrow> cascade w540 base t = base t"

theorem w540_orbit:
  "cascade w540 (\<lambda>_. orbit_reply) orbit_q = withhold d1_name d1_msg orbit_reply
   \<and> path (cascade w540 (\<lambda>_. orbit_reply) orbit_q)
       = ''precision_guard:D1_question_direction>general_reader:wikidata:P397:fwd>relstore''"
theorem w540_founder: "cascade w540 (\<lambda>_. founder_reply) founder_q = founder_reply"
theorem w540_cube:
  "cascade w540 (\<lambda>_. cube_zero) cube_q = withhold n2_name n2_msg cube_zero
   \<and> status (cascade w540 (\<lambda>_. cube_zero) cube_q) = Withheld"
theorem w540_cube_five: "cascade w540 (\<lambda>_. cube_five) cube_q = cube_five"
theorem w540_singer:
  "cascade w540 (\<lambda>_. singer_reply) singer_q = withhold g3_name g3_msg singer_reply
   \<and> response (cascade w540 (\<lambda>_. singer_reply) singer_q) = g3_msg"
theorem w540_name: "cascade w540 (\<lambda>_. name_reply) name_q = name_reply"
```

Questions: `orbit_q` "Which planet orbits the Moon?" (reply "Earth", path P397 forward); `founder_q`
"Which person founded Microsoft?" (P112, an agent relation); `cube_q` "A 5 kg cube has a density of 0 kg/m3.
What is its volume?" (math path, response "I read 0; then evaluate ..." vs "I read 5; ..."); `singer_q`
"Who is my favourite singer?" (converse path, "Here's what my sources say about singer ..."); `name_q`
"What is my name?" ("You told me your name is Ben."). Plus `w540_vector_00`..`39`: for each case,
`d1_guard q r = <py> \<and> n2_guard q r = <py> \<and> g3_guard q r = <py>` with `<py>` the shipped Python verdict;
cases cover case folding, auxiliaries, `\b` after digits/underscore/punctuation, hyphenated nouns, wrong path
prefix, upper-case source, signed and fractional and `00` read-backs, `;` spacing, `evaluate_`, leading
whitespace before "Here's", newline between question word and "my", "mycity".

## Which real folds each theorem covers

- `narrow_never_adds`, `narrow_preserves_answer_text`, `narrow_withheld_path`: each of the 7 `narrow` folds,
  taken against whatever lies below it (the theorem's `base`). They are not adjacent in the chain, and 312
  folds may answer on their own, so **no theorem says the whole chain never adds an answer**; it doesn't.
  `post_can_add` and `rewrite_can_add` show the hypotheses cannot be dropped. Applied to w540 in full via
  `w540_python_order` (three layers equal the shipped `if/elif/elif`). The *path* shape in
  `narrow_withheld_path` (`name>inner path`) is w540's. The other six write other shapes:
  `precision_guard:RULE|inner path` (`w532`, `w511`, `w510`), `inner path|compose:empty` (`w456`),
  `inner path|math:out_of_fragment|vessel:receipt` (`w458`), and a fixed path that drops the inner one
  (`w422`). Their status and never-adds claims hold; their paths would need `Narrow` to take a path
  function instead of a name.
- `non_adding_never_adds`: additionally the `Pass` kinds and the 3 `post_replace` folds whose own replies
  only inherit or clarify (`w242`, `w191`, `u`) if their helpers behave as read. No real `pre_route` qualifies:
  all 253 can write `answered` (or a reply the extractor cannot type).
- `answers_are_attributed`: contiguous stretches built from `narrow`, `pre_route`, `rewrite`,
  `probe_rewrite` and `Pass` kinds (longest: 55 folds from index 217). Not the whole chain: `Post`,
  `Redispatch` and `Replace` folds write replies of their own.
- `preroute_shadowing_below`, `preroute_dead_copy`: the generated self-report pre-routes. The catalogue's
  `shadowed_by` marks **121 dead copies** (75 of `w411`'s template, 46 of `w409`'s): same chat shape, same
  regexes, every own reply returned directly under its guard's `if`, only `same_question` kinds in between,
  and no jump from above landing between the two copies. Assumption carried in prose, not proved: the folds
  in between that collapse whitespace do not change the guard's verdict (both templates collapse
  whitespace before matching). `w410`'s 84 copies are not covered: each answers only when its own ledger
  holds the name.
- `skip_hides`: `s` passes over `r`, `q`, `p`; `ab` over `aa`; runtime `w` over `v`; `SiblingEvidentialV3`
  over `SiblingEvidentialV2` and `SiblingEvidential`. Those classes' `chat` never runs from the tip.
- `replace_cuts_below_reach`: `b` (index 359) never calls the base; every jump above it lands at 359 or
  higher (max landing 359), so `OracleReleaseRuntime.chat` never runs. The base's constructor still does.
- `w540_*`: the tip fold only.

## What the model does not cover

- **State.** Folds are functions of the question alone; dialogue state, sessions, ledgers and the
  `_pending_conversion` side channel are not modelled. 143 folds write state. `ao`'s referent resolution
  depends on state; modelled as a fixed rewriter per turn.
- **Re-entry.** Runtime `i` sends each part of "X, then Y" back through the whole chain from the tip
  (`reenters`). Not modelled; its fold is a `PreRoute` in the catalogue mapping, which is wrong for those turns.
- **Hooks and module patches** change a deeper fold's behaviour through late binding or import-time
  mutation. The model takes each fold's semantics after late binding; the hook's own position is `Pass`.
- **ao in full.** `ProbeRewrite 1` captures probe-on-`am`-then-rewrite; ao's second probe (fall back from
  "How old is Moon?" to "Summarize Moon.") and its returning the rewritten turn's decline are folded into
  the rewriter, not modelled separately.
- **Sub-dispatches.** `w533`, `w537`, `w193` ask the chain about parts or side questions in other session
  ids; `Redispatch` gives the handler the inner dispatcher but not a session.
- **Provenance and references.** `reply` has status, path and response only. w540's D1 message falls back to
  the default because `declined_response` lives in provenance.
- **Characters.** The w540 guards are exact for ASCII. Python's `\s`, `\w`, `\d` and `re.I` also accept some
  non-ASCII characters; those inputs are outside the translation.
- **Classification is static.** Kinds come from AST shape, following `self.<helper>` within the chain and
  module functions, not other modules. Helper replies of unknown status are `opaque`; only seven folds are
  certified `narrow`. No fold was executed.

## Anomalies (detail in `audit/folds/README.md`)

Windows `sys.path` entry in the base module (line 27); `ao` deep-copies the session dialogue up to twice per
turn and runs the chain below it up to three times, with its probe on a different stack (skips `an`);
about 322 `chat` frames per full descent, about twice that when `i` re-enters, against CPython's default
limit of 1,000, which nothing raises; `w522` and `w523` both patch `w521`'s solver at import, the newer
wins by import order; identical copies of `ao` and `w54`..`w75` in both `admitted/` and `wander-train/`.

## Remaining work

- Read the helpers of the six withheld-only `post_replace` folds; if they only withhold, they become
  `narrow` (extractor change: resolve helper statuses across modules).
- Model re-entry (`i`) with explicit fuel, and sessions, if a consumer needs them.
- Lift `w532`, `w511`, `w510` guards the way w540's were (the vector generator generalises).
- Consumers: none yet. Lane A's parity harness could use `folds.json` to attribute panel failures to the
  fold whose path prefix appears in the reply.
