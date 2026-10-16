theory Domain_Service_Objects
  imports Domain_Model_Context
    "Veri7vn_Effect_Tickets.Veri7vn_Effect_Tickets"
begin
ML_file "domain_ticket_execution.ML"
ML_file "domain_saved_types.ML"
ML_file "../recovery/domain_recovery_payload.ML"
ML_file "domain_conditions.ML"
ML_file "domain_request.ML"
end
