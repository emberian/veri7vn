theory Native_State_Owner_Tests
  imports Veri7vn_Runtime_Service.Native_Service
begin
ML \<open>
local
  structure F=Veri7vn_Metadata_Frame;
  datatype input=Cancel | Unsupported;
  structure Owner=Veri7vn_Native_State_Owner(struct
    type event=input
    fun is_live _=true
    fun event_frame _ _=F.lifecycle_frame(F.Cancel 42)
    fun supports Cancel [F.StopRequest 42]=true | supports _ _=false
    fun recovery_view _=F.NoAssociation
  end);
  fun require true _=() | require false message=error message;
  val first=Owner.prepare Cancel;
  val _=require(Owner.valid first) "Fresh candidate invalid";
  val rejected=Exn.capture Owner.prepare Unsupported;
  val _=require(Exn.is_exn rejected) "Unsupported handoff admitted";
  val _=require(not(Owner.valid first)) "Rejected event left old candidate valid";
  val _=require(Owner.current_epoch()=0) "Unsupported handoff installed authority";
  val second=Owner.prepare Cancel;
  val _=ignore(Owner.acknowledge second);
  val _=require(Owner.current_epoch()=1) "Acknowledged lifecycle not installed";
  val _=require(not(Owner.valid second)) "Acknowledged candidate reusable";
  val repeated=Exn.capture Owner.acknowledge second;
  val _=require(Exn.is_exn repeated andalso Owner.current_epoch()=1)
    "Duplicate acknowledgement changed authority";
  val staged=Owner.prepare Cancel;
  val _=Owner.invalidate();
  val _=require(not(Owner.valid staged)) "Association invalidation retained candidate";
in val _=writeln "Native state owner transition/handoff checks passed" end;
\<close>
end
