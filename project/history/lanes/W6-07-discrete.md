# Lane W6-07-discrete: MST minimality and exact declines (handoff, 2026-10-18)

Family `src/extract/discrete/` (session `Veri7vn_Discrete`, marker `VERI7VN_DISCRETE PASS`).
Row: MST minimality by an independently checked certificate, exact decline conditions
stated apart from the code, three binding theorems, the five unscanned theorems scanned.

## What changed

- `Disc_Algos.thy`: a spanning-tree specification (`adj`, `connects`, `spans`) that does
  not mention Kruskal, and a verified checker `mst_cert`. The kernel now states a spanning
  tree only when the checker passes it, and decides "not connected" by a label-merging
  test proved equal to the path definition. The checker, per edge weight c of the graph,
  counts the classes left after joining every edge of weight at most c (`ncomp c es`) and
  requires the tree to have exactly `ncomp c es - 1` edges heavier than c. Any spanning
  tree has at least that many (each heavier edge merges at most two classes), and a
  layer-cake sum over the sorted distinct weights turns those counts into weights. The
  proof works for negative weights and ties.
- `Disc_Formats.thy`: the base-conversion decline as character ranges (iff), and the SHA
  padding shape.
- `Discrete_Export.thy`: the six new theorems and the five `reply_of_*` added to the
  oracle scan; the PASS marker is still the last command.
- `build.sh`: uses the SML returned by `tools/dev/remote-build` when present
  (`DISCRETE_EXPORT=local` forces the local session database).
- `README.md`: limits updated.

## Definitions the statements use (verbatim)

```
definition adj :: "edge list \<Rightarrow> node \<Rightarrow> node \<Rightarrow> bool" where
  "adj F u v = (\<exists>w. (u, v, w) \<in> set F \<or> (v, u, w) \<in> set F)"
definition connects :: "edge list \<Rightarrow> node list \<Rightarrow> bool" where
  "connects F V = (\<forall>x \<in> set V. \<forall>y \<in> set V. (adj F)\<^sup>*\<^sup>* x y)"
definition spans :: "edge list \<Rightarrow> edge list \<Rightarrow> bool" where
  "spans t es = (set t \<subseteq> set es \<and> length t + 1 = length (remdups (node_list es))
      \<and> connects t (node_list es))"
definition mst_cert :: "edge list \<Rightarrow> edge list \<Rightarrow> bool" where
  "mst_cert es t = (set t \<subseteq> set es \<and> length t + 1 = length (remdups (node_list es))
      \<and> const_on (mergeall id t) (remdups (node_list es))
      \<and> (\<forall>c \<in> set (wts es). cnt_gt c t + 1 = ncomp c es))"
```

`wt` is the sum of edge weights, `node_list es` the ends of every edge (both unchanged).

## New binding theorems (verbatim)

```
theorem mst_cert_minimal:
assumes c: "mst_cert es t" and s: "spans t' es"
  shows "wt t \<le> wt t'"

theorem mst_cert_spans:
"mst_cert es t \<Longrightarrow> spans t es"

theorem a_mst_minimal:
assumes "a_kernel (A_mst es) = AMst t"
  shows "spans t es \<and> (\<forall>t'. spans t' es \<longrightarrow> wt t \<le> wt t')"

theorem a_mst_disconnected:
"a_kernel (A_mst es) = ADisconnected \<longleftrightarrow> es = [] \<or> \<not> connects es (node_list es)"

theorem f_base_decline_exact:
"f_kernel (F_base tok src dst cs) = FBaseBad tok' src' \<longleftrightarrow>
     tok' = tok \<and> src' = src \<and>
     (\<exists>c \<in> set cs. \<not> (48 \<le> c \<and> c \<le> 57 \<and> c - 48 < src) \<and> \<not> (97 \<le> c \<and> c \<le> 102 \<and> c - 87 < src))"

theorem sha_pad_shape:
"take (length m) (sha_pad big m) = m \<and> sha_pad big m ! length m = 128 \<and>
   length m + 9 \<le> length (sha_pad big m) \<and> length (sha_pad big m) \<le> length m + 72"
```

