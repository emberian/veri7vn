theory GeoStats_Paired
  imports GeoStats_Stats
begin

type_synonym observation = "rat \<times> rat"
type_synonym moments = "rat \<times> rat \<times> rat \<times> rat \<times> rat"

fun paired_moments :: "observation list \<Rightarrow> moments" where
  "paired_moments [] = (0,0,0,0,0)"
| "paired_moments ((x,y)#ps) =
    (let (n,sx,sy,sxx,sxy) = paired_moments ps
     in (n+1,sx+x,sy+y,sxx+x*x,sxy+x*y))"

lemma paired_moments_spec:
  "paired_moments ps = (of_nat(length ps), sum_list(map fst ps),
    sum_list(map snd ps), sum_list(map (\<lambda>(x,y). x*x) ps),
    sum_list(map (\<lambda>(x,y). x*y) ps))"
  by (induction ps) (auto simp: algebra_simps split: prod.splits)

definition line_fit :: "observation list \<Rightarrow> (rat \<times> rat) option" where
  "line_fit ps = (let (n,sx,sy,sxx,sxy) = paired_moments ps;
       d = n*sxx-sx*sx; b = (n*sxy-sx*sy)/d
     in if n>0 \<and> d>0 then Some ((sy-b*sx)/n,b) else None)"

definition residual_sum :: "observation list \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "residual_sum ps a b = sum_list(map (\<lambda>(x,y). y-a-b*x) ps)"
definition residual_x_sum :: "observation list \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "residual_x_sum ps a b = sum_list(map (\<lambda>(x,y). x*(y-a-b*x)) ps)"
definition line_sse :: "observation list \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "line_sse ps a b = sum_list(map (\<lambda>(x,y). (y-a-b*x)^2) ps)"
definition line_distance :: "observation list \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "line_distance ps a b = sum_list(map (\<lambda>(x,y). (a+b*x)^2) ps)"

lemma residual_sum_moments:
  "residual_sum ps a b = sum_list(map snd ps) - a * of_nat(length ps) - b*sum_list(map fst ps)"
  by (induction ps) (auto simp: residual_sum_def algebra_simps split: prod.splits)
lemma residual_x_sum_moments:
  "residual_x_sum ps a b = sum_list(map (\<lambda>(x,y). x*y) ps)
     - a*sum_list(map fst ps) - b*sum_list(map (\<lambda>(x,y). x*x) ps)"
  by (induction ps) (auto simp: residual_x_sum_def algebra_simps split: prod.splits)

lemma line_sse_expansion:
  "line_sse ps c d = line_sse ps a b + line_distance ps (c-a) (d-b)
     - 2*(c-a)*residual_sum ps a b - 2*(d-b)*residual_x_sum ps a b"
  by (induction ps)
     (auto simp: line_sse_def line_distance_def residual_sum_def residual_x_sum_def
       power2_eq_square algebra_simps split: prod.splits)

lemma line_distance_nonnegative: "0 \<le> line_distance ps a b"
  unfolding line_distance_def by (intro sum_list_nonneg) auto


definition centered_x_squares :: "observation list \<Rightarrow> rat \<Rightarrow> rat" where
  "centered_x_squares ps u = sum_list(map (\<lambda>(x,y). (x-u)^2) ps)"
lemma centered_x_nonnegative: "0 \<le> centered_x_squares ps u"
  unfolding centered_x_squares_def by (intro sum_list_nonneg) auto
lemma centered_x_expansion:
  "centered_x_squares ps u = sum_list(map (\<lambda>(x,y). x*x) ps)
     - 2*u*sum_list(map fst ps) + of_nat(length ps)*u*u"
  by (induction ps) (auto simp: centered_x_squares_def power2_eq_square algebra_simps split: prod.splits)
lemma centered_x_moments:
  assumes mm: "paired_moments ps=(n,sx,sy,sxx,sxy)" and nz: "n\<noteq>0"
  shows "centered_x_squares ps (sx/n) = (n*sxx-sx*sx)/n"
proof -
  have specs: "n = of_nat(length ps)" "sx=sum_list(map fst ps)"
    "sxx=sum_list(map (\<lambda>(x,y). x*x) ps)"
    using mm paired_moments_spec[of ps] by auto
  have "centered_x_squares ps (sx/n) = sxx - 2*(sx/n)*sx + n*(sx/n)*(sx/n)"
    using centered_x_expansion[of ps "sx/n"] specs by simp
  also have "... = (n*sxx-sx*sx)/n"
    using nz by (simp add: field_simps algebra_simps)
  finally show ?thesis .
qed

