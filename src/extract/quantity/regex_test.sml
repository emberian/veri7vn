(* Test for regex.sml: escape classes keep their meaning, literals fold case.
   Run: sh src/extract/quantity/regex_test.sh   (MLton from Isabelle; prints REGEX_TEST PASS) *)
structure RegexTest =
struct
  fun m p s = isSome (Regex.search (Regex.compile p) s)   (* text is lower-cased by callers *)
  val failures = ref 0
  fun check name b = if b then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))
  val () = (
    check "S matches non-space" (m "^\\S$" "a");
    check "S rejects space" (not (m "^\\S$" " "));
    check "s matches space" (m "^\\s$" " ");
    check "s rejects non-space" (not (m "^\\s$" "a"));
    check "D matches non-digit" (m "^\\D$" "a");
    check "D rejects digit" (not (m "^\\D$" "7"));
    check "W matches non-word" (m "^\\W$" "-");
    check "W rejects word" (not (m "^\\W$" "a"));
    check "B inside word" (m "a\\Bb" "ab");
    check "B rejects boundary" (not (m "a\\Bb" "a b"));
    check "class S in brackets (python [\\s\\S])" (m "^[\\s\\S]*$" "a b\tc");
    check "class [^\\S] is space" (m "^[^\\S]$" " " andalso not (m "^[^\\S]$" "x"));
    check "literal folds" (m "R-\\d" "r-5");
    check "class range folds" (m "^[A-C]$" "b");
    check "escaped literal folds" (m "\\R" "r");
    check "mixed" (m "\\bR-\\d{1,2}\\b(?![\\s\\S]*\\bR-\\d)" "heat r-13 x");
    if !failures = 0 then print "REGEX_TEST PASS\n" else OS.Process.exit OS.Process.failure)
end
