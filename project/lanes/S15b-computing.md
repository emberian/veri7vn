# Lane S15b-computing handoff

Lane S15 (Sonnet) drafted the computing family; S15b made it build, compiled it and
scored it. Session `Veri7vn_Computing` builds green with
`VERI7VN_COMPUTING PASS theorems=65 oracles=0`; the MLton binary
`var/computing/bin/computing` answers all nine specialists.

## Numbers (shipped panels, `tools/parity/harness.py`, `--specialist <id>`)

Right / wrong / withheld on a valid item / false yes. "Organ disagreements" is
`score.py`'s item-by-item comparison with the shipped organ on the held-out panel
(same answered or withheld status, same kind, same value within the scorer's tolerance).

| Specialist | dev | held-out | shipped held-out (spec) | organ disagreements | p50 in binary (budget 50 ms) |
|---|---|---|---|---|---|
| networking | 74 / 0 / 0 / 0 (n=74) | 68 / 0 / 3 / 0 (n=71) | 67 right, 1 false yes | 0 | 0.08 ms |
| embedded | 25 / 0 / 0 / 0 (n=25) | 25 / 0 / 0 / 0 (n=25) | 25 | 0 | 0.09 ms |
| cyber | 19 / 0 / 1 / 0 (n=20) | 16 / 0 / 4 / 0 (n=20) | 16 right, 1 false yes | 2 (entropy over 62 symbols, see below) | 0.09 ms |
| linux-v2 | 42 / 0 / 0 / 0 (n=42) | 42 / 0 / 0 / 0 (n=42) | 42 | 0 | 0.04 ms |
| git | 10 / 0 / 0 / 0 (n=10) | 7 / 1 / 2 / 0 (n=10) | 7 right, 1 wrong | 0 | 0.04 ms |
| sql | 61 / 0 / 0 / 0 (n=61) | 61 / 0 / 0 / 0 (n=61) | 61 | 0 | 0.17 ms |
| python | 198 / 0 / 0 / 0 (n=198) | 186 / 0 / 38 / 0 (n=224) | 186 | 0 | 0.03 ms |
| python-r2 | 198 / 0 / 0 / 0 (n=198) | 186 / 0 / 38 / 0 (n=224) | 186 | 0 | 0.02 ms |
| robotics-v2 | 36 / 0 / 0 / 0 (n=36) | 20 / 0 / 3 / 0 (n=23) | 20 | 0 | 0.13 ms |

Every held-out number equals or beats the shipped one; no false yes anywhere; the one
wrong answer (git) is the shipped organ's own wrong answer. Binary: 1,279,128 bytes;
cold start about 15 ms (the self tests run at load); round-trip p50 0.06 to 0.21 ms.

### Named held-out misses (all shared with the shipped organ unless marked)

- networking (withheld): "Which prefix would you use to fit 4000 devices?", "... 200 devices?", "... 2 devices?"
- cyber (withheld): "A password is 12 characters long, chosen randomly from alphanumeric characters. Entropy in bits?" (**the organ answers this one**; the kernel refuses because its enclosure of 12 log2 62 is not tight enough); "Worst-case time to exhaust all 8-character passwords from mixed-case letters at 1 billion guesses per second?", "... 6-character passwords from lowercase letters at 10 billion ...", "... 10-character passwords from alphanumeric characters at 100 billion ...". Dev: "What is the entropy in bits of a random 20-character password using alphanumeric characters?" (**organ answers**).
- git: wrong, "What command brings back the stash in git?" (answers `git stash`); withheld, "What git command cherry-picks a commit?", "What git command shows the log of commits?"
- python and python-r2 (same 38 withheld, all also withheld by the organ): "Explain what X does in Python." for ImportWarning, NotADirectoryError, super, ModuleNotFoundError, hasattr, isinstance, PermissionError, TabError, getattr, PendingDeprecationWarning, Exception, bytearray, BytesWarning, bytes, TimeoutError, UnicodeWarning, FutureWarning, GeneratorExit, hex, UnicodeEncodeError, classmethod, StopIteration, MemoryError, ProcessLookupError, print, compile, exec, str, NotImplementedError, sum, next, UserWarning, int; "What arguments does Python's X take?" for format, aiter, ord, all, divmod.
- robotics-v2 (withheld): the three "A rover's wheels are ... apart ... What is its rate of turn in rad/s?" items (0.6 m / 1.5 and 1.1 m/s; 0.2 m / 0.35 and 0.25 m/s; 0.45 m / 0.5 and 0.9 m/s).

## What S15b changed

- Proofs: `field_count_bound` (the inner subset step reads the `Some` from `all`);
  `git_commands_distinct` (quote characters are now `STR 0x22`-style literals, so the
  simplifier decides literal inequality with `add_Literal_assoc`); `agg_sum_ints`
  (`map (int_of o SInt) xs = xs`); `py_found_in_table`, `py_missing_sound`,
  `py_lookup_complete`, `py_withheld_iff` rewritten as structured proofs (the old ones
  were split into 6-tuples by `auto` and failed).
- Removed three theorems proved `by eval`: evaluation is a code-generator oracle, which
  the export's oracle check refuses. `py_names_distinct` ("distinct (map pe_name
  py_entries)"), `py_names_split` (each name is prefix.short, or short when the prefix is
  empty) and `py_table_size` ("length py_entries = 856") are now `tables_check.py`
  checks; nothing in the resolver depends on them.
