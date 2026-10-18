theory Math_Affine
  imports Math
begin

text \<open>The parser supplies an expression tree. Normalization and checking
operate on that original typed tree; these statements do not verify its
correspondence to an English request or the bytes of an equation.\<close>

fun affine_norm :: "String.literal \<Rightarrow> expr \<Rightarrow> (rat \<times> rat) option" where
  "affine_norm vname (C c) = Some (0,c)"
| "affine_norm vname (V v) = (if v = vname then Some (1,0) else None)"
| "affine_norm vname (Add e f) = (case (affine_norm vname e, affine_norm vname f) of
    (Some (a,b),Some (c,d)) \<Rightarrow> Some (a+c,b+d) | _ \<Rightarrow> None)"
| "affine_norm vname (Sub e f) = (case (affine_norm vname e, affine_norm vname f) of
    (Some (a,b),Some (c,d)) \<Rightarrow> Some (a-c,b-d) | _ \<Rightarrow> None)"
| "affine_norm vname (Neg e) = (case affine_norm vname e of
    Some (a,b) \<Rightarrow> Some (-a,-b) | _ \<Rightarrow> None)"
| "affine_norm vname (Mul e f) = (case (affine_norm vname e, affine_norm vname f) of
    (Some (a,b),Some (c,d)) \<Rightarrow>
      (if a=0 then Some (b*c,b*d)
       else if c=0 then Some (a*d,b*d) else None) | _ \<Rightarrow> None)"
| "affine_norm vname (Div e f) = (case (affine_norm vname e, affine_norm vname f) of
    (Some (a,b),Some (c,d)) \<Rightarrow>
      (if c=0 \<and> d\<noteq>0 then Some (a/d,b/d) else None) | _ \<Rightarrow> None)"
| "affine_norm vname (Pow e n) = None"

theorem affine_norm_sound:
  assumes "affine_norm vname e = Some (a,b)"
  shows "ev i e = Some (a * i vname + b)"
  using assms
  by (induction e arbitrary: a b)
     (auto simp: algebra_simps divide_simps split: option.splits prod.splits if_splits)

theorem affine_norm_only_chosen:
  assumes "affine_norm vname e = Some (a,b)"
  shows "vars e \<subseteq> {vname}"
  using assms
  by (induction e arbitrary: a b)
     (auto split: option.splits prod.splits if_splits)

datatype affine_solution = AffineUnique rat | AffineAll | AffineNone | AffineUnsupported

fun affine_candidate :: "String.literal \<Rightarrow> expr \<Rightarrow> expr \<Rightarrow> affine_solution" where
  "affine_candidate vname l r = (case (affine_norm vname l, affine_norm vname r) of
    (Some (a,b),Some (c,d)) \<Rightarrow>
       (if a=c then (if b=d then AffineAll else AffineNone)
        else AffineUnique ((d-b)/(a-c)))
    | _ \<Rightarrow> AffineUnsupported)"

text \<open>The actual checker re-normalizes the supplied trees. For a unique
root it also evaluates both original expressions at that exact rational.
All/no-solution certificates compare their normalized coefficients.\<close>
fun check_affine :: "String.literal \<Rightarrow> expr \<Rightarrow> expr \<Rightarrow> affine_solution \<Rightarrow> bool" where
  "check_affine vname l r answer = (case (affine_norm vname l,affine_norm vname r) of
    (Some (a,b),Some (c,d)) \<Rightarrow>
      (case answer of
        AffineUnique x \<Rightarrow> a\<noteq>c \<and>
          (case ev (\<lambda>v. if v=vname then x else 0) l of None \<Rightarrow> False
           | Some v \<Rightarrow> ev (\<lambda>v. if v=vname then x else 0) r = Some v)
      | AffineAll \<Rightarrow> a=c \<and> b=d
      | AffineNone \<Rightarrow> a=c \<and> b\<noteq>d
      | AffineUnsupported \<Rightarrow> False)
    | _ \<Rightarrow> False)"

definition affine_satisfies :: "String.literal \<Rightarrow> expr \<Rightarrow> expr \<Rightarrow> rat \<Rightarrow> bool" where
  "affine_satisfies vname l r x \<longleftrightarrow>
    (\<exists>v. ev (\<lambda>v. if v=vname then x else 0) l = Some v \<and> ev (\<lambda>v. if v=vname then x else 0) r = Some v)"

lemma affine_equation_normalized:
  assumes "affine_norm vname l = Some (a,b)" "affine_norm vname r = Some (c,d)"
  shows "affine_satisfies vname l r x \<longleftrightarrow> a*x+b=c*x+d"
  using affine_norm_sound[OF assms(1), of "\<lambda>v. if v=vname then x else 0"]
        affine_norm_sound[OF assms(2), of "\<lambda>v. if v=vname then x else 0"]
  by (auto simp: affine_satisfies_def)

