theory Policy_Service
  imports "Veri7vn_Policy_Bundle.Policy_Bundle"
    "Veri7vn_Domain_Service_Objects.Domain_Service_Objects"
    "Veri7vn_Native_Request_Scope.Native_Request_Scope"
begin
ML_file "policy_associations.ML"
ML_file "policy_request.ML"
ML_file "scoped_policy_request.ML"
end
