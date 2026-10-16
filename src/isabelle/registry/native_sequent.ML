(* Inert native syntax for durable semantic comparison. No theorem deserializer. *)
signature VERI7VN_NATIVE_SEQUENT =
sig
  type snapshot
  type view = {target: term, proposition: term, hypotheses: term list,
    premises: term list, sorts: sort list, tpairs: (term * term) list}
  val capture: cterm -> thm -> snapshot
  val inspect: snapshot -> view
  val encode: snapshot -> string
  val decode: {max_bytes: int, max_depth: int, max_nodes: int} -> string -> snapshot
  val certify_target: Proof.context -> snapshot -> cterm
  val matches: snapshot -> cterm -> thm -> bool
end;
structure Veri7vn_Native_Sequent :> VERI7VN_NATIVE_SEQUENT =
struct
  type view = {target: term, proposition: term, hypotheses: term list,
    premises: term list, sorts: sort list, tpairs: (term * term) list};
  datatype snapshot = Snapshot of view;
  fun inspect (Snapshot view) = view;
  fun capture target th = Snapshot {target=Thm.term_of target,proposition=Thm.prop_of th,
    hypotheses=Thm.hyps_of th,premises=Thm.prems_of th,sorts=Thm.shyps_of th,
    tpairs=Thm.tpairs_of th};
  val encode_body = XML.Encode.pair Term_XML.Encode.term_raw
    (XML.Encode.pair Term_XML.Encode.term_raw
      (XML.Encode.pair (XML.Encode.list Term_XML.Encode.term_raw)
        (XML.Encode.pair (XML.Encode.list Term_XML.Encode.term_raw)
          (XML.Encode.pair (XML.Encode.list Term_XML.Encode.sort)
            (XML.Encode.list (XML.Encode.pair Term_XML.Encode.term_raw Term_XML.Encode.term_raw))))));
  val decode_body = XML.Decode.pair Term_XML.Decode.term_raw
    (XML.Decode.pair Term_XML.Decode.term_raw
      (XML.Decode.pair (XML.Decode.list Term_XML.Decode.term_raw)
        (XML.Decode.pair (XML.Decode.list Term_XML.Decode.term_raw)
          (XML.Decode.pair (XML.Decode.list Term_XML.Decode.sort)
            (XML.Decode.list (XML.Decode.pair Term_XML.Decode.term_raw Term_XML.Decode.term_raw))))));
  fun encode (Snapshot {target,proposition,hypotheses,premises,sorts,tpairs}) =
    YXML.string_of_body [XML.Elem (("veri7vn-native-sequent",[("version","1")]),
      encode_body (target,(proposition,(hypotheses,(premises,(sorts,tpairs))))))];
  (* Count framing before recursive XML/term decoding; no split/list allocation. *)
  fun framing {max_depth,max_nodes} bytes =
    let
      val n = size bytes;
      val _ = if max_depth > 0 andalso max_nodes > 0 then () else error "Native sequent framing bounds";
      val depth_limit=Int.min (max_depth,256);
      val node_limit=Int.min (max_nodes,100000);
      fun walk i depth nodes =
        if i>=n then if depth=0 then () else error "Native sequent unclosed framing"
        else if String.sub (bytes,i)=Char.chr 5 andalso i+1<n andalso
          String.sub (bytes,i+1)=Char.chr 6 then
          if i+2<n andalso String.sub (bytes,i+2)=Char.chr 5 then
            if depth>0 then walk (i+3) (depth-1) nodes else error "Native sequent closing framing"
          else if depth<depth_limit andalso nodes<node_limit then
            walk (i+2) (depth+1) (nodes+1)
          else error "Native sequent depth/node bound"
        else walk (i+1) depth nodes;
    in walk 0 0 0 end;
  fun decode {max_bytes,max_depth,max_nodes} bytes =
    if max_bytes<0 orelse size bytes > Int.min (max_bytes,1048576)
    then error "Native sequent byte bound"
    else (framing {max_depth=max_depth,max_nodes=max_nodes} bytes;
      case YXML.parse_body bytes of
        [XML.Elem (("veri7vn-native-sequent",[("version","1")]),body)] =>
          let val (target,(proposition,(hypotheses,(premises,(sorts,tpairs)))))=decode_body body
          in Snapshot {target=target,proposition=proposition,hypotheses=hypotheses,
            premises=premises,sorts=sorts,tpairs=tpairs} end
      | _ => error "Native sequent version/shape");
  fun certify_target ctxt (Snapshot {target,...}) = Thm.cterm_of ctxt target;
  fun matches (Snapshot saved) target th =
    let val fresh = inspect (capture target th)
    in #target saved aconv #target fresh andalso #proposition saved aconv #proposition fresh
      andalso eq_list (op aconv) (#hypotheses saved,#hypotheses fresh)
      andalso eq_list (op aconv) (#premises saved,#premises fresh)
      andalso #sorts saved = #sorts fresh
      andalso eq_list (fn ((a,b),(c,d)) => a aconv c andalso b aconv d) (#tpairs saved,#tpairs fresh)
    end;
end;
