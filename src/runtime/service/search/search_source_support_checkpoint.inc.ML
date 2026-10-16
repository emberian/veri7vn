(* Insert inside Veri7vn_Search_Request_Checkpoint after decoded/stop helpers.
   Called ONLY with canonical SearchCodec.verify data, before pool acquisition. *)
fun source_matches committed(p:projection)(n:names)({execution,stopped,reason}:phase)=
  let val i= #identity p;
    val values=[#request i,#goal i,#slot i,#interpretation i,#decision i,#receiver p,#input p,
      #capability n,#operation n,#profile n,#step n,#template n,#claim n,#parameter n,#execution n,#code n,
      #evidence n,#output n,#batch n,#exhausted n,#budget n,#deadline n,#cancelled n,#failed n];
    val control= @{code search_service_control}(map nat values);
    val deps=distinct(op =)[#parameter n,#capability n,#operation n,#profile n,#code n,#template n,
      #input p,#receiver p,#interpretation i,#decision i];
    val names_ok=forall(fn id=>id>0 andalso size(IntInf.toString id)<=128)values andalso
      length(distinct(op =)values)=length values andalso #context p= #receiver p andalso #worker p= #receiver p;
    val phase_ok=(case execution of NONE=>true|SOME id=>id= #execution n)andalso
      (case(stopped,reason)of(NONE,NONE)=>true|(SOME kind,SOME id)=>is_some execution andalso
        id=(case kind of "exhausted"=> #exhausted n|"budget"=> #budget n|"deadline"=> #deadline n|
          "cancelled"=> #cancelled n|"failed"=> #failed n|_=>0)|_=>false)
  in names_ok andalso phase_ok andalso(case decoded committed of NONE=>false|SOME state=>
    @{code search_service_source_matches}state control(map nat deps)(nat(#cost p))(is_some execution))end;
