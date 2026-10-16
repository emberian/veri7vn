theory Veri7vn_Row_Population
  imports "Veri7vn_Source_Plans.Veri7vn_Source_Plans"
    "Veri7vn_Source_Import.Source_Row_Observation"
begin

record source_population_report =
  report_original_population :: "qualified_batch_observation list"
  report_selected_population :: "qualified_batch_observation list"
  report_unclassified_population :: "qualified_batch_observation list"
  report_window_diagnostics :: "source_batch source_assertion window_diagnostic list"

fun select_population_report where
  "select_population_report Population observations =
    \<lparr>report_original_population = observations, report_selected_population = observations,
      report_unclassified_population = [], report_window_diagnostics = []\<rparr>" |
  "select_population_report (Window cb lo hi p) observations =
    (let previous = select_population_report p observations;
         pre = report_selected_population previous;
         unknown = unclassified_population cb lo hi pre
     in \<lparr>report_original_population = report_original_population previous,
       report_selected_population = select_observations (Window cb lo hi Population) pre,
       report_unclassified_population = report_unclassified_population previous @ unknown,
       report_window_diagnostics = report_window_diagnostics previous @
         [\<lparr>diagnostic_clock = cb, diagnostic_lower = lo, diagnostic_upper = hi,
           diagnostic_population = pre, diagnostic_unclassified = unknown\<rparr>]\<rparr>)"

lemma report_preserves_original:
  "report_original_population (select_population_report p observations) = observations"
  by (induction p) (simp_all add: Let_def)
lemma report_known_selection_refinement:
  "report_selected_population (select_population_report p observations) =
    observation_meaning p observations"
  by (induction p) (simp_all add: Let_def observation_plan_refinement)

definition population_report_meaning where
  "population_report_meaning p observations =
    (select_population_report p observations)\<lparr>report_selected_population :=
      observation_meaning p observations\<rparr>"
lemma population_report_refinement:
  "select_population_report p observations = population_report_meaning p observations"
  by (simp add: population_report_meaning_def report_known_selection_refinement[symmetric])

text \<open>The guard computes only the selected list and classification bit, not
full diagnostic histories. Every nested window checks its actual prefilter
population. No absent or incomparable event clock is classified as outside.\<close>
fun classified_selection where
  "classified_selection Population observations = (observations,True)" |
  "classified_selection (Window cb lo hi p) observations =
    (let previous = classified_selection p observations in
      (select_observations (Window cb lo hi Population) (fst previous),
       snd previous \<and> window_classified cb (fst previous)))"
lemma classification_selected_matches_report:
  "fst (classified_selection p observations) =
    report_selected_population (select_population_report p observations)"
  by (induction p) (simp_all add: Let_def)
lemma row_window_unclassified_empty:
  "(unclassified_population cb lo hi observations = []) = window_classified cb observations"
  by (auto simp: unclassified_population_def window_classified_def filter_empty_conv
      list_all_iff split: option.splits if_splits)
lemma classification_matches_report:
  "snd (classified_selection p observations) =
    (report_unclassified_population (select_population_report p observations) = [])"
  by (induction p) (simp_all add: Let_def row_window_unclassified_empty
    classification_selected_matches_report)

fun population_policy_holds where
  "population_policy_holds ObservedKnownSelection p observations = True" |
  "population_policy_holds RequireClassifiedWindow p observations =
    snd (classified_selection p observations)"
lemma classified_policy_has_no_unknown:
  "population_policy_holds RequireClassifiedWindow p observations \<Longrightarrow>
    report_unclassified_population (select_population_report p observations) = []"
  by (simp add: classification_matches_report)

definition report_row_view where
  "report_row_view schema columns report = map_option (\<lambda>view.
      view\<lparr>view_original_population := report_original_population report,
        view_unclassified_population := report_unclassified_population report,
        view_window_diagnostics := report_window_diagnostics report\<rparr>)
    (row_view schema columns (report_selected_population report))"
lemma report_row_view_preserves_context:
  "report_row_view schema columns report = Some view \<Longrightarrow>
    view_original_population view = report_original_population report \<and>
    view_unclassified_population view = report_unclassified_population report \<and>
    view_window_diagnostics view = report_window_diagnostics report \<and>
    view_population view = report_selected_population report"
  by (auto simp: report_row_view_def row_view_def split: if_splits option.splits)
end
