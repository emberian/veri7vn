theory Networking
  imports Computing_Num
begin

text \<open>Lane S15-computing, specialist @{text networking}
(upstream/root/specialists/networking/organ_networking_v1.py): IPv4 addressing
arithmetic. An address is four octets; its value is the 32-bit number
@{text "((a*256+b)*256+c)*256+d"}. Every fact the organ states is an exact
natural-number identity about blocks of size @{text "2^(32-p)"}.\<close>

section \<open>Addresses and blocks\<close>

datatype ip4 = IP nat nat nat nat

fun ip_ok :: "ip4 \<Rightarrow> bool" where
  "ip_ok (IP a b c d) = (a \<le> 255 \<and> b \<le> 255 \<and> c \<le> 255 \<and> d \<le> 255)"

fun ip_val :: "ip4 \<Rightarrow> nat" where
  "ip_val (IP a b c d) = ((a * 256 + b) * 256 + c) * 256 + d"

definition of_val :: "nat \<Rightarrow> ip4" where
  "of_val n = IP (n div 16777216 mod 256) (n div 65536 mod 256) (n div 256 mod 256) (n mod 256)"

lemma byte_dm:
  fixes d X :: nat
  assumes "d < 256"
  shows "(256 * X + d) div 256 = X \<and> (256 * X + d) mod 256 = d"
proof -
  have q: "(256 * X + d) div 256 = X"
    by (rule div_nat_eqI) (use assms in auto)
  have "256 * ((256 * X + d) div 256) + (256 * X + d) mod 256 = 256 * X + d" by (rule mult_div_mod_eq)
  then have "(256 * X + d) mod 256 = d" using q by simp
  then show ?thesis using q by simp
qed

lemma byte_sum:
  fixes n q1 q2 q3 a b c d :: nat
  assumes "n = 256 * q1 + d" "q1 = 256 * q2 + c" "q2 = 256 * q3 + b" "a = q3"
  shows "((a * 256 + b) * 256 + c) * 256 + d = n"
  using assms by simp

lemma of_val_ip_val: "ip_ok x \<Longrightarrow> of_val (ip_val x) = x"
proof (cases x)
  case (IP a b c d)
  assume ok: "ip_ok x"
  then have lim: "a \<le> 255" "b \<le> 255" "c \<le> 255" "d \<le> 255" using IP by simp_all
  have lt: "a < 256" "b < 256" "c < 256" "d < 256" using lim by simp_all
  define n where "n = ip_val x"
  have n: "n = 256 * (256 * (256 * a + b) + c) + d" using IP by (simp add: n_def)
  have s1: "n div 256 = 256 * (256 * a + b) + c \<and> n mod 256 = d" using byte_dm[of d "256 * (256 * a + b) + c"] lt n by simp
  have s2: "(256 * (256 * a + b) + c) div 256 = 256 * a + b \<and> (256 * (256 * a + b) + c) mod 256 = c"
    using byte_dm[of c "256 * a + b"] lt by simp
  have s3: "(256 * a + b) div 256 = a \<and> (256 * a + b) mod 256 = b" using byte_dm[of b a] lt by simp
  have A: "n div 256 div 256 div 256 = a" using s1 s2 s3 by simp
  have B: "n div 256 div 256 mod 256 = b" using s1 s2 s3 by simp
  have C: "n div 256 mod 256 = c" using s1 s2 by simp
  have D: "n mod 256 = d" using s1 by simp
  have am: "a mod 256 = a" using lt by simp
  have d1: "n div 65536 = n div 256 div 256" by (simp add: div_div_eq_right)
  have d2: "n div 16777216 = n div 256 div 256 div 256" by (simp add: div_div_eq_right)
  have "of_val n = IP a b c d" using A B C D am by (simp add: of_val_def d1 d2)
  then show ?thesis using IP n_def by simp
qed

lemma ip_val_of_val: "n < 4294967296 \<Longrightarrow> ip_ok (of_val n) \<and> ip_val (of_val n) = n"
proof -
  assume n: "n < 4294967296"
  define q1 where "q1 = n div 256"
  define q2 where "q2 = q1 div 256"
  define q3 where "q3 = q2 div 256"
  have d1: "n div 65536 = q2" by (simp add: q2_def q1_def div_div_eq_right)
  have d2: "n div 16777216 = q3" by (simp add: q3_def q2_def q1_def div_div_eq_right)
  have q3lt: "q3 < 256" using n by (simp add: d2[symmetric] less_mult_imp_div_less)
  have e1: "n = 256 * q1 + n mod 256" by (simp add: q1_def)
  have e2: "q1 = 256 * q2 + q1 mod 256" by (simp add: q2_def)
  have e3: "q2 = 256 * q3 + q2 mod 256" by (simp add: q3_def)
  have "((q3 * 256 + q2 mod 256) * 256 + q1 mod 256) * 256 + n mod 256 = n"
    by (rule byte_sum[OF e1 e2 e3 refl])
  moreover have "q3 mod 256 = q3" using q3lt by simp
  ultimately have v: "ip_val (of_val n) = n"
    using d1 d2 q1_def q2_def by (simp add: of_val_def)
  have b1: "q2 mod 256 \<le> 255" "q1 mod 256 \<le> 255" "n mod 256 \<le> 255"
    using mod_less_divisor[of 256 q2] mod_less_divisor[of 256 q1] mod_less_divisor[of 256 n] by linarith+
  have ok: "ip_ok (of_val n)" using d1 d2 q1_def q2_def b1 q3lt by (simp add: of_val_def)
  show ?thesis using v ok by simp
qed

lemma ip_val_lt: "ip_ok x \<Longrightarrow> ip_val x < 4294967296"
  by (cases x) (auto; arith)

