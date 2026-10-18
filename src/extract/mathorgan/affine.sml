(* UNTRUSTED finite equation parser. Numeric atoms are parsed by ExactNumeric;
   this module only binds operators, parentheses and the single variable x.
   The HOL normalizer/checker owns all affine arithmetic and classification. *)
structure AffineParser =
struct
  exception Reject of string
  type rational = ExactNumeric.rational
  datatype expression = Const of rational | Var of string | Neg of expression
    | Add of expression * expression | Sub of expression * expression
    | Mul of expression * expression | Div of expression * expression | Pow of expression * int
  datatype token = Number of rational | Name of string | Plus | Minus | Times | Slash | LP | RP | Power

  fun lower s = String.map Char.toLower s
  fun trim s = String.concatWith " " (String.tokens Char.isSpace s)
  fun reject s = raise Reject s
  (* A finite task preface, only before a supported imperative. The original
     request text remains untouched in the reply binding. No inner span search. *)
  fun commandText text =
    let val q=trim(lower text)
        val courtesy=Regex.compile "^(?:please\\s+|(?:can|could|would)\\s+you\\s+(?:please\\s+)?)(?=(?:solve|find|calculate|compute|evaluate)\\b)"
    in case Regex.search courtesy q of SOME m=>String.extract(q,#stop m,NONE) | NONE=>q end
  fun digits n = size (IntInf.toString (IntInf.abs n))
  fun bounded (n,d) =
    if size(ExactNumeric.canonical(n,1)) <= 256 andalso digits d <= 256 then (n,d)
    else reject "An exact coefficient exceeds the 256-digit component limit."
  fun numeric s = case ExactNumeric.parse s of
      SOME value => bounded value
    | NONE => reject "Malformed exact numeric literal."

  fun lex s =
    let val n = size s
        fun numEnd j =
          if j >= n then j else
          let val c = String.sub(s,j)
          in if Char.isDigit c orelse Char.contains ".,eE" c then numEnd (j+1)
             else if Char.contains "+-" c andalso j>0 andalso
                     Char.contains "eE" (String.sub(s,j-1)) then numEnd(j+1)
             else j end
        fun go i acc =
          if i>=n then rev acc else
          let val c=String.sub(s,i)
          in if Char.isSpace c then go(i+1) acc
             else if Char.isDigit c orelse c = #"." then
               let val j=numEnd i
               in go j (Number(numeric(String.substring(s,i,j-i)))::acc) end
             else if i+3<=n andalso String.substring(s,i,3)="\226\136\146"
                  then go(i+3)(Minus::acc)
             else if c >= #"a" andalso c <= #"z" then go(i+1)(Name(String.str c)::acc)
             else case c of
               #"+" => go(i+1)(Plus::acc)
             | #"-" => go(i+1)(Minus::acc)
             | #"*" => go(i+1)(Times::acc)
             | #"/" => go(i+1)(Slash::acc)
             | #"^" => go(i+1)(Power::acc)
             | #"(" => go(i+1)(LP::acc)
             | #")" => go(i+1)(RP::acc)
             | _ => reject "Only single-letter variables, exact numbers, +, -, *, / and parentheses are supported."
          end
    in go 0 [] end

  fun parseExpression allowPowers s =
    let val nodes=ref 0
        fun node e = (nodes := !nodes+1;
          if !nodes>128 then reject "The equation exceeds the 128-node limit." else e)
        fun depth d = if d>32 then reject "The equation exceeds the 32-level limit." else ()
        fun sum d ts =
          let val (first,rest)=product d ts
              fun more (a,Plus::tail) = let val(b,r)=product d tail in more(node(Add(a,b)),r) end
                | more(a,Minus::tail) = let val(b,r)=product d tail in more(node(Sub(a,b)),r) end
                | more pair=pair
          in more(first,rest) end
        and product d ts =
          let val(first,rest)=unary d ts
              fun more(a,Times::tail) = let val(b,r)=unary d tail in more(node(Mul(a,b)),r) end
                | more(a,Slash::tail) = let val(b,r)=unary d tail in more(node(Div(a,b)),r) end
                | more(a,tail as Name _::_) = let val(b,r)=unary d tail in more(node(Mul(a,b)),r) end
                | more(a,tail as LP::_) = let val(b,r)=unary d tail in more(node(Mul(a,b)),r) end
                | more pair=pair
          in more(first,rest) end
        and unary d ts = (depth d; case ts of
            Plus::tail => unary(d+1) tail
          | Minus::tail => let val(e,r)=unary(d+1) tail in (node(Neg e),r) end
          | _ => power d ts)
        and power d ts =
          let val(e,rest)=atom d ts
          in case rest of
            Power::Number(n,den)::tail =>
              if allowPowers andalso den=1 andalso (n=2 orelse n=3)
              then (node(Pow(e,IntInf.toInt n)),tail)
              else reject "Only square and cube powers are supported in closed expressions."
          | Power::_ => reject "A power must be an explicit exponent 2 or 3."
          | _ => (e,rest) end
        and atom d ts = (depth d; case ts of
            Number q::tail => (node(Const q),tail)
          | Name name::tail => (node(Var name),tail)
          | LP::tail => (case sum(d+1) tail of
              (e,RP::rest)=>(e,rest) | _=>reject "A closing parenthesis is missing.")
          | _ => reject "An expression operand is missing.")
        val (e,rest)=sum 0 (lex s)
    in if null rest then e else reject "Unexpected trailing expression tokens." end

  fun parseSide s = parseExpression false s

  fun limits e =
    case e of Const _ => (1,1) | Var _ => (1,1)
    | Neg x => let val(n,d)=limits x in(n+1,d+1)end
    | Pow(x,_) => let val(n,d)=limits x in(n+1,d+1)end
    | Add(x,y)=>pairLimits(x,y) | Sub(x,y)=>pairLimits(x,y)
    | Mul(x,y)=>pairLimits(x,y) | Div(x,y)=>pairLimits(x,y)
  and pairLimits(x,y)=let val(nx,dx)=limits x val(ny,dy)=limits y
                     in(nx+ny+1,Int.max(dx,dy)+1)end

  fun names e =
    let fun merge xs ys = List.foldl (fn (v,acc)=>if List.exists(fn w=>v=w)acc then acc else v::acc) xs ys
    in case e of Const _=>[] | Var v=>[v] | Neg x=>names x | Pow(x,_)=>names x
      | Add(x,y)=>merge(names x)(names y) | Sub(x,y)=>merge(names x)(names y)
      | Mul(x,y)=>merge(names x)(names y) | Div(x,y)=>merge(names x)(names y)
    end

  fun bareSurface s =
    List.all (fn c=>Char.isDigit c orelse Char.isSpace c orelse
      (c >= #"a" andalso c <= #"z") orelse Char.contains ".,+-*/^()=" c orelse Char.ord c>=128) (String.explode s)
    andalso not(Option.isSome(Regex.search(Regex.compile "[a-z]{2,}")s))

  fun request text =
    let val q=commandText text
        fun search pat = Regex.search(Regex.compile pat) q
        val prefix="^(?:solve(?:\\s+for\\s+([a-z])\\b)?|find\\s+([a-z])\\b(?=\\s*(?:(?:if|given|when)\\b|[:0-9(.+*/-]|[a-z](?![a-z])))(?: if| given| when)?|what is (?:the value of )?([a-z])\\b(?=\\s*(?:(?:if|given|when)\\b|[:0-9(.+*/-]|[a-z](?![a-z])))(?: if| given| when)?)\\s*:?\\s*"
        val explicit=search prefix
        fun group source m i = case Regex.group source m i of SOME ""=>NONE | x=>x
        val target0=case explicit of NONE=>NONE | SOME m=>
          List.find (fn x=>Option.isSome x) (map (group q m) [1,2,3])
        val prefixTarget=case target0 of SOME x=>x | NONE=>NONE
        val body0=case explicit of SOME m=>String.extract(q,#stop m,NONE) | NONE=>q
        fun unpunct s = if size s>0 andalso Char.contains "?." (String.sub(s,size s-1))
                         then trim(String.substring(s,0,size s-1)) else s
        val body1=unpunct body0
        val suffix=Regex.search(Regex.compile "\\s+for\\s+([a-z])$")body1
        val suffixTarget=case suffix of SOME m=>group body1 m 1 | NONE=>NONE
        val body=case suffix of SOME m=>trim(String.substring(body1,0,#start m)) | NONE=>body1
        val complete=Option.isSome explicit orelse bareSurface body
    in if not complete orelse not(String.isSubstring "=" body) then NONE
       else if size body>8192 then reject "The equation text exceeds the input limit."
       else case String.fields(fn c=>c = #"=") body of
         [l,r] => let val left=parseSide l val right=parseSide r
                      val(nl,dl)=limits left val(nr,dr)=limits right
                      val allNames=names(Add(left,right))
                      val target=case (prefixTarget,suffixTarget) of
                          (SOME a,SOME b)=>if a=b then SOME a else reject "The requested variable names conflict."
                        | (SOME a,_)=>SOME a | (_,SOME b)=>SOME b | _=>NONE
                      val chosen=case target of SOME v=>v | NONE=>
                        (case allNames of []=>"x" | [v]=>v | _=>reject "Only one unknown variable is supported.")
                      val _=if List.all(fn v=>v=chosen)allNames then ()
                            else reject "The equation contains a different unknown from the requested variable."
                  in if nl+nr>128 orelse Int.max(dl,dr)>32
                     then reject "The equation exceeds its syntax-tree resource limit."
                     else SOME(chosen,left,right) end
       | _ => reject "An equation must contain exactly one equals sign."
    end

  (* Conservative bit-growth bound, checked BEFORE exact evaluation. A decimal
     digit needs fewer than four bits. The sum bounds numerator/denominator
     growth even without rational reduction; nested powers multiply it. *)
  fun closedWork e =
    let fun cap n = if n>8192 then reject "The expression exceeds the arithmetic work limit." else n
        fun both x y extra = cap(closedWork x + closedWork y + extra)
    in case e of Const(n,d)=>cap(4*Int.max(digits n,digits d))
      | Var _=>reject "A closed expression cannot contain an unbound variable."
      | Neg x=>closedWork x
      | Add(x,y)=>both x y 1 | Sub(x,y)=>both x y 1
      | Mul(x,y)=>both x y 0 | Div(x,y)=>both x y 0
      | Pow(x,n)=>cap(n*closedWork x)
    end

  fun closedRequest text =
    let val q=commandText text
        fun search pat = Regex.search(Regex.compile pat) q
        val prefix=search "^(?:what is|calculate|compute|evaluate)\\s*:?\\s+"
        val strong=Option.isSome(search "^(?:calculate|compute|evaluate)\\b")
        val body0=case prefix of SOME m=>String.extract(q,#stop m,NONE) | NONE=>q
        val body=if size body0>0 andalso Char.contains "?." (String.sub(body0,size body0-1))
                 then trim(String.substring(body0,0,size body0-1)) else body0
        val (base,power)=if String.isSuffix " squared" body then
              (trim(String.substring(body,0,size body-8)),SOME 2)
            else if String.isSuffix " cubed" body then
              (trim(String.substring(body,0,size body-6)),SOME 3)
            else (body,NONE)
        fun mathChar c = Char.isDigit c orelse Char.isSpace c orelse
              Char.contains "xe.,+-*/^()" c orelse Char.ord c>=128
        val startsMath=size base>0 andalso
          (Char.isDigit(String.sub(base,0)) orelse Char.contains "(.+-" (String.sub(base,0))
           orelse (Char.isAlpha(String.sub(base,0)) andalso (size base=1 orelse not(Char.isAlpha(String.sub(base,1)))))
           orelse Char.ord(String.sub(base,0))>=128)
        val finite=bareSurface base
        val powerCue=String.isSubstring " squared" body orelse String.isSubstring " cubed" body
    in if String.isSubstring "=" body orelse not startsMath orelse
          not(finite orelse strong orelse powerCue) then NONE
       else if size base>8192 then reject "The expression text exceeds its input limit."
       else let val e0=parseExpression true base
                val e=case power of NONE=>e0 | SOME n=>Pow(e0,n)
                val(nodes,depth)=limits e
                val _=if nodes<=128 andalso depth<=32 then ()
                      else reject "The expression exceeds its syntax-tree resource limit."
                val _=closedWork e
            in SOME e end
    end

  fun kernel e = case e of
      Const(n,d)=>Mathkernel.C(Mathkernel.mk_rat n d) | Var name=>Mathkernel.V name
    | Neg x=>Mathkernel.Neg(kernel x)
    | Pow(x,n)=>Mathkernel.Pow(kernel x,Mathkernel.Int_of_integer(IntInf.fromInt n))
    | Add(x,y)=>Mathkernel.Add(kernel x,kernel y)
    | Sub(x,y)=>Mathkernel.Sub(kernel x,kernel y)
    | Mul(x,y)=>Mathkernel.Mul(kernel x,kernel y)
    | Div(x,y)=>Mathkernel.Div(kernel x,kernel y)

  fun ratJson (n,d) = "{\"num\":" ^ Json.quote(ExactNumeric.canonical(n,1)) ^
    ",\"den\":" ^ Json.quote(ExactNumeric.canonical(d,1)) ^ "}"

  fun json e = case e of
      Const q=>"{\"op\":\"const\",\"value\":" ^ ratJson q ^ "}"
    | Var name=>"{\"op\":\"var\",\"name\":" ^ Json.quote name ^ "}"
    | Neg x=>"{\"op\":\"neg\",\"arg\":" ^ json x ^ "}"
    | Pow(x,n)=>"{\"op\":\"pow\",\"base\":" ^ json x ^ ",\"exponent\":" ^ Int.toString n ^ "}"
    | Add(x,y)=>binary "add" (x,y) | Sub(x,y)=>binary "sub" (x,y)
    | Mul(x,y)=>binary "mul" (x,y) | Div(x,y)=>binary "div" (x,y)
  and binary name (x,y)="{\"op\":\"" ^ name ^ "\",\"left\":" ^ json x ^ ",\"right\":" ^ json y ^ "}"
end