- Explicit `HOL-Library.Code_Target_Numeral` imports in `Computing_Num.thy` (inherited by
  every kernel theory) and `Computing_Export.thy`; it was already loaded through
  Approximation, and builds stayed small (about 3 minutes, no runaway).
- Export: `@{thms}` instead of `@{thm}` (some listed facts have several parts).
- Recognizer: the regex port folds pattern letters to lower case, so the case-sensitive
  organ patterns (`SIG[A-Z0-9]+`, `\bSIG`, `chmod -R`, the symbolic `rwx` mode with
  `S`/`T`, and the python name patterns) are now matched on the lower-cased text and
  checked against the original characters, as d85f26c prescribes. Before this the
  python candidates with capitals (`ImportWarning`, ...) and SIG names could not match.
- Embedded value field: the exact integer or ten significant digits (`val_str`); it was
  the reply text's four-decimal form, which gave `0.001` for a 1.024 ms period.

## Theorem statements (the 65 facts the export checks for oracles)

- `net_props`: "net_of x p mod bsize p = 0 /\ net_of x p <= x /\ x < net_of x p + bsize p"
- `net_unique`: assumes "n mod bsize p = 0" "n <= x" "x < n + bsize p" shows "net_of x p = n"
- `bcast_props`: "x <= bcast_of x p /\ bcast_of x p < x + bsize p /\ (bcast_of x p + 1) mod bsize p = 0"
- `mask_wildcard_complement`: "mask_val p + wild_val p = 4294967295"
- `usable_hosts`: assumes "p <= 30" shows "net_of x p + 1 <= bcast_of x p - 1 /\ usable p = (bcast_of x p - 1) - (net_of x p + 1) + 1"
- `mask_prefix_iff`: "mask_prefix m = Some p <-> p <= 32 /\ ip_ok m /\ ip_val m = mask_val p"
- `pfh_smallest`: assumes "pfh n = Some q" shows "1 <= q /\ q <= 30 /\ n <= usable q /\ (ALLq'. q < q' --> q' <= 30 --> ~ n <= usable q')"
- `pfh_complete`: "pfh n = None ==> 1 <= q' ==> q' <= 30 ==> ~ n <= usable q'"
- `net_private_iff`: "is_private a <-> (EXb p. (b, p) : set priv_blocks /\ b <= ip_val a /\ ip_val a < b + 2 ^ (32 - p))"
- `net_mask_value`: assumes "net_decline (NReq ips ms ps (BMask p)) = None" shows "EXm. net_value (BMask p) = VIp m /\ ip_ok m /\ mask_prefix m = Some p /\ ip_val m = 4294967296 - 2 ^ (32 - p)"
- `net_network_value`: assumes "net_decline (NReq ips ms ps (BAddr W_network a p)) = None" shows "EXn. net_value (BAddr W_network a p) = VIp n /\ ip_ok n /\ ip_val n mod 2 ^ (32 - p) = 0 /\ ip_val n <= ip_val a /\ ip_val a < ip_val n + 2 ^ (32 - p) /\ p <= 32"
- `net_broadcast_value`: assumes "net_decline (NReq ips ms ps (BAddr W_broadcast a p)) = None" shows "EXb. net_value (BAddr W_broadcast a p) = VIp b /\ ip_ok b /\ ip_val a <= ip_val b /\ ip_val b < ip_val a + 2 ^ (32 - p) /\ (ip_val b + 1) mod 2 ^ (32 - p) = 0"
- `net_subnets_value`: assumes "net_decline (NReq ips ms ps (BSubnets m n)) = None" shows "n <= m /\ net_value (BSubnets m n) = VNat (2 ^ (m - n)) /\ (2::nat) ^ (m - n) * 2 ^ (32 - m) = 2 ^ (32 - n)"
- `net_forhosts_value`: assumes "net_decline (NReq ips ms ps (BForHosts n)) = None" shows "EXq. net_value (BForHosts n) = VNat q /\ 1 <= q /\ q <= 30 /\ n <= usable q /\ (ALLq'. q < q' --> q' <= 30 --> ~ n <= usable q')"
- `net_reply_answered_iff`: "answered (net_reply r) <-> net_decline r = None"
- `round_he_close`: "|of_int (round_he q) - q| <= 1 / 2"
- `round_he_tie_even`: assumes "q = of_int n + 1 / 2" shows "even (round_he q)"
- `to_fixed_sound`: assumes x: "x :\<^sub>r X" and d: "to_fixed k X = Some d" shows "|dec_val d - x| <= pow10 (- int k) * (101 / 200)"
- `enclose_fixed_sound`: assumes "enclose_fixed k e = Some d" shows "|dec_val d - interpret_floatarith e []| <= pow10 (- int k) * (101 / 200)"
- `emb_ctc_value`: assumes "emb_decline (ECtc fc P ft bits) = None" shows "EXo'. emb_value (ECtc fc P ft bits) = of_int o' /\ 0 <= o' /\ o' <= 2 ^ bits - 1 /\ |of_int o' - ctc_raw fc P ft| <= 1 / 2 /\ 0 < fc /\ 0 < ft /\ 0 < P"
- `emb_ctc_gives`: assumes "emb_decline (ECtc fc P ft bits) = None" shows "0 < P /\ 0 < fc /\ (fc / (of_nat P * (1 + emb_value (ECtc fc P ft bits)))) * (of_nat P * (1 + emb_value (ECtc fc P ft bits))) = fc"
- `emb_ubrr_value`: assumes "emb_decline (EUbrr fc B) = None" shows "EXu. emb_value (EUbrr fc B) = of_int u /\ 0 <= u /\ |of_int u - ubrr_raw fc B| <= 1 / 2"
- `emb_timer_identities`: assumes "0 < fc" "0 < P" shows "emb_value (ETick fc P False) * fc = of_nat P" and "emb_value (ETick fc P True) * of_nat P = fc" and "emb_value (EOvf bits fc P False) * fc = 2 ^ bits * of_nat P" and "emb_value (EOvf bits fc P False) * emb_value (EOvf bits fc P True) = 1"
- `emb_uart_identities`: assumes "0 < B" shows "emb_value (EUartTp B d p s) * of_nat (frame_bits d p s) = B" and "emb_value (EUartTime B k d p s) * B = k * of_nat (frame_bits d p s)"
- `cyb_base64_len`: fixes n :: nat shows "0 < n ==> 8 * n <= 6 * (4 * ((n + 2) div 3)) /\ 6 * (4 * ((n + 2) div 3) - 4) < 8 * n"
- `cyb_brute_value`: assumes "cyb_decline (CBrute avg cs L (Some R)) = None" shows "0 < R /\ cyb_value (CBrute avg cs L (Some R)) * R * (if avg then 2 else 1) = of_nat (csize cs) ^ L"
- `cyb_entropy_sound`: assumes "cyb_entropy cs L = Some d" shows "|dec_val d - real L * log 2 (real (csize cs))| <= |real L * log 2 (real (csize cs))| / 1000 + 1 / 1000000000"
- `rob_diff_identities`: assumes "0 < L" shows "diff_value RW_angular a b L * L = b - a" and "diff_value RW_linear a b L * 2 = b + a" and "a ~= b ==> diff_value RW_radius a b L * |b - a| = L / 2 * |b + a|"
- `rob_wheel_sound`: assumes "rob_pi_dec (RWheel rpm D) = Some d" shows "|dec_val d - rl rpm * pi * rl D / 60| <= pow10 (- 3) * (101 / 200)"
- `rob_enc_sound`: assumes "rob_pi_dec (REnc k P D) = Some d" shows "|dec_val d - rl (k / P) * pi * rl D| <= pow10 (- 3) * (101 / 200)"
- `rob_fk_sound`: assumes "rob_fk_dec l1 l2 a1 a2 = Some (dx, dy)" shows "|dec_val dx - (rl l1 * cos (rl a1 * pi / 180) + rl l2 * cos (rl a1 * pi / 180 + rl a2 * pi / 180))| <= pow10 (- 3) * (101 / 200) /\ |dec_val dy - (rl l1 * sin (rl a1 * pi / 180) + rl l2 * sin (rl a1 * pi / 180 + rl a2 * pi / 180))| <= pow10 (- 3) * (101 / 200)"
- `sym_mode_sym`: "sym_of_mode (mode_of_sym s) = s"
- `mode_sym_mode`: assumes "sp < 8" "u < 8" "g < 8" "o' < 8" shows "mode_of_sym (sym_of_mode (Mode sp u g o')) = Mode sp u g o'"
- `item_vals_mem`: assumes "item_vals lo hi it = Some vs" shows "EXa b s. item_params lo hi it = Some (a, b, s) /\ lo <= a /\ a <= b /\ b <= hi /\ 1 <= s /\ (ALLx. x : set vs <-> a <= x /\ x <= b /\ s dvd (x - a))"
- `field_count_bound`: assumes "field_count lo hi its = Some n" "its ~= []" shows "1 <= n /\ n <= hi - lo + 1"
- `sig_table_bijective`: "distinct (map fst sig_table) /\ distinct (map snd sig_table) /\ (ALLp : set sig_table. sig_num (fst p) = Some (snd p) /\ sig_name (snd p) = Some (fst p))"
- `umask_file_bits`: assumes "u < 8" shows "bits3 (file_digit u) = (~ fst (bits3 u), ~ fst (snd (bits3 u)), False) /\ file_digit u < 8"
- `umask_dir_bits`: assumes "u < 8" shows "bits3 (dir_digit u) = (~ fst (bits3 u), ~ fst (snd (bits3 u)), ~ snd (snd (bits3 u))) /\ dir_digit u < 8"
- `lin_reply_answered_iff`: "answered (lin_reply r) <-> lin_decline r = None /\ lin_signal_ok r"
- `git_warns_exactly_destructive`: "filter gwarn all_intents = [G_reset_hard, G_restore]"
- `git_commands_distinct`: "distinct (map gcmd all_intents)"
- `git_reply_states_command`: "response (git_reply i) = STR ''The command is '' + bquote + gcmd i + bquote + STR '' - it '' + gnote i + STR ''.'' /\ answered (git_reply i) /\ stated (git_reply i) = Some (gcmd i)"
- `py_found_in_table`: "py_resolve cs = PyFound nm ==> EXe : set py_entries. pe_name e = nm"
- `py_missing_sound`: "py_resolve cs = PyMissing m a ==> py_lookup (m + STR ''.'' + a) = None /\ (m : set py_modules \/ m : set py_types)"
- `py_signature_states_row`: assumes "py_resolve cs = PyFound nm" "py_lookup nm = Some e" "pe_sig e ~= STR ''''" shows "answered (py_reply PQ_signature cs) /\ stated (py_reply PQ_signature cs) = Some (pe_sig e) /\ response (py_reply PQ_signature cs) = nm + STR '' - signature '' + pe_sig e + STR '' (Python '' + py_version + STR '').''"
- `py_withheld_iff`: "~ answered (py_reply q cs) <-> py_resolve cs = PyNone \/ (EXm a. py_resolve cs = PyMissing m a) \/ (EXns. py_resolve cs = PyAmbig ns) \/ (EXnm e. py_resolve cs = PyFound nm /\ py_lookup nm = Some e /\ q = PQ_signature /\ pe_sig e = STR '''')"
- `py_lookup_sound`: "py_lookup nm = Some e ==> e : set py_entries /\ pe_name e = nm"
- `py_lookup_complete`: "e : set py_entries ==> py_lookup (pe_name e) ~= None"
- `isort_perm`: "set (isort le xs) = set xs /\ length (isort le xs) = length xs"
- `isort_sorted`: assumes "ALLa b. le a b \/ le b a" "ALLa b c. le a b --> le b c --> le a c" shows "sorted_wrt le (isort le xs)"
- `where_keeps_exactly_true`: "r : set (where_rows cols (Some c) rows) <-> r : set rows /\ eval_cond cols r c = Some True"
- `agg_count_skips_null`: "agg_eval AF_count False vs = Some (SInt (int (length (filter (%v. v ~= SNull) vs))))"
- `agg_sum_empty`: "agg_eval AF_sum d [] = Some SNull /\ agg_eval AF_count d [] = Some (SInt 0) /\ agg_eval AF_avg d [] = Some SNull"
- `agg_sum_ints`: "agg_eval AF_sum False (map SInt xs) = Some (if xs = [] then SNull else SInt (sum_list xs))"
- `agg_avg_value`: assumes "vs ~= []" "ALLv : set vs. v ~= SNull /\ ~ is_text v" shows "agg_eval AF_avg False vs = Some (SReal (sum_list (map sv_num vs) / of_nat (length vs)))"
- `exec_unknown_column`: "find (%c. col_index cols (fst c) = None) (item_cols its @ (case cnd of None => [] | Some c => cond_cols c) @ (case grp of None => [] | Some g => [g]) @ map fst ordl) = Some c ==> exec_sq (STable tn to cols rows) (SQ dst its tb cnd grp ordl lmt) = SErr (STR ''no such column: '' + snd c)"
- `sql_reply_answered_iff`: "answered (sql_reply r) <-> (case r of SNeedData => False | SSetupErr _ => False | SUnsupported => False | _ => True)"
- `validity_unbalanced_is_no`: "~ paren_balance ts ==> strip_semi ts = ts ==> ts = TW (STR ''SELECT'') o' # r ==> sql_validity ts = V_no"
- `sql_answer_unparsed_withheld`: "parse_query q = None ==> ~ answered (sql_answer setup q)"


