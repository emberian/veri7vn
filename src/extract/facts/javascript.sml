(* UNTRUSTED: ASCII tokenizer, precedence parser and English request framing.
   A successful parse consumes the complete expression. Identifiers and string
   contents are case-sensitive. It builds the exported HOL AST, never executes
   JavaScript. Unsupported syntax and model operations decline. *)
structure Javascript =
struct
  datatype token = Value of Facts.js_value | Plus | Minus | Strict | Loose
                 | Typeof | Left | Right
  datatype request = Expression of Facts.js_expr | TableRow of int | Rejected | NotJS
  exception Parse
  fun trim s =
    let val cs = String.explode s
        fun drop [] = [] | drop (c::rest) = if Char.isSpace c then drop rest else c::rest
    in String.implode (rev (drop (rev (drop cs)))) end
  fun lower s = String.map Char.toLower s
  fun prefix p s = String.isPrefix (lower p) (lower s)
  fun suffix p s = String.isSuffix (lower p) (lower s)
  fun dropPrefix ps s =
    case List.find (fn p => prefix p s) ps of
      SOME p => (true,trim (String.extract(s,size p,NONE))) | NONE => (false,s)
  fun dropSuffix ps s =
    case List.find (fn p => suffix p s) ps of
      SOME p => (true,trim (String.substring(s,0,size s-size p))) | NONE => (false,s)
  fun stripQuestion s =
    let val s=trim s in if String.isSuffix "?" s then trim(String.substring(s,0,size s-1)) else s end
  fun tokenize s =
    let val n=size s
        fun char i = String.sub(s,i)
        fun quoted quote i acc =
          if i>=n then raise Parse
          else if char i=quote then (String.implode(rev acc),i+1)
          else if char i = #"\\" then
            if i+1>=n then raise Parse
            else let val c = case char(i+1) of #"n" => #"\n" | #"t" => #"\t" | #"r" => #"\r"
                       | #"\\" => #"\\" | #"\"" => #"\"" | #"'" => #"'" | _ => raise Parse
                 in quoted quote (i+2) (c::acc) end
          else if Char.ord(char i)<32 orelse Char.ord(char i)>126 then raise Parse
          else quoted quote (i+1) (char i::acc)
        fun span pred i = if i<n andalso pred(char i) then span pred (i+1) else i
        fun keyword text = case text of
            "typeof" => Typeof | "null" => Value Facts.JNull | "undefined" => Value Facts.JUndef
          | "NaN" => Value Facts.JNaN | "true" => Value(Facts.JBool true) | "false" => Value(Facts.JBool false)
          | _ => raise Parse
        fun go i acc count =
          if count>256 orelse n>4096 then raise Parse
          else if i>=n then rev acc
          else if Char.isSpace(char i) then go (i+1) acc count
          else case char i of
            #"+" => if i+1<n andalso char(i+1)= #"+" then raise Parse else go(i+1)(Plus::acc)(count+1)
          | #"-" => if i+1<n andalso char(i+1)= #"-" then raise Parse else go(i+1)(Minus::acc)(count+1)
          | #"(" => go(i+1)(Left::acc)(count+1)
          | #")" => go(i+1)(Right::acc)(count+1)
          | #"=" => if i+2<n andalso char(i+1)= #"=" andalso char(i+2)= #"="
                      then go(i+3)(Strict::acc)(count+1)
                    else if i+1<n andalso char(i+1)= #"=" then go(i+2)(Loose::acc)(count+1)
                    else raise Parse
          | c => if c= #"\"" orelse c= #"'" then
                     let val (text,j)=quoted c(i+1)[] in go j(Value(Facts.JStr text)::acc)(count+1) end
                 else if Char.isDigit c then
                     let val j=span Char.isDigit i
                         val text=String.substring(s,i,j-i)
                         val _=if size text>1 andalso String.sub(text,0)= #"0" then raise Parse else ()
                         val number=valOf(IntInf.fromString text)
                     in go j(Value(Facts.JNum(Facts.Int_of_integer number))::acc)(count+1) end
                 else if Char.isAlpha c orelse c= #"_" then
                     let val j=span(fn x => Char.isAlphaNum x orelse x= #"_")i
                     in go j(keyword(String.substring(s,i,j-i))::acc)(count+1) end
                 else raise Parse
    in go 0 [] 0 end

  fun parse s =
    let
      fun primary depth ts = if depth>32 then raise Parse else
        case ts of
          Value v::rest => (Facts.JLit v,rest)
        | Minus::Value(Facts.JNum n)::rest =>
            (Facts.JLit(Facts.JNum(Facts.Int_of_integer(~(Facts.integer_of_int n)))),rest)
        | Plus::Value(Facts.JNum n)::rest => (Facts.JLit(Facts.JNum n),rest)
        | Typeof::rest => let val(e,tail)=primary(depth+1)rest in(Facts.JTypeof e,tail)end
        | Left::rest => (case equality(depth+1)rest of (e,Right::tail)=>(e,tail)|_=>raise Parse)
        | _ => raise Parse
      and additive depth ts =
        let val (first,rest)=primary depth ts
            fun more e (Plus::tail)=let val(f,last)=primary depth tail in more(Facts.JBin(Facts.JAdd,e,f))last end
              | more e (Minus::tail)=let val(f,last)=primary depth tail in more(Facts.JBin(Facts.JSub,e,f))last end
              | more e tail=(e,tail)
        in more first rest end
      and equality depth ts =
        let val (first,rest)=additive depth ts
            fun more e (Strict::tail)=let val(f,last)=additive depth tail in more(Facts.JBin(Facts.JStrict,e,f))last end
              | more e (Loose::tail)=let val(f,last)=additive depth tail in more(Facts.JBin(Facts.JLoose,e,f))last end
              | more e tail=(e,tail)
        in more first rest end
    in case equality 0(tokenize s) of(e,[])=>SOME e|_=>NONE end
    handle Parse=>NONE | Option=>NONE | Overflow=>NONE

  fun languageAnchor q =
    Option.isSome(Regex.search(Regex.compileI "\\b(?:javascript|js|typeof|NaN|null|undefined|DOM)\\b|===|Array\\.|Math\\.|parseInt|\\.push\\b|\\blet\\b.*\\bvar\\b|\\bvar\\b.*\\blet\\b")q)
  fun frame q =
    let val q=stripQuestion q
        val (lead,q)=dropPrefix ["In JavaScript, ","In JS, "] q
        val (ending,q)=dropSuffix [" in JavaScript"," in JS"] q
        val (_,q)=dropPrefix ["what is the result of ","what is the output of ","what does ","what is ","evaluate ","output of ","result of ","is "] q
        val (_,q)=dropSuffix [" evaluate to"," return"," true or false"," with no arguments"] q
        val (_,q)=dropSuffix [" return"] q
    in (lead orelse ending,q) end

  (* These existing table rows have no general checked model here. Exact,
     case-sensitive whole expressions retain their separately declared scope. *)
  val exactExpressions = [("typeof []",2),("typeof([])",2),
      ("0.1 + 0.2 === 0.3",6),("0.1 + 0.2 == 0.3",6),("0.1 + 0.2",7),
      ("Array.isArray([])",12),("Math.max()",13),("parseInt(\"3.7\")",14),("parseInt('3.7')",14)]
  fun compactOutsideStrings s =
    let fun go [] _ acc=String.implode(rev acc)
          | go(c::cs) NONE acc=if c= #"'" orelse c= #"\"" then go cs(SOME c)(c::acc)
                               else if Char.isSpace c then go cs NONE acc else go cs NONE(c::acc)
          | go(c::cs)(SOME q)acc=if c=q then go cs NONE(c::acc) else go cs(SOME q)(c::acc)
    in go(String.explode s)NONE[] end
  fun exact s =
    case List.find(fn(e,_)=>compactOutsideStrings e=compactOutsideStrings s)exactExpressions of
      SOME(_,i)=>SOME i|NONE=>NONE
  fun factRow q =
    let val forms = [(15,"^what does (?-i:(?:Array\\.prototype\\.)?push(?:\\(\\))?) return\\??$"),
      (16,"^(?:what is the difference between == and ===(?: in javascript)?|what is strict equality(?: in javascript)?)\\??$"),
      (17,"^what is the difference in scope between (?-i:let) and (?-i:var)\\??$"),
      (18,"^(?:what does dom stand for|what is the dom|what is the document object model)\\??$"),
      (19,"^who (?:created|invented|developed|made) javascript\\??$")]
    in case List.find(fn(_,p)=>Option.isSome(Regex.search(Regex.compileI p)(trim q)))forms of
      SOME(i,_)=>SOME i|NONE=>NONE end
  fun request pinned q =
    let val (explicit,expr)=frame q
    in case factRow q of SOME i=>TableRow i | NONE =>
         if not(pinned orelse explicit orelse languageAnchor q) then NotJS
         else (case parse expr of SOME e=>Expression e | NONE=>
           (case exact expr of SOME i=>TableRow i|NONE=>Rejected))
    end
end
