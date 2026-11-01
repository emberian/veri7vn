# Lane S16-humanities: music-v2-r2, music-v2, grammar, mythology, ushistory, library, government (handoff, 2026-10-17)

Seven shipped Oracle7 specialists are now verified HOL kernels, exported to Standard ML and
compiled with the MLton inside Isabelle into one 629 KB binary, `var/humanities/bin/humanities`
(not committed). Files: `src/extract/humanities/` ([README](../../src/extract/humanities/README.md)).
Commit: `36f1fa4`.

## Result on the shipped panels

Scored with `tools/parity/harness.py` (`--answerer "var/humanities/bin/humanities --specialist {id}"`,
both splits; decision is INCOMPLETE only because no head answerer ran). Right / wrong / valid item
withheld / false yes. The lane's `score.py` gives the same counts and also compares every reply with the
shipped organ: 0 disagreements in status and kind on every panel, and reply text identical (after the
organ's x, / and sharp signs are written as plain ASCII) on all 28 to 128 questions per panel. Shipped
held-out numbers come from each `verdict_heldout.json`.

| Specialist | dev | held-out | Shipped held-out | p50 per question (round trip) vs budget |
|---|---|---|---|---|
| music-v2-r2 | 64 / 0 / 0 / 0 | **64 / 0 / 0 / 0** | 64/64, 0 wrong, 0 false yes | 0.06 ms vs 50 ms |
| music-v2 | 64 / 0 / 0 / 0 | **64 / 0 / 0 / 0** | 64/64 | 0.05 ms vs 50 ms |
| grammar | 15 / 0 / 0 / 0 | **15 / 0 / 0 / 0** | 15/15 | 0.04 ms vs 50 ms |
| mythology | 13 / 0 / 0 / 0 | **13 / 0 / 0 / 0** | 13/13 | 0.08 ms vs 50 ms |
| ushistory | 12 / 0 / 0 / 0 | **12 / 0 / 0 / 0** | 11/12 (the one miss is a head false yes) | 0.09 ms vs 50 ms |
| library | 15 / 0 / 0 / 0 | **14 / 0 / 1 / 0** | 14/15 | 0.05 ms vs 50 ms |
| government | 14 / 0 / 0 / 0 | **10 / 0 / 4 / 0** | 10/14 | 0.05 ms vs 50 ms |

Named misses (each is also unanswered by the shipped organ; the binary agrees with the organ on every question):
- library: "What is the equivalent ISBN-13 for ISBN-10 0306406152?" (the organ's conversion pattern does not match "equivalent ISBN-13 for").
- government: "What constitutional amendment limits the President to two terms?", "A candidate needs how many electoral votes to become President?", "How many judges sit on the US Supreme Court?", "What is the total number of US senators?".

Family mode (no `--specialist`; library, government, ushistory, mythology, grammar, music-v2-r2) gives
the same counts. Cold start 16 ms (5 runs), worst single question 13.5 ms (music: the verified
interval enclosure of a twelfth root of two), p50 under 0.25 ms.

The `value` field differs from the organ's in type for government (the binary states the subject text, the
organ the number); the reply text and the scorer's reading are identical.

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Humanities --session-root src/extract/humanities --expect 'VERI7VN_HUMANITIES PASS' --timeout 2400`
status `passed`; marker `VERI7VN_HUMANITIES PASS theorems=110 oracles=0` (in `var/native-scaffold/sessions/b16a2dc07aa92e52/smoke.log`;
receipt `var/native-scaffold/sessions/b16a2dc07aa92e52/receipt.json`, attempt `ed2ffbe2691b4f8d96c77d8e4c1296a0`).
The ML block in `Humanities_Export.thy` prints the marker only after `Thm_Deps.all_oracles` is empty for the 110
listed theorems and the compiled `all_self_test` holds. Sessions: `Veri7vn_Humanities_Base` (`base/`),
`_Music` (`music/`), `_Facts` (`facts/`), `Veri7vn_Humanities` (export).
Table check: `python3 src/extract/humanities/tables_check.py` PASS, 66 checks.

## Design

- `base/Hum_Num.thy`: rounding and layout copied from lane G; `fixed3` (three decimals, the music organ's `%.3f`,
  exact tie up) and `enclose3` (verified float-interval enclosure to a thousandth); `pick`, the first match on an
  ordered rule list, proved to return the first set bit (`pick_some`, `pick_none`).
- `music/Music.thy`: intervals, key signatures, scales, relative keys, MIDI, durations as modular arithmetic over 12 and
  over the seven letters, frequency 440 x 2^((m-69)/12) and cents 1200 log2(f2/f1) via `HOL-Decision_Procs.Approximation`.
  music-v2 and music-v2-r2 share the kernel; v2-r2 differs only in the recognizer's boundary rule.
- `facts/`: grammar, mythology, ushistory, library (check digits proved against their defining congruences),
  government. The recognizer matches the organs' patterns and passes one bit per ordered rule; the kernel takes
  the first set bit.

## Theorem statements (verbatim; proofs in the files named)

```
theorem keysig_formula_is_table:
  assumes "\<bar>snd n\<bar> \<le> 2"
  shows "keysig_table n m = keysig_of n m"

theorem keysig_circle_of_fifths:
  "(nat_pc L + a) mod 12 = (7 * fifths L a m + (if m then 9 else 0)) mod 12"

theorem rel_key_pitch:
  assumes "\<bar>snd n\<bar> \<le> 2"
  shows "pcn (rel_key n m) = (pcn n + (if m then 3 else 9)) mod 12"

theorem rel_key_letter:
  "lidx (fst (rel_key n m)) = (lidx (fst n) + (if m then 2 else 5)) mod 7"

theorem rel_key_signature:
  assumes "\<bar>snd n\<bar> \<le> 2"
  shows "fifths (fst (rel_key n m)) (snd (rel_key n m)) (\<not> m) = fifths (fst n) (snd n) m"

theorem scale_steps_close: "sum_list (steps m) = 12"

theorem scale_note_letter: "fst (scale_note n m i) = lstep i (fst n)"

theorem scale_note_pitch: "pcn (scale_note n m i) = (pcn n + off_at m i) mod 12"

theorem scale_first: "\<bar>snd n\<bar> \<le> 2 \<Longrightarrow> scale_note n m 0 = n"

theorem scale_adjacent:
  assumes "i < 6"
  shows "lidx (fst (scale_note n m (Suc i))) = (lidx (fst (scale_note n m i)) + 1) mod 7"

theorem scale_adjacent_distance:
  assumes "i < 7"
  shows "(pcn (scale_note n m (Suc i)) - pcn (scale_note n m i)) mod 12 = steps m ! i mod 12"

theorem scale_matches_signature:
  assumes "\<bar>snd n\<bar> \<le> 2" "keysig_of n m = Some k"
  shows "sig_ok (scale_notes n m) \<and> count_acc 1 (scale_notes n m) = nat k
         \<and> count_acc (-1) (scale_notes n m) = nat (- k)"

theorem qual_rows_rule:
  "\<forall>r \<in> set qual_rows. (case r of (s, k, q) \<Rightarrow>
      k = major_base s + qdelta (perfect_type s) q
      \<and> (perfect_type s \<longrightarrow> q \<noteq> Q_maj \<and> q \<noteq> Q_min)
      \<and> (\<not> perfect_type s \<longrightarrow> q \<noteq> Q_perf))"

