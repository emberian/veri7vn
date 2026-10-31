"""Independent manufactured transport and energy checks; no live-host claim."""
from pathlib import Path
import copy
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from thermal_transient import validate_reply,OPERATION,ContractError,request_identity
import importlib.util
_spec=importlib.util.spec_from_file_location('thermal_transient_independent_scorer',Path(__file__).with_name('scorer.py'))
_scorer=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_scorer)
score,truth=_scorer.score,_scorer.truth

ARGUMENTS={'network':{'nodes':[{'id':'body'}]},'capacities_j_per_k':[10],
    'initial_temperature_k':[300],'duration_s':2,'loads':[{'start_time_s':0,'applied_heat_w':[5]}],
    'sample_times_s':[],'events':[],'integration':{'max_steps':10}}

def envelope():
    return {'outcome':'completed','operation_id':OPERATION,'reply':{'operation_id':OPERATION,'authority':'computation_only','status':'answered','result':{
        'schema':'oracle-science-experimental-v1','operation':OPERATION,'outcome':'completed_with_local_error_control',
        'model_identity':request_identity(ARGUMENTS),'identity_encoding':'thermal-canonical-binary64-v1','node_order':['body'],
        'samples':[{'time_s':0,'temperature_k':[300]},{'time_s':2,'temperature_k':[301]}],
        'energy':{'nodes':[{'id':'body','storage_change_j':10,'applied_heat_j':10,'reservoir_heat_j':None,'outgoing_link_heat_j':0}], 'storage_change_j':10,'applied_heat_j':10,'reservoir_heat_j':0,'global_balance_residual_j':0,'internal_link_cancellation_j':0},
        'events':[],'diagnostics':{'attempted_steps':2,'maximum_accepted_local_error_ratio':0}}}}

class ConsumerChecks(unittest.TestCase):
    def test_storage_and_piecewise_integral_are_independent(self):
        self.assertEqual(validate_reply(ARGUMENTS,envelope())['status'],'answered')
        data=envelope();data['reply']['result']['energy']['nodes'][0]['applied_heat_j']=11
        with self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
    def test_missing_sample_or_wrong_initial_refused(self):
        data=envelope();data['reply']['result']['samples'].pop()
        with self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
        data=envelope();data['reply']['result']['samples'][0]['temperature_k']=[299]
        with self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
    def test_undisclosed_heat_cannot_close_a_free_node(self):
        data=envelope();data['reply']['result']['energy']['nodes'][0]['reservoir_heat_j']=1
        with self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
    def test_incomplete_trajectory_is_a_refusal(self):
        data=envelope();data['reply']['status']='withheld';data['reply']['reason']='native_request_refused'
        self.assertEqual(validate_reply(ARGUMENTS,data)['status'],'withheld')
    def test_scorer_uses_analytic_truth_not_balance_alone(self):
        case={'expect':{'model':'cooling','temperature_tolerance_k':0.001,'event_count':0}}
        reply={'status':'answered','samples':[{'time_s':5,'temperature_k':truth('cooling',5)}],'events':[]}
        self.assertTrue(score(case,reply)['right'])
        reply['samples'][0]['temperature_k'][0]+=1
        self.assertTrue(score(case,reply)['wrong'])

    def test_request_identity_binds_parameters_and_schedule(self):
        changed=copy.deepcopy(ARGUMENTS);changed['capacities_j_per_k'][0]=20
        with self.assertRaises(ContractError):validate_reply(changed,envelope())
        changed=copy.deepcopy(ARGUMENTS);changed['integration']['max_steps']=9
        with self.assertRaises(ContractError):validate_reply(changed,envelope())
        spelled=copy.deepcopy(ARGUMENTS);spelled['duration_s']=2.0
        self.assertEqual(request_identity(ARGUMENTS),request_identity(spelled))
    def test_aggregate_energy_cannot_be_fabricated_or_omitted(self):
        for field in ('storage_change_j','applied_heat_j','reservoir_heat_j','global_balance_residual_j','internal_link_cancellation_j'):
            data=envelope();data['reply']['result']['energy'][field]=999
            with self.subTest(field=field),self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
            data=envelope();data['reply']['result']['energy'].pop(field)
            with self.subTest(field=field),self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
    def test_event_estimate_must_match_endpoint_interpolant(self):
        arguments=copy.deepcopy(ARGUMENTS)
        arguments['events']=[{'id':'warm','node_id':'body','temperature_k':300.5,'direction':'rising'}]
        data=envelope();data['reply']['result']['model_identity']=request_identity(arguments)
        hit={'id':'warm','node_id':'body','direction':'rising','bracket_s':[0,2],
            'linear_estimate_s':1,'endpoint_temperature_k':[300,301]}
        data['reply']['result']['events']=[hit]
        self.assertEqual(validate_reply(arguments,data)['status'],'answered')
        hit['linear_estimate_s']=1.5
        with self.assertRaises(ContractError):validate_reply(arguments,data)

    def test_large_boundary_transfer_cannot_hide_small_source_forgery(self):
        arguments=copy.deepcopy(ARGUMENTS)
        arguments.update(network={'nodes':[{'id':'hot','fixed_temperature_k':400},{'id':'cold','fixed_temperature_k':300}]},
            capacities_j_per_k=[1,1],initial_temperature_k=[400,300],duration_s=1,
            loads=[{'start_time_s':0,'applied_heat_w':[1,0]}])
        data=envelope();result=data['reply']['result'];result.update(model_identity=request_identity(arguments),
            node_order=['hot','cold'],samples=[{'time_s':0,'temperature_k':[400,300]},{'time_s':1,'temperature_k':[400,300]}])
        result['energy']={'nodes':[{'id':'hot','storage_change_j':0,'applied_heat_j':1,'reservoir_heat_j':1e20,'outgoing_link_heat_j':1e20},
            {'id':'cold','storage_change_j':0,'applied_heat_j':0,'reservoir_heat_j':-1e20,'outgoing_link_heat_j':-1e20}],
            'storage_change_j':0,'applied_heat_j':1,'reservoir_heat_j':0,'global_balance_residual_j':-1,'internal_link_cancellation_j':0}
        self.assertEqual(validate_reply(arguments,data)['status'],'answered')
        result['energy']['nodes'][0]['applied_heat_j']=2
        result['energy']['applied_heat_j']=2
        result['energy']['global_balance_residual_j']=-2
        with self.assertRaises(ContractError):validate_reply(arguments,data)

if __name__=='__main__':unittest.main()
