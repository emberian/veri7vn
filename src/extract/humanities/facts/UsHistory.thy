theory UsHistory
  imports Facts_Common
begin

text \<open>
  Oracle7 ushistory (upstream/root/specialists/ushistory/organ_ushistory_v1.py): the nth
  President, the number(s) of a named President (Cleveland and Trump served twice) and
  the year of landmark events. The untrusted recognizer matches each President's name and
  each event's pattern and passes one bit per row; the kernel takes the first row whose
  bit is set and applies the organ's rule that an event that other countries share
  (civil war, constitution, ...) needs an explicit US marker and no other country.
\<close>

definition presidents :: "String.literal list" where
  "presidents = [
    STR ''George Washington'',
    STR ''John Adams'',
    STR ''Thomas Jefferson'',
    STR ''James Madison'',
    STR ''James Monroe'',
    STR ''John Quincy Adams'',
    STR ''Andrew Jackson'',
    STR ''Martin Van Buren'',
    STR ''William Henry Harrison'',
    STR ''John Tyler'',
    STR ''James K. Polk'',
    STR ''Zachary Taylor'',
    STR ''Millard Fillmore'',
    STR ''Franklin Pierce'',
    STR ''James Buchanan'',
    STR ''Abraham Lincoln'',
    STR ''Andrew Johnson'',
    STR ''Ulysses S. Grant'',
    STR ''Rutherford B. Hayes'',
    STR ''James A. Garfield'',
    STR ''Chester A. Arthur'',
    STR ''Grover Cleveland'',
    STR ''Benjamin Harrison'',
    STR ''Grover Cleveland'',
    STR ''William McKinley'',
    STR ''Theodore Roosevelt'',
    STR ''William Howard Taft'',
    STR ''Woodrow Wilson'',
    STR ''Warren G. Harding'',
    STR ''Calvin Coolidge'',
    STR ''Herbert Hoover'',
    STR ''Franklin D. Roosevelt'',
    STR ''Harry S. Truman'',
    STR ''Dwight D. Eisenhower'',
    STR ''John F. Kennedy'',
    STR ''Lyndon B. Johnson'',
    STR ''Richard Nixon'',
    STR ''Gerald Ford'',
    STR ''Jimmy Carter'',
    STR ''Ronald Reagan'',
    STR ''George H. W. Bush'',
    STR ''Bill Clinton'',
    STR ''George W. Bush'',
    STR ''Barack Obama'',
    STR ''Donald Trump'',
    STR ''Joe Biden'',
    STR ''Donald Trump'']"

text \<open>EVENTS: year, the sentence the organ states, and whether the event's pattern
mentions a term many countries share (the organ's @{text ambiguous} test on the pattern).\<close>
definition events :: "(String.literal \<times> String.literal \<times> bool) list" where
  "events = [
    (STR ''1776'', STR ''The Declaration of Independence was adopted in 1776 (July 4).'', True),
    (STR ''1787'', STR ''The Constitution was signed in 1787 (September 17).'', True),
    (STR ''1788'', STR ''The Constitution was ratified in 1788 (taking effect in 1789).'', True),
    (STR ''1791'', STR ''The Bill of Rights was ratified in 1791.'', True),
    (STR ''1803'', STR ''The Louisiana Purchase was in 1803.'', False),
    (STR ''1861'', STR ''The Civil War began in 1861.'', True),
    (STR ''1865'', STR ''The Civil War ended in 1865.'', True),
    (STR ''1863'', STR ''The Emancipation Proclamation was issued in 1863 (January 1).'', False),
    (STR ''1865'', STR ''Abraham Lincoln was assassinated in 1865 (April 14-15).'', False),
    (STR ''1869'', STR ''The transcontinental railroad was completed in 1869.'', False),
    (STR ''1920'', STR ''Women'' + apos + STR ''s right to vote (the 19th Amendment) was ratified in 1920.'', False),
    (STR ''1929'', STR ''The stock market crash was in 1929 (October).'', False),
    (STR ''1941'', STR ''The attack on Pearl Harbor was in 1941 (December 7).'', False),
    (STR ''1954'', STR ''Brown v. Board of Education was decided in 1954.'', False),
    (STR ''1964'', STR ''The Civil Rights Act was signed in 1964.'', False),
    (STR ''1965'', STR ''The Voting Rights Act was signed in 1965.'', False),
    (STR ''1969'', STR ''The Apollo 11 moon landing was in 1969 (July 20).'', False),
    (STR ''1974'', STR ''Richard Nixon resigned in 1974 (August 9).'', False),
    (STR ''2001'', STR ''The September 11 attacks were in 2001.'', False)]"

