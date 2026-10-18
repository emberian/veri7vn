(* UNTRUSTED JSON framing. This accepts typed data, never executable text.
   Generated Codekernel.check_program alone decides example consistency. *)
structure Main = struct
  structure K = Codekernel
  exception Reject of string
  fun get fs key = case List.find (fn (k,_) => k=key) fs of
      SOME (_,v) => v | NONE => raise Reject ("missing " ^ key)
  fun array s =
    let val i=Json.ws s 0
        val _=if i<size s andalso String.sub(s,i)= #"[" then () else raise Reject "array expected"
        fun loop j acc = let val j=Json.ws s j in
          if String.sub(s,j)= #"]" then rev acc else
          let val k=Json.skip s j val raw=String.substring(s,j,k-j) val z=Json.ws s k
          in case String.sub(s,z) of
             #"," => loop (z+1) (raw::acc)
           | #"]" => rev(raw::acc) | _ => raise Reject "array delimiter" end end
    in loop(i+1) [] end
  fun integer s =
    if size s > 80 orelse size s=0 orelse
       not (List.all Char.isDigit (String.explode (if String.sub(s,0)= #"-" then String.extract(s,1,NONE) else s)))
    then raise Reject "bounded integer expected"
    else case IntInf.fromString (if String.sub(s,0)= #"-" then "~" ^ String.extract(s,1,NONE) else s) of
      SOME n=>n | NONE=>raise Reject "integer expected"
  fun nat s = let val n=integer s in if n<0 orelse n>1000 then raise Reject "bounded natural expected" else K.nat_of_integer n end
  fun value s = if s="true" then K.Truth true else if s="false" then K.Truth false
    else if size s>0 andalso String.sub(s,0)= #"[" then
      let val xs=array s in if length xs>256 then raise Reject "list limit" else K.mk_numbers(map integer xs) end
    else K.mk_number(integer s)
  fun source s = let val fs=Json.fields s val opn=Json.stringValue(get fs "op") in
    if opn="arg" then K.Argument(nat(get fs "index")) else
    let val b=case opn of "add"=>K.Plus | "subtract"=>K.Minus | "multiply"=>K.Times
      | "concat"=>K.Concat | "zip_add"=>K.ZipPlus | "zip_multiply"=>K.ZipTimes
      | _=>raise Reject "unknown base operation"
    in K.Combine(b,nat(get fs "left"),nat(get fs "right")) end end
  fun move s = let val fs=Json.fields s val opn=Json.stringValue(get fs "op")
      fun param () = K.int_of_integer(integer(get fs "constant"))
    in case opn of
      "reverse"=>K.Reverse | "sort"=>K.Ascending | "sort_desc"=>K.Descending | "unique"=>K.Unique
    | "square_each"=>K.SquareEach | "abs_each"=>K.AbsEach | "negate_each"=>K.NegateEach
    | "even_only"=>K.KeepEven | "odd_only"=>K.KeepOdd | "positive_only"=>K.KeepPositive | "negative_only"=>K.KeepNegative
    | "sum"=>K.Sum | "product"=>K.Product | "length"=>K.Length | "maximum"=>K.Maximum | "minimum"=>K.Minimum
    | "all_same"=>K.AllSame | "all_unique"=>K.AllUnique | "is_sorted"=>K.IsSorted
    | "absolute"=>K.Absolute | "square"=>K.Square | "cube"=>K.Cube | "negate"=>K.Negate
    | "is_even"=>K.IsEven | "is_odd"=>K.IsOdd
    | "add_each"=>K.AddEach(param()) | "multiply_each"=>K.MultiplyEach(param())
    | "above"=>K.Above(param()) | "below"=>K.Below(param())
    | "take"=>K.Take(nat(get fs "constant")) | "drop"=>K.Drop(nat(get fs "constant"))
    | _=>raise Reject "unknown move" end
  fun program s = let val fs=Json.fields s val ms=array(get fs "moves")
    in if length ms>4 then raise Reject "move limit" else K.Program(source(get fs "base"),map move ms) end
  fun example s = let val fs=Json.fields s val args=array(get fs "args")
    in if length args>4 then raise Reject "argument limit" else (map value args,value(get fs "expected")) end
  fun number n = let val s=IntInf.toString n in if String.isPrefix "~" s then "-" ^ String.extract(s,1,NONE) else s end
  fun output v = case K.number_value v of SOME n=>number n | NONE=>
    (case K.numbers_value v of SOME ns=>"[" ^ String.concatWith "," (map number ns) ^ "]" | NONE=>
      (case K.truth_value v of SOME true=>"true" | SOME false=>"false" | NONE=>raise Reject "invalid value"))
  fun answer line = let val fs=Json.fields line val p=program(get fs "program")
      val cs=array(get fs "examples") val _=if length cs>64 then raise Reject "example limit" else ()
      val cases=map example cs val accepted=K.check_program p cases
      val results=map (fn (args,_)=>case K.run p args of NONE=>"null" | SOME v=>output v) cases
    in "{\"accepted\":" ^ Bool.toString accepted ^ ",\"results\":[" ^ String.concatWith "," results ^ "]}" end
    handle e=>"{\"accepted\":false,\"error\":" ^ Json.quote(exnMessage e) ^ "}"
  fun loop ()=case TextIO.inputLine TextIO.stdIn of NONE=>() | SOME line=>
    (TextIO.output(TextIO.stdOut,answer line ^ "\n"); TextIO.flushOut TextIO.stdOut;loop())
end
val _=Main.loop()
