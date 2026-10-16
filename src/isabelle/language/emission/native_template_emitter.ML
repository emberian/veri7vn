(* OWNER-oriented kernel prototype: native target/premise XML is not a recipient
   projection and must never be published wholesale. Fixed proposition patterns,
   never a callback registry. Current-binding/input/destination checks are separate.
   Ordinary recipient math output uses native_refined_math_display instead. *)
signature VERI7VN_NATIVE_TEMPLATE_EMITTER =
sig
  type emission
  type output = {html: string, target: string, conditions: (IntInf.int * string * string) list}
  val prepare_math: Veri7vn_Native_Descriptor.descriptor ->
    Veri7vn_Native_Language_Input.reading -> emission
  val descriptor: emission -> Veri7vn_Native_Descriptor.descriptor
  val reading: emission -> Veri7vn_Native_Language_Input.reading
  val render: emission -> output
end;
structure Veri7vn_Native_Template_Emitter :> VERI7VN_NATIVE_TEMPLATE_EMITTER =
struct
  structure N = Veri7vn_Native_Descriptor;
  structure L = Veri7vn_Native_Literals;
  structure I = Veri7vn_Native_Language_Input;
  structure F = Veri7vn_Metadata_Frame;
  datatype emission = Emission of N.descriptor * I.reading;
  type output = {html: string, target: string, conditions: (IntInf.int * string * string) list};
  fun descriptor (Emission (d,_)) = d;
  fun reading (Emission (_,r)) = r;
  fun guard true _ = () | guard false msg = error msg;
  fun decimal n =
    let val s = if n<0 then "-" ^ string_of_int (~n) else string_of_int n;
    in guard (size s <= 4096) "Display integer digit bound"; s end;
  fun integer t =
    let val (T,n) = HOLogic.dest_number t;
    in guard (T = @{typ int}) "Display operand is not native int"; n end;
  fun typed_target d =
    let
      val p = N.project d;
      val _ = guard (N.is_live d) "Released native emission descriptor";
      val ct = the (N.resolve_target d (#target_id p));
      val t = Thm.term_of ct;
      val _ = guard (Term.size_of_term t <= 16384) "Display target size bound";
      val body = HOLogic.dest_Trueprop t;
    in case body of Const (name,_) $ template =>
      (guard (name = @{const_name template_meaning}) "No registered safe display pattern";
       (t,Term.strip_comb template))
      | _ => error "No registered safe native target" end;
  fun inspect d r =
    let
      val (operation,x,y,slices) = I.resolve r;
      val (_,shape) = typed_target d;
      fun check_pair a b expected =
        guard ((IntInf.fromInt a,IntInf.fromInt b)=expected)
          "Native display target differs from original interpretation";
      fun three code label constructor expected =
        (case shape of (Const (name,_),[ta,tb,tc]) =>
          let val a=integer ta; val b=integer tb; val c=integer tc;
              val _=guard (name=constructor) "Display operation mismatch";
              val _=check_pair a b expected;
          in ("The exact " ^ label ^ " of " ^ decimal a ^ " and " ^ decimal b ^
            " is " ^ decimal c ^ ".", (code,map IntInf.fromInt [a,b,c])) end
        | _ => error "Malformed integer display target");
      val sentence = (case operation of
          I.Sum => three 0 "sum" @{const_name ExactSum} (x,y)
        | I.Difference => three 1 "difference" @{const_name ExactDifference} (x,y)
        | I.SubtractFrom => three 1 "difference" @{const_name ExactDifference} (y,x)
        | I.Product => three 2 "product" @{const_name ExactProduct} (x,y)
        | I.Quotient => (case shape of (Const (name,_),[ta,tb,tp,tq]) =>
            let val a=integer ta; val b=integer tb; val p=integer tp; val q=integer tq;
                val _=guard (name= @{const_name ExactQuotient}) "Display operation mismatch";
                val _=check_pair a b (x,y);
                val _=guard (b<>0 andalso q>0) "Undefined or noncanonical quotient display";
            in ("The exact quotient of " ^ decimal a ^ " and " ^ decimal b ^
              " is " ^ decimal p ^ "/" ^ decimal q ^ ".", (3,map IntInf.fromInt [a,b,p,q])) end
          | _ => error "Malformed quotient display target"));
    in (#1 sentence,slices,#2 sentence) end;
  fun prepare_math d r = (inspect d r; Emission (d,r));
  fun bounded s = (guard (size s <= 65536) "Native display byte bound"; s);
  fun render (Emission (d,r)) =
    let
      val (sentence,slices,view) = inspect d r;
      val statement = (case F.checked_statement_bytes view sentence of SOME html=>html
        | NONE=>error "Native sentence did not reconstruct exact template");
      val projection = N.project d;
      val ids = #premises projection;
      val _ = guard (length ids <= 64) "Native display condition count bound";
      fun condition id =
        (case N.resolve_premise d id of SOME t =>
          (guard (Term.size_of_term t <= 16384) "Native condition size bound";
           (id,"premise",bounded (YXML.string_of_body (Term_XML.Encode.term t))))
        | NONE => (case N.resolve_sort d id of SOME sort =>
            (id,"sort",bounded (YXML.string_of_body (Term_XML.Encode.sort sort)))
          | NONE => error "Native condition association unavailable"));
      val conditions = map condition ids;
      val qualifier = if null ids then "" else
        "Conditional on all " ^ string_of_int (length ids) ^
        " attached native premises and sort constraints: ";
      val literal_html = map (fn s => "<code>" ^ F.escape_html_bytes (L.original s) ^ "</code>") slices;
      val html = bounded ("<section>" ^
        (if null ids then "" else "<p>" ^ F.escape_html_bytes qualifier ^ "</p>") ^
        statement ^ "<p>Original input literals: " ^ space_implode "; " literal_html ^ "</p></section>");
      val (target,_) = typed_target d;
      val target_xml = bounded (YXML.string_of_body (Term_XML.Encode.term target));
      val total = size html + size target_xml + fold (fn (_,_,s) => fn n => size s+n) conditions 0;
      val _ = guard (total <= 1048576 andalso N.is_live d) "Display total bound or released descriptor";
    in {html=html,target=target_xml,conditions=conditions} end;
end;
