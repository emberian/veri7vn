theory Numerics
  imports Computing_Num
begin

text \<open>Lane S15-computing: the three numeric specialists of the family.
@{text embedded} (microcontroller timing; all exact rationals), @{text cyber}
(defensive security arithmetic; exact except entropy, which needs log2) and
@{text robotics} (kinematics; exact except pi, cos and sin). Sources:
upstream/root/specialists/{embedded,cyber,robotics-v2}/organ_*.py.\<close>

definition sintz :: "int \<Rightarrow> String.literal" where "sintz i = show_int i"
definition snat :: "nat \<Rightarrow> String.literal" where "snat n = lit (digits n)"

section \<open>Embedded\<close>

datatype eunit = E_char | E_byte

datatype ereq =
    EAddr nat "nat option"
  | EUbrr rat rat
  | EUartTp eunit rat nat nat nat
  | EUartTime eunit rat rat nat nat nat
  | ECtc rat nat rat nat
  | EOvf nat rat nat bool
  | ETick rat nat bool

datatype edecl = E_zero | E_nofit | E_slow | E_mapping

definition frame_bits :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where "frame_bits d p s = 1 + d + p + s"

definition ctc_raw :: "rat \<Rightarrow> nat \<Rightarrow> rat \<Rightarrow> rat" where
  "ctc_raw fc P ft = fc / (of_nat P * ft) - 1"

definition ubrr_raw :: "rat \<Rightarrow> rat \<Rightarrow> rat" where "ubrr_raw fc B = fc / (16 * B) - 1"

fun emb_decline :: "ereq \<Rightarrow> edecl option" where
  "emb_decline (EAddr n w) = None"
| "emb_decline (EUbrr fc B) = (if fc \<le> 0 \<or> B \<le> 0 then Some E_zero
     else if round_he (ubrr_raw fc B) < 0 then Some E_slow else None)"
| "emb_decline (EUartTp u B d p s) = (if B \<le> 0 then Some E_zero else if u = E_byte \<and> d \<noteq> 8 then Some E_mapping else None)"
| "emb_decline (EUartTime u B k d p s) = (if B \<le> 0 then Some E_zero else if u = E_byte \<and> d \<noteq> 8 then Some E_mapping else None)"
| "emb_decline (ECtc fc P ft bits) = (if fc \<le> 0 \<or> P = 0 \<or> ft \<le> 0 then Some E_zero
     else if round_he (ctc_raw fc P ft) < 0 \<or> 2 ^ bits - 1 < round_he (ctc_raw fc P ft) then Some E_nofit else None)"
| "emb_decline (EOvf bits fc P fl) = (if fc \<le> 0 \<or> P = 0 then Some E_zero else None)"
| "emb_decline (ETick fc P fl) = (if fc \<le> 0 \<or> P = 0 then Some E_zero else None)"

fun emb_value :: "ereq \<Rightarrow> rat" where
  "emb_value (EAddr n None) = 2 ^ n"
| "emb_value (EAddr n (Some w)) = of_nat (2 ^ n * w) / 8"
| "emb_value (EUbrr fc B) = of_int (round_he (ubrr_raw fc B))"
| "emb_value (EUartTp u B d p s) = B / of_nat (frame_bits d p s)"
| "emb_value (EUartTime u B k d p s) = k * of_nat (frame_bits d p s) / B"
| "emb_value (ECtc fc P ft bits) = of_int (round_he (ctc_raw fc P ft))"
| "emb_value (EOvf bits fc P False) = 2 ^ bits * of_nat P / fc"
| "emb_value (EOvf bits fc P True) = fc / (2 ^ bits * of_nat P)"
| "emb_value (ETick fc P False) = of_nat P / fc"
| "emb_value (ETick fc P True) = fc / of_nat P"

theorem emb_ctc_value:
  assumes "emb_decline (ECtc fc P ft bits) = None"
  shows "\<exists>o'. emb_value (ECtc fc P ft bits) = of_int o' \<and> 0 \<le> o' \<and> o' \<le> 2 ^ bits - 1 \<and>
           \<bar>of_int o' - ctc_raw fc P ft\<bar> \<le> 1 / 2 \<and> 0 < fc \<and> 0 < ft \<and> 0 < P"
proof -
  have c: "0 < fc" "0 < ft" "P \<noteq> 0" and r: "0 \<le> round_he (ctc_raw fc P ft)" "round_he (ctc_raw fc P ft) \<le> 2 ^ bits - 1"
    using assms by (auto simp: split: if_splits)
  show ?thesis using c r round_he_close[of "ctc_raw fc P ft"] by (auto intro!: exI[of _ "round_he (ctc_raw fc P ft)"])
qed

text \<open>The compare value @{text "N = 1 + value"} divides the clock by @{text "P * N"}; the achieved
frequency is @{text "fc / (P * N)"}. Rounding the divisor to the nearest integer moves the
frequency by at most @{text "ft / (2 N)"}: a count that is off by more than one half fails it.\<close>
theorem emb_ctc_freq_bound:
  assumes "emb_decline (ECtc fc P ft bits) = None"
  shows "\<bar>fc / (of_nat P * (1 + emb_value (ECtc fc P ft bits))) - ft\<bar>
           \<le> ft / (2 * (1 + emb_value (ECtc fc P ft bits)))"
