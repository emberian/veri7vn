(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md) for the
   stores family: reads one JSON request per line on stdin ({"id", "q",
   "session"}), writes one JSON reply per line on stdout, flushes after each,
   exits on EOF.

   The stores are read through the fetch shim (src/extract/stores/fetch.py),
   which this binary starts as a child process and asks for rows over a pipe,
   one JSON line each way. The shim opens the sqlite stores read-only and keeps
   the warehouse sessions in a JSON file; it decides nothing. All reply content
   (status, kind, response, value) and the next session state come from the HOL
   kernel (Stores.nreply, Stores.site_reply); this file recognizes (Cook, Site),
   fetches, and frames.

   Usage: stores [--specialist ID] [--state PATH]
     ID: cooking, cooking-v2, cooking-v3, cooking-v3-r2, warehouse, warehouse-r2.
     Without it the family is asked in a fixed order: cooking-v3-r2, then
     warehouse-r2. --state is the warehouse session file (default
     var/stores/state/sessions.json under the repository). *)
structure Main =
struct
  structure S = Stores

  val organs = ["cooking", "cooking-v2", "cooking-v3", "cooking-v3-r2", "warehouse", "warehouse-r2"]

  fun die msg = (TextIO.output (TextIO.stdErr, msg ^ "\n"); OS.Process.exit OS.Process.failure)

  val (mode, statePath) =
    let
      fun parse args (m, st) =
        case args of
          [] => (m, st)
        | "--specialist" :: id :: rest =>
            if List.exists (fn x => x = id) organs then parse rest (id, st) else die ("unknown specialist " ^ id)
        | "--state" :: p :: rest => parse rest (m, p)
        | _ => die "usage: stores [--specialist ID] [--state PATH]"
    in parse (CommandLine.arguments ()) ("family", Config.repo ^ "/var/stores/state/sessions.json") end

  (* ---------- the fetch shim ---------- *)
  val shim : (TextIO.instream * TextIO.outstream) option ref = ref NONE
  fun ask (req : Js.v) : Js.v =
    let
      val (i, out) =
        case !shim of
          SOME x => x
        | NONE =>
            let
              val p : (TextIO.instream, TextIO.outstream) Unix.proc =
                Unix.execute ("/usr/bin/env", ["python3", "-I", Config.repo ^ "/src/extract/stores/fetch.py", "--state", statePath])
              val x = (Unix.textInstreamOf p, Unix.textOutstreamOf p)
            in shim := SOME x; x end
      val _ = TextIO.output (out, Js.write req ^ "\n")
      val _ = TextIO.flushOut out
    in
      case TextIO.inputLine i of
        SOME l => Js.parse l
      | NONE => raise Fail "fetch shim closed"
    end
  fun op' name args = ask (Js.Obj (("op", Js.Str name) :: args))
  fun complete r = Js.bool (Js.field r "complete") andalso Js.field r "error" = Js.Null
  fun rows r = Js.arr (Js.field r "rows")

  (* ---------- cooking ---------- *)
  val foodsCache : Cook.food vector option ref = ref NONE
  val foodsComplete = ref true
  fun foods () =
    case !foodsCache of
      SOME v => v
    | NONE =>
        let
          val r = op' "foods" []
          val v = Vector.fromList (map (fn Js.Arr [f, d] => Cook.mkFood (Js.int f, Js.str d)
                                          | _ => raise Fail "bad food row") (rows r))
        in foodsComplete := complete r; foodsCache := SOME v; v end

  fun cookQuery (rc : Cook.recog) : S.nquery =
    let
      val {nut, amount, phrase, hit, near} = rc
      val ok = ref (!foodsComplete)
      fun fd (f : Cook.food) = (S.mk_int (#fid f), #desc f)
      val (nrows, ports) =
        case hit of
          NONE => ([], [])
        | SOME f =>
            let
              val fids = List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else acc @ [x]) []
                           (#fid f :: map #fid near)
              val r = op' "nut" [("fdc", Js.Arr (map (Js.Num o IntInf.toString) fids)), ("key", Js.Str (S.nutrient_key nut))]
              val _ = if complete r then () else ok := false
              val nr = map (fn Js.Arr [a, b, c] => (S.mk_int (Js.int a), (Num.ratOf (Js.str b), Js.str c))
                             | _ => raise Fail "bad nut row") (rows r)
              val needP = case amount of S.A_measure _ => true | S.A_count _ => true | _ => false
              val ps =
                if not needP then []
                else
                  let val p = op' "portions" [("fdc", Js.Num (IntInf.toString (#fid f)))]
                  in (if complete p then () else ok := false);
                     map (fn Js.Arr [l, g] => (Js.str l, Num.ratOf (Js.str g)) | _ => raise Fail "bad portion row") (rows p)
                  end
            in (nr, ps) end
    in
      S.NQ (nut, amount, phrase, Option.map fd hit, map fd near, nrows, ports, !ok)
    end

  (* ---------- site ---------- *)
  (* "2026-09-28T12:00:00" -> seconds since 1970 (proleptic Gregorian, no zone) *)
  fun isoSeconds (s : string) : IntInf.int =
    let
      fun n a b = valOf (IntInf.fromString (String.substring (s, a, b)))
      val y = n 0 4 and m = n 5 2 and d = n 8 2 and hh = n 11 2 and mi = n 14 2 and ss = n 17 2
      val y' = if m <= 2 then y - 1 else y
      val era = (if y' >= 0 then y' else y' - 399) div 400
      val yoe = y' - era * 400
      val mp = (m + 9) mod 12
      val doy = (153 * mp + 2) div 5 + d - 1
      val doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
      val days = era * 146097 + doe - 719468
    in days * 86400 + hh * 3600 + mi * 60 + ss end

  val siteCache : (Site.tables * Js.v) option ref = ref NONE
  fun site () =
    case !siteCache of
      SOME x => x
    | NONE =>
        let
          val r = op' "site" []
          val its = map (fn Js.Arr [a, b] => (Js.str a, Js.str b) | _ => raise Fail "bad item") (Js.arr (Js.field r "items"))
          val zs = map (fn Js.Arr [a, b] => (Js.int a, Js.str b) | _ => raise Fail "bad zone") (Js.arr (Js.field r "zones"))
          val x = (Site.mkTables (its, zs), r)
        in siteCache := SOME x; x end

  fun stateOf (j : Js.v) : S.sstate =
    case j of
      Js.Obj _ =>
        let
          fun pair v = case v of Js.Arr [a, b] => SOME (Js.str a, Js.str b) | _ => NONE
          val pending = case Js.field j "pending" of
                          Js.Arr [n, a, b] => SOME (S.mk_nat (Js.int n), (Js.str a, Js.str b)) | _ => NONE
          val zone = case Js.field j "zone" of Js.Arr [a, b] => SOME (S.mk_int (Js.int a), Js.str b) | _ => NONE
          val kind = case Js.field j "kind" of Js.Str k => Site.skindOfKey k | _ => NONE
          val last = case Js.field j "last" of
                       Js.Str "item" => S.SL_item | Js.Str "sensor" => S.SL_sensor
                     | Js.Str "zone_status" => S.SL_zone_status | _ => S.SL_none
        in S.SState (pending, pair (Js.field j "item"), zone, kind, last) end
    | _ => S.s0

  fun intText (i : S.int) = IntInf.toString (S.integer_of_int i)
  fun natText (n : S.nat) = IntInf.toString (S.integer_of_nat n)

  fun stateJs (st : S.sstate) : Js.v =
    Js.Obj [("pending", case S.s_pending st of
                          SOME (n, (a, b)) => Js.Arr [Js.Num (natText n), Js.Str a, Js.Str b] | NONE => Js.Null),
            ("item", case S.s_item st of SOME (a, b) => Js.Arr [Js.Str a, Js.Str b] | NONE => Js.Null),
            ("zone", case S.s_zone st of SOME (z, n) => Js.Arr [Js.Num (intText z), Js.Str n] | NONE => Js.Null),
            ("kind", case S.s_kind st of SOME k => Js.Str (S.skind_key k) | NONE => Js.Null),
            ("last", Js.Str (case S.s_last st of S.SL_item => "item" | S.SL_sensor => "sensor"
                                               | S.SL_zone_status => "zone_status" | S.SL_none => "none"))]

  fun readings (rs : Js.v) = map (fn Js.Arr [t, v] => (S.mk_int (isoSeconds (Js.str t)), Num.ratOf (Js.str v))
                                   | _ => raise Fail "bad reading") (Js.arr rs)

  (* the rows the reading needs, all from unbounded queries *)
  fun evidence (st : S.sstate) (r : S.rintent) : S.sev =
    let
      val (_, meta) = site ()
      val now = isoSeconds (Js.str (Js.field meta "now"))
      val fresh = Js.int (Js.field meta "fresh")
      val ok = ref (complete meta)
      fun q name args = let val x = op' name args in (if complete x then () else ok := false); x end
      val events = ref [] and reorder = ref (0 : IntInf.int) and bin = ref NONE and next = ref NONE
      val sensor = ref NONE and zone = ref [] and items = ref [] and self = ref (S.mk_nat 0, (S.mk_nat 0, (S.mk_nat 0, [])))
      val wher = ref []
      fun getEvents sku =
        events := map (fn Js.Arr [t, d] => (S.mk_int (isoSeconds (Js.str t)), S.mk_int (Js.int d))
                        | _ => raise Fail "bad event") (rows (q "events" [("sku", Js.Str sku)]))
      fun getItem sku =
        case rows (q "item" [("sku", Js.Str sku)]) of
          [Js.Arr [rl, lab, pos, zn, zid]] => (reorder := Js.int rl; bin := SOME (Js.str lab, Js.str zn);
                                              SOME (Js.int pos, Js.int zid))
        | _ => (ok := false; NONE)
      val _ =
        case r of
          S.R_stock (sku, _) => (getEvents sku; ignore (getItem sku))
        | S.R_where (sku, _) => ignore (getItem sku)
        | S.R_runout (sku, _) => getEvents sku
        | S.R_reorder (_, SOME (sku, _), _) => getEvents sku
        | S.R_neighbour =>
            (case S.s_item st of
               SOME (sku, _) =>
                 (case getItem sku of
                    SOME (pos, zid) =>
                      next := SOME (case rows (q "next_bin" [("zone", Js.Num (IntInf.toString zid)),
                                                             ("pos", Js.Num (IntInf.toString (pos + 1)))]) of
                                      [Js.Arr [lab, its]] =>
                                        SOME (Js.str lab, map (fn Js.Arr [n, ds] => (Js.str n, map (S.mk_int o Js.int) (Js.arr ds))
                                                                | _ => raise Fail "bad bin item") (Js.arr its))
                                    | _ => NONE)
                  | NONE => ())
             | NONE => ())
        | S.R_sensor ((zid, _), k, _) =>
            (case rows (q "sensor" [("zone", Js.Num (intText zid)), ("kind", Js.Str (S.skind_key k))]) of
               Js.Arr [u, lo, hi, rs] :: _ => sensor := SOME ((Js.str u, (Num.ratOf (Js.str lo), Num.ratOf (Js.str hi))), readings rs)
             | _ => ())
        | S.R_zone_status (zid, _) =>
            zone := List.mapPartial (fn Js.Arr [k, u, lo, hi, rs] =>
                                         (case Site.skindOfKey (Js.str k) of
                                            SOME kk => SOME (kk, ((Js.str u, (Num.ratOf (Js.str lo), Num.ratOf (Js.str hi))), readings rs))
                                          | NONE => (ok := false; NONE))
                                      | _ => raise Fail "bad sensor row")
                                    (rows (q "zone_sensors" [("zone", Js.Num (intText zid))]))
        | S.R_low =>
            items := map (fn Js.Arr [n, rl, ds] => (Js.str n, (S.mk_int (Js.int rl), map (S.mk_int o Js.int) (Js.arr ds)))
                           | _ => raise Fail "bad item row") (rows (q "all_items" []))
        | S.R_self =>
            let val x = q "self" []
            in self := (S.mk_nat (Js.int (Js.field x "items")), (S.mk_nat (Js.int (Js.field x "zones")),
                        (S.mk_nat (Js.int (Js.field x "sensors")), map Js.str (Js.arr (Js.field x "kinds"))))) end
        | S.R_kind_only k => wher := map Js.str (rows (q "kind_zones" [("kind", Js.Str (S.skind_key k))]))
        | _ => ()
    in
      S.SEv (S.mk_int now, S.mk_int fresh, !events, S.mk_int (!reorder), !bin, !next, !sensor, !zone, !items, !self,
             !wher, !ok)
    end

  (* ---------- replies ---------- *)
  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val cookThms = "[\"nutrient_answer_sound\",\"nutrient_readings_agree\",\"nutrient_measure_portion\",\"nutrient_count_portion\",\"stated_within_tolerance\"]"
  val siteThms = "[\"confirm_requires_proposal\",\"sensor_fresh\",\"stock_value\",\"runout_days\",\"low_exact\"]"

  fun notTaken id t0 =
    "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
    ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"

  fun frame id t0 organ kernel thms (r : S.reply) extra =
    "{\"id\": " ^ id ^ ", \"status\": " ^ Js.quote (S.reply_status r)
    ^ ", \"response\": " ^ Js.quote (S.response r)
    ^ ", \"path\": " ^ Js.quote ("specialist:" ^ organ ^ ">" ^ S.reply_kind r)
    ^ ", \"kind\": " ^ Js.quote (S.reply_kind r)
    ^ (case S.stated r of SOME v => ", \"value\": " ^ v | NONE => "")
    ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Js.quote organ ^ ", \"specialist_ms\": " ^ ms t0
    ^ ", \"kernel\": " ^ Js.quote kernel ^ ", \"session\": \"Veri7vn_Stores\", \"theorems\": " ^ thms ^ extra ^ "}}"

  fun cooking organ id q t0 =
    case Cook.recognize organ foods q of
      NONE => NONE
    | SOME (rc, narrowed) =>
        let
          val nq = cookQuery rc
          val r = S.nreply nq
        in
          if narrowed andalso not (S.answered r) andalso not (Narrow.short_direct q) then NONE
          else SOME (frame id t0 organ "Stores.nreply" cookThms r
                       (case #hit rc of SOME f => ", \"fdc_id\": " ^ IntInf.toString (#fid f) | NONE => ""))
        end

  fun warehouse organ id q session t0 =
    let
      val (tb, meta) = site ()
      val st = stateOf (Js.field (op' "state_get" [("session", Js.Str session)]) "state")
      val i = Site.recognize tb st q
      val r = case i of S.I_read r => r | S.I_confirm (_, r) => r
      val ev = evidence st r
      val (rep, (st', out)) = S.site_reply st i ev
      val order = case S.ordered_of out of
                    SOME (n, (sku, _)) => Js.Obj [("ts", Js.field meta "now"), ("sku", Js.Str sku),
                                                  ("qty", Js.Num (natText n)), ("status", Js.Str "requested")]
                  | NONE => Js.Null
      val _ = op' "state_put" [("session", Js.Str session), ("state", stateJs st'), ("order", order)]
      val narrowedAway =
        organ = "warehouse-r2" andalso
        (case S.unknown_what out of
           SOME w => Rx.words w > 4 orelse not (Narrow.short_direct q)
         | NONE => false)
    in
      if not (S.site_taken out) orelse narrowedAway then NONE
      else SOME (frame id t0 organ "Stores.site_reply" siteThms rep "")
    end

  fun reply id q session =
    let
      val t0 = Time.now ()
      fun ask organ = if String.isPrefix "cooking" organ then cooking organ id q t0 else warehouse organ id q session t0
      val r = if mode = "family" then (case ask "cooking-v3-r2" of SOME x => SOME x | NONE => ask "warehouse-r2")
              else ask mode
    in case r of SOME x => x | NONE => notTaken id t0 end

  fun handle_line (line : string) : string =
    let
      val j = Js.parse line
      val id = Js.write (Js.field j "id")
    in
      (case Js.field j "q" of
         Js.Str q => reply id q (case Js.field j "session" of Js.Str s => s | _ => "default")
       | _ => "{\"id\": " ^ id ^ ", \"error\": \"request has no q\"}")
      handle e => "{\"id\": " ^ id ^ ", \"error\": " ^ Js.quote (exnMessage e) ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\"}"
    end
    handle e => "{\"id\": null, \"error\": " ^ Js.quote (exnMessage e) ^ "}"

  fun loop () =
    case TextIO.inputLine TextIO.stdIn of
      NONE => ()
    | SOME line =>
        (if List.all Char.isSpace (String.explode line) then ()
         else (TextIO.output (TextIO.stdOut, handle_line line ^ "\n"); TextIO.flushOut TextIO.stdOut);
         loop ())
end

val _ = Main.loop ()
