(* UNTRUSTED. The ordered rule patterns of three organs, copied verbatim (as SML strings) from
     ushistory/organ_ushistory_v1.py   EVENTS   (pattern i pairs with Humanities events row i)
     government/organ_government_v1.py TOPIC    (pattern i pairs with Humanities topic_nums entry i)
                                       FACTS    (pattern i pairs with Humanities fact_rows row i)
                                       ORD      (ordinal word to number, longest word first)
   tables_check.py compares each list with the organ file. *)
structure Rules =
struct
  val events = [
    "\\bdeclaration of independence\\b",
    "\\bconstitution\\b.*\\bsigned\\b|\\bsigned\\b.*\\bconstitution\\b",
    "\\bconstitution\\b.*\\bratified\\b|\\bratified\\b.*\\bconstitution\\b",
    "\\bbill of rights\\b",
    "\\blouisiana purchase\\b",
    "\\bcivil war\\b.*\\b(?:begin|start|began|started)\\b|\\b(?:begin|start|began|started)\\b.*\\bcivil war\\b",
    "\\bcivil war\\b.*\\b(?:end|ended|finish)\\b|\\b(?:end|ended)\\b.*\\bcivil war\\b",
    "\\bemancipation proclamation\\b",
    "\\blincoln\\b.*\\bassassinat\\w*\\b|\\bassassinat\\w*\\b.*\\blincoln\\b",
    "\\btranscontinental railroad\\b",
    "\\bwomen\\b.*\\bright to vote\\b|\\b19th amendment\\b.*\\bratified\\b|\\bwomen'?s suffrage\\b",
    "\\bstock market crash\\b|\\bblack tuesday\\b",
    "\\bpearl harbor\\b",
    "\\bbrown v\\.? board\\b",
    "\\bcivil rights act\\b",
    "\\bvoting rights act\\b",
    "\\bmoon landing\\b|\\bapollo 11\\b|\\blanded on the moon\\b",
    "\\bnixon\\b.*\\bresign\\w*\\b|\\bresign\\w*\\b.*\\bnixon\\b",
    "\\bseptember 11\\b|\\b9/11\\b"]

  val topics = [
    "\\bslavery\\b",
    "\\bwomen'?s (?:right to vote|suffrage|voting)\\b|\\bsuffrage for women\\b|\\bwomen (?:the right to )?vote\\b",
    "\\bincome tax\\b",
    "\\brepeal\\w* prohibition\\b|\\bended prohibition\\b",
    "\\bprohibition\\b",
    "\\bvoting age\\b|\\b18[- ]year[- ]olds?\\b|\\bage (?:of )?18\\b",
    "\\btwo[- ]term\\b|\\bterm limits?\\b.*\\bpresident\\b|\\bpresident\\w*\\b.*\\bterm limits?\\b",
    "\\bpoll tax\\w*\\b",
    "\\bdirect election of senators\\b|\\bsenators\\b.*\\belect\\w* (?:directly|by the people)\\b",
    "\\bequal protection\\b|\\bbirthright citizenship\\b",
    "\\bfree(?:dom of)? speech\\b|\\bfreedom of (?:religion|the press|assembly)\\b",
    "\\bbear arms\\b|\\bright to (?:keep and )?bear\\b|\\bgun\\w*\\b",
    "\\bquartering\\b",
    "\\bsearch(?:es)? and seizures?\\b|\\bunreasonable search\\w*\\b",
    "\\bself[- ]incrimination\\b|\\bdouble jeopardy\\b|\\bplead(?:ing)? the fifth\\b|\\btakings?\\b",
    "\\bright to (?:a )?counsel\\b|\\bspeedy (?:and public )?trial\\b",
    "\\bcruel and unusual\\b|\\bexcessive bail\\b",
    "\\breserved to the states\\b|\\bstates'? rights\\b",
    "\\bpresidential succession\\b|\\bpresidential disability\\b|\\bvice president becomes president\\b",
    "\\brace\\b.*\\bvot\\w*\\b|\\bvot\\w*\\b.*\\brace\\b",
    "\\bwashington,? d\\.?c\\.?\\b.*\\belector\\w*\\b|\\belector\\w*\\b.*\\bwashington,? d\\.?c\\.?\\b",
    "\\bcongressional pay\\b|\\bpay raises? for congress\\b",
    "\\blame[- ]duck\\b"]

  val facts = [
    "\\bhow many senators\\b",
    "\\bhow many (?:voting )?(?:members of the house|representatives|house members)\\b|\\bhow many seats (?:are )?in the house\\b|\\bhow many (?:voting )?members (?:are )?in the house\\b",
    "\\bhow many electors\\b|\\bhow many electoral votes (?:are there|in total|total)\\b|\\btotal (?:number of )?electoral votes\\b",
    "\\bhow many electoral votes (?:are )?(?:needed|required|does it take) to win\\b|\\belectoral votes to win\\b|\\bneeded to win the presidency\\b",
    "\\bhow many amendments\\b",
    "\\bhow many (?:supreme court )?justices\\b",
    "\\bhow long (?:is a|are) senat\\w* terms?\\b|\\bsenate term\\b|\\bterm of a senator\\b",
    "\\bhow long (?:is a|are) (?:house|representative\\w*) terms?\\b|\\bhouse term\\b|\\bterm of a representative\\b",
    "\\bhow long (?:is a|are) president\\w* terms?\\b|\\bpresidential term\\b|\\bterm of (?:the|a) president\\b",
    "\\bhow old\\b.*\\bpresident\\b|\\bminimum age\\b.*\\bpresident\\b|\\bpresident\\w*\\b.*\\bminimum age\\b",
    "\\bhow old\\b.*\\bsenator\\b|\\bminimum age\\b.*\\bsenat\\w*\\b|\\bsenat\\w*\\b.*\\bminimum age\\b",
    "\\bhow old\\b.*\\b(?:representative|house)\\b|\\bminimum age\\b.*\\b(?:representative|house)\\b|\\b(?:representative|house)\\b.*\\bminimum age\\b",
    "\\bbill of rights\\b.*\\bhow many\\b|\\bhow many\\b.*\\bbill of rights\\b"]

  val ords = [
    ("twenty-seventh", 27),
    ("twenty-second", 22),
    ("twenty-fourth", 24),
    ("twenty-first", 21),
    ("twenty-third", 23),
    ("twenty-fifth", 25),
    ("twenty-sixth", 26),
    ("seventeenth", 17),
    ("thirteenth", 13),
    ("fourteenth", 14),
    ("eighteenth", 18),
    ("nineteenth", 19),
    ("fifteenth", 15),
    ("sixteenth", 16),
    ("twentieth", 20),
    ("eleventh", 11),
    ("seventh", 7),
    ("twelfth", 12),
    ("second", 2),
    ("fourth", 4),
    ("eighth", 8),
    ("first", 1),
    ("third", 3),
    ("fifth", 5),
    ("sixth", 6),
    ("ninth", 9),
    ("tenth", 10)]
end