proof -
  from emb_ctc_value[OF assms] obtain o' where
    o: "emb_value (ECtc fc P ft bits) = of_int o'" "0 \<le> o'"
       "\<bar>of_int o' - ctc_raw fc P ft\<bar> \<le> 1 / 2" "0 < fc" "0 < ft" "0 < P" by blast
  define n :: rat where "n = 1 + of_int o'"
  define x :: rat where "x = fc / (of_nat P * ft)"
  have g: "1 + emb_value (ECtc fc P ft bits) = n" unfolding n_def o(1) by (rule refl)
  have o0: "(0::rat) \<le> of_int o'" using o(2) by simp
  have n0: "0 < n" using o0 by (simp add: n_def add_pos_nonneg)
  have P0: "(0::rat) < of_nat P" using o(6) by simp
  have ne: "(of_nat P :: rat) \<noteq> 0" "ft \<noteq> 0" "n \<noteq> 0" using P0 o(5) n0 by simp_all
  have e1: "fc / (of_nat P * n) - ft = ft * (x - n) / n"
    using ne by (simp add: x_def field_simps)
  have xr: "x - n = - (of_int o' - ctc_raw fc P ft)" by (simp add: ctc_raw_def x_def n_def)
  have b: "\<bar>x - n\<bar> \<le> 1 / 2" unfolding xr abs_minus_cancel by (rule o(3))
  have fa: "\<bar>ft\<bar> = ft" and na: "\<bar>n\<bar> = n" using o(5) n0 by simp_all
  have "\<bar>fc / (of_nat P * n) - ft\<bar> = ft * \<bar>x - n\<bar> / n"
    by (simp add: e1 abs_mult abs_divide fa na)
  also have "\<dots> \<le> ft * (1 / 2) / n"
    using b o(5) n0 by (intro divide_right_mono mult_left_mono) simp_all
  also have "\<dots> = ft / (2 * n)" by simp
  finally show ?thesis unfolding g .
qed

theorem emb_ubrr_value:
  assumes "emb_decline (EUbrr fc B) = None"
  shows "\<exists>u. emb_value (EUbrr fc B) = of_int u \<and> 0 \<le> u \<and> \<bar>of_int u - ubrr_raw fc B\<bar> \<le> 1 / 2"
proof -
  have r: "0 \<le> round_he (ubrr_raw fc B)" using assms by (auto split: if_splits)
  show ?thesis using r round_he_close[of "ubrr_raw fc B"] by (auto intro!: exI[of _ "round_he (ubrr_raw fc B)"])
qed

theorem emb_timer_identities:
  assumes "0 < fc" "0 < P"
  shows "emb_value (ETick fc P False) * fc = of_nat P"
    and "emb_value (ETick fc P True) * of_nat P = fc"
    and "emb_value (EOvf bits fc P False) * fc = 2 ^ bits * of_nat P"
    and "emb_value (EOvf bits fc P False) * emb_value (EOvf bits fc P True) = 1"
proof -
  have f: "fc \<noteq> 0" and p: "(of_nat P :: rat) \<noteq> 0" using assms by simp_all
  show "emb_value (ETick fc P False) * fc = of_nat P" using f by simp
  show "emb_value (ETick fc P True) * of_nat P = fc" using p by simp
  show "emb_value (EOvf bits fc P False) * fc = 2 ^ bits * of_nat P" using f by simp
  show "emb_value (EOvf bits fc P False) * emb_value (EOvf bits fc P True) = 1" using f p by simp
qed

theorem emb_uart_identities:
  assumes "0 < B"
  shows "emb_value (EUartTp u B d p s) * of_nat (frame_bits d p s) = B"
    and "emb_value (EUartTime u B k d p s) * B = k * of_nat (frame_bits d p s)"
proof -
  have b: "B \<noteq> 0" using assms by simp
  show "emb_value (EUartTp u B d p s) * of_nat (frame_bits d p s) = B"
    by (simp add: frame_bits_def)
  show "emb_value (EUartTime u B k d p s) * B = k * of_nat (frame_bits d p s)" using b by simp
qed

theorem emb_address_value:
  "emb_value (EAddr n None) = 2 ^ n \<and> emb_value (EAddr n (Some w)) = of_nat (2 ^ n * w) / 8"
  by simp

text \<open>A physical bit address is an n-long Boolean vector. Every address
stores w bits; a byte contains eight bits, even when the total is fractional.
This capacity relation does not assume byte-aligned words.\<close>
definition bit_addresses :: "nat \<Rightarrow> bool list set" where
  "bit_addresses n = {xs. set xs \<subseteq> (UNIV :: bool set) \<and> length xs = n}"

lemma bit_addresses_card: "card (bit_addresses n) = 2 ^ n"
proof -
  have count: "card {xs. set xs \<subseteq> (UNIV :: bool set) \<and> length xs = n} = card (UNIV :: bool set) ^ n"
    by (rule card_lists_length_eq) simp
  show ?thesis using count unfolding bit_addresses_def by simp
qed

theorem emb_address_bytes_exact:
  "8 * emb_value (EAddr n (Some w)) = of_nat (card (bit_addresses n) * w)"
  by (simp add: bit_addresses_card)

theorem emb_address_locations:
  "emb_value (EAddr n None) = of_nat (card (bit_addresses n))"
  by (simp add: bit_addresses_card)

theorem emb_uart_byte_mapping:
  "emb_decline (EUartTp E_byte B d p s) = None \<Longrightarrow> d = 8"
  "emb_decline (EUartTime E_byte B k d p s) = None \<Longrightarrow> d = 8"
  by (auto split: if_splits)

definition g_emb :: "rat \<Rightarrow> String.literal" where
  "g_emb q = (if q \<noteq> 0 \<and> \<bar>q\<bar> < 1 / 1000 then sig4_str q
              else if \<bar>q\<bar> < 1000000 then fixed_str 4 q else commas (round_he q))"

definition secs_str :: "rat \<Rightarrow> String.literal" where
  "secs_str s = (if 1 \<le> s then g_emb s + STR '' s''
     else if 1 / 1000 \<le> s then g_emb (s * 1000) + STR '' ms''
     else if 1 / 1000000 \<le> s then g_emb (s * 1000000) + STR '' us''
     else g_emb (s * 1000000000) + STR '' ns'')"

fun uart_unit :: "eunit \<Rightarrow> rat \<Rightarrow> String.literal" where
  "uart_unit E_char k = (if k = 1 then STR '' character'' else STR '' characters'')"
| "uart_unit E_byte k = (if k = 1 then STR '' byte'' else STR '' bytes'')"

definition uart_label :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> String.literal" where
  "uart_label d p s = snat d + (if p = 0 then STR ''N'' else STR ''P'') + snat s"