theorem qual_rows_distinct:
  "distinct (map (\<lambda>r. (fst r, fst (snd r))) qual_rows)"

theorem qual_lookup_sound:
  "qual_lookup s k = Some q \<Longrightarrow> (s, k, q) \<in> set qual_rows"

theorem midi_pitch: "midi_num n oct mod 12 = pcn n"

theorem between_sound:
  assumes "between n1 o1 n2 o2 = Some (st, k)"
  shows "0 \<le> k \<and> k \<le> 12 \<and> st \<le> 7 \<and> (pcn n2 - pcn n1 - k) mod 12 = 0
         \<and> (\<forall>x y. o1 = Some x \<longrightarrow> o2 = Some y \<longrightarrow> midi_num n2 y - midi_num n1 x = k)
         \<and> (st < 7 \<longrightarrow> st = (lidx (fst n2) + 7 - lidx (fst n1)) mod 7)"

theorem midi_name_roundtrip:
  "midi_num (chroma_at k) (k div 12 - 1) = k"

theorem dur_defining: "b \<noteq> 0 \<Longrightarrow> dur_secs b dotted v * b = 60 * beats dotted v"

theorem dur_quarter_60: "dur_secs 60 False D_quarter = 1"

theorem beats_halving:
  "beats_of D_whole = 2 * beats_of D_half \<and> beats_of D_half = 2 * beats_of D_quarter
   \<and> beats_of D_quarter = 2 * beats_of D_eighth \<and> beats_of D_eighth = 2 * beats_of D_sixteenth
   \<and> beats_of D_sixteenth = 2 * beats_of D_thirty_second"

