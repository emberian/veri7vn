# E computing: unset Unix mode permissions

Owner: Codex computing deputy. **Ready and frozen for integration.** Proof,
exact native compilation, shipped panels and actual dispatcher checks passed.
D was integrated as `1ca00c3` and immutably captured before these edits.

## Concrete behavior and model

The actual D binary `2124ffc06475b3772fd2dde3285ff0f643269c4c0f51042e6c87695279e6dc7c`
answers "For mode 775, what permissions are denied?" with the granted symbolic
mode. Those facts are true, but they do not explicitly answer the requested
complement. "Which permission bits are unset in mode 4755?" is not taken.
`var/computing-next/linux-permissions/before.json` records five exact replies.

The new typed query reports unset read/write/execute bits for owner, group and
others, or a named class. For 775 the result is owner none, group none, others
write. For 640 it is owner execute, group write/execute, others all three.
Special mode bits do not change those nine ordinary permission bits.
[Linux inode(7)](https://man7.org/linux/man-pages/man7/inode.7.html) supplies the
source interpretation. This is not an effective-access calculation; explicit
ACL/effective-access/root-user requests are withheld. Multiple-mode and
additional-action requests are also withheld rather than partially answered.
These may be valid unsupported questions; refusal policy is not capability gain.

## Checked proof and implementation

`Permission_Query.thy` imports the existing `System` permission definitions and
reuses its checked Boolean complement (`dir_digit`). `missing_actions_exact`
states that for d<8, an action occurs in the computed complement list iff its
original mode bit is false. `permission_rows_exact` selects the requested classes
and carries that biconditional through the returned rows.
`permission_reply_lists_exact_unset` ties successful replies to those rows and
the rendered response; it does not prove natural-language recognition or OS
access semantics. The recognizer selects the typed mode/class query; the new
`chmod_unset` capability kind must survive actual dispatch.

## Evidence so far

The scratch arithmetic prototype compared all 4096 octal modes and four class
selectors (all/owner/group/others): **16384/16384** agree with Python `stat` bit
masks. This is a finite arithmetic check of a separate untrusted prototype,
not 16384 natural-language capabilities or a formal proof.

`e_probes.py` has seeded natural-language questions checked using independent
`stat` masks, malformed modes, effective-access requests, multi-request scope and
a positive-polarity control. Initial scratch 47-case D baseline was 1 correct,
11 incomplete/wrong for the requested interpretation, 29 valid withheld,
0 false yes on three malformed modes; of three underspecified effective-access
requests, one was withheld and two asserted. Policy assertions were 1/47.
Two whole-request cases were subsequently added; final baseline and results
remain pending. Tuning seed 802311; untouched evaluation seed 903037.

The full nine-ID semantic frontier remains in D; E substantively advances
linux-v2. Other IDs receive regression checks but no new examination claim.


The earlier 49-case baseline against D was recorded at
`var/computing-next/linux-permissions/E-before.json`: 1 correct, 12
incomplete/wrong for the requested interpretation, 30 valid withheld, 0 false
yes, three invalid withheld; one of three underspecified effective-access
requests withheld. Policy assertions 1/49. The 43 valid requests include two
multi-request cases that remain unsupported even if the scope refusal succeeds.
A smart-apostrophe positive-polarity control brings the final suite to 50 cases;
the final baseline replaces the earlier scratch report without changing its
immutable source binary. Final D baseline is **2 correct, 12 incomplete/wrong,
30 valid withheld**, three invalid withheld/zero false yes, and one of three
underspecified effective-access requests withheld. Policy assertions: **2/50**.


## Exact theorem statements

Here `action_set` reads an original digit's read/write/execute bit using `bits3`;
`missing_actions` uses `dir_digit`, the existing computed Boolean complement.
`permission_rows` selects the requested class or all three.

```isabelle
missing_actions_exact:
  d < 8 ⟹ (a ∈ set (missing_actions d) ⟷ ¬ action_set a d)

permission_rows_exact:
  mode_valid m ⟹
    ((c, acts) ∈ set (permission_rows m who) ⟷
     (who = None ∨ who = Some c) ∧ acts = missing_actions (class_digit m c))
  mode_valid m ⟹ (c, acts) ∈ set (permission_rows m who) ⟹
    (a ∈ set acts ⟷ ¬ action_set a (class_digit m c))

permission_reply_guard:
  answered (permission_reply m who) ⟷ mode_valid m

permission_reply_lists_exact_unset:
  answered (permission_reply m who) ⟹
  (c, acts) ∈ set (permission_rows m who) ⟹
    (a ∈ set acts ⟷ ¬ action_set a (class_digit m c))
  answered (permission_reply m who) ⟹
  (c, acts) ∈ set (permission_rows m who) ⟹
    response (permission_reply m who) = permission_response m who
```

The response renderer lists those exact computed rows. These statements do not
prove English interpretation, the reader's multi-request guard, or effective OS
access. The constant effective/scope refusals are model boundaries, not new
capabilities or a probability of correctness.

## Final evidence and consumer

- Managed hbox proof receipt:
  `var/computing/remote-attempts/20261018T100127Z-34624c74e6bb/receipt.json`.
  **PASS first attempt**, 2m10s total, new theory 1.67s;
  `VERI7VN_COMPUTING PASS theorems=128 oracles=0`.
  Source digest `b3f974c90c155e57fb6ee645675290c41ec1e955684195ad832557bac4e227ba`;
  export SHA `00f201ac8720ab19b5b80c69492780a9c70cd730c1f39ed2118a80ee50baac21`.
- Shared native receipt:
  `var/computing/native-attempts/20261018T100552Z-87c8ce7f6f80/compile-inputs.json`.
  Exact actual inputs matched the checked proof closure. Binary SHA
  `220348be0908a5521615fae6173281739349ef5d967583d87446ec4250889396`,
  **1,215,672 bytes** (16,288 more than D). Recognizer SHA
  `04d3cf5f9804fd8ffc272b73638dda1e05a57cf3be051de7ccec01e889f5a8f1`.
  Commons/main unchanged. A prior native attempt rejected a raw UTF-8 apostrophe;
  the final adapter uses explicit SML byte escapes and tests that spelling. This
  parser-only repair does not change the proved HOL source.
- Shipped panels: `var/computing-next/linux-permissions/E-shipped.json` and
  `E-parity/`: **1364/1364 right, 0 wrong, 0 false yes, 0 valid withheld**.
  Linux-v2 is **42/42 dev and 42/42 held-out**. Other per-ID totals remain the D
  table. Harness overall status stays **INCOMPLETE** without head/core/LANE/SELF
  and complete budget inputs; no six-criteria ADMIT is claimed.
- Authored E policy assertions: `E-tune.json` (seed 802311) and `E-eval.json`
  (seed 903037), each **50/50**. Evaluation was first run after compilation froze;
  it varies 32 finite modes/class choices while the other cases/templates repeat.
  Capability counts are separately **42 correct, 0 wrong, 2 valid withheld,
  0 false yes**, three invalid withheld, three underspecified effective-access
  requests withheld. Two valid unsupported compound requests remain gaps.
- Actual installed consumer: `E-composition.json`, **50/50**, same counts through
  `tools/dispatch/dispatch.py --organs computing --specialist linux-v2`, with every
  reply taken and decisive. The new `chmod_unset` kind and both refusal boundaries
  survive runtime acceptance; no shared runtime source was changed.
- Regression: `E-D-regression.json` **63/63 policy assertions**, retaining D's
  **38 correct / 0 wrong / 5 valid withheld** count; `E-C-regression.json`
  **40/40**, including 16 whole-result SQLite comparisons. Table checker 18/18.
  All named E artifacts above are under `var/computing-next/linux-permissions/`.

## Frozen changed files and remaining

Eight files: new `src/extract/computing/Permission_Query.thy`, new `e_probes.py`,
modified `Computing_Export.thy`, `ROOT`, `README.md`, `capabilities.json`,
`recognizer.sml`; new `project/lanes/E-symbolic-computing.md`.
D report and captured D artifacts remain immutable. Root owns commits.

The consumer is the computing binary and its actual dispatcher route. Linux
parity for this E artifact has not run; the package owner can capture the exact
native receipt. Multi-mode computations, ACL/effective-access semantics,
arbitrary natural-language polarity and general compound requests remain open.
Existing C/D frontiers for SQL, Git, Python and the other specialists remain
unchanged; this packet makes no new claims about them.
