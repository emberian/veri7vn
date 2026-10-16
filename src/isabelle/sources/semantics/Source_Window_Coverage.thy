theory Source_Window_Coverage
  imports Source_Semantics
begin

datatype population_policy = ObservedKnownSelection | RequireClassifiedWindow
record 'a window_diagnostic =
  diagnostic_clock :: clock_basis
  diagnostic_lower :: int
  diagnostic_upper :: int
  diagnostic_population :: "'a observation list"
  diagnostic_unclassified :: "'a observation list"

datatype window_classification = Inside_Window | Outside_Window | Unclassified_Window
fun classify_window where
  "classify_window cb lo hi obs = (case event_clock obs of None \<Rightarrow> Unclassified_Window
    | Some c \<Rightarrow> if basis c \<noteq> cb then Unclassified_Window
      else if lo \<le> ticks c \<and> ticks c < hi then Inside_Window else Outside_Window)"
definition window_classified where
  "window_classified cb observations \<longleftrightarrow>
    list_all (\<lambda>obs. \<exists>c. event_clock obs = Some c \<and> basis c = cb) observations"

text \<open>Classified-window execution inspects the recorded optional clock. The
existential specification remains unchanged; execution does not enumerate the
unbounded clock-reading type.\<close>
declare [[code drop: window_classified]]
lemma window_classified_code[code]:
  "window_classified cb observations =
    list_all (\<lambda>obs. case event_clock obs of None \<Rightarrow> False
      | Some observed_clock \<Rightarrow> basis observed_clock = cb) observations"
  by (auto simp: window_classified_def list_all_iff split: option.splits)

definition unclassified_population where
  "unclassified_population cb lo hi observations =
    filter (\<lambda>obs. classify_window cb lo hi obs = Unclassified_Window) observations"
definition closed_window_population where
  "closed_window_population cb lo hi observations =
    (if window_classified cb observations then Some (window_population cb lo hi observations) else None)"
lemma classification_matches_selection:
  "classify_window cb lo hi obs = Inside_Window \<longleftrightarrow> event_in_window cb lo hi obs"
  by (auto simp: event_in_window_def split: option.splits if_splits)
lemma missing_clock_unclassified:
  "event_clock obs = None \<Longrightarrow> classify_window cb lo hi obs = Unclassified_Window"
  by simp
lemma wrong_basis_unclassified:
  "event_clock obs = Some c \<Longrightarrow> basis c \<noteq> cb \<Longrightarrow>
   classify_window cb lo hi obs = Unclassified_Window"
  by simp
lemma classified_window_partition:
  "window_classified cb observations \<Longrightarrow> obs \<in> set observations \<Longrightarrow>
   classify_window cb lo hi obs = Inside_Window \<or> classify_window cb lo hi obs = Outside_Window"
  by (auto simp: window_classified_def list_all_iff split: option.splits if_splits)
lemma closed_window_has_no_unclassified:
  "closed_window_population cb lo hi observations = Some selected \<Longrightarrow>
   unclassified_population cb lo hi observations = [] \<and>
   selected = window_population cb lo hi observations"
  by (auto simp: closed_window_population_def unclassified_population_def window_classified_def
      list_all_iff filter_empty_conv split: if_splits option.splits)
end
