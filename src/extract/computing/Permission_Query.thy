theory Permission_Query
  imports System
begin

text \<open>Queries about unset ordinary mode bits. This is a statement about the
nine read/write/execute bits, not effective access through ACLs, privileges,
mount options or parent directories. Special mode bits do not grant these bits.\<close>

datatype permission_class = P_owner | P_group | P_other
datatype permission_action = P_read | P_write | P_execute

fun class_digit :: "mode \<Rightarrow> permission_class \<Rightarrow> nat" where
  "class_digit (Mode sp u g o') P_owner = u"
| "class_digit (Mode sp u g o') P_group = g"
| "class_digit (Mode sp u g o') P_other = o'"

fun action_set :: "permission_action \<Rightarrow> nat \<Rightarrow> bool" where
  "action_set P_read d = fst (bits3 d)"
| "action_set P_write d = fst (snd (bits3 d))"
| "action_set P_execute d = snd (snd (bits3 d))"

definition missing_actions :: "nat \<Rightarrow> permission_action list" where
  "missing_actions d = filter (\<lambda>a. action_set a (dir_digit d)) [P_read, P_write, P_execute]"

theorem missing_actions_exact:
  assumes "d < 8"
  shows "a \<in> set (missing_actions d) \<longleftrightarrow> \<not> action_set a d"
proof -
  have bits: "bits3 (dir_digit d) = (\<not> fst (bits3 d), \<not> fst (snd (bits3 d)), \<not> snd (snd (bits3 d)))"
    by (rule conjunct1[OF umask_dir_bits[OF assms]])
  show ?thesis by (cases a) (simp_all add: missing_actions_def bits)
qed

lemma missing_actions_distinct: "distinct (missing_actions d)"
  by (simp add: missing_actions_def)

definition permission_rows :: "mode \<Rightarrow> permission_class option \<Rightarrow> (permission_class \<times> permission_action list) list" where
  "permission_rows m who = map (\<lambda>c. (c, missing_actions (class_digit m c)))
    (case who of None \<Rightarrow> [P_owner, P_group, P_other] | Some c \<Rightarrow> [c])"

definition mode_valid :: "mode \<Rightarrow> bool" where
  "mode_valid m = (case m of Mode sp u g o' \<Rightarrow> sp < 8 \<and> u < 8 \<and> g < 8 \<and> o' < 8)"

lemma valid_class_digit: "mode_valid m \<Longrightarrow> class_digit m c < 8"
  by (cases m; cases c) (simp_all add: mode_valid_def)

theorem permission_rows_exact:
  assumes "mode_valid m"
  shows "(c, acts) \<in> set (permission_rows m who) \<longleftrightarrow>
    (who = None \<or> who = Some c) \<and> acts = missing_actions (class_digit m c)"
    and "(c, acts) \<in> set (permission_rows m who) \<Longrightarrow>
      (a \<in> set acts \<longleftrightarrow> \<not> action_set a (class_digit m c))"
proof -
  show row: "(c, acts) \<in> set (permission_rows m who) \<longleftrightarrow>
    (who = None \<or> who = Some c) \<and> acts = missing_actions (class_digit m c)"
    by (cases who; cases c) (auto simp: permission_rows_def)
  assume "(c, acts) \<in> set (permission_rows m who)"
  then have acts: "acts = missing_actions (class_digit m c)" using row by simp
  show "a \<in> set acts \<longleftrightarrow> \<not> action_set a (class_digit m c)"
    unfolding acts by (rule missing_actions_exact[OF valid_class_digit[OF assms]])
qed

fun class_text where
  "class_text P_owner = STR ''owner''" | "class_text P_group = STR ''group''" | "class_text P_other = STR ''others''"
fun action_text where
  "action_text P_read = STR ''read''" | "action_text P_write = STR ''write''" | "action_text P_execute = STR ''execute''"
fun permission_join :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "permission_join sep [] = STR ''''"
| "permission_join sep (x # xs) = x + (if xs = [] then STR '''' else sep + permission_join sep xs)"

definition permission_response where
  "permission_response m who = STR ''Unset permission bits in mode '' + dstr (mode_digits m) + STR '': '' +
    permission_join (STR ''; '') (map (\<lambda>(c, acts). class_text c + STR '': '' +
      (if acts = [] then STR ''none'' else permission_join (STR '', '') (map action_text acts))) (permission_rows m who)) +
    STR ''. This describes mode bits, not an effective-access check.''"

definition permission_reply where
  "permission_reply m who = (if mode_valid m then
    Reply True (STR ''chmod_unset'') (permission_response m who) None
    else Reply False (STR ''impossible'') (STR ''An octal mode needs digits 0-7.'') None)"

theorem permission_reply_guard:
  "answered (permission_reply m who) \<longleftrightarrow> mode_valid m"
  by (simp add: permission_reply_def)

theorem permission_reply_lists_exact_unset:
  assumes "answered (permission_reply m who)"
    "(c, acts) \<in> set (permission_rows m who)"
  shows "a \<in> set acts \<longleftrightarrow> \<not> action_set a (class_digit m c)"
    and "response (permission_reply m who) = permission_response m who"
proof -
  have valid: "mode_valid m" using assms(1) by (simp add: permission_reply_guard)
  show "a \<in> set acts \<longleftrightarrow> \<not> action_set a (class_digit m c)"
    by (rule permission_rows_exact(2)[OF valid assms(2)])
  show "response (permission_reply m who) = permission_response m who"
    using valid by (simp add: permission_reply_def)
qed

definition permission_effective_reply :: reply where
  "permission_effective_reply = Reply False (STR ''underspecified'')
    (STR ''Mode bits alone do not determine effective access. ACLs, identities and path or mount conditions may also matter.'') None"

definition permission_scope_reply :: reply where
  "permission_scope_reply = Reply False (STR ''underspecified'')
    (STR ''Ask about one mode and its unset permission bits at a time; I cannot combine those requests.'') None"

definition permission_self_test where
  "permission_self_test \<longleftrightarrow>
    permission_rows (Mode 0 7 7 5) None = [(P_owner, []), (P_group, []), (P_other, [P_write])] \<and>
    permission_rows (Mode 4 7 5 5) (Some P_group) = [(P_group, [P_write])] \<and>
    permission_rows (Mode 0 0 0 0) (Some P_owner) = [(P_owner, [P_read, P_write, P_execute])] \<and>
    \<not> answered (permission_reply (Mode 0 8 8 9) None)"

end
