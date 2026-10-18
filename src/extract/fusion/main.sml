(* UNTRUSTED. JSON framing for the fusion planner. Reads one JSON object per
   line on stdin: typed givens, a typed goal, the context facts and the AGREE
   mode, as tools/fusion/answerer.py's recognizer produces them. Writes one JSON
   outcome per line, flushes, exits on EOF. Every decision comes from the HOL
   function Fusion.fdecide (src/extract/fusion/Fusion_Nodes.thy); this file only
   converts between JSON and the generated datatypes. The string decoder is
   lane D's / lane G's (src/extract/quantity/main.sml).

   Input line:
     {"id": ..., "mode": "pairwise" | "anchor",
      "goal": {"kind": "dim", "dim": [m,kg,s,A,K,$], "factor": "num/den", "op": false}
            | {"kind": "bool"} | {"kind": "count", "unit": "nights"},
      "givens": [{"v": "num/den", "dim": [...6 ints], "role": "duty", "marks": ["material","fuel","depth"]}],
      "ctx": {"object": "copper"|null, "substance": ..., "fluid": ..., "fuel": ...,
              "burn": bool, "asks_co2": bool, "spring": bool, "full_of": bool,
              "heat_mat": "water"|null, "melt": bool, "gasoline": bool}}
   Output line:
     {"id": ..., "outcome": "answer"|"disagree"|"noplan"|"budget"|"single"|"invalid",
      "value": "num/den" | "bool": true, "plan": [{"op","node","args"}], "pool": ["num/den", ...],
      "plans": [[...], ...], "given": i, "rule": r, "ms": "0.123"} *)