definition bsize :: "nat \<Rightarrow> nat" where "bsize p = 2 ^ (32 - p)"
definition mask_val :: "nat \<Rightarrow> nat" where "mask_val p = 4294967296 - bsize p"
definition wild_val :: "nat \<Rightarrow> nat" where "wild_val p = bsize p - 1"
definition net_of :: "nat \<Rightarrow> nat \<Rightarrow> nat" where "net_of x p = (x div bsize p) * bsize p"
definition bcast_of :: "nat \<Rightarrow> nat \<Rightarrow> nat" where "bcast_of x p = net_of x p + bsize p - 1"
definition usable :: "nat \<Rightarrow> nat" where
  "usable p = (if p \<le> 30 then bsize p - 2 else if p = 31 then 2 else 1)"

lemma bsize_pos [simp]: "0 < bsize p" by (simp add: bsize_def)

lemma bsize_le: "bsize p \<le> 4294967296"
proof -
  have "bsize p \<le> 2 ^ 32" unfolding bsize_def by (rule power_increasing) simp_all
  then show ?thesis by simp
qed

lemma bsize_ge4: assumes "p \<le> 30" shows "4 \<le> bsize p"
proof -
  have e: "32 - p = (30 - p) + 2" using assms by simp
  have "bsize p = 2 ^ (30 - p) * 4" by (simp add: bsize_def e power_add)
  moreover have "0 < (2::nat) ^ (30 - p)" by simp
  ultimately show ?thesis by simp
qed

theorem net_props:
  "net_of x p mod bsize p = 0 \<and> net_of x p \<le> x \<and> x < net_of x p + bsize p"
proof -
  define b where "b = bsize p"
  have b: "0 < b" by (simp add: b_def)
  have 1: "x div b * b + x mod b = x" by (rule div_mult_mod_eq)
  have 2: "x mod b < b" using b by (rule mod_less_divisor)
  have a: "x div b * b mod b = 0" by simp
  have c: "x div b * b \<le> x" using 1 by linarith
  have d: "x < x div b * b + b" using 1 2 by linarith
  show ?thesis using a c d unfolding net_of_def b_def[symmetric] by blast
qed

theorem net_unique:
  assumes "n mod bsize p = 0" "n \<le> x" "x < n + bsize p"
  shows "net_of x p = n"
proof -
  define b where "b = bsize p"
  have b: "0 < b" by (simp add: b_def)
  obtain k where k: "n = b * k" using assms(1) unfolding b_def[symmetric] by blast
  have "x div b = k"
    by (rule div_nat_eqI) (use assms k in \<open>auto simp: b_def[symmetric]\<close>)
  then show ?thesis using k by (simp add: net_of_def b_def[symmetric])
qed

theorem net_of_eq_iff:
  assumes "base mod bsize p = 0"
  shows "net_of x p = base \<longleftrightarrow> base \<le> x \<and> x < base + bsize p"
proof
  assume "net_of x p = base"
  then show "base \<le> x \<and> x < base + bsize p" using net_props[of x p] by simp
next
  assume "base \<le> x \<and> x < base + bsize p"
  then show "net_of x p = base" using assms by (intro net_unique) auto
qed

theorem bcast_props:
  "x \<le> bcast_of x p \<and> bcast_of x p < x + bsize p \<and> (bcast_of x p + 1) mod bsize p = 0"
proof -
  have n: "net_of x p mod bsize p = 0" and l: "net_of x p \<le> x" and h: "x < net_of x p + bsize p"
    using net_props[of x p] by simp_all
  have pos: "0 < bsize p" by simp
  obtain k where k: "net_of x p = bsize p * k" using n by blast
  have "(bcast_of x p + 1) = bsize p * (k + 1)" using pos k by (simp add: bcast_of_def algebra_simps)
  then have "(bcast_of x p + 1) mod bsize p = 0" by simp
  moreover have "x \<le> bcast_of x p" "bcast_of x p < x + bsize p"
    using l h pos by (auto simp: bcast_of_def)
  ultimately show ?thesis by blast
qed

theorem mask_wildcard_complement:
  "mask_val p + wild_val p = 4294967295"
  using bsize_le[of p] bsize_pos[of p] by (simp add: mask_val_def wild_val_def; arith)

theorem usable_hosts:
  assumes "p \<le> 30"
  shows "net_of x p + 1 \<le> bcast_of x p - 1 \<and>
         usable p = (bcast_of x p - 1) - (net_of x p + 1) + 1"
  using bsize_ge4[OF assms] by (simp add: usable_def bcast_of_def assms; arith)

theorem usable_p2p: "usable 31 = 2 \<and> usable 32 = 1 \<and> bsize 31 = 2 \<and> bsize 32 = 1"
  by (simp add: usable_def bsize_def)

subsection \<open>Mask and prefix\<close>

definition mask_prefix :: "ip4 \<Rightarrow> nat option" where
  "mask_prefix m = (if ip_ok m then find (\<lambda>p. mask_val p = ip_val m) [0..<33] else None)"

lemma mask_val_inj: "p \<le> 32 \<Longrightarrow> q \<le> 32 \<Longrightarrow> mask_val p = mask_val q \<Longrightarrow> p = q"
proof -
  assume p: "p \<le> 32" and q: "q \<le> 32" and e: "mask_val p = mask_val q"
  have "bsize p = bsize q" using e bsize_le[of p] bsize_le[of q] by (simp add: mask_val_def; arith)
  then have "(2::nat) ^ (32 - p) = 2 ^ (32 - q)" by (simp add: bsize_def)
  then have "32 - p = 32 - q" by (simp add: power_inject_exp)
  then show "p = q" using p q by arith
qed