theorem dotted_adds_half: "beats True v = beats False v + beats False v / 2"

theorem freq_a4: "phys_freq A 69 = rl A"

theorem freq_octave: "phys_freq A (k + 12) = 2 * phys_freq A k"

theorem freq_semitone:
  assumes "0 < A"
  shows "(phys_freq A (k + 1) / phys_freq A k) ^ 12 = 2"

theorem cents_model:
  assumes "0 < f1" "0 < f2"
  shows "2 powr (phys_cents f1 f2 / 1200) = rl f2 / rl f1"

theorem key_value:
  "mkernel (MKey n m) = OSig k \<Longrightarrow>
     spellable n \<and> k = fifths (fst n) (snd n) m \<and> \<bar>k\<bar> \<le> 7
     \<and> (nat_pc (fst n) + snd n) mod 12 = (7 * k + (if m then 9 else 0)) mod 12"

theorem key_theoretical:
  "mkernel (MKey n m) = Decline ImpKey \<longleftrightarrow> spellable n \<and> 7 < \<bar>fifths (fst n) (snd n) m\<bar>"

theorem key_matches_organ_table:
  "spellable n \<Longrightarrow> (mkernel (MKey n m) = OSig k) \<longleftrightarrow> keysig_table n m = Some k"

theorem relative_value:
  "mkernel (MRel n m) = ORel r \<Longrightarrow>
     r = rel_key n m \<and> pcn r = (pcn n + (if m then 3 else 9)) mod 12
     \<and> (spellable n \<longrightarrow> fifths (fst r) (snd r) (\<not> m) = fifths (fst n) (snd n) m)"

theorem scale_value:
  "mkernel (MScale n m) = OScale ns \<Longrightarrow>
     ns = scale_notes n m \<and> length ns = 7 \<and> hd ns = n \<and> sig_ok ns
     \<and> (\<forall>i::nat<7. pcn (ns ! i) = (pcn n + off_at m i) mod 12 \<and> fst (ns ! i) = lstep i (fst n))"

theorem scale_double_accidental:
  "mkernel (MScale n m) = Decline ImpScale \<longleftrightarrow> spellable n \<and> \<not> sig_ok (scale_notes n m)"

theorem semitones_named:
  "mkernel (MSemis bs) = OSemis r \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length ivl_order \<and> bs ! i \<and> ivl_order ! i = r \<and> (\<forall>j<i. \<not> bs ! j)"

theorem semitones_named_none:
  "mkernel (MSemis bs) = Silent \<Longrightarrow> \<forall>i<length bs. i < length ivl_order \<longrightarrow> \<not> bs ! i"

theorem between_semitones:
  "mkernel (MBetween n1 o1 n2 o2 True) = OBetween k \<Longrightarrow>
     0 \<le> k \<and> k \<le> 12 \<and> (pcn n2 - pcn n1 - k) mod 12 = 0
     \<and> (\<forall>x y. o1 = Some x \<longrightarrow> o2 = Some y \<longrightarrow> midi_num n2 y - midi_num n1 x = k)"

theorem between_interval:
  "mkernel (MBetween n1 o1 n2 o2 False) = OIvl st k q \<Longrightarrow>
     (st, k, q) \<in> set qual_rows \<and> (pcn n2 - pcn n1 - k) mod 12 = 0
     \<and> (\<forall>x y. o1 = Some x \<longrightarrow> o2 = Some y \<longrightarrow> midi_num n2 y - midi_num n1 x = k)"

theorem midi_note_value:
  "mkernel (MMidiNote k) = OMidiNote nm oc \<Longrightarrow> 0 \<le> k \<and> k \<le> 127 \<and> midi_num nm oc = k"

theorem midi_note_impossible:
  "mkernel (MMidiNote k) = Decline w \<longleftrightarrow> w = ImpMidiNum \<and> 127 < k"

theorem midi_number_value:
  "mkernel (MMidiNum n oc) = OMidiNum k \<Longrightarrow>
     (\<exists>oct. oc = Some oct \<and> k = midi_num n oct) \<and> 0 \<le> k \<and> k \<le> 127"

theorem midi_number_underspecified: "mkernel (MMidiNum n None) = Decline UnderMidi"

