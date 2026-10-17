theory Grammar
  imports Facts_Common
begin

text \<open>
  Oracle7 grammar (upstream/root/specialists/grammar/organ_grammar_v1.py): English
  irregular verb forms, noun plurals and comparatives as closed tables. The untrusted
  recognizer reads which of past tense / past participle / plural / comparative /
  superlative the question names and the candidate words in the organ's order; the
  kernel applies the organ's ordered rules and takes the first candidate the table knows.
  Alternative forms (dreamed / dreamt) are lists, printed joined by "or".
\<close>

definition verbs :: "(String.literal \<times> (String.literal list \<times> String.literal list)) list" where
  "verbs = [
    (STR ''arise'', ([STR ''arose''], [STR ''arisen''])),
    (STR ''awake'', ([STR ''awoke''], [STR ''awoken''])),
    (STR ''be'', ([STR ''was'', STR ''were''], [STR ''been''])),
    (STR ''bear'', ([STR ''bore''], [STR ''borne''])),
    (STR ''beat'', ([STR ''beat''], [STR ''beaten''])),
    (STR ''become'', ([STR ''became''], [STR ''become''])),
    (STR ''begin'', ([STR ''began''], [STR ''begun''])),
    (STR ''bend'', ([STR ''bent''], [STR ''bent''])),
    (STR ''bet'', ([STR ''bet''], [STR ''bet''])),
    (STR ''bind'', ([STR ''bound''], [STR ''bound''])),
    (STR ''bite'', ([STR ''bit''], [STR ''bitten''])),
    (STR ''bleed'', ([STR ''bled''], [STR ''bled''])),
    (STR ''blow'', ([STR ''blew''], [STR ''blown''])),
    (STR ''break'', ([STR ''broke''], [STR ''broken''])),
    (STR ''breed'', ([STR ''bred''], [STR ''bred''])),
    (STR ''bring'', ([STR ''brought''], [STR ''brought''])),
    (STR ''build'', ([STR ''built''], [STR ''built''])),
    (STR ''burst'', ([STR ''burst''], [STR ''burst''])),
    (STR ''buy'', ([STR ''bought''], [STR ''bought''])),
    (STR ''catch'', ([STR ''caught''], [STR ''caught''])),
    (STR ''choose'', ([STR ''chose''], [STR ''chosen''])),
    (STR ''cling'', ([STR ''clung''], [STR ''clung''])),
    (STR ''come'', ([STR ''came''], [STR ''come''])),
    (STR ''cost'', ([STR ''cost''], [STR ''cost''])),
    (STR ''creep'', ([STR ''crept''], [STR ''crept''])),
    (STR ''cut'', ([STR ''cut''], [STR ''cut''])),
    (STR ''deal'', ([STR ''dealt''], [STR ''dealt''])),
    (STR ''dig'', ([STR ''dug''], [STR ''dug''])),
    (STR ''do'', ([STR ''did''], [STR ''done''])),
    (STR ''draw'', ([STR ''drew''], [STR ''drawn''])),
    (STR ''dream'', ([STR ''dreamed'', STR ''dreamt''], [STR ''dreamed'', STR ''dreamt''])),
    (STR ''drink'', ([STR ''drank''], [STR ''drunk''])),
    (STR ''drive'', ([STR ''drove''], [STR ''driven''])),
    (STR ''eat'', ([STR ''ate''], [STR ''eaten''])),
    (STR ''fall'', ([STR ''fell''], [STR ''fallen''])),
    (STR ''feed'', ([STR ''fed''], [STR ''fed''])),
    (STR ''feel'', ([STR ''felt''], [STR ''felt''])),
    (STR ''fight'', ([STR ''fought''], [STR ''fought''])),
    (STR ''find'', ([STR ''found''], [STR ''found''])),
    (STR ''flee'', ([STR ''fled''], [STR ''fled''])),
    (STR ''fling'', ([STR ''flung''], [STR ''flung''])),
    (STR ''fly'', ([STR ''flew''], [STR ''flown''])),
    (STR ''forbid'', ([STR ''forbade''], [STR ''forbidden''])),
    (STR ''forget'', ([STR ''forgot''], [STR ''forgotten''])),
    (STR ''forgive'', ([STR ''forgave''], [STR ''forgiven''])),
    (STR ''freeze'', ([STR ''froze''], [STR ''frozen''])),
    (STR ''get'', ([STR ''got''], [STR ''got'', STR ''gotten''])),
    (STR ''give'', ([STR ''gave''], [STR ''given''])),
    (STR ''go'', ([STR ''went''], [STR ''gone''])),
    (STR ''grind'', ([STR ''ground''], [STR ''ground''])),
    (STR ''grow'', ([STR ''grew''], [STR ''grown''])),
    (STR ''hang'', ([STR ''hung''], [STR ''hung''])),
    (STR ''have'', ([STR ''had''], [STR ''had''])),
    (STR ''hear'', ([STR ''heard''], [STR ''heard''])),
    (STR ''hide'', ([STR ''hid''], [STR ''hidden''])),
    (STR ''hit'', ([STR ''hit''], [STR ''hit''])),
    (STR ''hold'', ([STR ''held''], [STR ''held''])),
    (STR ''hurt'', ([STR ''hurt''], [STR ''hurt''])),
    (STR ''keep'', ([STR ''kept''], [STR ''kept''])),
    (STR ''kneel'', ([STR ''knelt'', STR ''kneeled''], [STR ''knelt'', STR ''kneeled''])),
    (STR ''know'', ([STR ''knew''], [STR ''known''])),
    (STR ''lay'', ([STR ''laid''], [STR ''laid''])),
    (STR ''lead'', ([STR ''led''], [STR ''led''])),
    (STR ''leap'', ([STR ''leaped'', STR ''leapt''], [STR ''leaped'', STR ''leapt''])),
    (STR ''learn'', ([STR ''learned'', STR ''learnt''], [STR ''learned'', STR ''learnt''])),
    (STR ''leave'', ([STR ''left''], [STR ''left''])),
    (STR ''lend'', ([STR ''lent''], [STR ''lent''])),
    (STR ''let'', ([STR ''let''], [STR ''let''])),
    (STR ''lie'', ([STR ''lay''], [STR ''lain''])),
    (STR ''light'', ([STR ''lit'', STR ''lighted''], [STR ''lit'', STR ''lighted''])),
    (STR ''lose'', ([STR ''lost''], [STR ''lost''])),
    (STR ''make'', ([STR ''made''], [STR ''made''])),
    (STR ''mean'', ([STR ''meant''], [STR ''meant''])),
    (STR ''meet'', ([STR ''met''], [STR ''met''])),
    (STR ''pay'', ([STR ''paid''], [STR ''paid''])),
    (STR ''put'', ([STR ''put''], [STR ''put''])),
    (STR ''quit'', ([STR ''quit''], [STR ''quit''])),
    (STR ''read'', ([STR ''read''], [STR ''read''])),
    (STR ''ride'', ([STR ''rode''], [STR ''ridden''])),
    (STR ''ring'', ([STR ''rang''], [STR ''rung''])),
    (STR ''rise'', ([STR ''rose''], [STR ''risen''])),
    (STR ''run'', ([STR ''ran''], [STR ''run''])),
    (STR ''say'', ([STR ''said''], [STR ''said''])),
    (STR ''see'', ([STR ''saw''], [STR ''seen''])),
    (STR ''seek'', ([STR ''sought''], [STR ''sought''])),
    (STR ''sell'', ([STR ''sold''], [STR ''sold''])),
    (STR ''send'', ([STR ''sent''], [STR ''sent''])),
    (STR ''set'', ([STR ''set''], [STR ''set''])),
    (STR ''shake'', ([STR ''shook''], [STR ''shaken''])),
    (STR ''shine'', ([STR ''shone'', STR ''shined''], [STR ''shone'', STR ''shined''])),
    (STR ''shoot'', ([STR ''shot''], [STR ''shot''])),
    (STR ''show'', ([STR ''showed''], [STR ''shown'', STR ''showed''])),
    (STR ''shrink'', ([STR ''shrank''], [STR ''shrunk''])),
    (STR ''shut'', ([STR ''shut''], [STR ''shut''])),
    (STR ''sing'', ([STR ''sang''], [STR ''sung''])),
    (STR ''sink'', ([STR ''sank''], [STR ''sunk''])),
    (STR ''sit'', ([STR ''sat''], [STR ''sat''])),
    (STR ''sleep'', ([STR ''slept''], [STR ''slept''])),
    (STR ''slide'', ([STR ''slid''], [STR ''slid''])),
    (STR ''speak'', ([STR ''spoke''], [STR ''spoken''])),
    (STR ''spend'', ([STR ''spent''], [STR ''spent''])),
    (STR ''spin'', ([STR ''spun''], [STR ''spun''])),
    (STR ''spit'', ([STR ''spat'', STR ''spit''], [STR ''spat'', STR ''spit''])),
    (STR ''split'', ([STR ''split''], [STR ''split''])),
    (STR ''spread'', ([STR ''spread''], [STR ''spread''])),
    (STR ''spring'', ([STR ''sprang''], [STR ''sprung''])),
    (STR ''stand'', ([STR ''stood''], [STR ''stood''])),
    (STR ''steal'', ([STR ''stole''], [STR ''stolen''])),
    (STR ''stick'', ([STR ''stuck''], [STR ''stuck''])),
    (STR ''sting'', ([STR ''stung''], [STR ''stung''])),
    (STR ''stink'', ([STR ''stank''], [STR ''stunk''])),
    (STR ''stride'', ([STR ''strode''], [STR ''stridden''])),
    (STR ''strike'', ([STR ''struck''], [STR ''struck''])),
    (STR ''swear'', ([STR ''swore''], [STR ''sworn''])),
    (STR ''sweep'', ([STR ''swept''], [STR ''swept''])),
    (STR ''swim'', ([STR ''swam''], [STR ''swum''])),
    (STR ''swing'', ([STR ''swung''], [STR ''swung''])),
    (STR ''take'', ([STR ''took''], [STR ''taken''])),
    (STR ''teach'', ([STR ''taught''], [STR ''taught''])),
    (STR ''tear'', ([STR ''tore''], [STR ''torn''])),
    (STR ''tell'', ([STR ''told''], [STR ''told''])),
    (STR ''think'', ([STR ''thought''], [STR ''thought''])),
    (STR ''throw'', ([STR ''threw''], [STR ''thrown''])),
    (STR ''understand'', ([STR ''understood''], [STR ''understood''])),
    (STR ''wake'', ([STR ''woke''], [STR ''woken''])),
    (STR ''wear'', ([STR ''wore''], [STR ''worn''])),
    (STR ''weave'', ([STR ''wove''], [STR ''woven''])),
    (STR ''weep'', ([STR ''wept''], [STR ''wept''])),
    (STR ''win'', ([STR ''won''], [STR ''won''])),
    (STR ''wind'', ([STR ''wound''], [STR ''wound''])),
    (STR ''write'', ([STR ''wrote''], [STR ''written'']))]"