lemma fit_normal_algebra:
  fixes a b n sx sy sxx sxy :: rat
  assumes n: "n \<noteq> 0" and d: "n*sxx-sx*sx \<noteq> 0"
      and slope: "b = (n*sxy-sx*sy)/(n*sxx-sx*sx)"
      and intercept: "a = (sy-b*sx)/n"
  shows "sy-a*n-b*sx = 0" "sxy-a*sx-b*sxx = 0"
  using n d by (simp_all add: intercept slope field_simps algebra_simps)

theorem line_fit_normal_equations:
  assumes fit: "line_fit ps = Some (a,b)"
  shows "residual_sum ps a b = 0 \<and> residual_x_sum ps a b = 0"
proof -
  obtain n sx sy sxx sxy where mm: "paired_moments ps=(n,sx,sy,sxx,sxy)"
    by (cases "paired_moments ps") auto
  have n: "0<n" and d: "0<n*sxx-sx*sx"
    and b: "b=(n*sxy-sx*sy)/(n*sxx-sx*sx)"
    and a: "a=(sy-b*sx)/n"
    using fit by (auto simp: line_fit_def mm Let_def split: if_splits)
  have eq: "sy-a*n-b*sx=0" "sxy-a*sx-b*sxx=0"
    using fit_normal_algebra[where n=n and sx=sx and sy=sy and sxx=sxx and sxy=sxy and a=a and b=b] n d a b by auto
  have specs: "n = of_nat(length ps)" "sx=sum_list(map fst ps)"
    "sy=sum_list(map snd ps)" "sxx=sum_list(map (\<lambda>(x,y). x*x) ps)"
    "sxy=sum_list(map (\<lambda>(x,y). x*y) ps)"
    using mm paired_moments_spec[of ps] by auto
  show ?thesis using eq by (simp add: specs residual_sum_moments residual_x_sum_moments)
qed

theorem line_fit_least_squares:
  assumes "line_fit ps=Some(a,b)"
  shows "line_sse ps c d = line_sse ps a b + line_distance ps (c-a) (d-b)"
        "line_sse ps a b \<le> line_sse ps c d"
proof -
  have normal: "residual_sum ps a b=0" "residual_x_sum ps a b=0"
    using line_fit_normal_equations[OF assms] by auto
  show eq: "line_sse ps c d = line_sse ps a b + line_distance ps (c-a) (d-b)"
    using line_sse_expansion[of ps c d a b] normal by simp
  show "line_sse ps a b \<le> line_sse ps c d"
    using eq line_distance_nonnegative[of ps "c-a" "d-b"] by linarith
qed


definition centered_cross :: "observation list \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "centered_cross ps u v = sum_list(map (\<lambda>(x,y). (x-u)*(y-v)) ps)"

lemma centered_cross_expansion:
  "centered_cross ps u v = sum_list(map (\<lambda>(x,y). x*y) ps)
    - u*sum_list(map snd ps) - v*sum_list(map fst ps) + of_nat(length ps)*u*v"
  by (induction ps) (auto simp: centered_cross_def algebra_simps split: prod.splits)

definition paired_covariance :: "bool \<Rightarrow> observation list \<Rightarrow> rat option" where
  "paired_covariance pop ps = (let (n,sx,sy,sxx,sxy)=paired_moments ps
    in if n>(if pop then 0 else 1)
       then Some ((n*sxy-sx*sy)/(n*(n-(if pop then 0 else 1)))) else None)"

lemma centered_cross_moments:
  assumes mm: "paired_moments ps=(n,sx,sy,sxx,sxy)" and nz: "n \<noteq> 0"
  shows "centered_cross ps (sx/n) (sy/n) = (n*sxy-sx*sy)/n"
proof -
  have specs: "n = of_nat(length ps)" "sx=sum_list(map fst ps)"
    "sy=sum_list(map snd ps)" "sxy=sum_list(map (\<lambda>(x,y). x*y) ps)"
    using mm paired_moments_spec[of ps] by auto
  have "centered_cross ps (sx/n) (sy/n) = sxy - (sx/n)*sy - (sy/n)*sx + n*(sx/n)*(sy/n)"
    using centered_cross_expansion[of ps "sx/n" "sy/n"] specs by simp
  also have "... = (n*sxy-sx*sy)/n"
    using nz by (simp add: field_simps algebra_simps)
  finally show ?thesis .
qed

theorem paired_covariance_centered:
  assumes cv: "paired_covariance pop ps=Some q"
  defines n_def: "n \<equiv> of_nat(length ps) :: rat"
  shows "q = centered_cross ps (sum_list(map fst ps)/n) (sum_list(map snd ps)/n)
       / (n-(if pop then 0 else 1))"
