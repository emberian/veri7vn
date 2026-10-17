theory System
  imports Computing_Num
begin

text \<open>Lane S15-computing: @{text linux-v2} (chmod, umask, cron, signals, exit
status; upstream/root/specialists/linux-v2/organ_linux_v{1,2}.py) and @{text git}
(a typed intent table; upstream/root/specialists/git/organ_git_v1.py).\<close>

section \<open>Permission bits\<close>

definition bits3 :: "nat \<Rightarrow> bool \<times> bool \<times> bool" where
  "bits3 d = (d div 4 mod 2 = 1, d div 2 mod 2 = 1, d mod 2 = 1)"

definition unbits3 :: "bool \<times> bool \<times> bool \<Rightarrow> nat" where
  "unbits3 b = (case b of (r, w, x) \<Rightarrow> (if r then 4 else 0) + (if w then 2 else 0) + (if x then 1 else 0))"

lemma unbits_bits: "d < 8 \<Longrightarrow> unbits3 (bits3 d) = d"
  unfolding unbits3_def bits3_def by (auto split: if_splits; arith)

lemma bits_unbits: "bits3 (unbits3 b) = b"
  unfolding unbits3_def bits3_def by (cases b) (auto split: if_splits)

lemma unbits_lt: "unbits3 b < 8" by (cases b) (auto simp: unbits3_def)

datatype xbit = X_no | X_x | X_sp | X_SP

fun xexec :: "xbit \<Rightarrow> bool" where
  "xexec X_no = False" | "xexec X_x = True" | "xexec X_sp = True" | "xexec X_SP = False"

fun xspecial :: "xbit \<Rightarrow> bool" where
  "xspecial X_no = False" | "xspecial X_x = False" | "xspecial X_sp = True" | "xspecial X_SP = True"

definition mkx :: "bool \<Rightarrow> bool \<Rightarrow> xbit" where
  "mkx e s = (if s then (if e then X_sp else X_SP) else (if e then X_x else X_no))"

lemma mkx_xexec: "mkx (xexec x) (xspecial x) = x" by (cases x) (auto simp: mkx_def)
lemma xexec_mkx: "xexec (mkx e s) = e" by (auto simp: mkx_def)
lemma xspecial_mkx: "xspecial (mkx e s) = s" by (auto simp: mkx_def)

datatype perm = Perm bool bool xbit
datatype sym = Sym perm perm perm

text \<open>A mode is its special digit (setuid 4, setgid 2, sticky 1) and three digits.\<close>
datatype mode = Mode nat nat nat nat

fun perm_digit :: "perm \<Rightarrow> nat" where
  "perm_digit (Perm r w x) = unbits3 (r, w, xexec x)"

fun perm_special :: "perm \<Rightarrow> bool" where
  "perm_special (Perm r w x) = xspecial x"

definition mode_of_sym :: "sym \<Rightarrow> mode" where
  "mode_of_sym s = (case s of Sym a b c \<Rightarrow>
     Mode (unbits3 (perm_special a, perm_special b, perm_special c)) (perm_digit a) (perm_digit b) (perm_digit c))"

definition perm_of :: "nat \<Rightarrow> bool \<Rightarrow> perm" where
  "perm_of d s = (case bits3 d of (r, w, x) \<Rightarrow> Perm r w (mkx x s))"

