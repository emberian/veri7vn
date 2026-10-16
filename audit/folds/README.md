# Oracle7's routing cascade, fold by fold

Oracle7 answers a message by calling `chat` on its newest runtime class,
`OracleReleaseRuntimeW540`. That class was written as a small change on top of
the class before it, which was written on top of the one before that, and so
on, back to the first runtime. Each of these layers is a **fold**. A fold either
handles the message itself or passes it down with `super().chat(...)`.

This directory is a catalogue of every fold in that stack, in the order a
message actually travels through them.

| File | What it is |
|---|---|
| `extract.py` | Reads the shipped Python source and writes `folds.json`. It never imports or runs the folds. `--check` confirms `folds.json` is current. |
| `folds.json` | One record per fold, newest first. |
| `w540_vectors.py` | Runs the three guard functions of the newest fold (lifted out of its source, nothing else loaded) on 40 test cases and writes `src/isabelle/routing/W540_Vectors.thy`, which checks that the Isabelle translation gives the same verdicts. |

The Isabelle side is in `src/isabelle/routing/` (session `Veri7vn_Routing`); see
`project/lanes/B-routing.md` for the proved statements.

## How many folds there are

The stack is longer than the head manifest says.

| Count | |
|---|---|
| 361 | classes a message can pass through (Python's method resolution order for `OracleReleaseRuntimeW540`) |
| 360 | source files they live in (`w530` holds two classes) |
| 31,296 | lines in those files |
| 329 | of the classes define their own `chat` |
| 317 | runtimes listed in `HEAD_MANIFEST.json` under `chain_tip_to_base` (the `admitted/` ones) |
| 353 | classes you reach by following each class's first parent by hand |

The difference between 353 and 361 comes from three folds that have two
parents (`w31`, `w46`, `w66`). Python merges both parent lines, which splices in
`w60`, `w45`, `w44`, `w42`, `w41`, and three "sibling" classes from
`wander-train/` (`SiblingEvidentialV3`, `SiblingEvidentialV2`,
`SiblingEvidential`). The siblings sit between `w1` and `ao`. 43 of the 361
classes come from `wander-train/`, not `admitted/`. The five
`orphaned_admitted` modules in the manifest (`w2`, `w3`, `w11`, `w25`, `w26`)
are on no path at all.

`ao` and `w54` to `w75` exist in both directories with identical bytes. The
extractor looks in `admitted/` first.

## Kinds

Each fold gets one kind from the shape of its `chat`. The shape is read from the
code: whether it calls the folds below first, what text it passes them, and what
it can return on its own. The HOL column is the constructor in
`src/isabelle/routing/Fold_Cascade.thy` that models the kind.

| Kind | Count | What the fold does | HOL |
|---|---|---|---|
| `pre_route` | 253 | Checks the message first. If its own route matches, it answers and the folds below never see the message. Otherwise it passes the message down. | `PreRoute` |
| `post_replace` | 40 | Asks the folds below first, then may change their reply, including turning a decline into an answer. | `Post` |
| `hook` | 21 | No `chat` of its own. Overrides a helper method that a fold further down calls, so it changes that fold's behaviour from above. | `Pass` |
| `post_redispatch` | 11 | Asks the folds below, then may ask them again about other questions (parts of a compound question, a rewritten form) and build a new reply. | `Redispatch` |
| `narrow` | 7 | Asks the folds below first. Every change it makes turns an answer into a decline. It never answers on its own. | `Narrow` |
| `rewrite` | 7 | Passes the folds below a rewritten form of the message. | `Rewrite` |
| `state_only` | 5 | Passes the message down unchanged and only records something. | `Pass` |
| `empty` | 4 | A class with no body. | `Pass` |
| `join` | 3 | A class with two parents and no body. It exists to merge two branches. | `Pass` |
| `module_patch` | 3 | No `chat`. When the file is imported it changes another module's settings (`w522` and `w523` point `w521`'s maths agent at a newer solver; `w61` appends to a shared operator table). | `Pass` |
| `transparent` | 2 | Defines `chat` but only passes the message down. | `Pass` |
| `helper` | 1 | `_C528Parts` in `w530`: methods used by the class above it. | `Pass` |
| `pre_and_post` | 1 | `w175`: its own route first, then a change to the reply from below. | `PreRoute` then `Post` |
| `probe_rewrite` | 1 | `ao`: first tries the message on the folds below; only if they do not answer does it rewrite the message and send that down. | `ProbeRewrite` |
| `replace` | 1 | `b`: answers every message itself and never calls the base. | `Replace` |
| `base` | 1 | `OracleReleaseRuntime`, the bottom of the stack. | `Replace` |

The seven `narrow` folds are `w540`, `w532`, `w511`, `w510`, `w458`, `w456` and
`w422`. A fold counts as narrow only if every reply it writes has status
`withheld`. Six more (`w514`, `w513`, `w432`, `w430`, `w428`, `w420`) write
only `withheld` replies themselves, but they also return a reply built by a
helper whose status the extractor cannot read, so they are filed under
`post_replace` until someone reads those helpers.

`may_answer_on_own` is true for 312 folds: their code contains a reply with
status `answered`, or a reply whose status the extractor cannot read. The other
49 write no answering reply of their own. That does not make all 49 harmless:
the 21 hooks change what a deeper fold does.

## What a record holds

