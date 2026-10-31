"""Manufactured independent client checks; no live host or panel claim."""
import copy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from thermal_scenarios import validate_reply, OPERATION, ContractError

ARGUMENTS=json.loads((Path(__file__).resolve().parent/'example.json').read_text())

def envelope():
    scenarios=[]
    for source,temperatures,boundary in zip(ARGUMENTS['scenarios'],([306,302,300],[322,314,310],[307,303,300]),(-8,-16,-12)):
        nodes=[{'id':name,'temperature_k':t,'fixed_temperature_k':source['fixed_temperature_k'][i],
                'boundary_exchange_w':boundary if i==2 else None} for i,(name,t) in enumerate(zip(('chip','case','sink'),temperatures))]
        scenarios.append({'id':source['id'],'result':{'outcome':'solved_within_tolerance','nodes':nodes}})
    derivatives=[{**r,'temperature_derivative':v} for r,v in zip(ARGUMENTS['sensitivities'],([0.75,0.25,0],[-2,0,0],[-0.5,-0.5,0]))]
    return {'outcome':'completed','operation_id':OPERATION,'reply':{'operation_id':OPERATION,'authority':'computation_only','status':'answered',
        'result':{'schema':'oracle-science-experimental-v1','operation':OPERATION,'node_order':['chip','case','sink'],
        'network_identity':'sha256:'+'a'*64,'factorization_count':1,'scenarios':scenarios,'sensitivities':derivatives}}}

class ConsumerChecks(unittest.TestCase):
    def test_independent_series_truth(self):
        result=validate_reply(ARGUMENTS,envelope())
        self.assertEqual(result['scenarios'][0]['temperature_k']['chip'],306)
        self.assertEqual(result['status'],'answered')
    def test_balanced_wrong_temperature_is_detected_against_boundary(self):
        data=envelope()
        for node in data['reply']['result']['scenarios'][0]['result']['nodes']: node['temperature_k']+=10
        with self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
    def test_wrong_hotspot_and_derivative_detected(self):
        data=envelope();data['reply']['result']['scenarios'][0]['result']['nodes'][0]['temperature_k']+=1
        with self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
        data=envelope();data['reply']['result']['sensitivities'][0]['temperature_derivative'][0]=0.5
        with self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
    def test_missing_scenario_not_completeness(self):
        data=envelope();data['reply']['result']['scenarios'].pop()
        with self.assertRaises(ContractError):validate_reply(ARGUMENTS,data)
    def test_structured_refusal_retained(self):
        data=envelope();data['reply']['status']='withheld';data['reply']['reason']='scenario_not_accepted'
        self.assertEqual(validate_reply(ARGUMENTS,data),{'status':'withheld','reason':'scenario_not_accepted'})

if __name__=='__main__':unittest.main()