definition sym_of_mode :: "mode \<Rightarrow> sym" where
  "sym_of_mode m = (case m of Mode sp u g o' \<Rightarrow>
     (case bits3 sp of (s1, s2, s3) \<Rightarrow> Sym (perm_of u s1) (perm_of g s2) (perm_of o' s3)))"

theorem sym_mode_sym: "sym_of_mode (mode_of_sym s) = s"
proof (cases s)
  case (Sym a b c)
  obtain r1 w1 x1 where a: "a = Perm r1 w1 x1" by (cases a)
  obtain r2 w2 x2 where b: "b = Perm r2 w2 x2" by (cases b)
  obtain r3 w3 x3 where c: "c = Perm r3 w3 x3" by (cases c)
  show ?thesis
    by (simp add: Sym a b c sym_of_mode_def mode_of_sym_def perm_of_def bits_unbits mkx_xexec)
qed

theorem mode_sym_mode:
  assumes "sp < 8" "u < 8" "g < 8" "o' < 8"
  shows "mode_of_sym (sym_of_mode (Mode sp u g o')) = Mode sp u g o'"
proof -
  obtain s1 s2 s3 where b: "bits3 sp = (s1, s2, s3)" by (cases "bits3 sp") auto
  obtain r1 w1 x1 where u1: "bits3 u = (r1, w1, x1)" by (cases "bits3 u") auto
  obtain r2 w2 x2 where g1: "bits3 g = (r2, w2, x2)" by (cases "bits3 g") auto
  obtain r3 w3 x3 where o1: "bits3 o' = (r3, w3, x3)" by (cases "bits3 o'") auto
  have es: "unbits3 (s1, s2, s3) = sp" using unbits_bits[OF assms(1)] b by simp
  have eu: "unbits3 (r1, w1, x1) = u" using unbits_bits[OF assms(2)] u1 by simp
  have eg: "unbits3 (r2, w2, x2) = g" using unbits_bits[OF assms(3)] g1 by simp
  have eo: "unbits3 (r3, w3, x3) = o'" using unbits_bits[OF assms(4)] o1 by simp
  show ?thesis
    by (simp add: sym_of_mode_def mode_of_sym_def perm_of_def b u1 g1 o1 xexec_mkx xspecial_mkx es eu eg eo)
qed

definition xchar :: "bool \<Rightarrow> xbit \<Rightarrow> String.literal" where
  "xchar lst x = (case x of X_no \<Rightarrow> STR ''-'' | X_x \<Rightarrow> STR ''x''
     | X_sp \<Rightarrow> (if lst then STR ''t'' else STR ''s'') | X_SP \<Rightarrow> (if lst then STR ''T'' else STR ''S''))"

fun perm_str :: "bool \<Rightarrow> perm \<Rightarrow> String.literal" where
  "perm_str lst (Perm r w x) = (if r then STR ''r'' else STR ''-'') + (if w then STR ''w'' else STR ''-'') + xchar lst x"

fun sym_str :: "sym \<Rightarrow> String.literal" where
  "sym_str (Sym a b c) = perm_str False a + perm_str False b + perm_str True c"

section \<open>The linux requests\<close>

datatype citem_base = CStar | CRange nat nat | CSingle nat
datatype citem = CI citem_base "nat option" | CBad

datatype umask_which = UM_file | UM_dir | UM_both

datatype lreq =
    LSymFromOct "nat list"
  | LOctFromSym sym
  | LUmask "nat list" umask_which
  | LCron bool "citem list list" String.literal String.literal
  | LCronNoPeriod
  | LSigNum String.literal
  | LSigName nat
  | LExit nat

datatype ldecl = L_mode | L_umask | L_cron | L_signal | L_period

fun digits_ok :: "nat list \<Rightarrow> bool" where "digits_ok ds = (\<forall>d \<in> set ds. d < 8)"

subsection \<open>Cron\<close>

definition item_params :: "nat \<Rightarrow> nat \<Rightarrow> citem \<Rightarrow> (nat \<times> nat \<times> nat) option" where
  "item_params lo hi it = (case it of
      CBad \<Rightarrow> None
    | CI base st \<Rightarrow>
       (let step = (case st of None \<Rightarrow> 1 | Some s \<Rightarrow> s);
            ab = (case base of CStar \<Rightarrow> (lo, hi) | CRange a b \<Rightarrow> (a, b)
                    | CSingle a \<Rightarrow> (a, (if st = None then a else hi)))
        in if step < 1 \<or> fst ab < lo \<or> hi < snd ab \<or> snd ab < fst ab then None
           else Some (fst ab, snd ab, step)))"

definition item_vals :: "nat \<Rightarrow> nat \<Rightarrow> citem \<Rightarrow> nat list option" where
  "item_vals lo hi it = (case item_params lo hi it of None \<Rightarrow> None
     | Some (a, b, s) \<Rightarrow> Some (filter (\<lambda>x. (x - a) mod s = 0) [a..<b + 1]))"

theorem item_vals_mem:
  assumes "item_vals lo hi it = Some vs"
  shows "\<exists>a b s. item_params lo hi it = Some (a, b, s) \<and> lo \<le> a \<and> a \<le> b \<and> b \<le> hi \<and> 1 \<le> s \<and>
           (\<forall>x. x \<in> set vs \<longleftrightarrow> a \<le> x \<and> x \<le> b \<and> s dvd (x - a))"
