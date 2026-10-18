(* Run from repository root: poly --script src/extract/commons/measured_input_test.sml *)
use "src/extract/commons/numeric.sml";
use "src/extract/commons/measured_input.sml";
open MeasuredInput;
val checks=ref 0;
fun check name b = (checks := !checks+1; if b then () else raise Fail name);
fun u alias tag dimension = {alias=alias,tag=tag,dimension=dimension,caseSensitive=true};
val table=[u "m" "m" "length",u "cm" "cm" "length",u "m2" "m2" "area",
 u "m/s^2" "mps2" "acceleration",u "m/s2" "mps2" "acceleration",
 u "kg/m3" "kgpm3" "density",u "mg/L" "mgpl" "concentration",
 u "mg-min/L" "ct" "ct",u "mg min/L" "ct" "ct",u "mg\194\183min/L" "ct" "ct",
 u "min" "min" "time",u "minutes" "min" "time",u "F" "F" "temperature",
 u "M" "M" "concentration",u "Pa" "Pa" "pressure",
 u "kg" "kg" "mass",u "pound" "lb" "mass"];
fun measurements s = List.mapPartial(fn Measurement m=>SOME m | _=>NONE)(scan table s);
fun first s = hd(measurements s);
fun tag s t = case #unitBinding(first s) of Explicit{unit,...}=> #tag unit=t | _=>false;
fun bad s = case #unitBinding(first s) of Unsupported _=>true | _=>false;
val _=List.app(fn(s,t)=>check s (tag s t))
 [("2m","m"),("2 cm","cm"),("1e3 kg/m3","kgpm3"),("9.81 m/s^2","mps2"),
  ("2 mg / L","mgpl"),("60 mg-min/L","ct"),("60 mg min/L","ct"),
  ("60 mg\194\183min/L","ct"),("2 M","M"),("2 m","m"),("2 minutes","min")];
val _=List.app(fn s=>check s (bad s))
 ["2 m/s","2 m / s","2 m per second","2 m squared","2 m\194\178",
  "2 mg/L/min","2 mg / L / min","2 F/s","2 F per second","2 m^3","2 m*s", "2xyz", "2/unknown", "2 mg/L-min", "2 mg/L min",
  "2 mg/L - min", "2 mg / L minutes", "2 m cm", "2 kg-force", "2 pound-force", "2 kg - force", "2 mg/L.min", "2 mg/L. min",
  "2 mg/L \195\151 min", "2 mg/L \226\139\133 min", "2 mg/L \226\136\153 min"];
val a=first "CT 60 mg/L";
val _=check "CT label cannot override concentration" (case bind{expected="ct",inheritFrom=NONE}a of WrongDimension{actual="concentration",...}=>true | _=>false);
val _=check "source exact spans" (case a of {numberSpan={start=3,stop=5},unitBinding=Explicit{span={start=6,stop=10},...},...}=>true | _=>false);
val ms=measurements "length 2 m and width 3";
val _=check "bare inherits agreed source length" (case bind{expected="length",inheritFrom=agreeSource ms}(List.nth(ms,1)) of Bound{unit,origin=Inherited,...}=> #tag unit="m" | _=>false);
val _=check "counts do not inherit length" (case bind{expected="count",inheritFrom=agreeSource ms}(List.nth(ms,1)) of WrongDimension _=>true | _=>false);
val _=check "mixed source units do not invent default" (case agreeSource(measurements "2m and 3cm") of NONE=>true | _=>false);
val _=check "output retained separately" (case requested table "output cm" {start=7,stop=9} of SOME(RequestedOutput{unit,span={start=7,stop=9}})=> #tag unit="cm" | _=>false);
val _=check "output whole expression" (case requested table "cm/s" {start=0,stop=4} of NONE=>true | _=>false);
val _=check "output strict span" (case requested table "cm garbage" {start=0,stop=10} of NONE=>true | _=>false);
val _=check "separated prose stays bare" (case #unitBinding(first "3 mass measurements") of Bare=>true | _=>false);
val _=check "malformed whole numeric token" (case scan table "1.2.3 m" of [Malformed _]=>true | _=>false);
val _=check "exact signed fraction" (#value(first "-1/2 m")=(~1,2));
val _=check "original Unicode spans" (case first "\226\136\1462 m" of {numberSpan={start=0,stop=4},value=(~2,1),...}=>true | _=>false);
val _=check "no swallowed following numbers" (length(measurements "2m and 3cm")=2);
val _=check "bad compound cannot inherit" (case bind{expected="temperature",inheritFrom=sourceUnit(first "2 F")}(first "2 F/s") of UnsupportedUnit _=>true | _=>false);
val _=check "folded alias retains original span" (case scan [{alias="mg/L",tag="c",dimension="concentration",caseSensitive=false}] "2 MG/l" of
 [Measurement{unitBinding=Explicit{span={start=2,stop=6},...},...}]=>true | _=>false);
val _=check "invalid span rejected" (case requested table "cm" {start= ~1,stop=2} of NONE=>true | _=>false);
val _=check "invalid stop rejected" (case requested table "cm" {start=0,stop=3} of NONE=>true | _=>false);
val _=check "unit exponent is not another measurement" (length(measurements "9.81 m/s^2")=1);
val _=check "ordinary role tail is not a unit" (tag "2 mg/L residual" "mgpl");
val _=check "ordinary connector tail is not a unit" (tag "2 mg/L and contact time 30 min" "mgpl");
val _=check "output span before ordinary trailing prose" (case requested table "cm please" {start=0,stop=2} of SOME _=>true | _=>false);
val _=check "output span may include its own whitespace" (case requested table "cm  please" {start=0,stop=4} of SOME _=>true | _=>false);
val _=check "output span cannot truncate a compound" (case requested table "cm/s" {start=0,stop=2} of NONE=>true | _=>false);
val _=check "sentence-ending period preserved" (tag "2 mg/L." "mgpl");
val _=check "sentence period before ordinary prose preserved" (tag "2 mg/L. What is its CT?" "mgpl");
val _=print("MeasuredInput PASS " ^ Int.toString(!checks) ^ " checks\n");