theorem freq_underspecified: "mkernel (MFreq n None A) = Decline UnderFreq"

theorem freq_value:
  "mkernel (MFreq n oc A) = OFreq d \<Longrightarrow>
     (\<exists>oct. oc = Some oct \<and> \<bar>dec_val d - phys_freq A (midi_num n oct)\<bar> \<le> 1 / 1000) \<and> 0 < A"

theorem cents_value:
  "mkernel (MCents f1 f2) = OCents d \<Longrightarrow>
     0 < f1 \<and> 0 < f2 \<and> \<bar>dec_val d - phys_cents f1 f2\<bar> \<le> 1 / 1000"

theorem duration_value:
  "mkernel (MDur b dotted v) = ODur s \<Longrightarrow> 0 < b \<and> s * b = 60 * beats dotted v"

theorem mreply_answered_iff:
  "answered (mreply r) \<longleftrightarrow> (mkernel r \<noteq> Silent \<and> (\<forall>w. mkernel r \<noteq> Decline w))"

theorem mreply_silent: "mkernel r = Silent \<Longrightarrow> \<not> answered (mreply r) \<and> response (mreply r) = STR ''''"

theorem mreply_withheld_names_decline:
  "mkernel r = Decline w \<Longrightarrow> \<not> answered (mreply r) \<and> reply_kind (mreply r) = mdecl_kind w"

theorem ord_suffix_teens: "10 \<le> n mod 100 \<Longrightarrow> n mod 100 \<le> 20 \<Longrightarrow> ord_suffix n = STR ''th''"

theorem ord_suffix_units:
  assumes h: "\<not> (10 \<le> n mod 100 \<and> n mod 100 \<le> 20)"
  shows "(n mod 10 = 1 \<longrightarrow> ord_suffix n = STR ''st'') \<and> (n mod 10 = 2 \<longrightarrow> ord_suffix n = STR ''nd'')
     \<and> (n mod 10 = 3 \<longrightarrow> ord_suffix n = STR ''rd'')
     \<and> (n mod 10 \<noteq> 1 \<and> n mod 10 \<noteq> 2 \<and> n mod 10 \<noteq> 3 \<longrightarrow> ord_suffix n = STR ''th'')"

theorem first_known_some:
  assumes "first_known tbl cands = Some (w, v)"
  shows "map_of tbl w = Some v \<and>
         (\<exists>i<length cands. cands ! i = w \<and> (\<forall>j<i. map_of tbl (cands ! j) = None))"

theorem first_known_none:
  assumes "first_known tbl cands = None"
  shows "\<forall>c\<in>set cands. map_of tbl c = None"

theorem gkernel_row:
  assumes "gkernel r = GVal k w a b"
  shows "(k = G_pp \<longrightarrow> g_pp r \<and> map_of verbs w = Some (b, a))
       \<and> (k = G_past \<longrightarrow> \<not> g_pp r \<and> g_past r \<and> map_of verbs w = Some (a, b))
       \<and> (k = G_plural \<longrightarrow> \<not> g_pp r \<and> \<not> g_past r \<and> g_plural r \<and> map_of plurals w = Some a)
       \<and> (k = G_cmp \<longrightarrow> \<not> g_pp r \<and> \<not> g_past r \<and> \<not> g_plural r \<and> g_cmp r \<and> \<not> g_sup r
                      \<and> map_of compares w = Some (a, b))
       \<and> (k = G_sup \<longrightarrow> \<not> g_pp r \<and> \<not> g_past r \<and> \<not> g_plural r \<and> g_cmp r \<and> g_sup r
                      \<and> map_of compares w = Some (b, a))"

theorem gkernel_first_candidate:
  assumes "gkernel r = GVal k w a b"
  shows "\<exists>i<length (g_cands r). g_cands r ! i = w \<and> (\<forall>j<i. gunknown k (g_cands r ! j))"

theorem gkernel_silent_no_flag:
  "\<not> g_pp r \<Longrightarrow> \<not> g_past r \<Longrightarrow> \<not> g_plural r \<Longrightarrow> \<not> g_cmp r \<Longrightarrow> gkernel r = GSilent"

theorem gkernel_silent_unknown:
  assumes "gkernel r = GSilent" "g_pp r"
  shows "\<forall>c\<in>set (g_cands r). map_of verbs c = None"

theorem greply_answered_iff: "answered (greply r) \<longleftrightarrow> gkernel r \<noteq> GSilent"