theorem mask_prefix_iff:
  "mask_prefix m = Some p \<longleftrightarrow> p \<le> 32 \<and> ip_ok m \<and> ip_val m = mask_val p"
proof
  assume h: "mask_prefix m = Some p"
  then have ok: "ip_ok m" by (auto simp: mask_prefix_def split: if_splits)
  from h have "find (\<lambda>p. mask_val p = ip_val m) [0..<33] = Some p"
    by (simp add: mask_prefix_def ok)
  then have "p \<in> set [0..<33]" "mask_val p = ip_val m" by (auto dest: findSomeD)
  then show "p \<le> 32 \<and> ip_ok m \<and> ip_val m = mask_val p" using ok by auto
next
  assume h: "p \<le> 32 \<and> ip_ok m \<and> ip_val m = mask_val p"
  then have p: "p \<le> 32" and ok: "ip_ok m" and v: "ip_val m = mask_val p" by simp_all
  have ex: "find (\<lambda>p. mask_val p = ip_val m) [0..<33] \<noteq> None"
  proof -
    have "\<exists>x. x < 33 \<and> mask_val x = ip_val m" using p v by (intro exI[of _ p]) simp
    then show ?thesis by (auto simp: find_None_iff)
  qed
  then obtain q where q: "find (\<lambda>p. mask_val p = ip_val m) [0..<33] = Some q" by auto
  then have "q \<in> set [0..<33]" "mask_val q = ip_val m" by (auto dest: findSomeD)
  then have "q = p" using mask_val_inj[of q p] p v by auto
  then show "mask_prefix m = Some p" using q ok by (simp add: mask_prefix_def)
qed

subsection \<open>The smallest prefix for N hosts\<close>

fun pfh_aux :: "nat \<Rightarrow> nat \<Rightarrow> nat option" where
  "pfh_aux n 0 = None"
| "pfh_aux n (Suc q) = (if n \<le> bsize (Suc q) - 2 then Some (Suc q) else pfh_aux n q)"

definition pfh :: "nat \<Rightarrow> nat option" where "pfh n = pfh_aux n 30"

lemma pfh_aux_some:
  "pfh_aux n k = Some q \<Longrightarrow> 1 \<le> q \<and> q \<le> k \<and> n \<le> bsize q - 2 \<and>
     (\<forall>q'. q < q' \<longrightarrow> q' \<le> k \<longrightarrow> \<not> n \<le> bsize q' - 2)"
proof (induction k arbitrary: q)
  case 0 then show ?case by simp
next
  case (Suc k)
  show ?case
  proof (cases "n \<le> bsize (Suc k) - 2")
    case True
    then show ?thesis using Suc.prems by simp
  next
    case False
    then have "pfh_aux n k = Some q" using Suc.prems by simp
    from Suc.IH[OF this] have ih: "1 \<le> q" "q \<le> k" "n \<le> bsize q - 2"
      "\<forall>q'. q < q' \<longrightarrow> q' \<le> k \<longrightarrow> \<not> n \<le> bsize q' - 2" by simp_all
    show ?thesis
    proof (intro conjI allI impI)
      show "1 \<le> q" using ih(1) .
      show "q \<le> Suc k" using ih(2) by simp
      show "n \<le> bsize q - 2" using ih(3) .
      fix q' assume a: "q < q'" and b: "q' \<le> Suc k"
      show "\<not> n \<le> bsize q' - 2"
        by (cases "q' = Suc k") (use False ih(4) a b in \<open>auto\<close>)
    qed
  qed
qed

lemma pfh_aux_none:
  "pfh_aux n k = None \<Longrightarrow> 1 \<le> q' \<Longrightarrow> q' \<le> k \<Longrightarrow> \<not> n \<le> bsize q' - 2"