What they say in plain words: when the kernel answers a spanning-tree question, the tree
it names is made of graph edges, has one edge fewer than the graph has nodes, joins every
node, and no other such tree weighs less. It says "not connected" exactly when the graph
has no edges or some two nodes have no path between them. A base conversion is declined
exactly when some character is neither 0-9 nor a-f with a value below the source base.
SHA/MD5 padding keeps the message as a prefix, puts 0x80 right after it, and adds 9 to 72
bytes.

`a_mst_sound` (graph edges only) is kept and now follows from `a_mst_minimal`;
`f_base_declines` (one-way) is kept.

## Checks and results

- Remote build on persvati: `tools/dev/remote-build persvati src/extract/discrete
  Veri7vn_Discrete -d src/extract/commons --expect 'VERI7VN_DISCRETE PASS'`. Build
  `Finished Veri7vn_Discrete (0:02:02 elapsed)`; session log line
  `VERI7VN_DISCRETE PASS theorems=81 oracles=0` (was 75). Two lemmas needed a second
  attempt (`card_lmerge`, `mergeall_reach`); two earlier attempts were killed by the
  shared swarm.slice memory cap on persvati (kernel oom-kill of the slice), not by the
  theory. Note for root: remote-build reported "marker not found" although the build
  passed: the marker is beyond the `tail -2000` of the session log (Approximation's
  output fills it). Confirmed with `isabelle build_log -v Veri7vn_Discrete | grep`.
- Generated code: `lmerge` evaluates the two end labels once (`let val la = f a; val lb = f b
  in fn x => ...`), so the checker is polynomial; algorithms p50 0.10 -> 0.10 ms, max 0.19 ->
  0.21 ms.
- `tables_check.py`: TABLES_CHECK PASS 102 checks.
- Binary: `sh src/extract/discrete/build.sh`, 891,032 bytes.
- Harness, old binary vs new, all five specialists, both splits
  (`PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer <bin> --specialist
  games-v3,logic-v3,dataformats,algorithms,calculus --split both --out var/discrete/w6/parity-<before|after>`):
  508 items, 0 reply differences (timing fields excluded). All 16 spanning-tree answers pass
  the checker.

| Specialist | dev (right/wrong/withheld valid/false yes) | heldout |
|---|---|---|
| games-v3 | 51/0/0/0 | 18/0/0/0 |
| logic-v3 | 33/0/0/0 | 12/0/0/0 |
| dataformats | 93/0/0/0 | 93/0/0/0 |
| algorithms | 42/0/0/0 | 42/0/0/0 |
| calculus | 62/0/0/0 | 62/0/0/0 |

Harness decision INCOMPLETE as before (no head answerer run). Spot checks by hand: a
two-component graph replies "not connected"; a 4-node graph whose five edges all weigh 2
gives weight 6; a 12-node, 44-edge graph answers in well under a millisecond.

## Audit counts (tools/audit extract.py, markers.py, check_class.py discrete)

| | statements | vacuous | definitional | binding | example | helper | unclassified | theorems scanned / unscanned | marker |
|---|---|---|---|---|---|---|---|---|---|
| before | 139 | 0 | 11 | 71 | 3 | 54 | 0 | 75 / 5 | last |
| after | 166 | 0 | 11 | 77 | 3 | 75 | 0 | 81 / 0 | last, oracles=0 |

New classifications appended to `var/audit/class/discrete.txt` (B: the six above; A: the
21 checker lemmas). `aggregate.py` currently stops on another family's unclassified
`wf_nil`; the discrete line above is `check_class.py discrete`.

## Remaining

- `remaining: kruskal_passes_cert` — prove that Kruskal's output always passes `mst_cert`
  on a connected graph (then the kernel never withholds a connected spanning-tree
  question). Today a failure would reply "imprecise" and withhold; no panel question does.
- SHA-2/SHA-1/MD5 and the JSON validator are still tested, not proved against an
  independent definition (unchanged).
- `main.sml`'s provenance theorem list is unchanged (adding names would change every reply).

## Consumer

Root: commit integration; the parity board numbers are unchanged.