`index` (position, 0 is the newest), `module`, `class`, `base_module`, `bases`,
`file`, `sha256`, `lines` (lines in the file), `class_lines`, `doc_head` (first
docstring line), `kind`, `hol`, `defines_chat`, `calls_super_first`,
`inner_calls` (each call to the folds below: line, how, which text, which fold
it lands on), `inner_text` (`same`, `normalized` for whitespace collapsed, or
`rewritten`), `rewrites_text`, `skips` (folds a call passes over), `reenters`,
`guards` (each regular expression the fold uses, by name, with its source and
flags), `reads` (which fields of the reply below it looks at), `touches_state`
and `state_writes`, `own_statuses_before` and `own_statuses_after` (statuses of
replies it writes before and after asking below), `may_answer_on_own`,
`same_question`, `overrides`, `module_patches`, `template`, `shadowed_by`,
`answers_whenever_guard_fires`, `on_manifest_chain`, `on_first_base_walk`.

73 folds read the reply's `status` and 73 its `path`; 58 read its `response`
and 53 its `provenance`. 143 write some state of their own. 237 pass the folds
below a whitespace-collapsed copy of the message; 18 pass a rewritten one.

## The ten most common guard shapes

Guards are the regular expressions folds use to decide whether to act. There
are 966 guard uses, 497 distinct patterns (5 are built at run time and could
not be read). Shapes, with an example of each:

| Uses | Folds | Shape | Example |
|---|---|---|---|
| 206 | 107 | A whole question from start to end, case ignored, with a named slot for the topic | `^who (?:built\|made\|raised) (?:a \|an \|the )?(?P<k>...)[?.! ]*$` |
| 136 | 136 | A set of fixed phrasings, case ignored | `(what (?:could\|can) you (?:learn\|become)\|what are your potentials\|...)` |
| 105 | 54 | One fixed phrasing, case ignored | `(what (?:did\|have) you learn(?:ed)?( recently)?)` |
| 103 | 40 | Whole words from a list, case ignored | `\b(my\|our)\s+(?:own\s+)?(favou?rite\|best\|...)\b` |
| 54 | 32 | A plain character class, used to cut text into words | `[a-z]+` |
| 35 | 21 | The opening words of a question, case ignored | `^\s*(?:what\|who\|whom\|whose\|where\|when\|which\|why\|how\|is\|are\|...)` |
| 32 | 14 | Whole words from a list, case kept | `\n[ \t]{2,}\S\|\bdef \w+\(\|\breturn\b` |
| 25 | 17 | Patterns with digits, mostly over a reply's path | `general_reader:[a-z]+:P(\d+):(fwd\|inv)>` |
| 20 | 10 | A capitalised word | `\b[A-Z][a-z]+` |
| 19 | 9 | One step of a reply's path | `(?:^\|\|)synth:composed(?:\|\|$)` |

The first three rows are mostly copies: 216 of the 253 `pre_route` folds are
three generated templates repeated (`w410`'s shape 84 times, `w411`'s 82 times,
`w409`'s 50 times). Each copy carries the same regular expressions and its own
ledger numbers.

## Things worth knowing

**Most copies of the generated folds can never answer.** A `w411` copy answers
"what could you become?" from its ledger as soon as its pattern matches. A copy
further down with the same pattern only sees the message if every copy above
it declined, and they all match the same messages. Between consecutive copies
the folds only pass the same message down (whitespace collapsing aside), so the
deeper copy never answers. `shadowed_by` marks 121 such copies (75 of `w411`'s,
46 of `w409`'s); the newest copy's ledger is the one served. Isabelle's
`preroute_dead_copy` is this argument in general form. `w410`'s 84 copies are
not marked: each answers only if its own records hold the asked name, so a
deeper copy with more records can still answer.

**Some folds are skipped over.** A fold that calls `X.chat(self, ...)` or
`super(X, self).chat(...)` jumps past the folds between. `s` calls `o`
directly, so `r`, `q` and `p` never run from the tip. `ab` passes over `aa`,
`w` (the runtime named `w`) passes over `v`, `SiblingEvidentialV3` passes over
`SiblingEvidentialV2` and `SiblingEvidential`, and `ao`'s probe passes over
`an`. `b` answers every message without calling the base, so
`OracleReleaseRuntime.chat` never runs; the base's constructor still does. The
`skips` field lists these; `w193` also passes over four folds, but only for the
side question it asks on its own behalf.

**The base adds a Windows folder to Python's import path.**
`wander-train/oracle_release_runtime.py` line 27 runs
`sys.path.insert(0, r"C:\Users\...\control-install")` when it is imported. On
any other machine that folder does not exist, so the modules imported from it
must be found elsewhere on the path or the import fails.

**`ao` copies the dialogue state twice per turn.** To try a message without
recording it, `ao` deep-copies the session's dialogue, runs the folds below on a
probe, and puts the copy back; it does this again for the rewritten form. Every
message that reaches `ao` pays for up to two full copies of that session's
dialogue and up to three trips through everything below `ao`. The probe also
calls `am` directly, so it runs a slightly different stack (without `an`) from
the one the real reply comes from.

**The stack is deep enough to matter for Python's recursion limit.** A message
that travels all the way down passes through about 322 `chat` calls, each one a
Python stack frame, before helper functions add their own. Runtime `i` splits
"do X, then Y" and sends each part through the whole stack again from the top,
so those turns use about twice that. Python stops at 1,000 frames by default;
no file in the stack raises that limit. The entry point `upstream/oracle7.py`
does, to 20,000, with the comment "the admitted fold chain is >250 modules
deep". Anything that imports the chain without going through `oracle7.py`
(the Workbench's own exam runner, for instance) runs at the default and is a
few folds from the limit.

**Import order decides which patch wins.** `w522` and `w523` both replace
`w521`'s maths agent when they are imported. Python imports the deeper module
first, so `w523` (newer) wins and the agent is solver v3.

**The kinds are read from code, not run.** The extractor follows `self.<helper>`
calls inside each class and module-level functions, but not into other modules.
A helper that returns a reply built elsewhere is recorded with status `opaque`,
which is why only seven folds are certified `narrow`.