proof (induction k arbitrary: q')
  case 0 then show ?case by simp
next
  case (Suc k)
  have n: "\<not> n \<le> bsize (Suc k) - 2" and r: "pfh_aux n k = None" using Suc.prems(1) by (auto split: if_splits)
  show ?case
  proof (cases "q' = Suc k")
    case True then show ?thesis using n by simp
  next
    case False then show ?thesis using Suc.IH[OF r Suc.prems(2)] Suc.prems(3) by simp
  qed
qed

theorem pfh_smallest:
  assumes "pfh n = Some q"
  shows "1 \<le> q \<and> q \<le> 30 \<and> n \<le> usable q \<and> (\<forall>q'. q < q' \<longrightarrow> q' \<le> 30 \<longrightarrow> \<not> n \<le> usable q')"
proof -
  from assms have h: "pfh_aux n 30 = Some q" by (simp add: pfh_def)
  from pfh_aux_some[OF h] have a: "1 \<le> q" "q \<le> 30" "n \<le> bsize q - 2"
    and m: "\<forall>q'. q < q' \<longrightarrow> q' \<le> 30 \<longrightarrow> \<not> n \<le> bsize q' - 2" by simp_all
  show ?thesis using a m by (auto simp: usable_def)
qed

theorem pfh_complete:
  "pfh n = None \<Longrightarrow> 1 \<le> q' \<Longrightarrow> q' \<le> 30 \<Longrightarrow> \<not> n \<le> usable q'"
  using pfh_aux_none[of n 30 q'] by (simp add: pfh_def usable_def)

subsection \<open>RFC 1918\<close>

definition priv_blocks :: "(nat \<times> nat) list" where
  "priv_blocks = [(167772160, 8), (2886729728, 12), (3232235520, 16)]"

definition priv_block :: "ip4 \<Rightarrow> (nat \<times> nat) option" where
  "priv_block a = find (\<lambda>bp. net_of (ip_val a) (snd bp) = fst bp) priv_blocks"

theorem priv_block_range:
  assumes "priv_block a = Some (b, p)"
  shows "b \<le> ip_val a \<and> ip_val a < b + 2 ^ (32 - p) \<and> (b, p) \<in> set priv_blocks"
proof -
  from assms have "(b, p) \<in> set priv_blocks" "net_of (ip_val a) p = b"
    unfolding priv_block_def by (auto dest: findSomeD)
  then show ?thesis using net_props[of "ip_val a" p] by (simp add: bsize_def)
qed

theorem priv_block_complete:
  assumes "(b, p) \<in> set priv_blocks" "b \<le> ip_val a" "ip_val a < b + 2 ^ (32 - p)"
  shows "priv_block a \<noteq> None"
proof -
  have al: "b mod bsize p = 0" using assms(1) by (auto simp: priv_blocks_def bsize_def)
  have "net_of (ip_val a) p = b" using assms(2,3) al by (simp add: net_of_eq_iff bsize_def)
  then show ?thesis using assms(1) unfolding priv_block_def by (auto simp: find_None_iff)
qed

section \<open>Requests, declines, values\<close>

datatype nwant = W_hosts | W_network | W_broadcast | W_first | W_last | W_range

datatype nbody =
    BMask nat | BPrefix ip4 | BWildcard nat | BCount nat bool
  | BAddr nwant ip4 nat | BNeedPrefix | BSame ip4 ip4 "nat option"
  | BPrivate ip4 | BSubnets nat nat | BForHosts nat

text \<open>@{text NReq} carries every address token (masks included), the masks and
the prefix lengths read from the text, in order, then the question.\<close>
datatype nreq = NReq "ip4 list" "ip4 list" "nat list" nbody

datatype ndecl = D_ip ip4 | D_mask ip4 | D_prefix nat | D_need | D_hosts nat | D_subnets nat nat | D_p2p nat

datatype nval = VIp ip4 | VNat nat | VBool bool | VRange ip4 ip4

definition body_decline :: "nbody \<Rightarrow> ndecl option" where
  "body_decline b = (case b of
      BMask p \<Rightarrow> if 32 < p then Some (D_prefix p) else None
    | BPrefix m \<Rightarrow> if mask_prefix m = None then Some (D_mask m) else None
    | BWildcard p \<Rightarrow> if 32 < p then Some (D_prefix p) else None
    | BCount p w \<Rightarrow> if 32 < p then Some (D_prefix p) else None
    | BAddr w a p \<Rightarrow> if 32 < p then Some (D_prefix p)
        else if ip_ok a = False then Some (D_ip a)
        else if 31 \<le> p \<and> w \<noteq> W_hosts \<and> w \<noteq> W_network then Some (D_p2p p) else None
    | BNeedPrefix \<Rightarrow> Some D_need
    | BSame a b None \<Rightarrow> Some D_need
    | BSame a b (Some p) \<Rightarrow> if 32 < p then Some (D_prefix p) else None
    | BPrivate a \<Rightarrow> if ip_ok a then None else Some (D_ip a)
    | BSubnets m n \<Rightarrow> if 32 < m then Some (D_prefix m) else if 32 < n then Some (D_prefix n)
        else if m < n then Some (D_subnets m n) else None
    | BForHosts n \<Rightarrow> if n < 1 \<or> pfh n = None then Some (D_hosts n) else None)"

definition net_decline :: "nreq \<Rightarrow> ndecl option" where
  "net_decline r = (case r of NReq ips ms ps b \<Rightarrow>
     (case find (\<lambda>i. \<not> ip_ok i) ips of Some i \<Rightarrow> Some (D_ip i) | None \<Rightarrow>
      (case find (\<lambda>m. mask_prefix m = None) ms of Some m \<Rightarrow> Some (D_mask m) | None \<Rightarrow>
       (case find (\<lambda>p. 32 < p) ps of Some p \<Rightarrow> Some (D_prefix p) | None \<Rightarrow> body_decline b))))"

definition is_private :: "ip4 \<Rightarrow> bool" where "is_private a = (priv_block a \<noteq> None)"

definition net_value :: "nbody \<Rightarrow> nval" where
  "net_value b = (case b of
      BMask p \<Rightarrow> VIp (of_val (mask_val p))
    | BPrefix m \<Rightarrow> VNat (case mask_prefix m of Some p \<Rightarrow> p | None \<Rightarrow> 0)
    | BWildcard p \<Rightarrow> VIp (of_val (wild_val p))
    | BCount p w \<Rightarrow> VNat (if w then usable p else bsize p)
    | BAddr W_hosts a p \<Rightarrow> VNat (usable p)
    | BAddr W_network a p \<Rightarrow> VIp (of_val (net_of (ip_val a) p))
    | BAddr W_broadcast a p \<Rightarrow> VIp (of_val (bcast_of (ip_val a) p))
    | BAddr W_first a p \<Rightarrow> VIp (of_val (net_of (ip_val a) p + 1))
    | BAddr W_last a p \<Rightarrow> VIp (of_val (bcast_of (ip_val a) p - 1))
    | BAddr W_range a p \<Rightarrow> VRange (of_val (net_of (ip_val a) p + 1)) (of_val (bcast_of (ip_val a) p - 1))
    | BNeedPrefix \<Rightarrow> VNat 0
    | BSame a b None \<Rightarrow> VNat 0
    | BSame a b (Some p) \<Rightarrow> VBool (net_of (ip_val a) p = net_of (ip_val b) p)
    | BPrivate a \<Rightarrow> VBool (is_private a)
    | BSubnets m n \<Rightarrow> VNat (2 ^ (m - n))
    | BForHosts n \<Rightarrow> VNat (case pfh n of Some q \<Rightarrow> q | None \<Rightarrow> 0))"