Weak statements, named so nobody counts them as more than they are:
`emb_ctc_gives` is essentially x / y * y = x with y > 0; `git_reply_states_command` and
`py_signature_states_row` restate the reply's definition; `sql_reply_answered_iff` is a
case table. The substantive ones are the networking block theorems, `pfh_smallest` /
`pfh_complete`, the rounding and enclosure bounds, `item_vals_mem` / `field_count_bound`,
`sig_table_bijective`, `sym_mode_sym` / `mode_sym_mode`, `py_found_in_table` /
`py_missing_sound`, `isort_sorted`, `where_keeps_exactly_true` and the aggregate facts.

## Remaining

- **`interp_ln_fa` (deferred after two failed builds, rule of the brief).** Intended
  statement, verbatim: `interpret_floatarith (ln_fa n) xs = ln (real n)`, with `ln_fa n`
  computing ln n as k ln 2 - ln (2^k / n) when 2^k is within a factor 1.5 of n. It would let
  the kernel state the entropy of 62-symbol passwords (two organ disagreements above,
  +1 held-out, +1 dev). Build 15 failed on `rl (2 ^ k)` (fixed by `of_rat_power`), build 16
  on the else branch, whose `simp` cannot use the negated condition; `using False by (rule
  if_not_P)` after `unfolding ln_fa_def Let_def` should close it. Full text:
  `var/computing/deferred_ln_fa.thy`. (Raising the precision to 256 bits instead also
  works but costs about 335 ms per entropy question and 0.7 s cold start; rejected.)
