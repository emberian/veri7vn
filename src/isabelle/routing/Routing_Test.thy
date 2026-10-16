theory Routing_Test
  imports W540_Vectors
begin

text \<open>Session check: every theorem the lane reports is present, depends on no oracle (no
  \<open>sorry\<close>, no code-generator evaluation), and then the marker is printed.\<close>

ML \<open>
  val reported = [
    ("narrow_never_adds", @{thm narrow_never_adds}),
    ("narrow_preserves_answer_text", @{thm narrow_preserves_answer_text}),
    ("narrow_withheld_path", @{thm narrow_withheld_path}),
    ("non_adding_never_adds", @{thm non_adding_never_adds}),
    ("answers_are_attributed", @{thm answers_are_attributed}),
    ("preroute_shadowing", @{thm preroute_shadowing}),
    ("preroute_shadowing_below", @{thm preroute_shadowing_below}),
    ("preroute_dead_copy", @{thm preroute_dead_copy}),
    ("skip_hides", @{thm skip_hides}),
    ("replace_cuts_below", @{thm replace_cuts_below}),
    ("replace_cuts_below_reach", @{thm replace_cuts_below_reach}),
    ("post_can_add", @{thm post_can_add}),
    ("rewrite_can_add", @{thm rewrite_can_add}),
    ("w540_python_order", @{thm w540_python_order}),
    ("w540_never_adds", @{thm w540_never_adds}),
    ("w540_answer_unchanged", @{thm w540_answer_unchanged}),
    ("w540_orbit", @{thm w540_orbit}),
    ("w540_founder", @{thm w540_founder}),
    ("w540_cube", @{thm w540_cube}),
    ("w540_cube_five", @{thm w540_cube_five}),
    ("w540_singer", @{thm w540_singer}),
    ("w540_name", @{thm w540_name})];
  val bad = filter (fn (_, th) => not (null (Thm_Deps.all_oracles [th]))) reported;
  val _ = if null bad then () else error ("oracle-dependent: " ^ commas (map fst bad));
  val _ = List.app (fn (n, th) => writeln ("VERI7VN_ROUTING_THM " ^ n ^ ": " ^
            Syntax.string_of_term @{context} (Thm.prop_of th))) reported;
  val _ = writeln ("VERI7VN_ROUTING PASS")
\<close>

end