definition emb_kind :: "ereq \<Rightarrow> String.literal" where
  "emb_kind r = (case r of
      EAddr _ None \<Rightarrow> STR ''address_space'' | EAddr _ (Some _) \<Rightarrow> STR ''address_bytes''
    | EUbrr _ _ \<Rightarrow> STR ''ubrr'' | EUartTp _ _ _ _ _ \<Rightarrow> STR ''uart_throughput''
    | EUartTime _ _ _ _ _ _ \<Rightarrow> STR ''uart_time'' | ECtc _ _ _ _ \<Rightarrow> STR ''ctc''
    | EOvf _ _ _ True \<Rightarrow> STR ''overflow_freq'' | EOvf _ _ _ False \<Rightarrow> STR ''overflow''
    | ETick _ _ True \<Rightarrow> STR ''tick_freq'' | ETick _ _ False \<Rightarrow> STR ''tick'')"

definition emb_decl_text :: "ereq \<Rightarrow> edecl \<Rightarrow> String.literal" where
  "emb_decl_text r d = (case (r, d) of
      (ECtc fc P ft bits, E_nofit) \<Rightarrow> STR ''The compare value would be '' + g_emb (ctc_raw fc P ft)
        + STR '', which does not fit a '' + snat bits + STR ''-bit timer (max '' + sintz (2 ^ bits - 1)
        + STR ''); use a larger prescaler.''
    | (EUbrr fc B, E_slow) \<Rightarrow> STR ''The clock is too slow for '' + g_emb B + STR '' baud in normal mode.''
    | (_, E_mapping) \<Rightarrow> STR ''A byte has eight bits. Specify how bytes map to these non-eight-bit UART characters, or ask for characters.''
    | _ \<Rightarrow> STR ''A zero clock, baud rate, prescaler or target frequency makes that undefined.'')"