definition plurals :: "(String.literal \<times> String.literal list) list" where
  "plurals = [
    (STR ''child'', [STR ''children'']),
    (STR ''man'', [STR ''men'']),
    (STR ''woman'', [STR ''women'']),
    (STR ''person'', [STR ''people'']),
    (STR ''tooth'', [STR ''teeth'']),
    (STR ''foot'', [STR ''feet'']),
    (STR ''mouse'', [STR ''mice'']),
    (STR ''goose'', [STR ''geese'']),
    (STR ''ox'', [STR ''oxen'']),
    (STR ''louse'', [STR ''lice'']),
    (STR ''die'', [STR ''dice'']),
    (STR ''cactus'', [STR ''cacti'', STR ''cactuses'']),
    (STR ''fungus'', [STR ''fungi'', STR ''funguses'']),
    (STR ''nucleus'', [STR ''nuclei'']),
    (STR ''radius'', [STR ''radii'']),
    (STR ''stimulus'', [STR ''stimuli'']),
    (STR ''criterion'', [STR ''criteria'']),
    (STR ''phenomenon'', [STR ''phenomena'']),
    (STR ''analysis'', [STR ''analyses'']),
    (STR ''crisis'', [STR ''crises'']),
    (STR ''thesis'', [STR ''theses'']),
    (STR ''hypothesis'', [STR ''hypotheses'']),
    (STR ''axis'', [STR ''axes'']),
    (STR ''index'', [STR ''indices'', STR ''indexes'']),
    (STR ''appendix'', [STR ''appendices'', STR ''appendixes'']),
    (STR ''matrix'', [STR ''matrices'']),
    (STR ''vertex'', [STR ''vertices'']),
    (STR ''datum'', [STR ''data'']),
    (STR ''medium'', [STR ''media'']),
    (STR ''curriculum'', [STR ''curricula'', STR ''curriculums'']),
    (STR ''bacterium'', [STR ''bacteria'']),
    (STR ''alga'', [STR ''algae'']),
    (STR ''larva'', [STR ''larvae'']),
    (STR ''formula'', [STR ''formulae'', STR ''formulas'']),
    (STR ''sheep'', [STR ''sheep'']),
    (STR ''deer'', [STR ''deer'']),
    (STR ''fish'', [STR ''fish'', STR ''fishes'']),
    (STR ''moose'', [STR ''moose'']),
    (STR ''series'', [STR ''series'']),
    (STR ''species'', [STR ''species'']),
    (STR ''aircraft'', [STR ''aircraft'']),
    (STR ''knife'', [STR ''knives'']),
    (STR ''wife'', [STR ''wives'']),
    (STR ''leaf'', [STR ''leaves'']),
    (STR ''half'', [STR ''halves'']),
    (STR ''wolf'', [STR ''wolves'']),
    (STR ''calf'', [STR ''calves'']),
    (STR ''loaf'', [STR ''loaves'']),
    (STR ''shelf'', [STR ''shelves'']),
    (STR ''thief'', [STR ''thieves'']),
    (STR ''life'', [STR ''lives'']),
    (STR ''potato'', [STR ''potatoes'']),
    (STR ''tomato'', [STR ''tomatoes'']),
    (STR ''hero'', [STR ''heroes'']),
    (STR ''echo'', [STR ''echoes''])]"