structure J =
struct
  (* ws, utf8, hex4, str, quote and exception Parse are the commons.sml Json ones (src/extract/commons). *)
  open Json
  datatype v = Obj of (string * v) list | Arr of v list | Str of string | Num of string | Bool of bool | Null

  fun value s i =
    let val i = ws s i
    in if i >= size s then raise Parse "unexpected end"
       else case String.sub (s, i) of
         #"{" => obj s (ws s (i + 1)) []
       | #"[" => arr s (ws s (i + 1)) []
       | #"\"" => let val (x, j) = str s i in (Str x, j) end
       | #"t" => (Bool true, i + 4)
       | #"f" => (Bool false, i + 5)
       | #"n" => (Null, i + 4)
       | _ =>
           let fun sc j = if j < size s andalso not (Char.contains ",}] \t\r\n" (String.sub (s, j)))
                          then sc (j + 1) else j
               val j = sc i
           in (Num (String.substring (s, i, j - i)), j) end
    end
  and obj s i acc =
    if String.sub (s, i) = #"}" then (Obj (rev acc), i + 1)
    else
      let
        val (k, j) = str s (ws s i)
        val j = ws s j
        val _ = if String.sub (s, j) = #":" then () else raise Parse "expected :"
        val (x, j) = value s (j + 1)
        val j = ws s j
      in
        case String.sub (s, j) of
          #"," => obj s (ws s (j + 1)) ((k, x) :: acc)
        | #"}" => (Obj (rev ((k, x) :: acc)), j + 1)
        | _ => raise Parse "expected , or }"
      end
  and arr s i acc =
    if String.sub (s, i) = #"]" then (Arr (rev acc), i + 1)
    else
      let
        val (x, j) = value s i
        val j = ws s j
      in
        case String.sub (s, j) of
          #"," => arr s (ws s (j + 1)) (x :: acc)
        | #"]" => (Arr (rev (x :: acc)), j + 1)
        | _ => raise Parse "expected , or ]"
      end

  fun parse s = #1 (value s 0)
  fun get (Obj kvs) k = (case List.find (fn (k', _) => k' = k) kvs of SOME (_, x) => x | NONE => Null)
    | get _ _ = Null
  fun raw (Str s) = "\"" ^ s ^ "\""
    | raw (Num n) = n
    | raw _ = "null"
end

structure Main =
struct
  exception Bad of string

  fun int_of (J.Num n) = (case IntInf.fromString n of SOME k => k | NONE => raise Bad ("not an integer: " ^ n))
    | int_of _ = raise Bad "expected an integer"

  fun rat_of (J.Str s) =
        (case String.fields (fn c => c = #"/") s of
           [a, b] => Fusion.fz_rat (int_of (J.Num a)) (int_of (J.Num b))
         | [a] => Fusion.fz_rat (int_of (J.Num a)) 1
         | _ => raise Bad ("not a fraction: " ^ s))
    | rat_of _ = raise Bad "expected a fraction string"

  fun bool_of (J.Bool b) = b
    | bool_of _ = false

  fun dim_of (J.Arr [a, b, c, d, e, f]) =
        Fusion.fz_dim (int_of a) (int_of b) (int_of c) (int_of d) (int_of e) (int_of f)
    | dim_of _ = raise Bad "dim needs six exponents"

  fun role_of (J.Str "") = NONE
    | role_of J.Null = NONE
    | role_of (J.Str r) =
        SOME (case r of
                "delta" => Fusion.Ro_delta
              | "duty" => Fusion.Ro_duty
              | "derived" => Fusion.Ro_derived
              | "co2" => Fusion.Ro_co2
              | "temp" => Fusion.Ro_temp
              | "earth_mass" => Fusion.Ro_earth_mass
              | "earth_radius" => Fusion.Ro_earth_radius
              | _ => if String.isPrefix "per_unit_" r then Fusion.Ro_per_unit (String.extract (r, 9, NONE))
                     else Fusion.Ro_tag r)
    | role_of _ = raise Bad "bad role"

  fun mark_of (J.Str "material") = Fusion.Of_material
    | mark_of (J.Str "fuel") = Fusion.Of_fuel
    | mark_of (J.Str "depth") = Fusion.Depth_of
    | mark_of _ = raise Bad "bad mark"

  fun list_of (J.Arr xs) = xs
    | list_of J.Null = []
    | list_of _ = raise Bad "expected an array"

  fun given i g =
    Fusion.fz_q (rat_of (J.get g "v")) (dim_of (J.get g "dim")) (role_of (J.get g "role"))
      (IntInf.fromInt i) (map mark_of (list_of (J.get g "marks")))

  fun material (J.Str s) = (case Fusion.v3_material s of SOME m => SOME m | NONE => raise Bad ("unknown material " ^ s))
    | material _ = NONE
  fun fuel (J.Str s) = (case Fusion.v3_fuel s of SOME f => SOME f | NONE => raise Bad ("unknown fuel " ^ s))
    | fuel _ = NONE

  fun str_opt (J.Str s) = SOME s
    | str_opt _ = NONE

  fun ctx_of c =
    Fusion.fz_ctx (material (J.get c "object")) (material (J.get c "substance")) (material (J.get c "fluid"))
      (fuel (J.get c "fuel")) (bool_of (J.get c "burn")) (bool_of (J.get c "asks_co2"))
      (bool_of (J.get c "spring")) (bool_of (J.get c "full_of"))
      (str_opt (J.get c "heat_mat")) (bool_of (J.get c "melt")) (bool_of (J.get c "gasoline"))

  fun goal_of g =
    case J.get g "kind" of
      J.Str "dim" => Fusion.GDim (dim_of (J.get g "dim"), rat_of (J.get g "factor"), bool_of (J.get g "op"))
    | J.Str "bool" => Fusion.GBool
    | J.Str "count" => (case J.get g "unit" of J.Str u => Fusion.GCount u | _ => raise Bad "count needs unit")
    | _ => raise Bad "bad goal"

  fun istr k = String.map (fn #"~" => #"-" | c => c) (IntInf.toString k)
  fun nstr n = istr (Fusion.integer_of_nat n)
  fun rstr q = let val (a, b) = Fusion.fz_num q in J.quote (istr a ^ "/" ^ istr b) end

  fun arg_json (Fusion.Pool k) = "[" ^ nstr k ^ "]"
    | arg_json (Fusion.Derive (i, j)) = "[" ^ nstr i ^ ", " ^ nstr j ^ "]"

  fun step_json (Fusion.Step (f, args)) =
    "{\"op\": " ^ J.quote (Fusion.fop_name f) ^ ", \"node\": " ^ J.quote (Fusion.fz_node f)
    ^ ", \"args\": [" ^ String.concatWith ", " (map arg_json args) ^ "]}"

  fun plan_json pl = "[" ^ String.concatWith ", " (map step_json pl) ^ "]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  fun decide_line (req : J.v) : string =
    let
      val t0 = Time.now ()
      val mode = case J.get req "mode" of J.Str "anchor" => Fusion.Anchor | _ => Fusion.Pairwise
      val goal = goal_of (J.get req "goal")
      val gs = list_of (J.get req "givens")
      val pool = ListPair.map (fn (i, g) => given i g) (List.tabulate (length gs, fn i => i), gs)
      val c = ctx_of (J.get req "ctx")
      val d = Fusion.fdecide mode goal c pool
      val body =
        case d of
          Fusion.Answer (fv, pl) =>
            "\"outcome\": \"answer\", "
            ^ (case fv of Fusion.FVal q => "\"value\": " ^ rstr q | Fusion.FBool b => "\"bool\": " ^ Bool.toString b)
            ^ ", \"plan\": " ^ plan_json pl
            ^ ", \"pool\": [" ^ String.concatWith ", " (map rstr (Fusion.fz_trace c pool pl)) ^ "]"
        | Fusion.Disagree pls =>
            "\"outcome\": \"disagree\", \"plans\": [" ^ String.concatWith ", " (map plan_json pls) ^ "]"
            ^ ", \"values\": [" ^ String.concatWith ", "
                (map (fn pl => case rev (Fusion.fz_trace c pool pl) of q :: _ => rstr q | [] => "null") pls) ^ "]"
        | Fusion.NoPlan => "\"outcome\": \"noplan\""
        | Fusion.BudgetExceeded => "\"outcome\": \"budget\""
        | Fusion.SingleConversion => "\"outcome\": \"single\""
        | Fusion.Invalid (i, r) => "\"outcome\": \"invalid\", \"given\": " ^ nstr i ^ ", \"rule\": " ^ nstr r
    in
      "{\"id\": " ^ J.raw (J.get req "id") ^ ", " ^ body ^ ", \"ms\": \"" ^ ms t0 ^ "\"}"
    end

  fun handle_line (line : string) : string =
    let val req = J.parse line
    in decide_line req
       handle e => "{\"id\": " ^ J.raw (J.get req "id") ^ ", \"error\": " ^ J.quote (exnMessage e) ^ "}"
    end
    handle e => "{\"id\": null, \"error\": " ^ J.quote (exnMessage e) ^ "}"

  fun loop () =
    case TextIO.inputLine TextIO.stdIn of
      NONE => ()
    | SOME line =>
        (if List.all Char.isSpace (String.explode line) then ()
         else (TextIO.output (TextIO.stdOut, handle_line line ^ "\n"); TextIO.flushOut TextIO.stdOut);
         loop ())

  val _ = if Fusion.fz_self_test then () else (TextIO.output (TextIO.stdErr, "fusion self test failed\n"); OS.Process.exit OS.Process.failure)
end

val _ = Main.loop ()
