theory Native_State_Owner_Tests
  imports Veri7vn_Runtime_Service.Native_Service
begin
definition retirement_fixture_value :: "nat \<Rightarrow> nat list \<Rightarrow> retained_value" where
  "retirement_fixture_value key deps = \<lparr>retained_id=key,retained_owner=WorkspaceShared,
    retained_dependencies=deps,retained_read_dependencies=[],retained_access_requirements=[],retained_payload=key\<rparr>"
lemma retirement_validates_full_record_in_duplicate_bucket:
  "service_recorded_support_groups
    (initial_state\<lparr>retained_values := [retirement_fixture_value 10 [99],retirement_fixture_value 10 [11]]\<rparr>)
    [[RegisterManaged (retirement_fixture_value 10 [11])],
      [RegisterManaged (retirement_fixture_value 10 [88])]] = [[10],[]]"
  by eval
lemma retirement_protects_external_through_inaccessible_duplicate:
  "service_forget_support_event
    (initial_state\<lparr>revoked_objects:=[20],retained_values:=[
      retirement_fixture_value 10 [11],retirement_fixture_value 11 [10],
      retirement_fixture_value 20 [999],retirement_fixture_value 20 [10],
      retirement_fixture_value 30 [20],
      retirement_fixture_value 40 [41],retirement_fixture_value 41 [40]]\<rparr>)
    1 [[10,11],[40,41]] = Some (ForgetRoots [1,40,41])"
  by eval

definition retirement_fixture_request :: request where
  "retirement_fixture_request = (case service_math_reserve
    (service_math_names 100 101 102 103 104 105 106 107 108 109 110 111 112 113) 0 1 [] of
    ReserveRequest r slots \<Rightarrow> r\<lparr>request_goals := map (\<lambda>g.
      g\<lparr>goal_required := (goal_required g)\<lparr>dependencies := [10]\<rparr>\<rparr>) (request_goals r)\<rparr>
    | _ \<Rightarrow> undefined)"
lemma retirement_protects_original_goal_only_reference:
  "service_forget_support_event
    (initial_state\<lparr>requests:=[retirement_fixture_request],retained_values:=[
      retirement_fixture_value 10 [11],retirement_fixture_value 11 [10],
      retirement_fixture_value 40 [41],retirement_fixture_value 41 [40]]\<rparr>)
    1 [[10,11],[40,41]] = Some (ForgetRoots [1,40,41])"
  by eval

definition retirement_fixture_unused_evidence :: evidence where
  "retirement_fixture_unused_evidence = (let c = service_math_requirement
    (service_math_names 100 101 102 103 104 105 106 107 108 109 110 111 112 113) [10]
    in \<lparr>evidence_id=200,evidence_claim=c,evidence_route=KernelConsequence,
      evidence_managed_dependencies=200 # service_claim_references c\<rparr>)"
lemma retirement_protects_accessible_unused_evidence:
  "service_forget_support_event
    (initial_state\<lparr>evidence_table:=[retirement_fixture_unused_evidence],retained_values:=[
      retirement_fixture_value 10 [11],retirement_fixture_value 11 [10],
      retirement_fixture_value 40 [41],retirement_fixture_value 41 [40]]\<rparr>)
    1 [[10,11],[40,41]] = Some (ForgetRoots [1,40,41])"
  by eval

ML \<open>
local
  structure F=Veri7vn_Metadata_Frame;
  datatype input=Cancel | Unsupported;
  structure Owner=Veri7vn_Native_State_Owner(struct
    type event=input
    fun is_live _=true
    fun event_frame _ _=F.lifecycle_frame(F.Cancel 42)
    fun retirement_registrations _=[]
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
ML \<open>
val _=Export.export @{theory} (Path.binding0(Path.explode "veri7vn/assertions/state-owner"))
  [XML.Text "Native state owner transition/handoff checks passed"];
\<close>
end