definition compares :: "(String.literal \<times> (String.literal list \<times> String.literal list)) list" where
  "compares = [
    (STR ''good'', ([STR ''better''], [STR ''best''])),
    (STR ''well'', ([STR ''better''], [STR ''best''])),
    (STR ''bad'', ([STR ''worse''], [STR ''worst''])),
    (STR ''badly'', ([STR ''worse''], [STR ''worst''])),
    (STR ''far'', ([STR ''farther'', STR ''further''], [STR ''farthest'', STR ''furthest''])),
    (STR ''little'', ([STR ''less''], [STR ''least''])),
    (STR ''much'', ([STR ''more''], [STR ''most''])),
    (STR ''many'', ([STR ''more''], [STR ''most''])),
    (STR ''old'', ([STR ''older'', STR ''elder''], [STR ''oldest'', STR ''eldest'']))]"

datatype gkind = G_past | G_pp | G_plural | G_cmp | G_sup

text \<open>What the question named (the organ's regex tests, in its order) and the candidate
words (the matched word, then every quoted word that differs from it).\<close>
datatype greq = GReq (g_pp: bool) (g_past: bool) (g_plural: bool) (g_cmp: bool) (g_sup: bool)
  (g_cands: "String.literal list")

datatype gout = GSilent | GVal gkind String.literal "String.literal list" "String.literal list"

definition gkernel :: "greq \<Rightarrow> gout" where
  "gkernel r =
     (if g_pp r then
        (case first_known verbs (g_cands r) of Some (w, (p, q)) \<Rightarrow> GVal G_pp w q p | None \<Rightarrow> GSilent)
      else if g_past r then
        (case first_known verbs (g_cands r) of Some (w, (p, q)) \<Rightarrow> GVal G_past w p q | None \<Rightarrow> GSilent)
      else if g_plural r then
        (case first_known plurals (g_cands r) of Some (w, ps) \<Rightarrow> GVal G_plural w ps [] | None \<Rightarrow> GSilent)
      else if g_cmp r then
        (case first_known compares (g_cands r) of
           Some (w, (c, s)) \<Rightarrow> (if g_sup r then GVal G_sup w s c else GVal G_cmp w c s)
         | None \<Rightarrow> GSilent)
      else GSilent)"

definition gunknown :: "gkind \<Rightarrow> String.literal \<Rightarrow> bool" where
  "gunknown k w = (case k of G_pp \<Rightarrow> map_of verbs w = None | G_past \<Rightarrow> map_of verbs w = None
                 | G_plural \<Rightarrow> map_of plurals w = None | G_cmp \<Rightarrow> map_of compares w = None
                 | G_sup \<Rightarrow> map_of compares w = None)"

