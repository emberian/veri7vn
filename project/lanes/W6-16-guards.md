# W6-16 guards: vectors without eval, guards as narrowing folds

Build: `tools/dev/remote-build persvati src/extract/guards Veri7vn_Guards -d src/isabelle/routing --expect 'VERI7VN_GUARDS PASS'`
passed first try: `VERI7VN_GUARDS PASS theorems=49 oracles=0` (3:51 elapsed).

## Before and after
| | before | after |
|---|---|---|
| theorems in the marker's scan | 42 (of 44) | 49 (of 49) |
| `by eval` proofs | 2, after the marker | 0 |
| oracles | 0 in the scan, 2 outside it | 0 |
| ROOT order | Export, then Vectors | Vectors, Narrow, Export (marker last) |
| binding theorems added | | 5 (below) |

Panel: the guards family has no specialist panel. Its number is the 114 recorded
guard decisions: the binary rebuilt from this export is 430,552 bytes (unchanged),
`--selftest` prints `self_test=true`, and regenerating `Guards_Vectors.thy` from
the binary's output reproduces the committed file byte for byte.

## Vectors
`vectors_pin` and `vectors_count` are now `by code_simp` (about 3 minutes, no oracle).
The rationals in the vectors are written `Fract n d` over `int` instead of `mk_rat`
over `integer`, so `Guards_Vectors` imports only `Guards`; `gen_vectors.py` emits the same.
```
theorem vectors_pin: "list_all (\<lambda>(v, r). decision_auto v = r) vectors"
theorem vectors_count: "length vectors = 114"
```

## New statements (`Guards_Narrow.thy`)
`ext` is the untrusted recognizer, `(string => reply => feats)`.
```
definition guard_fold ext = Narrow ''precision_guard''
   (\<lambda>t r. decision_auto (ext t r) \<noteq> None) (\<lambda>r. ''precision_guard'')

theorem guard_fold_is_narrow: "is_narrow (guard_fold ext)"
theorem guard_withholds:
  "decision_auto (ext t (cascade fs base t)) \<noteq> None \<Longrightarrow>
   status (cascade (guard_fold ext # fs) base t) = Withheld"
theorem guard_passes:
  "decision_auto (ext t (cascade fs base t)) = None \<Longrightarrow>
   cascade (guard_fold ext # fs) base t = cascade fs base t"
theorem guards_never_add:
  "\<forall>f \<in> set fs. \<exists>ext. f = guard_fold ext \<Longrightarrow>
   status (cascade fs base t) = Answered \<Longrightarrow> cascade fs base t = base t"
theorem guard_leaves_unanswered:
  "\<forall>t r. answered (ext t r) \<longleftrightarrow> status r = Answered \<Longrightarrow>
   status (cascade fs base t) \<noteq> Answered \<Longrightarrow>
   cascade (guard_fold ext # fs) base t = cascade fs base t"
```
`guards_never_add` rests on lane B's `narrow_preserves_answer_text`; `guard_leaves_unanswered`
uses `decision_needs_answer`. The first four hold for any recognizer; the last assumes the
recognizer reports answered-ness faithfully.

## Limits
- The fold's path is `precision_guard>route`, the cascade's form; the real folds write
  `precision_guard:CODE|route`. Not modelled (`withheld_path` states the real form).
- Audit item 3 (a HOL definition of `nums_q` from the question text) is not done.
- `regex.sml` is still the family's own copy (W5-12 did not port it); left alone.
- The session now needs `-d src/isabelle/routing` (it lists `Veri7vn_Routing` in `sessions`).