definition numbers_of :: "String.literal \<Rightarrow> nat list" where
  "numbers_of name = map Suc (filter (\<lambda>i. presidents ! i = name) [0..<length presidents])"

datatype hreq = HNth nat | HNum "bool list" | HEvent "bool list" bool bool

datatype hout =
    HSilent
  | HNthV nat String.literal
  | HNumV String.literal "nat list"
  | HEvV String.literal String.literal

definition hkernel :: "hreq \<Rightarrow> hout" where
  "hkernel r = (case r of
      HNth n \<Rightarrow> (if 1 \<le> n \<and> n \<le> length presidents then HNthV n (presidents ! (n - 1)) else HSilent)
    | HNum bs \<Rightarrow> (case pick bs presidents of Some name \<Rightarrow> HNumV name (numbers_of name) | None \<Rightarrow> HSilent)
    | HEvent bs us other \<Rightarrow>
        (case pick bs events of
           Some (yr, sent, amb) \<Rightarrow> (if amb \<and> (\<not> us \<or> other) then HSilent else HEvV yr sent)
         | None \<Rightarrow> HSilent))"

theorem nth_value:
  "hkernel (HNth n) = HNthV m name \<Longrightarrow> m = n \<and> 1 \<le> n \<and> n \<le> length presidents \<and> presidents ! (n - 1) = name"
  by (auto simp: hkernel_def split: if_splits)

text \<open>The numbers of a President are exactly the positions at which he appears, so the
"nth President" and "which number" questions agree.\<close>
theorem numbers_of_iff:
  "k \<in> set (numbers_of name) \<longleftrightarrow> 1 \<le> k \<and> k \<le> length presidents \<and> presidents ! (k - 1) = name"
proof
  assume "k \<in> set (numbers_of name)"
  then obtain i where "i < length presidents" "presidents ! i = name" "k = Suc i"
    by (auto simp: numbers_of_def)
  then show "1 \<le> k \<and> k \<le> length presidents \<and> presidents ! (k - 1) = name" by simp
next
  assume h: "1 \<le> k \<and> k \<le> length presidents \<and> presidents ! (k - 1) = name"
  then obtain i where i: "k = Suc i" by (cases k) auto
  then have "i < length presidents" "presidents ! i = name" using h by simp_all
  then show "k \<in> set (numbers_of name)" using i by (auto simp: numbers_of_def)
qed

theorem num_value:
  "hkernel (HNum bs) = HNumV name nums \<Longrightarrow>
     (\<forall>k. k \<in> set nums \<longleftrightarrow> 1 \<le> k \<and> k \<le> length presidents \<and> presidents ! (k - 1) = name)
     \<and> (\<exists>i. i < length bs \<and> i < length presidents \<and> bs ! i \<and> presidents ! i = name \<and> (\<forall>j<i. \<not> bs ! j))"
  by (auto simp: hkernel_def numbers_of_iff dest: pick_some split: option.splits)

theorem event_value:
  "hkernel (HEvent bs us other) = HEvV yr sent \<Longrightarrow>
     (\<exists>i. i < length bs \<and> i < length events \<and> bs ! i \<and> (\<forall>j<i. \<not> bs ! j)
          \<and> fst (events ! i) = yr \<and> fst (snd (events ! i)) = sent
          \<and> (snd (snd (events ! i)) \<longrightarrow> us \<and> \<not> other))"