proof -
  from assms obtain a b s where p: "item_params lo hi it = Some (a, b, s)"
    by (cases "item_params lo hi it") (auto simp: item_vals_def)
  then have v: "vs = filter (\<lambda>x. (x - a) mod s = 0) [a..<b + 1]" using assms by (simp add: item_vals_def)
  from p have chk: "1 \<le> s \<and> lo \<le> a \<and> b \<le> hi \<and> a \<le> b"
    by (auto simp: item_params_def Let_def split: citem.splits citem_base.splits option.splits if_splits)
  have mem: "\<And>x. x \<in> set vs \<longleftrightarrow> a \<le> x \<and> x \<le> b \<and> s dvd (x - a)"
    unfolding v set_filter set_upt by (auto simp: dvd_eq_mod_eq_0 less_Suc_eq_le)
  show ?thesis using p chk mem by blast
qed

definition field_vals :: "nat \<Rightarrow> nat \<Rightarrow> citem list \<Rightarrow> nat list option" where
  "field_vals lo hi its = (let rs = map (item_vals lo hi) its in
     if None \<in> set rs then None else Some (concat (map the rs)))"

definition field_count :: "nat \<Rightarrow> nat \<Rightarrow> citem list \<Rightarrow> nat option" where
  "field_count lo hi its = map_option (\<lambda>vs. length (remdups vs)) (field_vals lo hi its)"

theorem field_count_bound:
  assumes "field_count lo hi its = Some n" "its \<noteq> []"
  shows "1 \<le> n \<and> n \<le> hi - lo + 1"
proof -
  from assms obtain vs where vs: "field_vals lo hi its = Some vs" and n: "n = length (remdups vs)"
    by (auto simp: field_count_def split: option.splits)
  have all: "\<forall>it \<in> set its. \<exists>xs. item_vals lo hi it = Some xs"
  proof (intro ballI)
    fix it assume it: "it \<in> set its"
    have nn: "None \<notin> set (map (item_vals lo hi) its)"
      using vs by (auto simp: field_vals_def Let_def split: if_splits)
    have "item_vals lo hi it \<noteq> None" using nn it by force
    then show "\<exists>xs. item_vals lo hi it = Some xs" by auto
  qed
  have sub: "set vs \<subseteq> {lo..hi}"
  proof
    fix x assume "x \<in> set vs"
    then obtain it xs where it: "it \<in> set its" and xs: "item_vals lo hi it = Some xs" and x: "x \<in> set xs"
      using vs by (auto simp: field_vals_def Let_def split: if_splits)
    from item_vals_mem[OF xs] x show "x \<in> {lo..hi}" by auto
  qed
  have ne: "vs \<noteq> []"
  proof -
    obtain it where it: "it \<in> set its" using assms(2) by (cases its) auto
    obtain xs where xs: "item_vals lo hi it = Some xs" using all it by blast
    from item_vals_mem[OF xs] obtain a b s where ab: "a \<le> b" and s1: "1 \<le> s"
      and mem: "\<forall>x. x \<in> set xs \<longleftrightarrow> a \<le> x \<and> x \<le> b \<and> s dvd (x - a)" by blast
    have "a \<in> set xs" using mem ab by simp
    then have "xs \<noteq> []" by auto
    moreover have "set xs \<subseteq> set vs" using it xs vs by (auto simp: field_vals_def Let_def split: if_splits)
    ultimately show ?thesis by auto
  qed
  have "length (remdups vs) = card (set vs)" by (rule length_remdups_card_conv)
  moreover have "card (set vs) \<le> card {lo..hi}" using sub by (intro card_mono) auto
  moreover have "0 < card (set vs)" using ne by (simp add: card_gt_0_iff)
  ultimately show ?thesis using n by simp
qed

definition cron_ranges :: "(nat \<times> nat) list" where
  "cron_ranges = [(0, 59), (0, 23), (1, 31), (1, 12), (0, 7)]"

definition cron_counts :: "citem list list \<Rightarrow> nat list option" where
  "cron_counts fs = (if length fs = 5 then
      (let cs = map2 (\<lambda>f r. field_count (fst r) (snd r) f) fs cron_ranges in
       if None \<in> set cs then None else Some (map the cs)) else None)"

definition lin_decline :: "lreq \<Rightarrow> ldecl option" where
  "lin_decline r = (case r of
      LSymFromOct ds \<Rightarrow> if digits_ok ds then None else Some L_mode
    | LOctFromSym _ \<Rightarrow> None
    | LUmask ds _ \<Rightarrow> if digits_ok ds then None else Some L_umask
    | LCron ph fs _ _ \<Rightarrow> if cron_counts fs = None then Some L_cron else None
    | LCronNoPeriod \<Rightarrow> Some L_period
    | LSigNum nm \<Rightarrow> None
    | LSigName n \<Rightarrow> None
    | LExit n \<Rightarrow> None)"

