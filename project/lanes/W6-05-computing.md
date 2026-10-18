# W6-05-computing: timer bound, key order, scan the 44

Family `src/extract/computing/` (session `Veri7vn_Computing`). Build: one remote
build on persvati, first attempt green:
`VERI7VN_COMPUTING PASS theorems=65 oracles=0` (65 scan lists; the marker is the
export theory's last command, `markers.py`: unscanned theorems 0, was 44).

## New and replaced statements (verbatim)

`emb_ctc_gives` (it was `x / y * y = x`) is retired. In its place, in `Numerics.thy`:

```
theorem emb_ctc_freq_bound:
  assumes "emb_decline (ECtc fc P ft bits) = None"
  shows "|fc / (of_nat P * (1 + emb_value (ECtc fc P ft bits))) - ft|
           <= ft / (2 * (1 + emb_value (ECtc fc P ft bits)))"
```
In words: the timer divides the clock by P times the compare count N = 1 + value;
the frequency it actually gets is within ft / (2N) of the target. A count rounded
the wrong way (off by more than one half) breaks the bound.

`cyb_base64_len` is now tied to the kernel value (it was about a bare formula, with `0 < n`):
```
theorem cyb_base64_len:
  "8 * of_nat n <= 6 * cyb_value (CBase64 n) /\ 6 * (cyb_value (CBase64 n) - 4) < 8 * of_nat n"
```
In words: the reported length is the smallest multiple of four that holds 8n bits in six-bit groups.

`exec_group_order_is_key_order` (it was `isort_sorted` restated, never mentioning
`exec_sq`) is retired. In its place, in `Sql.thy`:
```
theorem exec_group_keys_strictly_ordered:
  assumes "exec_sq (STable tn to cols rows) (SQ False [SI_col g] tb cnd (Some g) [] None) = SRows out"
  shows "EX gi. col_index cols (fst g) = Some gi /\
     sorted_wrt (%r s. sv_ord (hd r) (hd s) < 0) out /\ (ALL r : set out. EX k. r = [k]) /\
     (ALL row : set (where_rows cols cnd rows). EX r : set out. sv_ord (cell row gi) (hd r) = 0) /\
     (ALL r : set out. EX row : set (where_rows cols cnd rows). sv_ord (cell row gi) (hd r) = 0)"
```
In words: a grouped select of the grouping column returns each group once, in
strictly ascending order, and the groups are exactly those of the rows WHERE keeps.
Helper lemmas: `uniq_subset`, `uniq_cover`, `uniq_sep`, `uniq_distinct`, `strict_sorted`, `group_keys_out`.

## Counts (tools/audit, this tree)

| | before | after |
|---|---|---|
| statements in family | 140 | 146 |
| theorem-keyword facts outside the scan | 44 | 0 |
| vacuous | 3 named (`emb_ctc_gives`, `cyb_base64_len` weak form, `exec_group_order_is_key_order`) | 0 |
| binding added | | 2 (+ `cyb_base64_len` re-tied) |
| `by eval` | 0 | 0 |

The 44 are now in the scan (`Computing_Export.thy`). The 44 include the
`exec_group_order_is_key_order` that was then replaced, so 43 scanned old names plus the new theorem.

## Panels

The binary was rebuilt from the persvati export. The nine specialists were scored
with `tools/parity/harness.py --split both` before (old binary) and after: summaries
identical, and all 1,364 item replies (status, response, path, kind, value) identical.
Numbers are the handoff `S15b-computing.md` numbers unchanged (networking 74/74 dev,
68/71 heldout; embedded 25/25, 25/25; cyber 19/20, 16/20; linux-v2 42/42, 42/42;
git 10/10, 7/10 with 1 wrong; sql 61/61, 61/61; python 198/198, 186/224;
python-r2 198/198, 186/224; robotics-v2 36/36, 20/23). No kernel code changed, only theorems.

## Not done

`interp_ln_fa` stays deferred (not attempted). The SQL ungrouped select against a
relational specification is W6-06's.
Note for root: `build.sh` reads the local session database, whose generated SML
differs in ordering from persvati's (77 diff lines); I built the binary from the persvati export.