text \<open>Every answer is a row of the table of its kind, for a candidate that is the first
one the table knows; the kind is the first one the question named, in the organ's order.\<close>
theorem gkernel_row:
  assumes "gkernel r = GVal k w a b"
  shows "(k = G_pp \<longrightarrow> g_pp r \<and> map_of verbs w = Some (b, a))
       \<and> (k = G_past \<longrightarrow> \<not> g_pp r \<and> g_past r \<and> map_of verbs w = Some (a, b))
       \<and> (k = G_plural \<longrightarrow> \<not> g_pp r \<and> \<not> g_past r \<and> g_plural r \<and> map_of plurals w = Some a)
       \<and> (k = G_cmp \<longrightarrow> \<not> g_pp r \<and> \<not> g_past r \<and> \<not> g_plural r \<and> g_cmp r \<and> \<not> g_sup r
                      \<and> map_of compares w = Some (a, b))
       \<and> (k = G_sup \<longrightarrow> \<not> g_pp r \<and> \<not> g_past r \<and> \<not> g_plural r \<and> g_cmp r \<and> g_sup r
                      \<and> map_of compares w = Some (b, a))"
  using assms
  by (auto simp: gkernel_def dest: first_known_some split: if_splits option.splits prod.splits)

theorem gkernel_first_candidate:
  assumes "gkernel r = GVal k w a b"
  shows "\<exists>i<length (g_cands r). g_cands r ! i = w \<and> (\<forall>j<i. gunknown k (g_cands r ! j))"
  using assms
  by (auto simp: gkernel_def gunknown_def dest: first_known_some split: if_splits option.splits prod.splits)