section \<open>Signals\<close>

definition sig_table :: "(String.literal \<times> nat) list" where
  "sig_table = [(STR ''SIGHUP'', 1), (STR ''SIGINT'', 2), (STR ''SIGQUIT'', 3), (STR ''SIGILL'', 4),
    (STR ''SIGTRAP'', 5), (STR ''SIGABRT'', 6), (STR ''SIGBUS'', 7), (STR ''SIGFPE'', 8), (STR ''SIGKILL'', 9),
    (STR ''SIGUSR1'', 10), (STR ''SIGSEGV'', 11), (STR ''SIGUSR2'', 12), (STR ''SIGPIPE'', 13),
    (STR ''SIGALRM'', 14), (STR ''SIGTERM'', 15), (STR ''SIGCHLD'', 17), (STR ''SIGCONT'', 18),
    (STR ''SIGSTOP'', 19), (STR ''SIGTSTP'', 20), (STR ''SIGTTIN'', 21), (STR ''SIGTTOU'', 22)]"

definition sig_num :: "String.literal \<Rightarrow> nat option" where "sig_num nm = map_of sig_table nm"

definition sig_name :: "nat \<Rightarrow> String.literal option" where
  "sig_name n = map_option fst (find (\<lambda>p. snd p = n) sig_table)"

theorem sig_table_bijective:
  "distinct (map fst sig_table) \<and> distinct (map snd sig_table) \<and>
   (\<forall>p \<in> set sig_table. sig_num (fst p) = Some (snd p) \<and> sig_name (snd p) = Some (fst p))"
  by (simp add: sig_table_def sig_num_def sig_name_def)

theorem sig_name_some: "sig_name n = Some nm \<Longrightarrow> sig_num nm = Some n"
proof -
  assume h: "sig_name n = Some nm"
  then obtain p where p: "find (\<lambda>p. snd p = n) sig_table = Some p" and nm: "nm = fst p"
    by (auto simp: sig_name_def split: option.splits)
  then have "p \<in> set sig_table" "snd p = n" by (auto dest: findSomeD)
  then show ?thesis using nm sig_table_bijective by (auto simp: sig_num_def)
qed

definition lin_signal_ok :: "lreq \<Rightarrow> bool" where
  "lin_signal_ok r = (case r of LSigNum nm \<Rightarrow> sig_num nm \<noteq> None | LSigName n \<Rightarrow> sig_name n \<noteq> None
     | LExit n \<Rightarrow> sig_name n \<noteq> None | _ \<Rightarrow> True)"

section \<open>Umask\<close>

fun last3 :: "nat list \<Rightarrow> nat list" where "last3 ds = drop (length ds - 3) ds"

definition file_digit :: "nat \<Rightarrow> nat" where
  "file_digit u = (case bits3 u of (r, w, x) \<Rightarrow> unbits3 (\<not> r, \<not> w, False))"

definition dir_digit :: "nat \<Rightarrow> nat" where
  "dir_digit u = (case bits3 u of (r, w, x) \<Rightarrow> unbits3 (\<not> r, \<not> w, \<not> x))"

theorem umask_file_bits:
  assumes "u < 8"
  shows "bits3 (file_digit u) = (\<not> fst (bits3 u), \<not> fst (snd (bits3 u)), False) \<and> file_digit u < 8"
  using assms by (cases "bits3 u") (simp add: file_digit_def bits_unbits unbits_lt)

theorem umask_dir_bits:
  assumes "u < 8"
  shows "bits3 (dir_digit u) = (\<not> fst (bits3 u), \<not> fst (snd (bits3 u)), \<not> snd (snd (bits3 u))) \<and> dir_digit u < 8"
  using assms by (cases "bits3 u") (simp add: dir_digit_def bits_unbits unbits_lt)

theorem umask_values:
  "file_digit 2 = 4 \<and> dir_digit 2 = 5 \<and> file_digit 0 = 6 \<and> dir_digit 0 = 7 \<and> file_digit 7 = 0 \<and> dir_digit 7 = 0 \<and>
   file_digit 7 = 0 \<and> dir_digit 5 = 2"
  by (simp add: file_digit_def dir_digit_def bits3_def unbits3_def)

