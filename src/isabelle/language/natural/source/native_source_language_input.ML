(* Original-byte reading handles; a reading is interpretation evidence only.
   The source recipe, effect policy and current owner are separate native gates. *)
signature VERI7VN_NATIVE_SOURCE_LANGUAGE_INPUT =
sig
  datatype scope = Observed_Snapshot | Full_Source_Total
  type reading
  type status = {recognized:bool,over_budget:bool,key_required:bool,alternatives:int list}
  val inspect: Veri7vn_Native_Literals.input -> status
  val select: Veri7vn_Native_Literals.input -> int -> reading
  val owner: reading -> Veri7vn_Native_Literals.input
  val resolve: reading -> scope * Veri7vn_Native_Literals.slice
end;
structure Veri7vn_Native_Source_Language_Input :> VERI7VN_NATIVE_SOURCE_LANGUAGE_INPUT =
struct
  structure L=Veri7vn_Native_Literals;
  structure F=Veri7vn_Metadata_Frame;
  datatype scope = Observed_Snapshot | Full_Source_Total;
  datatype reading = Reading of L.input * int;
  type status = {recognized:bool,over_budget:bool,key_required:bool,alternatives:int list};
  fun packet input =
    let val raw=L.bytes input;
      val _=if size raw<=256 then () else error "Source-language input byte bound";
    in F.source_interpretation_packet_bytes raw end;
  fun inspect input = if size(L.bytes input)>256 then
      {recognized=false,over_budget=true,key_required=false,alternatives=[]}
    else let val (status,readings)=packet input in
      {recognized=status<>0,over_budget=status=1,key_required=status=2,
        alternatives=map_index (fn(i,_)=>i) readings} end;
  fun select input index =
    let val (status,readings)=packet input;
      val _=if status=3 andalso index>=0 andalso index<length readings then ()
        else error "Unresolved source interpretation";
    in Reading(input,index) end;
  fun owner (Reading(input,_))=input;
  fun resolve (Reading(input,index)) =
    let val (status,readings)=packet input;
      val _=if status=3 andalso index>=0 andalso index<length readings then ()
        else error "Source interpretation unavailable";
      val (scope,(start,stop))=nth readings index;
      val raw=L.bytes input;
      val _=if 0<=start andalso start<=stop andalso stop<=size raw then ()
        else error "Source key span outside original input";
      val literal=L.slice input {start=start,stop=stop,
        expected=String.substring(raw,start,stop-start)};
      val scope'=(case scope of 0=>Observed_Snapshot | 1=>Full_Source_Total
        | _=>error "Unknown native source scope");
    in (scope',literal) end;
end;