datatype nout = NValue nval | NDecline ndecl

definition net_kernel :: "nreq \<Rightarrow> nout" where
  "net_kernel r = (case net_decline r of Some d \<Rightarrow> NDecline d
     | None \<Rightarrow> (case r of NReq ips ms ps b \<Rightarrow> NValue (net_value b)))"

section \<open>What the answers mean\<close>

theorem net_kernel_value:
  "net_kernel (NReq ips ms ps b) = NValue v \<longleftrightarrow> net_decline (NReq ips ms ps b) = None \<and> v = net_value b"
  by (auto simp: net_kernel_def split: option.splits)

theorem net_decline_ip:
  "net_decline (NReq ips ms ps b) = Some (D_ip i) \<Longrightarrow> \<not> ip_ok i"
  by (auto simp: net_decline_def body_decline_def dest: findSomeD
      split: option.splits nbody.splits nwant.splits if_splits)

theorem net_decline_prefix:
  "net_decline (NReq ips ms ps b) = Some (D_prefix p) \<Longrightarrow> 32 < p"
  by (auto simp: net_decline_def body_decline_def dest: findSomeD
      split: option.splits nbody.splits nwant.splits if_splits)

theorem net_decline_mask:
  "net_decline (NReq ips ms ps b) = Some (D_mask m) \<Longrightarrow> mask_prefix m = None"
  by (auto simp: net_decline_def body_decline_def dest: findSomeD
      split: option.splits nbody.splits nwant.splits if_splits)

theorem net_mask_value:
  assumes "net_decline (NReq ips ms ps (BMask p)) = None"
  shows "\<exists>m. net_value (BMask p) = VIp m \<and> ip_ok m \<and> mask_prefix m = Some p \<and> ip_val m = 4294967296 - 2 ^ (32 - p)"
proof -
  have p: "p \<le> 32" using assms by (auto simp: net_decline_def body_decline_def split: option.splits if_splits)
  have lt: "mask_val p < 4294967296" using bsize_pos[of p] by (simp add: mask_val_def)
  have "mask_prefix (of_val (mask_val p)) = Some p"
    using ip_val_of_val[OF lt] p by (simp add: mask_prefix_iff)
  then show ?thesis using ip_val_of_val[OF lt] by (auto simp: net_value_def mask_val_def bsize_def)
qed

theorem net_prefix_value:
  assumes "net_decline (NReq ips ms ps (BPrefix m)) = None"
  shows "\<exists>p. net_value (BPrefix m) = VNat p \<and> p \<le> 32 \<and> ip_val m = 4294967296 - 2 ^ (32 - p)"
proof -
  from assms obtain p where "mask_prefix m = Some p"
    by (auto simp: net_decline_def body_decline_def split: option.splits if_splits)
  then show ?thesis using mask_prefix_iff[of m p] by (auto simp: net_value_def mask_val_def bsize_def)
qed

theorem net_wildcard_value:
  assumes "net_decline (NReq ips ms ps (BWildcard p)) = None"
  shows "\<exists>w m. net_value (BWildcard p) = VIp w \<and> ip_ok w \<and> m = mask_val p \<and> ip_val w + m = 4294967295"
proof -
  have "wild_val p < 4294967296" using bsize_le[of p] by (simp add: wild_val_def)
  then show ?thesis using ip_val_of_val mask_wildcard_complement[of p] by (auto simp: net_value_def)
qed

theorem net_network_value:
  assumes "net_decline (NReq ips ms ps (BAddr W_network a p)) = None"
  shows "\<exists>n. net_value (BAddr W_network a p) = VIp n \<and> ip_ok n \<and> ip_val n mod 2 ^ (32 - p) = 0 \<and>
           ip_val n \<le> ip_val a \<and> ip_val a < ip_val n + 2 ^ (32 - p) \<and> p \<le> 32"
proof -
  from assms have p: "p \<le> 32" and a: "ip_ok a"
    by (auto simp: net_decline_def body_decline_def split: option.splits if_splits)
  have lt: "net_of (ip_val a) p < 4294967296" using net_props[of "ip_val a" p] ip_val_lt[OF a] bsize_le[of p]
    by (auto; arith)
  show ?thesis using ip_val_of_val[OF lt] net_props[of "ip_val a" p] p by (auto simp: net_value_def bsize_def)
qed

theorem net_broadcast_value:
  assumes "net_decline (NReq ips ms ps (BAddr W_broadcast a p)) = None"
  shows "\<exists>b. net_value (BAddr W_broadcast a p) = VIp b \<and> ip_ok b \<and> ip_val a \<le> ip_val b \<and>
           ip_val b < ip_val a + 2 ^ (32 - p) \<and> (ip_val b + 1) mod 2 ^ (32 - p) = 0"
proof -
  from assms have p: "p \<le> 32" and a: "ip_ok a"
    by (auto simp: net_decline_def body_decline_def split: option.splits if_splits)
  have n: "net_of (ip_val a) p + bsize p \<le> 4294967296"
  proof -
    have 1: "net_of (ip_val a) p mod bsize p = 0" using net_props[of "ip_val a" p] by simp
    obtain k where k: "net_of (ip_val a) p = bsize p * k" using 1 by blast
    have 2: "bsize p * k \<le> ip_val a" using net_props[of "ip_val a" p] k by simp
    have "ip_val a < 4294967296" by (rule ip_val_lt[OF a])
    obtain m where m: "4294967296 = bsize p * m"
    proof -
      have "(2::nat) ^ 32 = 2 ^ (32 - p) * 2 ^ p" using p by (simp flip: power_add)
      then show thesis using that by (simp add: bsize_def)
    qed
    have ipl: "ip_val a < 4294967296" by (rule ip_val_lt[OF a])
    have "k < m"
    proof (rule ccontr)
      assume "\<not> k < m"
      then have "m \<le> k" by simp
      then have "bsize p * m \<le> bsize p * k" by (rule mult_le_mono2)
      then show False using m 2 ipl by linarith
    qed
    then have "Suc k \<le> m" by simp
    then have "bsize p * Suc k \<le> bsize p * m" by (rule mult_le_mono2)
    then show ?thesis using k m by simp
  qed
  have lt: "bcast_of (ip_val a) p < 4294967296" using n by (auto simp: bcast_of_def; arith)
  show ?thesis using ip_val_of_val[OF lt] bcast_props[of "ip_val a" p] by (auto simp: net_value_def bsize_def)