- The three removed `by eval` table theorems could come back as real proofs (for example
  by a sorted-list argument); today `tables_check.py` checks them.
- Family mode (no `--specialist`) is built but not scored.

## Untrusted parts

`recognizer.sml` (hand port of the organs' regular expressions and branch order,
including the SQL lexer), `regex.sml` (lane G's matcher, identical to the quantity copy at
d85f26c), `main.sml` (JSON framing), `tables_check.py` (a transcription check, not a proof).

## Receipt

`var/native-scaffold/sessions/61b7acc57a143f43/receipt.json`, status `passed`, attempt
`9baeccf1926e4db3978cd43b7df0ef80`
(`var/native-scaffold/sessions/61b7acc57a143f43/attempts/9baeccf1926e4db3978cd43b7df0ef80/receipt.json`),
marker `VERI7VN_COMPUTING PASS theorems=65 oracles=0`. Generated SML sha256
`02c92289cde082b89ba33a362962e74062fb5f36437ab5143dfb457a3220e18b`, binary sha256
`fb520e1d514923ee20ef95af91f01e795c249a6ff839092655747018b5ddcef3`.

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Computing --session-root src/extract/computing \
  --expect 'VERI7VN_COMPUTING PASS' --timeout 600
python3 -B src/extract/computing/tables_check.py          # TABLES PASS
sh src/extract/computing/build.sh                          # var/computing/bin/computing
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/parity/harness.py \
  --answerer "var/computing/bin/computing --specialist {id}" \
  --specialist networking,embedded,cyber,linux-v2,git,sql,python,python-r2,robotics-v2 \
  --split both --out var/computing/parity
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/computing/score.py
```