section \<open>Replies\<close>

definition lsint :: "nat \<Rightarrow> String.literal" where "lsint n = lit (digits n)"
definition dstr :: "nat list \<Rightarrow> String.literal" where "dstr ds = lit ds"

definition mode_digits :: "mode \<Rightarrow> nat list" where
  "mode_digits m = (case m of Mode sp u g o' \<Rightarrow> (if sp \<noteq> 0 then [sp] else []) @ [u, g, o'])"

definition mode_of_digits :: "nat list \<Rightarrow> mode" where
  "mode_of_digits ds = (if length ds = 4 then Mode (ds ! 0) (ds ! 1) (ds ! 2) (ds ! 3)
                        else Mode 0 (ds ! 0) (ds ! 1) (ds ! 2))"

definition plural :: "nat \<Rightarrow> String.literal" where "plural n = (if n = 1 then STR '''' else STR ''s'')"

definition lin_text :: "lreq \<Rightarrow> String.literal" where
  "lin_text r = (case r of
      LSymFromOct ds \<Rightarrow> (let s = sym_str (sym_of_mode (mode_of_digits ds)) in
         STR ''Mode '' + dstr ds + STR '' is '' + s + STR '' (owner '' + lit [] + perm_str False (case sym_of_mode (mode_of_digits ds) of Sym a b c \<Rightarrow> a)
           + STR '', group '' + perm_str False (case sym_of_mode (mode_of_digits ds) of Sym a b c \<Rightarrow> b)
           + STR '', others '' + perm_str True (case sym_of_mode (mode_of_digits ds) of Sym a b c \<Rightarrow> c) + STR '').'')
    | LOctFromSym s \<Rightarrow> (let ds = mode_digits (mode_of_sym s) in
         STR ''The octal mode is '' + dstr ds + STR '' ('' + sym_str s + STR ''; r=4, w=2, x=1''
           + (if length ds = 4 then STR ''; s/t add 4000/2000/1000'' else STR '''') + STR '').'')
    | LUmask ds w \<Rightarrow> (let us = last3 ds; fd = map file_digit us; dd = map dir_digit us;
           fs = sym_str (sym_of_mode (Mode 0 (fd ! 0) (fd ! 1) (fd ! 2)));
           dsym = sym_str (sym_of_mode (Mode 0 (dd ! 0) (dd ! 1) (dd ! 2))) in
         (case w of
            UM_dir \<Rightarrow> STR ''The default is '' + dstr dd + STR '' ('' + dsym + STR '') for new directories (777 & ~'' + dstr ds + STR '').''
          | UM_file \<Rightarrow> STR ''The default is '' + dstr fd + STR '' ('' + fs + STR '') for new files (666 & ~'' + dstr ds + STR '').''
          | UM_both \<Rightarrow> STR ''The defaults are '' + dstr fd + STR '' ('' + fs + STR '') for new files and '' + dstr dd
              + STR '' ('' + dsym + STR '') for new directories (666 / 777 & ~'' + dstr ds + STR '').''))
    | LCron ph fs mtxt whole \<Rightarrow> (case cron_counts fs of None \<Rightarrow> STR '''' | Some cs \<Rightarrow>
         (if ph then STR ''It runs '' + lsint (cs ! 0) + STR '' time'' + plural (cs ! 0) + STR '' per hour (minute field ''
              + apos + mtxt + apos + STR '').''
          else STR ''It runs '' + lsint (cs ! 0 * cs ! 1) + STR '' time'' + plural (cs ! 0 * cs ! 1) + STR '' per day (''
              + lsint (cs ! 0) + STR '' minute'' + plural (cs ! 0) + STR '' x '' + lsint (cs ! 1) + STR '' hour''
              + plural (cs ! 1) + STR '').''))
    | LCronNoPeriod \<Rightarrow> STR ''''
    | LSigNum nm \<Rightarrow> (case sig_num nm of Some n \<Rightarrow> STR ''The signal number of '' + nm + STR '' is '' + lsint n
         + STR '' (Linux x86/ARM numbering; kill -'' + lsint n + STR '').'' | None \<Rightarrow> STR '''')
    | LSigName n \<Rightarrow> (case sig_name n of Some nm \<Rightarrow> STR ''Signal '' + lsint n + STR '' is '' + nm
         + STR '' (Linux x86/ARM numbering).'' | None \<Rightarrow> STR '''')
    | LExit n \<Rightarrow> (case sig_name n of Some nm \<Rightarrow> STR ''The exit status is '' + lsint (128 + n) + STR '' (128 + '' + lsint n
         + STR '' for '' + nm + STR '', as the shell reports a process killed by a signal).'' | None \<Rightarrow> STR ''''))"

definition lin_kind :: "lreq \<Rightarrow> String.literal" where
  "lin_kind r = (case r of
      LSymFromOct _ \<Rightarrow> STR ''chmod_symbolic'' | LOctFromSym _ \<Rightarrow> STR ''chmod_octal''
    | LUmask _ UM_dir \<Rightarrow> STR ''umask_dir'' | LUmask _ UM_file \<Rightarrow> STR ''umask_file'' | LUmask _ UM_both \<Rightarrow> STR ''umask''
    | LCron True _ _ _ \<Rightarrow> STR ''cron_per_hour'' | LCron False _ _ _ \<Rightarrow> STR ''cron_per_day''
    | LCronNoPeriod \<Rightarrow> STR ''underspecified'' | LSigNum _ \<Rightarrow> STR ''signal_number''
    | LSigName _ \<Rightarrow> STR ''signal_name'' | LExit _ \<Rightarrow> STR ''exit_status'')"

definition lin_decl_text :: "lreq \<Rightarrow> ldecl \<Rightarrow> String.literal" where
  "lin_decl_text r d = (case (r, d) of
      (LSymFromOct ds, _) \<Rightarrow> dstr ds + STR '' is not an octal mode (each digit is 0-7).''
    | (LUmask ds _, _) \<Rightarrow> STR ''umask '' + dstr ds + STR '' is not an octal mask (digits 0-7 only).''
    | (LCron _ _ _ whole, _) \<Rightarrow> apos + whole + apos
        + STR '' has a field out of range or malformed (minute 0-59, hour 0-23, day 1-31, month 1-12, weekday 0-7).''
    | (LCronNoPeriod, _) \<Rightarrow> STR ''Per hour or per day? Say which period and I'' + apos + STR ''ll count the runs.''
    | _ \<Rightarrow> STR ''That signal is not in the Linux x86/ARM table.'')"

definition lin_reply :: "lreq \<Rightarrow> reply" where
  "lin_reply r = (case lin_decline r of
      Some d \<Rightarrow> Reply False (if d = L_period then STR ''underspecified'' else STR ''impossible'') (lin_decl_text r d) None
    | None \<Rightarrow> if lin_signal_ok r then Reply True (lin_kind r) (lin_text r) None
              else Reply False (STR ''impossible'') (lin_decl_text r L_signal) None)"