qed

theorem net_usable_value:
  assumes "net_decline (NReq ips ms ps (BAddr W_hosts a p)) = None"
  shows "net_value (BAddr W_hosts a p) = VNat (usable p) \<and>
         (p \<le> 30 \<longrightarrow> usable p = 2 ^ (32 - p) - 2) \<and> usable 31 = 2 \<and> usable 32 = 1"
  using assms by (simp add: net_value_def usable_def bsize_def)

theorem net_same_value:
  assumes "net_decline (NReq ips ms ps (BSame a b (Some p))) = None"
  shows "net_value (BSame a b (Some p)) = VBool (net_of (ip_val a) p = net_of (ip_val b) p)"
  by (simp add: net_value_def)

theorem net_private_iff:
  "is_private a \<longleftrightarrow> (\<exists>b p. (b, p) \<in> set priv_blocks \<and> b \<le> ip_val a \<and> ip_val a < b + 2 ^ (32 - p))"
proof
  assume "is_private a"
  then obtain b p where "priv_block a = Some (b, p)" by (cases "priv_block a") (auto simp: is_private_def)
  then show "\<exists>b p. (b, p) \<in> set priv_blocks \<and> b \<le> ip_val a \<and> ip_val a < b + 2 ^ (32 - p)"
    using priv_block_range by blast
next
  assume "\<exists>b p. (b, p) \<in> set priv_blocks \<and> b \<le> ip_val a \<and> ip_val a < b + 2 ^ (32 - p)"
  then show "is_private a" using priv_block_complete by (auto simp: is_private_def)
qed

theorem net_subnets_value:
  assumes "net_decline (NReq ips ms ps (BSubnets m n)) = None"
  shows "n \<le> m \<and> net_value (BSubnets m n) = VNat (2 ^ (m - n)) \<and>
         (2::nat) ^ (m - n) * 2 ^ (32 - m) = 2 ^ (32 - n)"
proof -
  from assms have mn: "n \<le> m" and m32: "m \<le> 32"
    by (auto simp: net_decline_def body_decline_def split: option.splits if_splits)
  have "(m - n) + (32 - m) = 32 - n" using mn m32 by arith
  then have e: "(2::nat) ^ (m - n) * 2 ^ (32 - m) = 2 ^ (32 - n)" by (simp add: power_add[symmetric])
  show ?thesis using mn e by (simp add: net_value_def)
qed

theorem net_forhosts_value:
  assumes "net_decline (NReq ips ms ps (BForHosts n)) = None"
  shows "\<exists>q. net_value (BForHosts n) = VNat q \<and> 1 \<le> q \<and> q \<le> 30 \<and> n \<le> usable q \<and>
           (\<forall>q'. q < q' \<longrightarrow> q' \<le> 30 \<longrightarrow> \<not> n \<le> usable q')"
proof -
  from assms obtain q where "pfh n = Some q"
    by (cases "pfh n") (auto simp: net_decline_def body_decline_def split: option.splits if_splits)
  then show ?thesis using pfh_smallest by (auto simp: net_value_def)
qed

theorem net_forhosts_declines_iff:
  "net_decline (NReq [] [] [] (BForHosts n)) \<noteq> None \<longleftrightarrow> n < 1 \<or> (\<forall>q. 1 \<le> q \<longrightarrow> q \<le> 30 \<longrightarrow> \<not> n \<le> usable q)"
proof
  assume "net_decline (NReq [] [] [] (BForHosts n)) \<noteq> None"
  then have "n < 1 \<or> pfh n = None" by (auto simp: net_decline_def body_decline_def split: if_splits)
  then show "n < 1 \<or> (\<forall>q. 1 \<le> q \<longrightarrow> q \<le> 30 \<longrightarrow> \<not> n \<le> usable q)"
    using pfh_complete by blast
next
  assume h: "n < 1 \<or> (\<forall>q. 1 \<le> q \<longrightarrow> q \<le> 30 \<longrightarrow> \<not> n \<le> usable q)"
  show "net_decline (NReq [] [] [] (BForHosts n)) \<noteq> None"
  proof (cases "pfh n")
    case None then show ?thesis by (simp add: net_decline_def body_decline_def)
  next
    case (Some q)
    from pfh_smallest[OF Some] have "1 \<le> q" "q \<le> 30" "n \<le> usable q" by simp_all
    then show ?thesis using h by (auto simp: net_decline_def body_decline_def Some)
  qed
qed

section \<open>Response text\<close>

definition sint :: "nat \<Rightarrow> String.literal" where "sint n = lit (digits n)"

fun ip_str :: "ip4 \<Rightarrow> String.literal" where
  "ip_str (IP a b c d) = sint a + STR ''.'' + sint b + STR ''.'' + sint c + STR ''.'' + sint d"

definition net_str :: "nat \<Rightarrow> nat \<Rightarrow> String.literal" where
  "net_str x p = ip_str (of_val (net_of x p)) + STR ''/'' + sint p"

