"""Untrusted structured-adapter tests; no theorem or physical validation claim."""
from pathlib import Path
import copy
import json
import sys
import unittest
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
sys.path.insert(0, str(ROOT/'tools/appliance'))
from oracle_components.native_science import NativeScienceOperations
from operations import validate, OperationError

OP = 'science.thermal_scenarios'
CATALOG = {'schema':'oracle-science-experimental-v1','operations':['science.thermal_network',OP],
    'limits':{'request_bytes':1048576,'rows':512,'columns':128,'work_estimate':8388608,'svd_scratch_bytes':33554432},
    'thermal_network':{'nodes':128,'links':1024},'thermal_scenarios':{'scenarios':64,'sensitivities':128}}
ARGUMENTS = json.loads((ROOT/'tools/usage/specialist/thermal-scenarios/example.json').read_text())

def result():
    nested = {'schema':CATALOG['schema'],'operation':'science.thermal_network','outcome':'solved_within_tolerance',
        'nodes':[],'links':[],'components':[],'conservation':{},'linear_diagnostics':None,'warnings':[]}
    return {'schema':CATALOG['schema'],'operation':OP,'network_identity':'sha256:'+'a'*64,
        'factorization_count':1,'scenario_rhs_solves':3,'sensitivity_rhs_solves':0,
        'node_order':['chip','case','sink'],'scenarios':[{'id':'normal','result':nested}],
        'sensitivities':[],'warnings':[]}

class ThermalScenariosAdapter(unittest.TestCase):
    def adapter(self, output):
        return NativeScienceOperations(CATALOG,lambda _:output,'fixture:science')
    def test_discovery_and_strict_schema(self):
        adapter=self.adapter(result())
        schema=next(x['input_schema'] for x in adapter.catalog() if x['id']==OP)
        validate(ARGUMENTS,schema)
        for change in ({'uncertainty_bounds':True},{'network':{**ARGUMENTS['network'],'advection':True}},
            {'sensitivities':[{'scenario_id':'normal','parameter':{'kind':'boundary_temperature','node_id':'sink'}}]}):
            with self.subTest(change=change),self.assertRaises(OperationError):
                validate({**ARGUMENTS,**change},schema)
    def test_refused_candidate_never_promoted(self):
        data=result();data['scenarios'][0]['result']['outcome']='below_absolute_zero_candidate'
        answer=self.adapter(data).invoke(OP,ARGUMENTS)
        self.assertEqual(answer['status'],'withheld')
        self.assertEqual(answer['reason'],'scenario_not_accepted')
        self.assertEqual(answer['result'],data)
    def test_invalid_derivative_and_identity_refused(self):
        for mutate in (lambda x:x.update(network_identity='wrong'),
            lambda x:x.update(sensitivities=[{'temperature_derivative':[1,float('nan'),0]}]),
            lambda x:x.update(sensitivities=[{'temperature_derivative':[1]}]),
            lambda x:x.update(scenarios=[])):
            data=result();mutate(data)
            self.assertEqual(self.adapter(data).invoke(OP,ARGUMENTS)['reason'],'native_reply_invalid')
    def test_explicit_numeric_scenario_classification(self):
        answer=self.adapter(result()).invoke(OP,ARGUMENTS)
        self.assertEqual(answer['classification'],'numerical_scenarios')
        self.assertEqual(answer['authority'],'computation_only')


TRANSIENT = 'science.thermal_transient'
TRANSIENT_CATALOG = copy.deepcopy(CATALOG)
TRANSIENT_CATALOG['operations'].append(TRANSIENT)
TRANSIENT_CATALOG['thermal_transient'] = {'nodes':64,'links':512,'attempted_steps':8192,'load_segments':64,
    'requested_samples':128,'events':32,'event_hits':256,'factor_cache':8}
TRANSIENT_ARGUMENTS = json.loads((ROOT/'native/oracle-science/examples/thermal-transient-heater.json').read_text())['arguments']


def transient_reply():
    node_energy = lambda name, boundary: {'id':name,'storage_change_j':0,'applied_heat_j':0,'reservoir_heat_j':boundary,
        'outgoing_link_heat_j':0,'integrated_balance_residual_j':0,'maximum_step_balance_residual_j':0}
    return {'schema':CATALOG['schema'],'operation':TRANSIENT,'outcome':'completed_with_local_error_control',
        'model_identity':'sha256:'+'b'*64,'identity_encoding':'thermal-canonical-binary64-v1','node_order':['body','sink'],
        'samples':[{'time_s':0,'temperature_k':[300,300]},{'time_s':2,'temperature_k':[300,300]}],
        'events':[],'energy':{'nodes':[node_energy('body',None),node_energy('sink',0)],'storage_change_j':0,
            'applied_heat_j':0,'reservoir_heat_j':0,'global_balance_residual_j':0,'internal_link_cancellation_j':0},
        'diagnostics':{'attempted_steps':1,'accepted_steps':1,'rejected_steps':0,'implicit_substeps':3,
            'factorizations':2,'factor_cache_hits':1,'maximum_accepted_local_error_ratio':0},'warnings':[]}


class ThermalTransientAdapter(unittest.TestCase):
    def adapter(self, output):
        return NativeScienceOperations(TRANSIENT_CATALOG,lambda _:output,'fixture:science')
    def test_transient_discovery_is_strict_and_classified(self):
        adapter=self.adapter(transient_reply())
        schema=next(x['input_schema'] for x in adapter.catalog() if x['id']==TRANSIENT)
        validate(TRANSIENT_ARGUMENTS,schema)
        answer=adapter.invoke(TRANSIENT,TRANSIENT_ARGUMENTS)
        self.assertEqual(answer['classification'],'numerical_transient_local_error_control')
        self.assertEqual(answer['authority'],'computation_only')
        for changes in ({'boundary_schedule':[]},{'integration':{**TRANSIENT_ARGUMENTS['integration'],'max_steps':8193}},
            {'events':[{'id':'warm','node_id':'body','temperature_k':305,'direction':'certified_absence'}]}):
            with self.subTest(changes=changes),self.assertRaises(OperationError):validate({**TRANSIENT_ARGUMENTS,**changes},schema)
    def test_incomplete_or_uncontrolled_candidate_not_promoted(self):
        for mutate in (lambda x:x.update(outcome='partial'),
            lambda x:x['diagnostics'].update(maximum_accepted_local_error_ratio=2),
            lambda x:x['diagnostics'].update(attempted_steps=8193),
            lambda x:x['diagnostics'].update(implicit_substeps=2),
            lambda x:x['energy']['nodes'][0].update(storage_change_j=float('nan')),
            lambda x:x['samples'][1].update(temperature_k=[-1,300]),
            lambda x:x['samples'].pop(),lambda x:x.update(node_order=['body','body'])):
            data=transient_reply();mutate(data)
            self.assertEqual(self.adapter(data).invoke(TRANSIENT,TRANSIENT_ARGUMENTS)['reason'],'native_reply_invalid')
    def test_invalid_event_bracket_or_node_refused(self):
        data=transient_reply();data['events']=[{'id':'warm','node_id':'body','direction':'rising','bracket_s':[0,2],
            'linear_estimate_s':3,'endpoint_temperature_k':[300,306]}]
        self.assertEqual(self.adapter(data).invoke(TRANSIENT,TRANSIENT_ARGUMENTS)['reason'],'native_reply_invalid')

if __name__=='__main__':unittest.main()
