(* UNTRUSTED finite equation parser. Numeric atoms are parsed by ExactNumeric;
   this module only binds operators, parentheses and the single variable x.
   The HOL normalizer/checker owns all affine arithmetic and classification. *)
structure AffineParser =
struct
  exception Reject of string
  type rational = ExactNumeric.rational
  datatype expression = Const of rational | Var | Neg of expression
    | Add of expression * expression | Sub of expression * expression
    | Mul of expression * expression | Div of expression * expression
  datatype token = Number of rational | X | Plus | Minus | Times | Slash | LP | RP

  fun lower s = String.map Char.toLower s
  fun trim s = String.concatWith " " (String.tokens Char.isSpace s)
  fun reject s = raise Reject s
  fun digits n = size (IntInf.toString (IntInf.abs n))
  fun bounded (n,d) =
    if digits n <= 256 andalso digits d <= 256 then (n,d)
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
             else case c of
               #"x" => go(i+1)(X::acc)
             | #"+" => go(i+1)(Plus::acc)
             | #"-" => go(i+1)(Minus::acc)
             | #"*" => go(i+1)(Times::acc)
             | #"/" => go(i+1)(Slash::acc)
             | #"(" => go(i+1)(LP::acc)
             | #")" => go(i+1)(RP::acc)
             | _ => reject "Only x, exact numbers, +, -, *, / and parentheses are supported."
          end
    in go 0 [] end

  fun parseSide s =
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
                | more(a,tail as X::_) = let val(b,r)=unary d tail in more(node(Mul(a,b)),r) end
                | more(a,tail as LP::_) = let val(b,r)=unary d tail in more(node(Mul(a,b)),r) end
                | more pair=pair
          in more(first,rest) end
        and unary d ts = (depth d; case ts of
            Plus::tail => unary(d+1) tail
          | Minus::tail => let val(e,r)=unary(d+1) tail in (node(Neg e),r) end
          | Number q::tail => (node(Const q),tail)
          | X::tail => (node Var,tail)
          | LP::tail => (case sum(d+1) tail of
              (e,RP::rest)=>(e,rest) | _=>reject "A closing parenthesis is missing.")
          | _ => reject "An expression operand is missing.")
        val (e,rest)=sum 0 (lex s)
    in if null rest then e else reject "Unexpected trailing expression tokens." end

  fun limits e =
    case e of Const _ => (1,1) | Var => (1,1)
    | Neg x => let val(n,d)=limits x in(n+1,d+1)end
    | Add(x,y)=>pairLimits(x,y) | Sub(x,y)=>pairLimits(x,y)
    | Mul(x,y)=>pairLimits(x,y) | Div(x,y)=>pairLimits(x,y)
  and pairLimits(x,y)=let val(nx,dx)=limits x val(ny,dy)=limits y
                     in(nx+ny+1,Int.max(dx,dy)+1)end

  fun request text =
    let val q=trim(lower text)
        fun search pat = Regex.search(Regex.compile pat) q
        val prefix="^(?:solve(?: for x)?|find x(?: if| given| when)?|what is (?:the value of )?x(?: if| given| when)?)\\s*:?\\s*"
        val explicit=search prefix
        val body0=case explicit of SOME m=>String.extract(q,#stop m,NONE) | NONE=>q
        fun unpunct s = if size s>0 andalso Char.contains "?." (String.sub(s,size s-1))
                         then trim(String.substring(s,0,size s-1)) else s
        val body1=unpunct body0
        val body=if String.isSuffix " for x" body1 then trim(String.substring(body1,0,size body1-6)) else body1
        fun bareChar c = Char.isDigit c orelse Char.isSpace c orelse
          Char.contains "xyze.,+-*/^()=" c orelse Char.ord c>=128
        val complete = Option.isSome explicit orelse List.all bareChar (String.explode body)
    in if not complete orelse not(String.isSubstring "=" body) then NONE
       else if size body>8192 then reject "The equation text exceeds the input limit."
       else case String.fields(fn c=>c = #"=") body of
         [l,r] => let val left=parseSide l val right=parseSide r
                      val(nl,dl)=limits left val(nr,dr)=limits right
                  in if nl+nr>128 orelse Int.max(dl,dr)>32
                     then reject "The equation exceeds its syntax-tree resource limit."
                     else SOME(left,right) end
       | _ => reject "An equation must contain exactly one equals sign."
    end

  fun kernel e = case e of
      Const(n,d)=>Mathkernel.C(Mathkernel.mk_rat n d) | Var=>Mathkernel.V "x"
    | Neg x=>Mathkernel.Neg(kernel x)
    | Add(x,y)=>Mathkernel.Add(kernel x,kernel y)
    | Sub(x,y)=>Mathkernel.Sub(kernel x,kernel y)
    | Mul(x,y)=>Mathkernel.Mul(kernel x,kernel y)
    | Div(x,y)=>Mathkernel.Div(kernel x,kernel y)

  fun ratJson (n,d) = "{\"num\":" ^ Json.quote(ExactNumeric.canonical(n,1)) ^
    ",\"den\":" ^ Json.quote(ExactNumeric.canonical(d,1)) ^ "}"

  fun json e = case e of
      Const q=>"{\"op\":\"const\",\"value\":" ^ ratJson q ^ "}"
    | Var=>"{\"op\":\"var\",\"name\":\"x\"}"
    | Neg x=>"{\"op\":\"neg\",\"arg\":" ^ json x ^ "}"
    | Add(x,y)=>binary "add" (x,y) | Sub(x,y)=>binary "sub" (x,y)
    | Mul(x,y)=>binary "mul" (x,y) | Div(x,y)=>binary "div" (x,y)
  and binary name (x,y)="{\"op\":\"" ^ name ^ "\",\"left\":" ^ json x ^ ",\"right\":" ^ json y ^ "}"
end