definition emb_text :: "ereq \<Rightarrow> String.literal" where
  "emb_text r = (let v = emb_value r in case r of
      EAddr n None \<Rightarrow> STR ''That is '' + commas (int (2 ^ n)) + STR '' addressable locations (2^'' + snat n + STR '').''
    | EAddr n (Some w) \<Rightarrow> STR ''That is '' + g_emb v + STR '' bytes (2^'' + snat n
        + STR '' locations x '' + snat w + STR '' bits / 8).''
    | EUbrr fc B \<Rightarrow> (let u = round_he (ubrr_raw fc B); act = fc / (16 * (of_int u + 1)) in
        STR ''The UBRR value is '' + sintz u + STR '' (f_clk / (16 x baud) - 1 = '' + g_emb (ubrr_raw fc B)
        + STR '', rounded; actual '' + g_emb act + STR '' baud, error '' + g_emb ((act / B - 1) * 100) + STR ''%).'')
    | EUartTp u B d p s \<Rightarrow> STR ''The throughput is '' + g_emb v + uart_unit u 2 + STR '' per second ('' + g_emb B
        + STR '' baud / '' + snat (frame_bits d p s) + STR ''-bit frame, '' + uart_label d p s + STR '').''
    | EUartTime u B k d p s \<Rightarrow> STR ''It takes '' + secs_str v + STR '' ('' + g_emb k
        + uart_unit u k + STR '' x '' + snat (frame_bits d p s)
        + STR ''-bit frame / '' + g_emb B + STR '' baud, '' + uart_label d p s + STR '').''
    | ECtc fc P ft bits \<Rightarrow> (let o' = round_he (ctc_raw fc P ft) in
        STR ''The compare value is '' + sintz o' + STR '' (f_clk / (N x f) - 1 = '' + g_emb (ctc_raw fc P ft)
        + STR '', rounded; gives '' + g_emb (fc / (of_nat P * (1 + of_int o'))) + STR '' Hz).'')
    | EOvf bits fc P True \<Rightarrow> STR ''The overflow frequency is '' + g_emb v + STR '' Hz (f_clk / (2^'' + snat bits
        + STR '' x '' + snat P + STR '')).''
    | EOvf bits fc P False \<Rightarrow> STR ''The overflow period is '' + secs_str v + STR '' (2^'' + snat bits + STR '' x ''
        + snat P + STR '' / '' + g_emb fc + STR '' Hz).''
    | ETick fc P True \<Rightarrow> STR ''The timer frequency is '' + g_emb v + STR '' Hz ('' + g_emb fc + STR '' Hz / ''
        + snat P + STR '').''
    | ETick fc P False \<Rightarrow> STR ''The tick period is '' + secs_str v + STR '' ('' + snat P + STR '' / '' + g_emb fc + STR '' Hz).'')"

text \<open>The value field (lane S15b): the exact integer, or ten significant digits; the
reply text keeps the organ's four-decimal layout.\<close>
definition val_str :: "rat \<Rightarrow> String.literal" where
  "val_str q = (if q = of_int \<lfloor>q\<rfloor> then show_int \<lfloor>q\<rfloor>
     else case round_sig 10 (rl q) of Some d \<Rightarrow> render_dec 10 d | None \<Rightarrow> g_emb q)"

definition emb_reply :: "ereq \<Rightarrow> reply" where
  "emb_reply r = (case emb_decline r of
      Some d \<Rightarrow> Reply False (if d = E_mapping then STR ''underspecified'' else STR ''impossible'') (emb_decl_text r d) None
    | None \<Rightarrow> Reply True (emb_kind r) (emb_text r) (Some (val_str (emb_value r))))"

theorem emb_reply_answered_iff: "answered (emb_reply r) \<longleftrightarrow> emb_decline r = None"
  by (auto simp: emb_reply_def split: option.splits)

definition emb_self_test :: bool where
  "emb_self_test \<longleftrightarrow>
     emb_value (ETick 8000000 8 False) = 1 / 1000000 \<and>
     emb_value (ETick 20000000 256 True) = 78125 \<and>
     emb_value (EOvf 16 16000000 256 False) = 1048576 / 1000000 \<and>
     emb_value (ECtc 8000000 8 100 16) = 9999 \<and>
     emb_decline (ECtc 16000000 1 1 8) = Some E_nofit \<and>
     emb_value (EUbrr 8000000 57600) = 8 \<and>
     emb_value (EUartTp E_byte 115200 8 0 1) = 11520 \<and>
     emb_value (EAddr 32 None) = 4294967296 \<and>
     response (emb_reply (EUartTime E_byte 9600 10 8 0 1)) =
       STR ''It takes 10.4167 ms (10 bytes x 10-bit frame / 9600 baud, 8N1).'' \<and>
     response (emb_reply (ETick 8000000 8 False)) = STR ''The tick period is 1 us (8 / 8,000,000 Hz).'' \<and>
     stated (emb_reply (EOvf 8 16000000 64 False)) = Some (STR ''0.001024'') \<and>
     stated (emb_reply (EAddr 32 None)) = Some (STR ''4294967296'')"

section \<open>Cyber\<close>

datatype cset = CS_printable | CS_alnum | CS_mixed | CS_lower | CS_digits | CS_custom nat

fun csize :: "cset \<Rightarrow> nat" where
  "csize CS_printable = 95" | "csize CS_alnum = 62" | "csize CS_mixed = 52"
| "csize CS_lower = 26" | "csize CS_digits = 10" | "csize (CS_custom n) = n"

fun clabel :: "cset \<Rightarrow> String.literal" where
  "clabel CS_printable = STR ''printable ASCII (95)''"
| "clabel CS_alnum = STR ''alphanumeric (62)''"
| "clabel CS_mixed = STR ''mixed-case letters (52)''"
| "clabel CS_lower = STR ''lowercase letters (26)''"
| "clabel CS_digits = STR ''digits (10)''"
| "clabel (CS_custom n) = STR ''a '' + snat n + STR ''-symbol set''"

datatype creq =
    CDigest nat | CBirthday nat | CBase64 nat
  | CKeyspace cset nat | CEntropy cset nat | CDistribution | CBrute bool cset nat "rat option"

datatype cdecl = C_need_rate | C_zero | C_need_distribution

fun cyb_decline :: "creq \<Rightarrow> cdecl option" where
  "cyb_decline (CBrute avg cs L None) = Some C_need_rate"
| "cyb_decline (CBrute avg cs L (Some R)) = (if R \<le> 0 then Some C_zero else None)"
| "cyb_decline (CEntropy cs L) = (if csize cs = 0 then Some C_zero else None)"
| "cyb_decline CDistribution = Some C_need_distribution"
| "cyb_decline r = None"

fun cyb_value :: "creq \<Rightarrow> rat" where
  "cyb_value (CDigest bits) = of_nat (bits div 4)"
| "cyb_value (CBirthday n) = of_nat n / 2"
| "cyb_value (CBase64 n) = of_nat (4 * ((n + 2) div 3))"
| "cyb_value (CKeyspace cs L) = of_nat (csize cs ^ L)"
| "cyb_value (CEntropy cs L) = 0"
| "cyb_value CDistribution = 0"
| "cyb_value (CBrute avg cs L None) = 0"
| "cyb_value (CBrute avg cs L (Some R)) = of_nat (csize cs ^ L) / R / (if avg then 2 else 1)"

text \<open>The padded Base64 length is the smallest multiple of four that holds @{text "8n"} bits
in six-bit groups.\<close>
theorem cyb_base64_len:
  "8 * of_nat n \<le> 6 * cyb_value (CBase64 n) \<and> 6 * (cyb_value (CBase64 n) - 4) < 8 * of_nat n"
proof -
  have h: "8 * n \<le> 6 * (4 * ((n + 2) div 3)) \<and> 6 * (4 * ((n + 2) div 3)) < 8 * n + 24" by arith
  then have h1: "(of_nat (8 * n) :: rat) \<le> of_nat (6 * (4 * ((n + 2) div 3)))"
    and h2: "(of_nat (6 * (4 * ((n + 2) div 3))) :: rat) < of_nat (8 * n + 24)"
    by (simp_all only: of_nat_le_iff of_nat_less_iff)
  show ?thesis using h1 h2 by (simp add: algebra_simps)
qed

theorem cyb_digest_hex:
  "bits mod 4 = 0 \<Longrightarrow> cyb_value (CDigest bits) * 4 = of_nat bits"
proof -
  assume "bits mod 4 = 0"
  then obtain k where "bits = 4 * k" by auto
  then show ?thesis by simp
qed

theorem cyb_birthday_value: "cyb_value (CBirthday n) * 2 = of_nat n"
  by simp

theorem cyb_keyspace_value:
  "cyb_value (CKeyspace cs L) = of_nat (csize cs) ^ L"
  by simp

theorem cyb_brute_value:
  assumes "cyb_decline (CBrute avg cs L (Some R)) = None"
  shows "0 < R \<and> cyb_value (CBrute avg cs L (Some R)) * R * (if avg then 2 else 1) = of_nat (csize cs) ^ L"
proof -
  have R: "0 < R" using assms by (auto split: if_splits)
  then have R0: "R \<noteq> 0" by simp
  show ?thesis using R R0 by (cases avg) simp_all
qed

theorem cyb_brute_avg_half:
  "cyb_value (CBrute True cs L (Some R)) * 2 = cyb_value (CBrute False cs L (Some R))"
  by simp

theorem cyb_underspecified:
  "cyb_decline (CBrute avg cs L ro) = Some C_need_rate \<longleftrightarrow> ro = None"
  by (cases ro) auto

definition entropy_fa :: "cset \<Rightarrow> nat \<Rightarrow> floatarith" where
  "entropy_fa cs L = floatarith.Mult (I (int L)) (floatarith.Mult (floatarith.Ln (I (int (csize cs))))
     (floatarith.Inverse (floatarith.Ln (I 2))))"

lemma interp_entropy:
  "interpret_floatarith (entropy_fa cs L) xs = real L * log 2 (real (csize cs))"
  by (simp add: entropy_fa_def log_def divide_inverse mult_ac)