theorem lin_reply_answered_iff:
  "answered (lin_reply r) \<longleftrightarrow> lin_decline r = None \<and> lin_signal_ok r"
  by (auto simp: lin_reply_def split: option.splits if_splits)

theorem lin_chmod_declines_iff:
  "lin_decline (LSymFromOct ds) \<noteq> None \<longleftrightarrow> (\<exists>d \<in> set ds. 8 \<le> d)"
  by (auto simp: lin_decline_def not_less split: if_splits)

theorem lin_umask_declines_iff:
  "lin_decline (LUmask ds w) \<noteq> None \<longleftrightarrow> (\<exists>d \<in> set ds. 8 \<le> d)"
  by (auto simp: lin_decline_def not_less split: if_splits)

theorem lin_exit_value:
  "sig_name n = Some nm \<Longrightarrow> sig_num nm = Some n \<and> response (lin_reply (LExit n)) =
     STR ''The exit status is '' + lsint (128 + n) + STR '' (128 + '' + lsint n + STR '' for '' + nm
       + STR '', as the shell reports a process killed by a signal).''"
  by (simp add: sig_name_some lin_reply_def lin_decline_def lin_signal_ok_def lin_text_def)

definition lin_self_test :: bool where
  "lin_self_test \<longleftrightarrow>
     response (lin_reply (LSymFromOct [7, 0, 0])) = STR ''Mode 700 is rwx------ (owner rwx, group ---, others ---).'' \<and>
     response (lin_reply (LSymFromOct [4, 7, 5, 5])) = STR ''Mode 4755 is rwsr-xr-x (owner rws, group r-x, others r-x).'' \<and>
     response (lin_reply (LSymFromOct [1, 7, 7, 7])) = STR ''Mode 1777 is rwxrwxrwt (owner rwx, group rwx, others rwt).'' \<and>
     response (lin_reply (LOctFromSym (sym_of_mode (Mode 0 7 5 0)))) = STR ''The octal mode is 750 (rwxr-x---; r=4, w=2, x=1).'' \<and>
     response (lin_reply (LOctFromSym (sym_of_mode (Mode 4 7 5 5)))) =
       STR ''The octal mode is 4755 (rwsr-xr-x; r=4, w=2, x=1; s/t add 4000/2000/1000).'' \<and>
     response (lin_reply (LUmask [0, 2, 2] UM_file)) = STR ''The default is 644 (rw-r--r--) for new files (666 & ~022).'' \<and>
     response (lin_reply (LUmask [0, 2, 7] UM_dir)) = STR ''The default is 750 (rwxr-x---) for new directories (777 & ~027).'' \<and>
     lin_decline (LUmask [0, 8, 8] UM_file) = Some L_umask \<and>
     lin_decline (LSymFromOct [7, 9, 8]) = Some L_mode \<and>
     cron_counts [[CI CStar (Some 15)], [CI CStar None], [CI CStar None], [CI CStar None], [CI CStar None]] = Some [4, 24, 31, 12, 8] \<and>
     cron_counts [[CI (CRange 0 0) None], [CI (CSingle 24) None], [CI CStar None], [CI CStar None], [CI CStar None]] = None \<and>
     cron_counts [[CI CStar (Some 5)], [CI (CRange 9 17) None], [CI CStar None], [CI CStar None], [CI CStar None]] = Some [12, 9, 31, 12, 8] \<and>
     sig_num (STR ''SIGQUIT'') = Some 3 \<and> sig_name 11 = Some (STR ''SIGSEGV'') \<and> sig_name 16 = None \<and>
     response (lin_reply (LExit 1)) = STR ''The exit status is 129 (128 + 1 for SIGHUP, as the shell reports a process killed by a signal).''"

