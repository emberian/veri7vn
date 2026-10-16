(* Insert after search_service_execution_matches in Search_Service_Metadata.
   This is the first standalone profile: every proposal allocates its own input.
   Kept unreferenced during the bounded parent compiler repair window. *)
definition search_service_input :: "search_service_control \<Rightarrow> event" where
  "search_service_input n = RegisterManaged
    \<lparr>retained_id=ssc_input n,retained_owner=RequestLocal (ssc_request n),
      retained_dependencies=[ssc_request n],retained_read_dependencies=[],
      retained_access_requirements=[],retained_payload=ssc_input n\<rparr>"

definition search_service_source_rows_match :: "authority_state \<Rightarrow> search_service_control \<Rightarrow>
    nat list \<Rightarrow> bool \<Rightarrow> bool" where
  "search_service_source_rows_match s n deps consumed =
    ((case search_service_input n of RegisterManaged expected \<Rightarrow>
       (case filter (\<lambda>v. retained_id v=ssc_input n) (retained_values s) of
         [] \<Rightarrow> \<not>consumed | [v] \<Rightarrow> v=expected | _ \<Rightarrow> False)
      | _ \<Rightarrow> False) \<and>
     (case search_service_parameter n deps of RegisterManaged expected \<Rightarrow>
       (case filter (\<lambda>v. retained_id v=ssc_parameter n) (retained_values s) of
         [] \<Rightarrow> \<not>consumed | [v] \<Rightarrow> v=expected | _ \<Rightarrow> False)
      | _ \<Rightarrow> False) \<and>
     (\<forall>r\<in>set (requests s). ssc_input n\<in>set (request_dependencies r) \<longrightarrow>
       request_id r=ssc_request n))"

definition search_service_source_matches :: "authority_state \<Rightarrow> search_service_control \<Rightarrow>
    nat list \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> bool" where
  "search_service_source_matches s n deps cost consumed =
    (search_service_request_matches s n deps cost \<and>
     search_service_execution_matches s n cost consumed \<and>
     search_service_source_rows_match s n deps consumed \<and>
     ssc_input n \<notin> set (retired_sources s) \<and>
     (\<exists>r\<in>set (requests s). request_id r=ssc_request n \<and> parent_accessible s r \<and>
       (\<exists>g\<in>set (request_goals r). goal_id g=ssc_goal n \<and> child_accessible s g \<and>
         (request_cancelled r \<or> goal_outcome g=Cancelled))))"