proof -
  assume h: "hkernel (HEvent bs us other) = HEvV yr sent"
  show ?thesis
  proof (cases "pick bs events")
    case None
    then show ?thesis using h by (simp add: hkernel_def)
  next
    case (Some row)
    obtain y s a where row: "row = (y, s, a)" by (metis prod.exhaust)
    have p: "pick bs events = Some (y, s, a)" using Some row by simp
    have ok: "\<not> (a \<and> (\<not> us \<or> other))" and e1: "y = yr" and e2: "s = sent"
      using h p by (auto simp: hkernel_def split: if_splits)
    from pick_some[OF p] obtain i where
      i: "i < length bs \<and> i < length events \<and> bs ! i \<and> events ! i = (y, s, a) \<and> (\<forall>j<i. \<not> bs ! j)"
      by blast
    show ?thesis by (rule exI[of _ i]) (use ok e1 e2 i in auto)
  qed
qed

theorem event_silent_ambiguous:
  "pick bs events = Some (y, s, True) \<Longrightarrow> (\<not> us \<or> other) \<Longrightarrow> hkernel (HEvent bs us other) = HSilent"
  by (simp add: hkernel_def)

definition htext :: "hout \<Rightarrow> String.literal" where
  "htext res = (case res of
      HSilent \<Rightarrow> STR ''''
    | HNthV n name \<Rightarrow> cat [STR ''The '', ordinal n, STR '' President was '', name, STR ''.'']
    | HNumV name nums \<Rightarrow> cat [name, STR '' was the '', join_with (STR '' and '') (map ordinal nums), STR '' President.'']
    | HEvV yr sent \<Rightarrow> sent)"

definition hkind :: "hout \<Rightarrow> String.literal" where
  "hkind res = (case res of HSilent \<Rightarrow> STR ''silent'' | HNthV n name \<Rightarrow> STR ''nth_president''
               | HNumV name nums \<Rightarrow> STR ''president_number'' | HEvV yr sent \<Rightarrow> STR ''event_year'')"

definition hstated :: "hout \<Rightarrow> String.literal" where
  "hstated res = (case res of HSilent \<Rightarrow> STR '''' | HNthV n name \<Rightarrow> name
                 | HNumV name nums \<Rightarrow> join_with (STR '' and '') (map ordinal nums) | HEvV yr sent \<Rightarrow> yr)"

definition hreply :: "hreq \<Rightarrow> reply" where
  "hreply r = (case hkernel r of HSilent \<Rightarrow> Reply False (STR ''silent'') (STR '''') None
      | v \<Rightarrow> Reply True (hkind v) (htext v) (Some (hstated v)))"

theorem hreply_answered_iff: "answered (hreply r) \<longleftrightarrow> hkernel r \<noteq> HSilent"
  by (auto simp: hreply_def split: hout.splits)

definition us_self_test :: bool where
  "us_self_test \<longleftrightarrow>
     length presidents = 47 \<and>
     numbers_of (STR ''Grover Cleveland'') = [22, 24] \<and>
     numbers_of (STR ''Donald Trump'') = [45, 47] \<and>
     hkernel (HNth 46) = HNthV 46 (STR ''Joe Biden'') \<and>
     hkernel (HNth 48) = HSilent \<and>
     response (hreply (HNth 3)) = STR ''The 3rd President was Thomas Jefferson.'' \<and>
     response (hreply (HNth 42)) = STR ''The 42nd President was Bill Clinton.'' \<and>
     ord_suffix 11 = STR ''th'' \<and> ord_suffix 22 = STR ''nd'' \<and>
     response (hreply (HNum (map (\<lambda>p. p = STR ''Grover Cleveland'') presidents))) =
       STR ''Grover Cleveland was the 22nd and 24th President.''"

end