section \<open>Git\<close>

datatype gintent =
    G_reset_soft | G_reset_hard | G_amend | G_switch_c | G_switch | G_unstage | G_restore | G_add_all
  | G_rename | G_del_remote | G_del_local | G_remotes | G_stash_pop | G_stash | G_diff_staged | G_log
  | G_clone | G_init | G_config_name | G_status | G_fetch | G_pull_rebase | G_cherry_pick | G_tag_a
  | G_blame | G_revert

definition all_intents :: "gintent list" where
  "all_intents = [G_reset_soft, G_reset_hard, G_amend, G_switch_c, G_switch, G_unstage, G_restore, G_add_all,
    G_rename, G_del_remote, G_del_local, G_remotes, G_stash_pop, G_stash, G_diff_staged, G_log,
    G_clone, G_init, G_config_name, G_status, G_fetch, G_pull_rebase, G_cherry_pick, G_tag_a, G_blame, G_revert]"

fun gcmd :: "gintent \<Rightarrow> String.literal" where
  "gcmd G_reset_soft = STR ''git reset --soft HEAD~1''"
| "gcmd G_reset_hard = STR ''git reset --hard HEAD~1''"
| "gcmd G_amend = STR ''git commit --amend''"
| "gcmd G_switch_c = STR ''git switch -c <name>''"
| "gcmd G_switch = STR ''git switch <name>''"
| "gcmd G_unstage = STR ''git restore --staged <file>''"
| "gcmd G_restore = STR ''git restore <file>''"
| "gcmd G_add_all = STR ''git add -A''"
| "gcmd G_rename = STR ''git branch -m <new-name>''"
| "gcmd G_del_remote = STR ''git push origin --delete <name>''"
| "gcmd G_del_local = STR ''git branch -d <name>''"
| "gcmd G_remotes = STR ''git remote -v''"
| "gcmd G_stash_pop = STR ''git stash pop''"
| "gcmd G_stash = STR ''git stash''"
| "gcmd G_diff_staged = STR ''git diff --staged''"
| "gcmd G_log = STR ''git log''"
| "gcmd G_clone = STR ''git clone <url>''"
| "gcmd G_init = STR ''git init''"
| "gcmd G_config_name = STR ''git config --global user.name '' + dquote + STR ''Your Name'' + dquote"
| "gcmd G_status = STR ''git status''"
| "gcmd G_fetch = STR ''git fetch''"
| "gcmd G_pull_rebase = STR ''git pull --rebase''"
| "gcmd G_cherry_pick = STR ''git cherry-pick <commit>''"
| "gcmd G_tag_a = STR ''git tag -a v1.0 -m '' + dquote + STR ''message'' + dquote"
| "gcmd G_blame = STR ''git blame <file>''"
| "gcmd G_revert = STR ''git revert <commit>''"