definition cyb_entropy :: "cset \<Rightarrow> nat \<Rightarrow> (int \<times> int) option" where
  "cyb_entropy cs L = enclose 120 (entropy_fa cs L)"

theorem cyb_entropy_sound:
  assumes "cyb_entropy cs L = Some d"
  shows "\<bar>dec_val d - real L * log 2 (real (csize cs))\<bar> \<le>
         \<bar>real L * log 2 (real (csize cs))\<bar> / 1000 + 1 / 1000000000"
  using enclose_sound[of 120 "entropy_fa cs L"] assms by (simp add: cyb_entropy_def interp_entropy)

definition g_cy :: "rat \<Rightarrow> String.literal" where
  "g_cy x = (if x \<noteq> 0 \<and> (10000000 \<le> \<bar>x\<bar> \<or> \<bar>x\<bar> < 1 / 1000) then sig4_str x else fixed_str 4 x)"

definition dur_str :: "rat \<Rightarrow> String.literal" where
  "dur_str s = (if 31557600 \<le> s then g_cy (s / 31557600) + STR '' years''
     else if 86400 \<le> s then g_cy (s / 86400) + STR '' days''
     else if 3600 \<le> s then g_cy (s / 3600) + STR '' hours''
     else if 60 \<le> s then g_cy (s / 60) + STR '' minutes''
     else g_cy s + STR '' seconds'')"

theorem dur_unit_years: "dur_str (31557600 * 2) = g_cy 2 + STR '' years''"
  by (simp add: dur_str_def)

definition ks_str :: "rat \<Rightarrow> String.literal" where
  "ks_str ks = (if 10000000 \<le> ks then g_cy ks else commas (round_he ks))"

definition cyb_kind :: "creq \<Rightarrow> String.literal" where
  "cyb_kind r = (case r of
      CDigest _ \<Rightarrow> STR ''digest_hex'' | CBirthday _ \<Rightarrow> STR ''birthday'' | CBase64 _ \<Rightarrow> STR ''base64_len''
    | CKeyspace _ _ \<Rightarrow> STR ''keyspace'' | CEntropy _ _ \<Rightarrow> STR ''entropy'' | CDistribution \<Rightarrow> STR ''underspecified''
    | CBrute True _ _ _ \<Rightarrow> STR ''brute_avg'' | CBrute False _ _ _ \<Rightarrow> STR ''brute_worst'')"

