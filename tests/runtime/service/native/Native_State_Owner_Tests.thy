theory Native_State_Owner_Tests
  imports Veri7vn_Runtime_Service.Native_Service
begin
definition staging_observation :: observation_context where
  "staging_observation=\<lparr>observed_session=600,observed_version=1,
    evaluation_time=Some \<lparr>basis=Monotonic ''clock'',ticks=10\<rparr>,observed_reads=[(601,1)]\<rparr>"
lemma staging_requires_exact_clock_even_without_freshness_window:
  "let changed=staging_observation\<lparr>evaluation_time:=Some \<lparr>basis=Monotonic ''clock'',ticks=11\<rparr>\<rparr>;
       s=initial_state\<lparr>current_observations:=[changed]\<rparr>
    in observation_fresh s (RequireObservation staging_observation None) \<and>
      \<not>service_exact_observation_current s staging_observation"
  by eval
lemma staging_requires_exact_reads_even_when_original_reads_match:
  "let changed=staging_observation\<lparr>observed_reads:=[(601,1),(602,1)]\<rparr>;
       s=initial_state\<lparr>current_observations:=[changed]\<rparr>
    in observation_fresh s (RequireObservation staging_observation None) \<and>
      \<not>service_exact_observation_current s staging_observation"
  by eval
lemma staging_accepts_exact_accessible_observation:
  "service_exact_observation_current
    (initial_state\<lparr>current_observations:=[staging_observation]\<rparr>) staging_observation"
  by eval
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
      g\<lparr>goal_required := (case goal_required g of ClaimRequirement c \<Rightarrow> ClaimRequirement (c\<lparr>dependencies := [10]\<rparr>) | a \<Rightarrow> a)\<rparr>) (request_goals r)\<rparr>
    | _ \<Rightarrow> undefined)"
lemma scoped_checkpoint_matches_original_child_plan:
  "scope_checkpoint_plan_matches
    (initial_state\<lparr>requests:=[retirement_fixture_request]\<rparr>)
    100 [(101,111,102,[])] [(101,111)]"
  by eval
lemma scoped_checkpoint_preserves_plan_after_child_denial:
  "scope_checkpoint_plan_matches
    (initial_state\<lparr>requests:=[retirement_fixture_request],revoked_objects:=[101]\<rparr>)
    100 [(101,111,102,[])] []"
  by eval
lemma scoped_checkpoint_rejects_changed_child_identity:
  "\<not> scope_checkpoint_plan_matches
    (initial_state\<lparr>requests:=[retirement_fixture_request]\<rparr>)
    100 [(101,999,102,[])] [(101,111)]"
  by eval

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
  structure S=Veri7vn_Native_Request_Scope;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  fun require true _=() | require false message=error message;
  val ids=I.install_host_block{workspace="53000000000000000000000000000001",first=4000000,past=4065536};
  val original=L.input{bytes="first;second",encoding="UTF-8"};
  val parent=S.new_parent{allocator=ids,policy=Veri7vn_Native_Admission.policy @{theory},
    observation=S.StateTimeUnused,inputs=[original]};
  val first=S.new_child parent{source=L.slice original{start=0,stop=5,expected="first"},predecessors=[]};
  val second=S.new_child parent{source=L.slice original{start=6,stop=12,expected="second"},predecessors=[first]};
  val alien=L.input{bytes="first;second",encoding="UTF-8"};
  val _=require(Exn.is_exn(Exn.capture(fn()=>S.new_child parent
    {source=L.slice alien{start=0,stop=5,expected="first"},predecessors=[]})()))
    "Equal bytes from another original became a native child source";
  val _=ignore(L.drop_base alien);
  val a=S.identity first; val b=S.identity second;
  val _=require(#request a= #request b andalso #goal a<> #goal b andalso #slot a<> #slot b)
    "Native parent did not preserve distinct goal/slot identities";
  val _=S.claim first;val _=S.claim second;
  val _=require(Exn.is_exn(Exn.capture S.claim first)) "Native child constructed twice";
  val _=require(Exn.is_exn(Exn.capture(S.seal parent)[second,first]))
    "Native parent accepted reversed predecessor order";
  val _=S.seal parent[first,second];
  val _=ignore(L.drop_base original);
  val retained_first=S.retain_child first;
  val _=S.release_child first;val _=S.release_parent parent;
  val _=require(S.child_live retained_first andalso
    S.same_child(first,retained_first) andalso S.identity first=S.identity retained_first)
    "Independent retained child lost its source/identity with producer release";
  val _=require(Exn.is_exn(Exn.capture S.claim retained_first))
    "Retained child obtained a second construction claim";
  val _=require(S.child_live second andalso L.retained original)
    "Sibling or parent producer release erased a surviving child source";
  val _=S.deny parent;
  val _=require(not(S.child_live second) andalso not(S.child_live retained_first))
    "Parent denial left a child scope live";
  val _=S.release_child retained_first;
  val _=S.release_child second;
  val _=require(L.disposed original) "Final child retained original source bytes";
in val _=writeln "Native parent child identity/order/source lifetime checks passed" end;
\<close>

ML \<open>
local
  structure F=Veri7vn_Metadata_Frame;
  datatype input=Cancel | Unsupported;
  val recursive_query=Unsynchronized.ref(fn()=>());
  val query_countdown=Unsynchronized.ref 0;
  structure Owner=Veri7vn_Native_State_Owner(struct
    type event=input
    fun is_live _=
      (if !query_countdown=0 then () else
        (query_countdown:= !query_countdown-1;
         if !query_countdown=0 then (!recursive_query)() else ());true)
    fun current_expectation _=F.NoCurrentExpectation
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
  val _=recursive_query:=(fn()=>ignore(Owner.current_epoch()));
  val guarded=Owner.prepare Cancel;
  (* acknowledge first checks liveness outside the monitor, then checks again
     during installation. Re-enter only on that second call: rejection must be
     synchronous and leave the actual owner unchanged, without a timeout test. *)
  val _=query_countdown:=2;
  val recursive=Exn.capture Owner.acknowledge guarded;
  val _=require(case recursive of
      Exn.Exn(ERROR message)=>message="Native gate liveness must not query its authority Owner"
    | _=>false) "Recursive gate authority query was not rejected synchronously";
  val _=require(Owner.current_epoch()=1 andalso Owner.valid guarded)
    "Rejected recursive liveness installed or lost the current candidate";
  val _=ignore(Owner.acknowledge guarded);
  val _=require(Owner.current_epoch()=2)
    "Intrinsic liveness could not acknowledge after rejected recursive query";
in val _=writeln "Native state owner transition/handoff checks passed" end;
\<close>
ML \<open>
val _=Export.export @{theory} (Path.binding0(Path.explode "veri7vn/assertions/state-owner"))
  [XML.Text (cat_lines ["Native state owner transition/handoff checks passed",
    "Native parent child identity/order/source lifetime checks passed"])];
\<close>
end
