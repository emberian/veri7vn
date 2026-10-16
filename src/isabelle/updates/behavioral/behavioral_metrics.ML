(* Data reduction for the fixed behavioral observer. These values are empirical
   observations, never native theorem/admission or publication authority. *)
structure Veri7vn_Behavioral_Metrics =
struct
  datatype expectation = Expected_Rational of IntInf.int * IntInf.int
    | Must_Decline | Unknown;
  datatype role = Domain | General | Identity;
  datatype reply = Asserted_Rational of IntInf.int * IntInf.int
    | Declined | Not_Taken | Guarded | Measurement_Failed of string;
  type measured = {reply:reply,elapsed_us:IntInf.int};
  type row = {index:int,role:role,expected:expectation,
    baseline:measured,candidate:measured};
  type totals = {correct:int,false_assertions:int,wrong:int,refusals:int,
    assertions:int,unscored:int,measurement_failures:int,general_taken:int,identity_taken:int};
  type summary = {n:int,scored:int,unknown:int,domain:int,general:int,identity:int,
    baseline:totals,candidate:totals,gain:int,
    baseline_p50_us:IntInf.int option,candidate_p50_us:IntInf.int option};
  fun require true _=() | require false message=error message;
  fun rational(n,d)=d>0 andalso size(IntInf.toString n)<=2048 andalso
    size(IntInf.toString d)<=2048;
  fun assertion(Asserted_Rational _)=true | assertion _=false;
  fun taken Not_Taken=false | taken _=true;
  fun same((n,d),(a,b))=n*b=a*d;
  fun correct Unknown _=false
    | correct _ (Measurement_Failed _)=false
    | correct Must_Decline reply=not(assertion reply)
    | correct(Expected_Rational expected)(Asserted_Rational actual)=same(expected,actual)
    | correct _ _=false;
  fun known Unknown=false | known _=true;
  fun valid_expected(Expected_Rational value)=rational value | valid_expected _=true;
  fun valid_reply(Asserted_Rational value)=rational value
    | valid_reply(Measurement_Failed message)=size message<=256
    | valid_reply _=true;
  fun checked_row({index,expected,baseline,candidate,...}:row)=
    require(index>=0 andalso index<2048 andalso valid_expected expected andalso
      valid_reply(#reply baseline) andalso valid_reply(#reply candidate) andalso
      #elapsed_us baseline>=0 andalso #elapsed_us candidate>=0)
      "Behavioral row bounds";
  val zero:totals={correct=0,false_assertions=0,wrong=0,refusals=0,
    assertions=0,unscored=0,measurement_failures=0,general_taken=0,identity_taken=0};
  fun bit true=1 | bit false=0;
  fun add role expected reply (total:totals):totals=
    {correct= #correct total+bit(correct expected reply),
     false_assertions= #false_assertions total+bit(expected=Must_Decline andalso assertion reply),
     wrong= #wrong total+bit(case expected of Expected_Rational _=>
       assertion reply andalso not(correct expected reply) | _=>false),
     refusals= #refusals total+bit(case reply of Declined=>true | Guarded=>true | _=>false),
     assertions= #assertions total+bit(assertion reply),
     unscored= #unscored total+bit(not(known expected)),
     measurement_failures= #measurement_failures total+
       bit(case reply of Measurement_Failed _=>true | _=>false),
     general_taken= #general_taken total+bit(role=General andalso taken reply),
     identity_taken= #identity_taken total+bit(role=Identity andalso taken reply)};
  fun median []=NONE
    | median values=let val sorted=sort IntInf.compare values
      in SOME(nth sorted(length sorted div 2))end;
  fun summarize(rows:row list):summary=
    let
      val _=require(not(null rows) andalso length rows<=2048)"Behavioral panel size";
      val _=List.app checked_row rows;
      val _=require(length(distinct(op =)(map #index rows))=length rows)
        "Behavioral duplicate panel row";
      fun total(side:row -> measured)=fold(fn row=>add(#role row)(#expected row)(#reply(side row)))rows zero;
      val baseline=total #baseline;
      val candidate=total #candidate;
      fun count predicate=length(filter predicate rows);
    in {n=length rows,scored=count(known o #expected),unknown=count(not o known o #expected),
      domain=count(fn r=> #role r=Domain),general=count(fn r=> #role r=General),
      identity=count(fn r=> #role r=Identity),baseline=baseline,candidate=candidate,
      gain= #correct(fold(fn row=>if #role row=Domain then
        add Domain (#expected row)(#reply(#candidate row))else I)rows zero)-
        #correct(fold(fn row=>if #role row=Domain then
          add Domain (#expected row)(#reply(#baseline row))else I)rows zero),
      baseline_p50_us=median(map(#elapsed_us o #baseline)rows),
      candidate_p50_us=median(map(#elapsed_us o #candidate)rows)}end;
  (* Qualification criteria are separate from recording. Empty/unmeasured panels
     cannot silently satisfy a routing or identity requirement. *)
  type policy={minimum_gain:int,maximum_wrong:int,maximum_general_taken:int,
    require_general:bool,require_identity:bool,maximum_p50_us:IntInf.int};
  fun failures(policy:policy)(result:summary)=
    let val b= #baseline result; val c= #candidate result;
      val _=require(#minimum_gain policy>=0 andalso #maximum_wrong policy>=0 andalso
        #maximum_general_taken policy>=0 andalso #maximum_p50_us policy>=0)
        "Behavioral policy bounds";
      fun because condition message=if condition then[message]else[];
    in because(#scored result=0)"No known expectations" @
      because(#measurement_failures b+ #measurement_failures c>0)"Execution measurement failed" @
      because(#gain result< #minimum_gain policy)"Insufficient correctness gain" @
      because(#false_assertions c> #false_assertions b)"False assertions increased" @
      because(#wrong c> #maximum_wrong policy)"Wrong asserted values exceed policy" @
      because(#require_general policy andalso #general result=0)"General interception unmeasured" @
      because(#general_taken c> #maximum_general_taken policy)"General interception exceeds policy" @
      because(#require_identity policy andalso #identity result=0)"Identity interception unmeasured" @
      because(#identity_taken c>0)"Identity interception" @
      because(case #candidate_p50_us result of NONE=>true |
        SOME elapsed=>elapsed> #maximum_p50_us policy)"Median latency exceeds policy"
    end;
end;