proof -
  obtain nn sx sy sxx sxy where mm: "paired_moments ps=(nn,sx,sy,sxx,sxy)"
    by (cases "paired_moments ps") auto
  have positive: "nn>(if pop then 0 else 1)"
    and q: "q=(nn*sxy-sx*sy)/(nn*(nn-(if pop then 0 else 1)))"
    using cv by (auto simp: paired_covariance_def mm Let_def split: if_splits)
  have nz: "nn \<noteq> 0" using positive by (cases pop) auto
  have specs: "nn=n" "sx=sum_list(map fst ps)" "sy=sum_list(map snd ps)"
    using mm paired_moments_spec[of ps] by (auto simp: n_def)
  show ?thesis using centered_cross_moments[OF mm nz] q
    by (simp add: specs)
qed

datatype paired_request = P_covariance bool | P_slope | P_intercept | P_predict rat | P_line

definition paired_invalid :: reply where
  "paired_invalid = Reply False (STR ''impossible'')
    (STR ''Paired statistics need equally long observation lists. Sample covariance needs at least two pairs; a fitted line needs nonconstant x values.'') None"
definition paired_empty :: reply where
  "paired_empty = Reply False (STR ''underspecified'')
    (STR ''I need nonempty paired x and y observation lists.'') None"

definition paired_model_refusal :: reply where
  "paired_model_refusal = Reply False (STR ''underspecified'')
    (STR ''Please specify population covariance or sample covariance.'') None"
definition paired_prediction_refusal :: reply where
  "paired_prediction_refusal = Reply False (STR ''underspecified'')
    (STR ''Please state a complete numeric x value for the fitted prediction.'') None"

definition paired_scalar_reply :: "String.literal \<Rightarrow> String.literal \<Rightarrow> rat \<Rightarrow> reply" where
  "paired_scalar_reply kind label q = Reply True kind
    (label + STR '' is '' + f4 q + STR ''.'') (Some(f4 q))"

fun fitted_reply :: "paired_request \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> reply" where
  "fitted_reply P_slope a b = paired_scalar_reply (STR ''regression_slope'') (STR ''The least-squares slope'') b"
| "fitted_reply P_intercept a b = paired_scalar_reply (STR ''regression_intercept'') (STR ''The least-squares intercept'') a"
| "fitted_reply (P_predict t) a b = paired_scalar_reply (STR ''regression_prediction'') (STR ''The fitted prediction'') (a+b*t)"
| "fitted_reply P_line a b = Reply True (STR ''regression_line'')
     (STR ''The least-squares line, with coefficients rounded to four decimal places, is y = '' + f4 a + STR '' + ('' + f4 b + STR '') x.'') None"
| "fitted_reply (P_covariance _) a b = paired_invalid"

definition paired_reply :: "paired_request \<Rightarrow> rat list \<Rightarrow> rat list \<Rightarrow> reply" where
  "paired_reply req xs ys = (if length xs \<noteq> length ys then paired_invalid
     else if xs=[] then paired_empty
     else case req of
       P_covariance pop \<Rightarrow> (case paired_covariance pop (zip xs ys) of
         None \<Rightarrow> paired_invalid
       | Some q \<Rightarrow> paired_scalar_reply (STR ''covariance'')
          (if pop then STR ''The population covariance'' else STR ''The sample covariance'') q)
     | _ \<Rightarrow> (case line_fit (zip xs ys) of None \<Rightarrow> paired_invalid
             | Some(a,b) \<Rightarrow> fitted_reply req a b))"

lemma paired_mismatch:
  assumes "length xs \<noteq> length ys"
  shows "paired_reply req xs ys=paired_invalid"
  using assms by (simp add: paired_reply_def)



lemma paired_line_reply_normal:
  assumes "answered(paired_reply P_line xs ys)"
  shows "length xs=length ys \<and> xs\<noteq>[] \<and>
    (\<exists>a b. line_fit(zip xs ys)=Some(a,b) \<and>
       paired_reply P_line xs ys=fitted_reply P_line a b \<and>
       residual_sum (zip xs ys) a b=0 \<and> residual_x_sum (zip xs ys) a b=0)"
  using assms line_fit_normal_equations
  by (auto simp: paired_reply_def paired_invalid_def paired_empty_def
      split: if_splits option.splits prod.splits)

lemma paired_line_reply_minimal:
  assumes "line_fit(zip xs ys)=Some(a,b)"
      and "length xs=length ys" "xs\<noteq>[]"
  shows "paired_reply P_line xs ys=fitted_reply P_line a b"
        "line_sse (zip xs ys) a b \<le> line_sse (zip xs ys) c d"
  using assms line_fit_least_squares(2)[OF assms(1)]
  by (simp_all add: paired_reply_def)

end