theorem g2r_first_match:
  "ykernel (YG2R bs) = YG2RV g r \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length g2r_rows \<and> bs ! i \<and> (\<forall>j<i. \<not> bs ! j)
         \<and> fst (snd (g2r_rows ! i)) = g \<and> fst (snd (snd (g2r_rows ! i))) = r"

theorem r2g_first_match:
  "ykernel (YR2G bs) = YR2GV r g \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length r2g_rows \<and> bs ! i \<and> (\<forall>j<i. \<not> bs ! j)
         \<and> fst (snd (r2g_rows ! i)) = r \<and> snd (snd (r2g_rows ! i)) = g"

theorem g2r_no_bit: "ykernel (YG2R bs) = YSilent \<Longrightarrow> \<forall>i<length bs. i < length g2r_rows \<longrightarrow> \<not> bs ! i"

theorem domain_value:
  "ykernel (YDomain p dmn) = YDomV p' dmn' n \<Longrightarrow> p' = p \<and> dmn' = dmn \<and> domain_god p dmn = Some n"

theorem role_value:
  "ykernel (YRole n) = YRoleV d t \<Longrightarrow> map_of roles n = Some (d, t) \<and> (n, d, t) \<in> set roles"

theorem r2g_from_g2r:
  "\<forall>x\<in>set r2g_rows. x = (STR ''apollo'', STR ''Apollo'', STR ''Apollo'') \<or>
     (\<exists>r\<in>set g2r_rows. x = (snd (snd (snd r)), fst (snd (snd r)), fst (snd r)) \<and> snd (snd (snd r)) \<noteq> fst r)"

theorem yreply_answered_iff: "answered (yreply r) \<longleftrightarrow> ykernel r \<noteq> YSilent"

theorem nth_value:
  "hkernel (HNth n) = HNthV m name \<Longrightarrow> m = n \<and> 1 \<le> n \<and> n \<le> length presidents \<and> presidents ! (n - 1) = name"

theorem numbers_of_iff:
  "k \<in> set (numbers_of name) \<longleftrightarrow> 1 \<le> k \<and> k \<le> length presidents \<and> presidents ! (k - 1) = name"

theorem num_value:
  "hkernel (HNum bs) = HNumV name nums \<Longrightarrow>
     (\<forall>k. k \<in> set nums \<longleftrightarrow> 1 \<le> k \<and> k \<le> length presidents \<and> presidents ! (k - 1) = name)
     \<and> (\<exists>i. i < length bs \<and> i < length presidents \<and> bs ! i \<and> presidents ! i = name \<and> (\<forall>j<i. \<not> bs ! j))"

theorem event_value:
  "hkernel (HEvent bs us other) = HEvV yr sent \<Longrightarrow>
     (\<exists>i. i < length bs \<and> i < length events \<and> bs ! i \<and> (\<forall>j<i. \<not> bs ! j)
          \<and> fst (events ! i) = yr \<and> fst (snd (events ! i)) = sent
          \<and> (snd (snd (events ! i)) \<longrightarrow> us \<and> \<not> other))"

theorem event_silent_ambiguous:
  "pick bs events = Some (y, s, True) \<Longrightarrow> (\<not> us \<or> other) \<Longrightarrow> hkernel (HEvent bs us other) = HSilent"

theorem hreply_answered_iff: "answered (hreply r) \<longleftrightarrow> hkernel r \<noteq> HSilent"

theorem chk13_valid: "length xs = 12 \<Longrightarrow> wsum w13 0 (xs @ [chk13 xs]) mod 10 = 0"

theorem chk13_unique:
  "length xs = 12 \<Longrightarrow> y < 10 \<Longrightarrow> wsum w13 0 (xs @ [y]) mod 10 = 0 \<Longrightarrow> y = chk13 xs"

theorem chk13_valid_iff:
  "length xs = 12 \<Longrightarrow> y < 10 \<Longrightarrow> (chk13 xs = y) = (wsum w13 0 (xs @ [y]) mod 10 = 0)"

theorem chk10_valid: "length xs = 9 \<Longrightarrow> wsum w10 0 (xs @ [chk10 xs]) mod 11 = 0"

theorem chk10_unique:
  "length xs = 9 \<Longrightarrow> y \<le> 10 \<Longrightarrow> wsum w10 0 (xs @ [y]) mod 11 = 0 \<Longrightarrow> y = chk10 xs"

