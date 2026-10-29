theory Mst_Certificate_Export
  imports "Veri7vn_Discrete.Discrete" "HOL-Library.Code_Target_Numeral"
begin

text \<open>The caller supplies both the complete edge list and its proposed tree.
The explicit vertex list must equal the edge-derived universe used by the
existing certificate. This deliberately excludes isolated vertices and the
empty graph; disconnected graphs cannot pass mst_cert. No candidate producer
is part of this interface.\<close>

definition external_mst_cert :: "node list \<Rightarrow> edge list \<Rightarrow> edge list \<Rightarrow> bool" where
  "external_mst_cert vs es t = (distinct vs \<and> 2 \<le> length vs
    \<and> set vs = set (node_list es) \<and> mst_cert es t)"

theorem external_mst_cert_spans:
  assumes "external_mst_cert vs es t"
  shows "spans t es \<and> connects t vs"
proof -
  have c: "mst_cert es t" and v: "set vs = set (node_list es)"
    using assms by (auto simp: external_mst_cert_def)
  have s: "spans t es" using mst_cert_spans[OF c] .
  have "connects t vs" using s v by (auto simp: spans_def connects_def)
  then show ?thesis using s by blast
qed

theorem external_mst_cert_minimal:
  assumes "external_mst_cert vs es t" and "spans t' es"
  shows "wt t \<le> wt t'"
  using assms mst_cert_minimal by (auto simp: external_mst_cert_def)

export_code external_mst_cert mk_rat
  in SML module_name MstCertificate file_prefix mst_certificate

ML \<open>
  val theorems = [@{thm external_mst_cert_spans}, @{thm external_mst_cert_minimal},
    @{thm mst_cert_spans}, @{thm mst_cert_minimal}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error "external MST certificate uses oracles";
  val a = "0"; val b = "1"; val c = "2";
  val q = @{code mk_rat};
  val es = [(a, (b, q 4 1)), (b, (c, q (~2) 1)), (a, (c, q 7 1))];
  val check = @{code external_mst_cert};
  val _ = if check [a,b,c] es [List.nth (es, 0), List.nth (es, 1)] then ()
          else error "external valid candidate failed";
  val _ = if not (check [a,b,c] es [List.nth (es, 0), List.nth (es, 2)]) then ()
          else error "external nonminimal candidate passed";
  val _ = if not (check [a,b,c,"3"] es [List.nth (es, 0), List.nth (es, 1)]) then ()
          else error "external omitted vertex passed";
  val _ = writeln "VERI7VN_DISCRETE_CERTIFICATE PASS theorems=4 oracles=0";
\<close>

end