fun gwarn :: "gintent \<Rightarrow> bool" where
  "gwarn G_reset_hard = True" | "gwarn G_restore = True" | "gwarn i = False"

fun gbody :: "gintent \<Rightarrow> String.literal" where
  "gbody G_reset_soft = STR ''moves the branch back one commit and keeps your changes staged''"
| "gbody G_reset_hard = STR ''this permanently discards the last commit and any uncommitted changes''"
| "gbody G_amend = STR ''rewrites the last commit (don'' + apos + STR ''t amend commits you have already pushed to a shared branch)''"
| "gbody G_switch_c = STR ''creates the branch and switches to it (older equivalent: git checkout -b <name>)''"
| "gbody G_switch = STR ''switches branches (older equivalent: git checkout <name>)''"
| "gbody G_unstage = STR ''unstages the file and keeps your edits (older: git reset HEAD <file>)''"
| "gbody G_restore = STR ''discards uncommitted changes in that file (older: git checkout -- <file>)''"
| "gbody G_add_all = STR ''stages all changes, including deletions (git add . stages the current directory)''"
| "gbody G_rename = STR ''renames the current branch''"
| "gbody G_del_remote = STR ''deletes the branch on the remote''"
| "gbody G_del_local = STR ''deletes a merged local branch (-D forces an unmerged one)''"
| "gbody G_remotes = STR ''lists the remotes and their URLs''"
| "gbody G_stash_pop = STR ''re-applies the latest stash and drops it''"
| "gbody G_stash = STR ''saves uncommitted changes and cleans the working tree''"
| "gbody G_diff_staged = STR ''shows what is staged for the next commit''"
| "gbody G_log = STR ''shows the commit history (git log --oneline for one line each)''"
| "gbody G_clone = STR ''copies a remote repository''"
| "gbody G_init = STR ''creates a new repository in the current directory''"
| "gbody G_config_name = STR ''sets your commit author name''"
| "gbody G_status = STR ''shows staged, unstaged and untracked files''"
| "gbody G_fetch = STR ''downloads remote commits without merging them''"
| "gbody G_pull_rebase = STR ''fetches and rebases your local commits on top''"
| "gbody G_cherry_pick = STR ''applies that commit onto the current branch''"
| "gbody G_tag_a = STR ''creates an annotated tag''"
| "gbody G_blame = STR ''shows who last changed each line''"
| "gbody G_revert = STR ''adds a new commit that undoes it - safe for shared history''"

definition gnote :: "gintent \<Rightarrow> String.literal" where
  "gnote i = (if gwarn i then STR ''WARNING: '' + gbody i else gbody i)"

definition git_reply :: "gintent \<Rightarrow> reply" where
  "git_reply i = Reply True (STR ''git_cmd'')
     (STR ''The command is '' + bquote + gcmd i + bquote + STR '' - it '' + gnote i + STR ''.'') (Some (gcmd i))"

theorem git_warns_exactly_destructive:
  "filter gwarn all_intents = [G_reset_hard, G_restore]"
  by (simp add: all_intents_def)

theorem git_all_intents_complete: "\<forall>i. i \<in> set all_intents"
proof
  fix i show "i \<in> set all_intents" by (cases i) (simp_all add: all_intents_def)
qed

theorem git_commands_distinct: "distinct (map gcmd all_intents)"
  by (simp add: all_intents_def dquote_def)

theorem git_reply_states_command:
  "response (git_reply i) = STR ''The command is '' + bquote + gcmd i + bquote + STR '' - it '' + gnote i + STR ''.'' \<and>
   answered (git_reply i) \<and> stated (git_reply i) = Some (gcmd i)"
  by (simp add: git_reply_def)

definition git_self_test :: bool where
  "git_self_test \<longleftrightarrow>
     response (git_reply G_stash_pop) = STR ''The command is `git stash pop` - it re-applies the latest stash and drops it.'' \<and>
     response (git_reply G_reset_hard) =
       STR ''The command is `git reset --hard HEAD~1` - it WARNING: this permanently discards the last commit and any uncommitted changes.''"

end