definition ncommas :: "nat \<Rightarrow> String.literal" where "ncommas n = commas (int n)"

definition p2p_note :: "nat \<Rightarrow> String.literal" where
  "p2p_note p = (if p = 31 then STR ''RFC 3021 point-to-point, no network/broadcast''
                 else if p = 32 then STR ''a single-host route'' else STR ''network and broadcast reserved'')"

definition cidr_special :: "ip4 \<Rightarrow> String.literal" where
  "cidr_special a = (if net_of (ip_val a) 8 = 2130706432 then STR '' It is loopback (127.0.0.0/8).''
     else if net_of (ip_val a) 16 = 2851995648 then STR '' It is link-local (169.254.0.0/16).''
     else if net_of (ip_val a) 10 = 1681915904
       then STR '' It is shared address space for carrier-grade NAT (100.64.0.0/10, RFC 6598), not RFC 1918.''
     else STR '''')"

definition decl_kind :: "ndecl \<Rightarrow> String.literal" where
  "decl_kind d = (case d of D_need \<Rightarrow> STR ''underspecified'' | D_p2p p \<Rightarrow> STR ''p2p'' | _ \<Rightarrow> STR ''impossible'')"

definition decl_text :: "ndecl \<Rightarrow> String.literal" where
  "decl_text d = (case d of
      D_ip i \<Rightarrow> ip_str i + STR '' is not a valid IPv4 address (each of the four octets is 0-255).''
    | D_mask m \<Rightarrow> ip_str m + STR '' is not a valid subnet mask (a mask is contiguous 1 bits followed by 0 bits).''
    | D_prefix p \<Rightarrow> STR ''/'' + sint p + STR '' is not a valid IPv4 prefix length (0-32).''
    | D_need \<Rightarrow> STR ''I need the prefix length or subnet mask to work that out; I won'' + apos + STR ''t assume one.''
    | D_hosts n \<Rightarrow> STR ''No IPv4 subnet holds '' + ncommas n + STR '' usable hosts (a /1 holds at most 2,147,483,646).''
    | D_subnets m n \<Rightarrow> STR ''A /'' + sint m + STR '' is larger than a /'' + sint n + STR '', so no /'' + sint m
        + STR '' subnets fit inside it.''
    | D_p2p p \<Rightarrow> STR ''A /'' + sint p + STR '' has no broadcast address or reserved network address (''
        + (if p = 31 then STR ''RFC 3021 point-to-point'' else STR ''single host'') + STR '').'')"

definition kind_of_body :: "nbody \<Rightarrow> String.literal" where
  "kind_of_body b = (case b of
      BMask _ \<Rightarrow> STR ''mask'' | BPrefix _ \<Rightarrow> STR ''prefix'' | BWildcard _ \<Rightarrow> STR ''wildcard''
    | BCount _ w \<Rightarrow> (if w then STR ''hosts'' else STR ''total'')
    | BAddr w _ _ \<Rightarrow> (case w of W_hosts \<Rightarrow> STR ''hosts'' | W_network \<Rightarrow> STR ''network''
        | W_broadcast \<Rightarrow> STR ''broadcast'' | W_first \<Rightarrow> STR ''first'' | W_last \<Rightarrow> STR ''last'' | W_range \<Rightarrow> STR ''range'')
    | BNeedPrefix \<Rightarrow> STR ''underspecified'' | BSame _ _ _ \<Rightarrow> STR ''same_subnet'' | BPrivate _ \<Rightarrow> STR ''private''
    | BSubnets _ _ \<Rightarrow> STR ''subnet_count'' | BForHosts _ \<Rightarrow> STR ''prefix_for_hosts'')"

definition yes_no :: "bool \<Rightarrow> String.literal" where "yes_no b = (if b then STR ''Yes'' else STR ''No'')"

definition body_text :: "nbody \<Rightarrow> nval \<Rightarrow> String.literal" where
  "body_text b v = (case b of
      BMask p \<Rightarrow> (case v of VIp m \<Rightarrow> STR ''The subnet mask for /'' + sint p + STR '' is '' + ip_str m + STR ''.'' | _ \<Rightarrow> STR '''')
    | BPrefix m \<Rightarrow> (case v of VNat p \<Rightarrow> STR ''The prefix length is /'' + sint p + STR '' ('' + ip_str m + STR '' has ''
        + sint p + STR '' one bits).'' | _ \<Rightarrow> STR '''')
    | BWildcard p \<Rightarrow> (case v of VIp w \<Rightarrow> STR ''The wildcard mask for /'' + sint p + STR '' is '' + ip_str w
        + STR '' (255.255.255.255 minus the mask).'' | _ \<Rightarrow> STR '''')
    | BCount p w \<Rightarrow> (case v of VNat n \<Rightarrow>
        (if w then STR ''A /'' + sint p + STR '' has '' + ncommas n + STR '' usable host addresses ('' + ncommas (bsize p)
            + STR '' in total; '' + p2p_note p + STR '').''
         else STR ''A /'' + sint p + STR '' contains '' + ncommas n + STR '' addresses in total (2^'' + sint (32 - p)
            + STR ''; '' + ncommas (usable p) + STR '' usable for hosts, '' + p2p_note p + STR '').'')
        | _ \<Rightarrow> STR '''')
    | BAddr w a p \<Rightarrow> (case v of
        VNat n \<Rightarrow> net_str (ip_val a) p + STR '' has '' + ncommas n + STR '' usable host addresses (''
            + ncommas (bsize p) + STR '' in total).''
      | VIp r \<Rightarrow> (case w of
          W_network \<Rightarrow> STR ''The network address is '' + ip_str r + STR '' ('' + ip_str a + STR '' AND mask ''
              + ip_str (of_val (mask_val p)) + STR '').''
        | W_broadcast \<Rightarrow> STR ''The broadcast address is '' + ip_str r + STR '' (the last address of ''
              + net_str (ip_val a) p + STR '').''
        | W_first \<Rightarrow> STR ''The first usable host is '' + ip_str r + STR '' (in '' + net_str (ip_val a) p + STR '').''
        | _ \<Rightarrow> STR ''The last usable host is '' + ip_str r + STR '' (in '' + net_str (ip_val a) p + STR '').'')
      | VRange f l \<Rightarrow> STR ''The usable range is '' + ip_str f + STR '' - '' + ip_str l + STR '' ('' + net_str (ip_val a) p
          + STR ''; network '' + ip_str (of_val (net_of (ip_val a) p)) + STR '', broadcast ''
          + ip_str (of_val (bcast_of (ip_val a) p)) + STR '').''
      | _ \<Rightarrow> STR '''')
    | BNeedPrefix \<Rightarrow> STR ''''
    | BSame a c po \<Rightarrow> (case (po, v) of (Some p, VBool t) \<Rightarrow>
        (if t then STR ''Yes - both are in '' + net_str (ip_val a) p + STR ''.''
         else STR ''No - '' + ip_str a + STR '' is in '' + net_str (ip_val a) p + STR '' but '' + ip_str c + STR '' is in ''
            + net_str (ip_val c) p + STR ''.'')
        | _ \<Rightarrow> STR '''')
    | BPrivate a \<Rightarrow> (case priv_block a of
        Some (base, p) \<Rightarrow> STR ''Yes - '' + ip_str a + STR '' is a private address (RFC 1918 block ''
            + ip_str (of_val base) + STR ''/'' + sint p + STR '').''
      | None \<Rightarrow> STR ''No - '' + ip_str a + STR '' is not in the RFC 1918 private blocks (10/8, 172.16/12, 192.168/16).''
            + cidr_special a)
    | BSubnets m n \<Rightarrow> (case v of VNat c \<Rightarrow> STR ''The count is '' + ncommas c + STR '' /'' + sint m + STR '' subnets in a /''
        + sint n + STR '' (2^('' + sint m + STR '' - '' + sint n + STR '')).'' | _ \<Rightarrow> STR '''')
    | BForHosts n \<Rightarrow> (case v of VNat q \<Rightarrow> STR ''The smallest subnet is /'' + sint q + STR '' (mask ''
        + ip_str (of_val (mask_val q)) + STR '', '' + ncommas (usable q) + STR '' usable hosts = 2^'' + sint (32 - q)
        + STR '' - 2).'' | _ \<Rightarrow> STR ''''))"

definition net_reply :: "nreq \<Rightarrow> reply" where
  "net_reply r = (case net_kernel r of
      NDecline d \<Rightarrow> Reply False (decl_kind d) (decl_text d) None
    | NValue v \<Rightarrow> (case r of NReq _ _ _ b \<Rightarrow> Reply True (kind_of_body b) (body_text b v) None))"

theorem net_reply_answered_iff:
  "answered (net_reply r) \<longleftrightarrow> net_decline r = None"
  by (cases r) (auto simp: net_reply_def net_kernel_def split: option.splits)

theorem net_reply_withheld_names_decline:
  "net_kernel r = NDecline d \<Longrightarrow> \<not> answered (net_reply r) \<and> reply_kind (net_reply r) = decl_kind d
     \<and> response (net_reply r) = decl_text d"
  by (simp add: net_reply_def)

definition net_self_test :: bool where
  "net_self_test \<longleftrightarrow>
     net_value (BMask 12) = VIp (IP 255 240 0 0) \<and>
     net_value (BWildcard 12) = VIp (IP 0 15 255 255) \<and>
     net_value (BAddr W_network (IP 100 100 94 78) 12) = VIp (IP 100 96 0 0) \<and>
     net_value (BAddr W_broadcast (IP 100 100 94 78) 12) = VIp (IP 100 111 255 255) \<and>
     net_value (BAddr W_range (IP 100 100 94 78) 12) = VRange (IP 100 96 0 1) (IP 100 111 255 254) \<and>
     net_value (BCount 12 True) = VNat 1048574 \<and> net_value (BCount 12 False) = VNat 1048576 \<and>
     net_value (BForHosts 100) = VNat 25 \<and> net_value (BSubnets 30 24) = VNat 64 \<and>
     is_private (IP 192 168 1 1) \<and> \<not> is_private (IP 100 100 94 78) \<and> \<not> is_private (IP 172 32 0 1) \<and>
     mask_prefix (IP 255 255 0 255) = None \<and> mask_prefix (IP 255 240 0 0) = Some 12 \<and>
     net_decline (NReq [IP 10 1 300 4] [] [24] (BAddr W_network (IP 10 1 300 4) 24)) = Some (D_ip (IP 10 1 300 4)) \<and>
     net_decline (NReq [IP 192 168 10 77] [] [] BNeedPrefix) = Some D_need \<and>
     net_decline (NReq [] [] [35] (BCount 35 True)) = Some (D_prefix 35) \<and>
     net_decline (NReq [] [] [24, 20] (BSubnets 20 24)) = Some (D_subnets 20 24) \<and>
     net_decline (NReq [IP 172 16 5 9] [] [31] (BAddr W_first (IP 172 16 5 9) 31)) = Some (D_p2p 31) \<and>
     response (net_reply (NReq [] [] [24] (BMask 24))) = STR ''The subnet mask for /24 is 255.255.255.0.'' \<and>
     response (net_reply (NReq [] [] [12] (BCount 12 True))) =
       STR ''A /12 has 1,048,574 usable host addresses (1,048,576 in total; network and broadcast reserved).''"

end