theorem affine_unique_checked:
  assumes "check_affine vname l r (AffineUnique x)"
  shows "affine_satisfies vname l r t \<longleftrightarrow> t=x"
proof -
  from assms obtain a b c d where
    L: "affine_norm vname l = Some (a,b)" and R: "affine_norm vname r = Some (c,d)"
    and slope: "a\<noteq>c" and root: "affine_satisfies vname l r x"
    by (auto simp: affine_satisfies_def split: option.splits prod.splits)
  have xeq: "a*x+b=c*x+d" using root affine_equation_normalized[OF L R] by simp
  have xval: "x=(d-b)/(a-c)" by (rule solve_linear_complete[OF slope xeq])
  show ?thesis
    using affine_equation_normalized[OF L R, of t]
      solve_linear_complete[OF slope, of t] xval root
    by auto
qed

theorem affine_all_checked:
  assumes "check_affine vname l r AffineAll"
  shows "affine_satisfies vname l r t"
  using assms affine_equation_normalized[of vname l _ _ r _ _ t]
  by (auto split: option.splits prod.splits)

theorem affine_none_checked:
  assumes "check_affine vname l r AffineNone"
  shows "\<not> affine_satisfies vname l r t"
  using assms affine_equation_normalized[of vname l _ _ r _ _ t]
  by (auto split: option.splits prod.splits)

theorem affine_candidate_checked:
  assumes "affine_norm vname l = Some (a,b)" "affine_norm vname r = Some (c,d)"
  shows "check_affine vname l r (affine_candidate vname l r)"
  using affine_norm_sound[OF assms(1), of "\<lambda>v. if v=vname then (d-b)/(a-c) else 0"]
        affine_norm_sound[OF assms(2), of "\<lambda>v. if v=vname then (d-b)/(a-c) else 0"]
  by (auto simp: assms field_simps)

definition affine_exact :: "rat \<Rightarrow> String.literal" where
  "affine_exact q = (let (n,d)=quotient_of q in
    show_int n + (if d=1 then STR '''' else STR ''/'' + show_int d))"

definition affine_rat_components :: "rat \<Rightarrow> integer \<times> integer" where
  "affine_rat_components q = (let (n,d)=quotient_of q in (integer_of_int n,integer_of_int d))"

fun affine_response :: "String.literal \<Rightarrow> affine_solution \<Rightarrow> String.literal" where
  "affine_response vname (AffineUnique x) = STR ''[ev:derived] '' + vname + STR '' = '' + affine_exact x + STR ''.''"
| "affine_response vname AffineAll = STR ''[ev:derived] Every rational value of '' + vname + STR '' satisfies this equation.''"
| "affine_response vname AffineNone = STR ''[ev:derived] No rational value of '' + vname + STR '' satisfies this equation.''"
| "affine_response vname AffineUnsupported = STR ''This equation is outside the supported affine grammar or contains an undefined division.''"

definition affine_self_test :: bool where
  "affine_self_test \<longleftrightarrow>
    affine_candidate (STR ''x'') (V (STR ''x'')) (C 2) = AffineUnique 2 \<and>
    affine_candidate (STR ''x'') (Mul (C 2) (Sub (V (STR ''x'')) (C 3))) (C 4) = AffineUnique 5 \<and>
    check_affine (STR ''x'') (Mul (C 2) (Sub (V (STR ''x'')) (C 3))) (C 4) (AffineUnique 5) \<and>
    \<not> check_affine (STR ''x'') (V (STR ''x'')) (C 2) (AffineUnique 3) \<and>
    affine_candidate (STR ''x'') (Sub (V (STR ''x'')) (V (STR ''x''))) (C 0) = AffineAll \<and>
    affine_candidate (STR ''x'') (V (STR ''x'')) (Add (V (STR ''x'')) (C 1)) = AffineNone \<and>
    affine_norm (STR ''x'') (Mul (V (STR ''x'')) (V (STR ''x''))) = None \<and>
    affine_norm (STR ''x'') (Div (V (STR ''x'')) (C 0)) = None \<and>
    affine_candidate (STR ''t'') (Add (Mul (C 3) (V (STR ''t''))) (C 2)) (C 11) = AffineUnique 3 \<and>
    check_affine (STR ''t'') (V (STR ''t'')) (C 3) (AffineUnique 3) \<and>
    \<not> check_affine (STR ''x'') (V (STR ''t'')) (C 3) (AffineUnique 3) \<and>
    affine_norm (STR ''t'') (Add (V (STR ''t'')) (Sub (V (STR ''y'')) (V (STR ''y'')))) = None \<and>
    affine_exact (1/3) = STR ''1/3''"

end