theorem gkernel_silent_no_flag:
  "\<not> g_pp r \<Longrightarrow> \<not> g_past r \<Longrightarrow> \<not> g_plural r \<Longrightarrow> \<not> g_cmp r \<Longrightarrow> gkernel r = GSilent"
  by (simp add: gkernel_def)

theorem gkernel_silent_unknown:
  assumes "gkernel r = GSilent" "g_pp r"
  shows "\<forall>c\<in>set (g_cands r). map_of verbs c = None"
  using assms by (auto simp: gkernel_def dest: first_known_none split: option.splits prod.splits)

definition gkind_name :: "gkind \<Rightarrow> String.literal" where
  "gkind_name k = (case k of G_past \<Rightarrow> STR ''past_tense'' | G_pp \<Rightarrow> STR ''past_participle''
                   | G_plural \<Rightarrow> STR ''plural'' | G_cmp \<Rightarrow> STR ''comparative'' | G_sup \<Rightarrow> STR ''superlative'')"

definition gtext :: "gkind \<Rightarrow> String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "gtext k w a b = (case k of
      G_pp \<Rightarrow> cat [STR ''The past participle of '', quoted w, STR '' is '', join_or a, STR '' ('', w, STR '', '',
                      join_or b, STR '', '', join_or a, STR '').'']
    | G_past \<Rightarrow> cat [STR ''The past tense of '', quoted w, STR '' is '', join_or a, STR '' ('', w, STR '', '',
                      join_or a, STR '', '', join_or b, STR '').'']
    | G_plural \<Rightarrow> cat [STR ''The plural of '', quoted w, STR '' is '', join_or a, STR ''.'']
    | G_cmp \<Rightarrow> cat [STR ''The comparative of '', quoted w, STR '' is '', join_or a, STR '' (irregular).'']
    | G_sup \<Rightarrow> cat [STR ''The superlative of '', quoted w, STR '' is '', join_or a, STR '' (irregular).''])"

definition greply :: "greq \<Rightarrow> reply" where
  "greply r = (case gkernel r of
      GSilent \<Rightarrow> Reply False (STR ''silent'') (STR '''') None
    | GVal k w a b \<Rightarrow> Reply True (gkind_name k) (gtext k w a b) (Some (join_or a)))"

theorem greply_answered_iff: "answered (greply r) \<longleftrightarrow> gkernel r \<noteq> GSilent"
  by (auto simp: greply_def split: gout.splits)

definition grammar_self_test :: bool where
  "grammar_self_test \<longleftrightarrow>
     gkernel (GReq False True False False False [STR ''spring'']) = GVal G_past (STR ''spring'') [STR ''sprang''] [STR ''sprung''] \<and>
     response (greply (GReq True False False False False [STR ''dream''])) =
       cat [STR ''The past participle of '', apos, STR ''dream'', apos, STR '' is dreamed or dreamt (dream, dreamed or dreamt, dreamed or dreamt).''] \<and>
     gkernel (GReq False False True False False [STR ''mouse'']) = GVal G_plural (STR ''mouse'') [STR ''mice''] [] \<and>
     gkernel (GReq False False False True True [STR ''good'']) = GVal G_sup (STR ''good'') [STR ''best''] [STR ''better''] \<and>
     gkernel (GReq False True False False False [STR ''zzz'', STR ''swim'']) = GVal G_past (STR ''swim'') [STR ''swam''] [STR ''swum''] \<and>
     gkernel (GReq True True False False False [STR ''zzz'']) = GSilent"

end
