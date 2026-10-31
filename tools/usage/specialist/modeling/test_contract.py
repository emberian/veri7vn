"""Authored boundary checks; mocks test routing only, never numerical correctness."""
import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from organ_modeling import Organ, PREFIX, validate, wire_reply
from scorer import ok


class Contract(unittest.TestCase):
    def setUp(self):
        self.panel = json.loads(Path(__file__).with_name('panel.json').read_text())

    def test_lane_controls_never_call_host(self):
        with patch('organ_modeling.calibration.hosted', side_effect=AssertionError('host called')), patch('organ_modeling.events_exposure.hosted', side_effect=AssertionError('host called')):
            for split in self.panel.values():
                for case in split:
                    if case.get('lane_control'):
                        self.assertIsNone(Organ().answer(case['q'], 'session'))

    def test_bad_inputs_never_call_host(self):
        with patch('organ_modeling.calibration.hosted', side_effect=AssertionError('host called')), patch('organ_modeling.events_exposure.hosted', side_effect=AssertionError('host called')):
            for split in self.panel.values():
                for case in split:
                    if not case.get('valid', True) and not case.get('lane_control'):
                        self.assertEqual(Organ().answer(case['q'], 'session')['reason'], 'invalid_input')
            for text in [PREFIX+'{"operation":1,"operation":2}', PREFIX+'{"x":NaN}', PREFIX+'['*2000, PREFIX+' '*65536]:
                self.assertEqual(Organ().answer(text,'s')['reason'],'invalid_input')

    def test_execution_failure_is_not_semantic_refusal(self):
        case=self.panel['dev'][0]
        with patch('organ_modeling.calibration.hosted', side_effect=OSError('unavailable')):
            r=Organ().answer(case['q'],'s')
            self.assertEqual(r['reason'],'execution_failure')
            self.assertNotIn('result',r)

    def test_original_workbench_projection_preserves_failure_class(self):
        row=wire_reply({'status':'withheld','kind':'modeling_input','reason':'execution_failure'})
        projected={'status':row['status'],'response':row['response']}
        self.assertFalse(ok({'valid':False},projected)[0])
        good=wire_reply({'status':'answered','kind':'supplied_modeling','authority':'computation_only','result':{'estimates':[{'value':7,'unit':'N'}]}})
        self.assertTrue(ok({'values':[7],'unit':'N'}, {'status':'answered','response':good['response']})[0])

    def test_glm_work_is_bounded_before_exact_replay(self):
        request=json.loads(self.panel['dev'][3]['q'][len(PREFIX):])
        for rows,columns in [(257,0),(1,17)]:
            a=copy.deepcopy(request)
            a['arguments']['features']=[[0]*columns for _ in range(rows)]
            a['arguments']['successes']=[1]*rows
            a['arguments']['trials']=[2]*rows
            a['arguments']['model']['predictor_names']=['x']*columns
            a['arguments']['model']['predictor_units']=['1']*columns
            a['arguments']['predictions']=[{'features':[0]*columns,'trials':2}]
            with self.assertRaises(ValueError):validate(a)


if __name__=='__main__':unittest.main()