theorem chk10_valid_iff:
  "length xs = 9 \<Longrightarrow> y \<le> 10 \<Longrightarrow> (chk10 xs = y) = (wsum w10 0 (xs @ [y]) mod 11 = 0)"

theorem chkissn_valid: "length xs = 7 \<Longrightarrow> wsum wissn 0 (xs @ [chkissn xs]) mod 11 = 0"

theorem chkissn_unique:
  "length xs = 7 \<Longrightarrow> y \<le> 10 \<Longrightarrow> wsum wissn 0 (xs @ [y]) mod 11 = 0 \<Longrightarrow> y = chkissn xs"

theorem chkissn_valid_iff:
  "length xs = 7 \<Longrightarrow> y \<le> 10 \<Longrightarrow> (chkissn xs = y) = (wsum wissn 0 (xs @ [y]) mod 11 = 0)"

theorem issn_check_value:
  assumes "lkernel (LIsbn True ds raw ac av cv) = LIssnCheck ds' c"
  shows "ds' = ds \<and> length ds = 7 \<and> all_digits ds \<and> c = chkissn ds \<and> c \<le> 10
     \<and> wsum wissn 0 (ds @ [c]) mod 11 = 0"

theorem issn_valid_value:
  assumes "lkernel (LIsbn True ds raw ac av cv) = LIssnValid ds' ok c" "ds ! 7 \<le> 10"
  shows "ds' = ds \<and> length ds = 8 \<and> all_digits (take 7 ds) \<and> c = chkissn (take 7 ds)
         \<and> (ok \<longleftrightarrow> wsum wissn 0 ds mod 11 = 0)"

theorem isbn_convert_value:
  "lkernel (LIsbn False ds raw ac av cv) = LConv v \<Longrightarrow>
     length ds = 10 \<and> all_digits (take 9 ds) \<and> length v = 13
     \<and> take 3 v = [9, 7, 8] \<and> take 9 (drop 3 v) = take 9 ds
     \<and> wsum w13 0 v mod 10 = 0"

theorem isbn13_check_value:
  assumes "lkernel (LIsbn False ds raw ac av cv) = LI13Check ds' c"
  shows "ds' = ds \<and> length ds = 12 \<and> all_digits ds \<and> c = chk13 ds \<and> c < 10
     \<and> wsum w13 0 (ds @ [c]) mod 10 = 0"

theorem isbn10_check_value:
  assumes "lkernel (LIsbn False ds raw ac av cv) = LI10Check ds' c"
  shows "ds' = ds \<and> length ds = 9 \<and> all_digits ds \<and> c = chk10 ds \<and> c \<le> 10
     \<and> wsum w10 0 (ds @ [c]) mod 11 = 0"

theorem isbn13_valid_value:
  "lkernel (LIsbn False ds raw ac av cv) = LValid13 ds' ok c \<Longrightarrow>
     ds' = ds \<and> length ds = 13 \<and> all_digits ds \<and> c = chk13 (take 12 ds)
     \<and> (ok \<longleftrightarrow> wsum w13 0 ds mod 10 = 0)"

theorem isbn10_valid_value:
  assumes "lkernel (LIsbn False ds raw ac av cv) = LValid10 ds' ok c" "ds ! 9 \<le> 10"
  shows "ds' = ds \<and> length ds = 10 \<and> all_digits (take 9 ds) \<and> c = chk10 (take 9 ds)
         \<and> (ok \<longleftrightarrow> wsum w10 0 ds mod 11 = 0)"

theorem bad_length:
  "lkernel (LIsbn issn ds raw ac av cv) = LBadIsbn raw' n \<Longrightarrow> \<not> issn \<and> n = length ds \<and> (ac \<or> av)"

theorem bad_issn:
  "lkernel (LIsbn issn ds raw ac av cv) = LBadIssn raw' \<Longrightarrow>
     issn \<and> raw' = raw \<and> \<not> (ac \<and> length ds = 7 \<and> all_digits ds)
     \<and> \<not> (length ds = 8 \<and> all_digits (take 7 ds))"

theorem lcc_sub_value:
  "lkernel (LCode c) = LSubV c' t par \<Longrightarrow> c' = c \<and> map_of lcc_subs c = Some (t, par)"

theorem lcc_class_value:
  "lkernel (LCode c) = LClassV c' t \<Longrightarrow> c' = c \<and> map_of lcc_classes c = Some t \<and> map_of lcc_subs c = None"

