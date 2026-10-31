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

if __name__=='__main__':unittest.main()
