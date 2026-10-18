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
    (* W6-25: UTF-8. Literals are whole characters, classes hold multi-byte members,
       . and negated classes never split a character, case folding is ASCII-only. *)
    check "u: curly open literal" (m "“x" "say “x”");
    check "u: curly literal absent" (not (m "“" "say \"x\""));
    check "u: class holds curly quotes" (m "^[“”]{2}$" "“”");
    check "u: class matches one char of 3 bytes" (m "^[“”]$" "”");
    check "u: class rejects its first-byte sibling" (not (m "^[“”]$" "‘"));
    check "u: class rejects ascii quote" (not (m "^[“”]$" "\""));
    check "u: ascii and curly mixed class" (m "^[\"“]{3}$" "“\"“");
    check "u: negated class takes whole char" (m "^[^\"”]{3}$" "a“b");
    check "u: negated class stops at member" (Regex.whole "ab”c" (valOf (Regex.search (Regex.compile "[^”]+") "ab”c")) = "ab");
    check "u: negated class never splits" (m "^[^x]$" "“");
    check "u: negated class on ascii-only member" (not (m "^[^“]$" "“"));
    check "u: negated class does not match half a char" (Regex.whole "“x" (valOf (Regex.search (Regex.compile "[^a]") "“x")) = "“");
    check "u: dot is one char" (m "^.$" "“" andalso m "^...$" "a–b" andalso not (m "^..$" "a–b"));
    check "u: dot count in bounded rep" (m "^.{1,3}$" "°×÷" andalso not (m "^.{1,2}$" "°×÷"));
    check "u: quoted group" (Regex.group "I have no entry for “my passport” x" (valOf (Regex.search (Regex.compile "[“]([^”]{1,120})[”]") "I have no entry for “my passport” x")) 1 = SOME "my passport");
    check "u: en dash literal" (m "5–10" "ages 5–10");
    check "u: en dash in class" (m "^\\d[-–—]\\d$" "5–6" andalso m "^\\d[-–—]\\d$" "5-6" andalso m "^\\d[-–—]\\d$" "5—6");
    check "u: en dash not hyphen" (not (m "5–10" "5-10"));
    check "u: degree literal" (m "\\d+ ?°c" "20°c");
    check "u: degree in class" (m "^[°º]$" "°" andalso not (m "^[°º]$" "o"));
    check "u: times and divide literal" (m "3×4" "3×4" andalso m "8÷2" "8÷2");
    check "u: times/divide in class" (m "^\\d[×÷*/]\\d$" "3×4" andalso m "^\\d[×÷*/]\\d$" "8÷2" andalso m "^\\d[×÷*/]\\d$" "8/2");
    check "u: times/divide negated" (not (m "^[^×÷]$" "×") andalso m "^[^×÷]$" "−");
    check "u: x vs times distinct" (not (m "3×4" "3x4"));
    check "u: range of codepoints" (m "^[à-ÿ]$" "é" andalso not (m "^[à-ÿ]$" "a"));
    check "u: quantified multibyte literal" (m "^“+$" "““““" andalso not (m "^“{2}$" "“““"));
    check "u: alternation of multibyte" (m "^(?:“|”|‘)$" "”");
    check "u: multibyte escaped literal" (m "\\–" "–");
    check "u: ascii-only case folding" (m "^é$" "é" andalso not (m "^É$" "é") andalso not (m "^[a-c]$" "é"));
    check "u: compileI folds ascii only" (isSome (Regex.search (Regex.compileI "^ab$") "AB") andalso not (isSome (Regex.search (Regex.compileI "^é$") "É")));
    check "u: compileCS exact" (not (isSome (Regex.search (Regex.compileCS "^a“$") "A“")));
    check "u: search starts on boundaries" (length (Regex.findall (Regex.compile ".") "a“b") = 3);
    check "u: empty-match findall advances by char" (length (Regex.findall (Regex.compile "x*") "“") = 2);
    check "u: positions stay byte offsets" (let val mm = valOf (Regex.search (Regex.compile "b") "“b") in #start mm = 3 andalso #stop mm = 4 end);
    check "u: lookbehind after multibyte" (m "(?<=“)x" "“x" andalso not (m "(?<=”)x" "“x"));
    check "u: backreference multibyte" (m "(“)\\1" "““");
    check "u: invalid bytes degrade to bytes" (m "^..$" "\128\128" andalso not (m "^[“]$" "\226\128") andalso m "^[^a]$" "\226");
    check "u: truncated sequence not a char" (not (m "^[^x]{1}$" "\226\128"));
    check "u: w is ascii only" (not (m "^\\w$" "é") andalso m "^\\W$" "é");
    if !failures = 0 then print "REGEX_TEST PASS\n" else OS.Process.exit OS.Process.failure)
end