definition cyb_text :: "creq \<Rightarrow> String.literal" where
  "cyb_text r = (let v = cyb_value r in case r of
      CDigest bits \<Rightarrow> STR ''The digest is '' + snat (bits div 4) + STR '' hex characters ('' + snat bits + STR '' bits / 4).''
    | CBirthday n \<Rightarrow> STR ''About 2^'' + g_cy v + STR '' hashes (''
        + (if even n then g_cy (2 ^ (n div 2)) else STR ''2^'' + g_cy v) + STR '') are needed for a 50% collision chance (birthday bound 2^(n/2), n = ''
        + snat n + STR '').''
    | CBase64 n \<Rightarrow> STR ''The Base64 length is '' + snat (4 * ((n + 2) div 3)) + STR '' characters (4 x ceil('' + snat n
        + STR '' / 3), with padding).''
    | CKeyspace cs L \<Rightarrow> STR ''The keyspace is '' + ks_str v + STR '' ('' + snat (csize cs) + STR ''^'' + snat L + STR ''; ''
        + clabel cs + STR '').''
    | CEntropy cs L \<Rightarrow> STR ''''
    | CDistribution \<Rightarrow> STR ''''
    | CBrute avg cs L ro \<Rightarrow> (case ro of None \<Rightarrow> STR '''' | Some R \<Rightarrow>
        (let ks = of_nat (csize cs ^ L) in
         if avg then STR ''The average time is '' + dur_str v + STR '' (half the keyspace: '' + g_cy ks + STR '' / 2 / '' + g_cy R
            + STR '' guesses/s; '' + clabel cs + STR '', length '' + snat L + STR '').''
         else STR ''The worst-case time is '' + dur_str v + STR '' (keyspace '' + g_cy ks + STR '' / '' + g_cy R
            + STR '' guesses/s; '' + clabel cs + STR '', length '' + snat L + STR '').'')))"

definition cyb_reply :: "creq \<Rightarrow> reply" where
  "cyb_reply r = (case r of
      CEntropy cs L \<Rightarrow>
        (if cyb_decline r \<noteq> None then Reply False (STR ''impossible'') (STR ''A character set needs at least one symbol.'') None
         else case cyb_entropy cs L of
           None \<Rightarrow> Reply False (STR ''imprecise'') (STR ''I could not bound that value tightly enough to state it.'') None
         | Some d \<Rightarrow> Reply True (STR ''entropy'') (STR ''The entropy is '' + render_dec 4 d + STR '' bits ('' + snat L
             + STR '' x log2 '' + snat (csize cs) + STR ''; random '' + clabel cs + STR '', length '' + snat L + STR '').'')
             (Some (render_dec 4 d)))
    | _ \<Rightarrow> (case cyb_decline r of
        Some C_need_rate \<Rightarrow> Reply False (STR ''underspecified'')
          (STR ''I need the guess rate (guesses per second) - the time depends entirely on the hardware; I won'' + apos + STR ''t assume one.'') None
      | Some C_need_distribution \<Rightarrow> Reply False (STR ''underspecified'')
          (STR ''This calculation requires uniform independent choices. Nonuniform or dependent choices need a probability model that this calculator does not support.'') None
      | Some C_zero \<Rightarrow> Reply False (STR ''impossible'') (STR ''A guess rate must be positive.'') None
      | None \<Rightarrow> Reply True (cyb_kind r) (cyb_text r) None))"

theorem cyb_reply_answered:
  "answered (cyb_reply r) \<longleftrightarrow>
     (case r of CEntropy cs L \<Rightarrow> cyb_decline r = None \<and> cyb_entropy cs L \<noteq> None | _ \<Rightarrow> cyb_decline r = None)"
  by (cases r) (auto simp: cyb_reply_def split: option.splits cdecl.splits)

theorem cyb_distribution_withheld:
  "\<not> answered (cyb_reply CDistribution) \<and>
   reply_kind (cyb_reply CDistribution) = STR ''underspecified'' \<and>
   stated (cyb_reply CDistribution) = None"
  by (simp add: cyb_reply_def)

definition cyb_self_test :: bool where
  "cyb_self_test \<longleftrightarrow>
     cyb_value (CKeyspace CS_lower 12) = 95428956661682176 \<and>
     cyb_value (CBase64 3) = 4 \<and> cyb_value (CBase64 4) = 8 \<and> cyb_value (CDigest 128) = 32 \<and>
     cyb_value (CBirthday 128) = 64 \<and>
     cyb_entropy CS_lower 12 \<noteq> None \<and>
     cyb_value (CBrute True CS_digits 4 (Some 1)) = 5000 \<and>
     cyb_decline (CBrute False CS_alnum 8 None) = Some C_need_rate \<and>
     response (cyb_reply (CBase64 3)) = STR ''The Base64 length is 4 characters (4 x ceil(3 / 3), with padding).'' \<and>
     response (cyb_reply (CBrute True CS_digits 4 (Some 1))) =
       STR ''The average time is 1.3889 hours (half the keyspace: 10000 / 2 / 1 guesses/s; digits (10), length 4).'' \<and>
     response (cyb_reply (CBirthday 128)) =
       STR ''About 2^64 hashes (1.845e+19) are needed for a 50% collision chance (birthday bound 2^(n/2), n = 128).''"

section \<open>Robotics\<close>

datatype rwant = RW_radius | RW_angular | RW_linear

datatype rreq =
    RPwm rat rat
  | RFk rat rat rat rat String.literal
  | REnc rat rat rat
  | RWheel rat rat
  | RDiff rwant "rat option" "rat option" "rat option"

datatype rdecl = R_duty | R_straight | R_need | R_imprecise

definition deg_fa :: "rat \<Rightarrow> floatarith" where
  "deg_fa a = floatarith.Mult (Q a) (floatarith.Mult floatarith.Pi (floatarith.Inverse (I 180)))"

definition sin_fa :: "floatarith \<Rightarrow> floatarith" where
  "sin_fa A = floatarith.Cos (floatarith.Add (floatarith.Mult floatarith.Pi (floatarith.Inverse (I 2))) (floatarith.Minus A))"

lemma interp_deg [simp]: "interpret_floatarith (deg_fa a) xs = rl a * pi / 180"
  by (simp add: deg_fa_def inverse_eq_divide)

lemma interp_sin_fa [simp]: "interpret_floatarith (sin_fa A) xs = sin (interpret_floatarith A xs)"
proof -
  have "pi * inverse 2 + - interpret_floatarith A xs = pi / 2 - interpret_floatarith A xs"
    by (simp add: inverse_eq_divide)
  then show ?thesis by (simp add: sin_fa_def sin_cos_eq)
qed

definition fk_x :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "fk_x l1 l2 a1 a2 = floatarith.Add (floatarith.Mult (Q l1) (floatarith.Cos (deg_fa a1)))
      (floatarith.Mult (Q l2) (floatarith.Cos (floatarith.Add (deg_fa a1) (deg_fa a2))))"

definition fk_y :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "fk_y l1 l2 a1 a2 = floatarith.Add (floatarith.Mult (Q l1) (sin_fa (deg_fa a1)))
      (floatarith.Mult (Q l2) (sin_fa (floatarith.Add (deg_fa a1) (deg_fa a2))))"

lemma interp_fk_x [simp]:
  "interpret_floatarith (fk_x l1 l2 a1 a2) xs =
     rl l1 * cos (rl a1 * pi / 180) + rl l2 * cos (rl a1 * pi / 180 + rl a2 * pi / 180)"
  by (simp add: fk_x_def)

lemma interp_fk_y [simp]:
  "interpret_floatarith (fk_y l1 l2 a1 a2) xs =
     rl l1 * sin (rl a1 * pi / 180) + rl l2 * sin (rl a1 * pi / 180 + rl a2 * pi / 180)"
  by (simp add: fk_y_def)

definition wheel_fa :: "rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "wheel_fa rpm D = floatarith.Mult (floatarith.Mult (Q rpm) floatarith.Pi)
      (floatarith.Mult (Q D) (floatarith.Inverse (I 60)))"

lemma interp_wheel [simp]: "interpret_floatarith (wheel_fa rpm D) xs = rl rpm * pi * rl D / 60"
  by (simp add: wheel_fa_def inverse_eq_divide)

definition enc_fa :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "enc_fa k P D = floatarith.Mult (floatarith.Mult (Q (k / P)) floatarith.Pi) (Q D)"

lemma interp_enc [simp]: "interpret_floatarith (enc_fa k P D) xs = rl (k / P) * pi * rl D"
  by (simp add: enc_fa_def)

text \<open>Three decimals as the organ prints them, refusing values of 100000 or more
(the organ switches to a comma format there).\<close>
definition enc3 :: "floatarith \<Rightarrow> (int \<times> int) option" where
  "enc3 e = (case enclose_fixed 3 e of Some (m, ex) \<Rightarrow> if \<bar>m\<bar> < 100000000 then Some (m, ex) else None | None \<Rightarrow> None)"

lemma enc3_sound:
  assumes "enc3 e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le> pow10 (- 3) * (101 / 200)"
proof -
  obtain m ex where "enclose_fixed 3 e = Some (m, ex)" and "d = (m, ex)"
    using assms by (auto simp: enc3_def split: option.splits prod.splits if_splits)
  then show ?thesis using enclose_fixed_sound[of 3 e] by simp
qed

definition g3 :: "rat \<Rightarrow> String.literal" where
  "g3 q = (if \<bar>q\<bar> < 100000 then fixed_str 3 q else commas (round_he q))"

fun rob_decline :: "rreq \<Rightarrow> rdecl option" where
  "rob_decline (RPwm d V) = (if 100 < d then Some R_duty else None)"
| "rob_decline (RDiff w vl vr L) = (case (vl, vr) of
     (Some a, Some b) \<Rightarrow>
        (if w \<noteq> RW_linear \<and> (L = None \<or> L = Some 0) then Some R_need
         else if w = RW_radius \<and> a = b then Some R_straight else None)
   | _ \<Rightarrow> Some R_need)"
| "rob_decline r = None"

fun diff_value :: "rwant \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "diff_value RW_radius a b L = \<bar>L / 2 * (b + a) / (b - a)\<bar>"
| "diff_value RW_angular a b L = (b - a) / L"
| "diff_value RW_linear a b L = (b + a) / 2"

theorem rob_diff_identities:
  assumes "0 < L"
  shows "diff_value RW_angular a b L * L = b - a"
    and "diff_value RW_linear a b L * 2 = b + a"
    and "a \<noteq> b \<Longrightarrow> diff_value RW_radius a b L * \<bar>b - a\<bar> = L / 2 * \<bar>b + a\<bar>"
proof -
  show "diff_value RW_angular a b L * L = b - a" using assms by simp
  show "diff_value RW_linear a b L * 2 = b + a" by simp
  assume ab: "a \<noteq> b"
  have ne: "b - a \<noteq> 0" using ab by simp
  have e: "L / 2 * (b + a) / (b - a) * (b - a) = L / 2 * (b + a)" using ne by (simp add: field_simps)
  have hl: "\<bar>L / 2\<bar> = L / 2" using assms by simp
  have "diff_value RW_radius a b L * \<bar>b - a\<bar> = \<bar>L / 2 * (b + a) / (b - a) * (b - a)\<bar>"
    by (simp only: diff_value.simps abs_mult)
  also have "\<dots> = \<bar>L / 2 * (b + a)\<bar>" by (simp only: e)
  also have "\<dots> = L / 2 * \<bar>b + a\<bar>" by (simp only: abs_mult hl)
  finally show "diff_value RW_radius a b L * \<bar>b - a\<bar> = L / 2 * \<bar>b + a\<bar>" .
qed

theorem rob_diff_straight:
  "rob_decline (RDiff RW_radius (Some a) (Some b) (Some L)) = Some R_straight \<longleftrightarrow> a = b \<and> L \<noteq> 0"
  by auto

definition rob_pwm_value :: "rat \<Rightarrow> rat \<Rightarrow> rat" where "rob_pwm_value d V = d / 100 * V"

theorem rob_pwm_bound:
  assumes "rob_decline (RPwm d V) = None" "0 \<le> d" "0 \<le> V"
  shows "0 \<le> rob_pwm_value d V \<and> rob_pwm_value d V \<le> V"
proof -
  have d: "d \<le> 100" using assms(1) by (auto split: if_splits)
  have 1: "d * V \<le> 100 * V" using d assms(3) by (rule mult_right_mono)
  have 2: "0 \<le> d * V" using assms(2,3) by (rule mult_nonneg_nonneg)
  show ?thesis using 1 2 by (auto simp: rob_pwm_value_def; linarith)
qed

definition rob_pi_dec :: "rreq \<Rightarrow> (int \<times> int) option" where
  "rob_pi_dec r = (case r of
      RWheel rpm D \<Rightarrow> enc3 (wheel_fa rpm D)
    | REnc k P D \<Rightarrow> enc3 (enc_fa k P D)
    | _ \<Rightarrow> None)"

theorem rob_wheel_sound:
  assumes "rob_pi_dec (RWheel rpm D) = Some d"
  shows "\<bar>dec_val d - rl rpm * pi * rl D / 60\<bar> \<le> pow10 (- 3) * (101 / 200)"
  using enc3_sound[of "wheel_fa rpm D" d] assms by (simp add: rob_pi_dec_def)

theorem rob_enc_sound:
  assumes "rob_pi_dec (REnc k P D) = Some d"
  shows "\<bar>dec_val d - rl (k / P) * pi * rl D\<bar> \<le> pow10 (- 3) * (101 / 200)"
  using enc3_sound[of "enc_fa k P D" d] assms by (simp add: rob_pi_dec_def)

definition rob_fk_dec :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> ((int \<times> int) \<times> (int \<times> int)) option" where
  "rob_fk_dec l1 l2 a1 a2 = (case (enc3 (fk_x l1 l2 a1 a2), enc3 (fk_y l1 l2 a1 a2)) of
      (Some x, Some y) \<Rightarrow> Some (x, y) | _ \<Rightarrow> None)"

theorem rob_fk_sound:
  assumes "rob_fk_dec l1 l2 a1 a2 = Some (dx, dy)"
  shows "\<bar>dec_val dx - (rl l1 * cos (rl a1 * pi / 180) + rl l2 * cos (rl a1 * pi / 180 + rl a2 * pi / 180))\<bar>
           \<le> pow10 (- 3) * (101 / 200) \<and>
         \<bar>dec_val dy - (rl l1 * sin (rl a1 * pi / 180) + rl l2 * sin (rl a1 * pi / 180 + rl a2 * pi / 180))\<bar>
           \<le> pow10 (- 3) * (101 / 200)"
proof -
  from assms obtain x y where x: "enc3 (fk_x l1 l2 a1 a2) = Some x" and y: "enc3 (fk_y l1 l2 a1 a2) = Some y"
    and e: "dx = x" "dy = y"
    by (auto simp: rob_fk_dec_def split: option.splits)
  show ?thesis using enc3_sound[OF x] enc3_sound[OF y] e by simp
qed

definition rob_decl_text :: "rdecl \<Rightarrow> String.literal" where
  "rob_decl_text d = (case d of
      R_duty \<Rightarrow> STR ''A duty cycle above 100% is not possible.''
    | R_straight \<Rightarrow> STR ''Equal wheel speeds drive straight - the turning radius is infinite.''
    | R_need \<Rightarrow> STR ''I couldn'' + apos + STR ''t read both wheel speeds and the track width from that; give them as ''
        + apos + STR ''left wheel 0.4 m/s, right wheel 0.6 m/s, track width 0.3 m'' + apos + STR '' and I'' + apos + STR ''ll work it out.''
    | R_imprecise \<Rightarrow> STR ''I could not bound that value tightly enough to state it.'')"

definition rob_decl_kind :: "rdecl \<Rightarrow> String.literal" where
  "rob_decl_kind d = (case d of R_duty \<Rightarrow> STR ''impossible'' | R_straight \<Rightarrow> STR ''straight''
     | R_need \<Rightarrow> STR ''underspecified'' | R_imprecise \<Rightarrow> STR ''imprecise'')"

definition decs :: "int \<times> int \<Rightarrow> String.literal" where "decs d = render_dec 40 d"

definition rob_reply :: "rreq \<Rightarrow> reply" where
  "rob_reply r = (case rob_decline r of
      Some d \<Rightarrow> Reply False (rob_decl_kind d) (rob_decl_text d) None
    | None \<Rightarrow> (case r of
        RPwm d V \<Rightarrow> Reply True (STR ''pwm'') (STR ''The average voltage is '' + g3 (rob_pwm_value d V) + STR '' V (''
            + g3 d + STR ''% duty x '' + g3 V + STR '' V).'') (Some (g3 (rob_pwm_value d V)))
      | RWheel rpm D \<Rightarrow> (case rob_pi_dec r of
            None \<Rightarrow> Reply False (STR ''imprecise'') (rob_decl_text R_imprecise) None
          | Some x \<Rightarrow> Reply True (STR ''wheel_speed'') (STR ''The linear speed is '' + decs x + STR '' m/s ('' + g3 rpm
              + STR '' rpm x pi x '' + g3 D + STR '' m / 60).'') (Some (decs x)))
      | REnc k P D \<Rightarrow> (case rob_pi_dec r of
            None \<Rightarrow> Reply False (STR ''imprecise'') (rob_decl_text R_imprecise) None
          | Some x \<Rightarrow> Reply True (STR ''encoder'') (STR ''The distance is '' + decs x + STR '' m ('' + g3 k
              + STR '' ticks / '' + g3 P + STR '' per rev x pi x '' + g3 D + STR '' m).'') (Some (decs x)))
      | RFk l1 l2 a1 a2 u \<Rightarrow> (case rob_fk_dec l1 l2 a1 a2 of
            None \<Rightarrow> Reply False (STR ''imprecise'') (rob_decl_text R_imprecise) None
          | Some (x, y) \<Rightarrow> Reply True (STR ''fk'') (STR ''The end effector is at ('' + decs x + STR '', '' + decs y + STR '') ''
              + u + STR '' (x = L1 cos t1 + L2 cos(t1+t2), y = L1 sin t1 + L2 sin(t1+t2); t1 = '' + g3 a1
              + STR '' deg, t2 = '' + g3 a2 + STR '' deg relative).'') None)
      | RDiff w vl vr L \<Rightarrow> (case (vl, vr, L) of
          (Some a, Some b, Some l) \<Rightarrow>
            (case w of
               RW_radius \<Rightarrow> Reply True (STR ''turn_radius'') (STR ''The turning radius is '' + g3 (diff_value w a b l)
                  + STR '' m (L/2 x (vR + vL)/(vR - vL) = '' + g3 l + STR ''/2 x '' + g3 (b + a) + STR ''/'' + g3 (b - a) + STR '').'')
                  (Some (g3 (diff_value w a b l)))
             | RW_angular \<Rightarrow> Reply True (STR ''diff_angular'') (STR ''The angular velocity is '' + g3 (diff_value w a b l)
                  + STR '' rad/s ((vR - vL) / L = ('' + g3 b + STR '' - '' + g3 a + STR '') / '' + g3 l
                  + STR '' m; positive = counter-clockwise).'') (Some (g3 (diff_value w a b l)))
             | RW_linear \<Rightarrow> Reply True (STR ''diff_linear'') (STR ''The linear velocity is '' + g3 (diff_value w a b l)
                  + STR '' m/s ((vR + vL) / 2).'') (Some (g3 (diff_value w a b l))))
        | (Some a, Some b, None) \<Rightarrow> Reply True (STR ''diff_linear'') (STR ''The linear velocity is '' + g3 (diff_value w a b 1)
                  + STR '' m/s ((vR + vL) / 2).'') (Some (g3 (diff_value w a b 1)))
        | _ \<Rightarrow> Reply False (STR ''underspecified'') (rob_decl_text R_need) None)))"

theorem rob_reply_withheld_iff_decline:
  "rob_decline r \<noteq> None \<Longrightarrow> \<not> answered (rob_reply r)"
  by (auto simp: rob_reply_def split: option.splits)

definition rob_self_test :: bool where
  "rob_self_test \<longleftrightarrow>
     diff_value RW_linear (1 / 2) (3 / 10) 0 = 2 / 5 \<and>
     diff_value RW_angular (2 / 5) (3 / 5) (3 / 10) = 2 / 3 \<and>
     diff_value RW_radius (2 / 5) (3 / 5) (3 / 10) = 3 / 4 \<and>
     rob_decline (RPwm 150 12) = Some R_duty \<and>
     rob_decline (RDiff RW_radius (Some (1 / 2)) (Some (1 / 2)) (Some (3 / 10))) = Some R_straight \<and>
     rob_decline (RDiff RW_angular (Some 1) None (Some 1)) = Some R_need \<and>
     response (rob_reply (RPwm 40 9)) = STR ''The average voltage is 3.6 V (40% duty x 9 V).'' \<and>
     response (rob_reply (RDiff RW_angular (Some (2 / 5)) (Some (3 / 5)) (Some (3 / 10)))) =
       STR ''The angular velocity is 0.667 rad/s ((vR - vL) / L = (0.6 - 0.4) / 0.3 m; positive = counter-clockwise).''"

end