theorem lcc_unused_value:
  "lkernel (LCode c) = LBadLetter c' \<Longrightarrow>
     c' = c \<and> c \<in> set unused_letters \<and> map_of lcc_classes c = None \<and> map_of lcc_subs c = None"

theorem lcc_subject_first_match:
  "lkernel (LSubject bs) = LSubjV s c d \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length subject_order \<and> bs ! i \<and> subject_order ! i = (s, c, d) \<and> (\<forall>j<i. \<not> bs ! j)"

theorem lreply_answered_iff: "answered (lreply r) \<longleftrightarrow> \<not> lwithheld (lkernel r)"

theorem amendments_count: "length amendments = 27"

theorem articles_count: "length articles = 7"

theorem topics_are_amendments: "\<forall>n\<in>set topic_nums. 1 \<le> n \<and> n \<le> length amendments"

theorem electors_sum:
  "fst (fact_rows ! 2) = fst (fact_rows ! 1) + fst (fact_rows ! 0) + 3"

theorem electoral_majority:
  "fst (fact_rows ! 3) = fst (fact_rows ! 2) div 2 + 1"

theorem amendment_count_fact: "fst (fact_rows ! 4) = length amendments"

theorem bill_of_rights_is_first_ten:
  "fst (fact_rows ! 12) = 10 \<and> 10 \<le> length amendments"

theorem topic_value:
  "vkernel (VTopic bs) = VTopicV n t \<Longrightarrow>
     1 \<le> n \<and> n \<le> 27 \<and> amendments ! (n - 1) = t \<and>
     (\<exists>i. i < length bs \<and> i < length topic_nums \<and> bs ! i \<and> topic_nums ! i = n \<and> (\<forall>j<i. \<not> bs ! j))"

theorem amend_value:
  "vkernel (VAmend n) = VAmendV m t \<Longrightarrow> m = n \<and> 1 \<le> n \<and> n \<le> 27 \<and> amendments ! (n - 1) = t"

theorem amend_impossible:
  "vkernel (VAmend n) = VImposs m \<longleftrightarrow> m = n \<and> (n < 1 \<or> 27 < n)"

theorem article_value:
  "vkernel (VArticle n) = VArtV m t \<Longrightarrow> m = n \<and> 1 \<le> n \<and> n \<le> 7 \<and> articles ! (n - 1) = t"

theorem fact_value:
  "vkernel (VFact bs) = VFactV v s \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length fact_rows \<and> bs ! i \<and> fact_rows ! i = (v, s) \<and> (\<forall>j<i. \<not> bs ! j)"

theorem vreply_answered_iff:
  "answered (vreply r) \<longleftrightarrow> (vkernel r \<noteq> VSilent \<and> (\<forall>n. vkernel r \<noteq> VImposs n))"
```

## Untrusted parts

`regex.sml` (lane G's matcher, with the S17 fix, plus `compileCS` for case-sensitive organ patterns), `recognizer.sml`
(hand port of the organs' regexes, branch order and `narrow_v1`), `rules.sml` (the ordered pattern lists of ushistory
events and government topics and facts, compared with the organs by `tables_check.py`), `main.sml` (JSON framing). Tables are
HOL constants checked by `tables_check.py`, which is a text comparison, not a proof.

## Limits and remaining work

- Finite facts about the lookup tables (every Greek domain god has a Roman name; the derived Roman-to-Greek table inverts
  Greek-to-Roman; LCC main-class letters are the alphabet minus I, O, W, X, Y; every subject names a described code) were
  stated as `code_simp` lemmas and dropped after `code_simp` did not evaluate them within the two attempts; they are covered
  by the table derivation and `tables_check.py`, not by theorems. Remaining entry: prove them with `list_all` unfolding.
- The recognizer's reading of free text is not verified; the kernels are only as right as the bits and numbers it passes.
- Music frequencies and cents are stated to three decimals, and the enclosure is declined (Imprecise) if too wide.
- Not run: Oracle7 head composition (rules 1 and 2 of the gate).

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Humanities --session-root src/extract/humanities --expect 'VERI7VN_HUMANITIES PASS' --timeout 2400
python3 src/extract/humanities/tables_check.py
sh src/extract/humanities/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "var/humanities/bin/humanities --specialist {id}" --specialist music-v2-r2,music-v2,grammar,mythology,ushistory,library,government --split both --out var/humanities/parity
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/humanities/score.py
```
