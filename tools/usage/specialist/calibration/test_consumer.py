"""Authored consumer contract checks; no theorem or panel result."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from calibration import exact_extracted, ExactInputError, strict_json

PANEL = json.loads(Path(__file__).with_name('panel.json').read_text())


class ExtractedConsumer(unittest.TestCase):
    def run_fixture(self, mutate=None):
        def run(argv, **kwargs):
            self.assertEqual(argv[-2:], ['--specialist', 'statistics-v3'])
            requests=[json.loads(line) for line in kwargs['input'].splitlines()]
            self.assertEqual([r['q'] for r in requests], [
                'regression intercept for x = [1, 2, 3], y = [2, 5, 5]',
                'regression slope for x = [1, 2, 3], y = [2, 5, 5]',
                'regression prediction at x = 4 for x = [1, 2, 3], y = [2, 5, 5]'])
            replies=[{'id':str(i), 'status':'answered', 'value':value, 'kind':'regression_'+kind,
                      'provenance':{'kernel':'GeoStats.g_reply/s_reply/weighted_reply/paired_reply'}}
                     for i,(kind,value) in enumerate([('intercept',1),('slope',1.5),('prediction',7)])]
            if mutate:
                mutate(replies)
            return subprocess.CompletedProcess(argv,0,'\n'.join(map(json.dumps,replies)),'')
        return run

    def test_real_transport_shape_keeps_rounded_values_and_raw_replies(self):
        with patch('calibration.subprocess.run',side_effect=self.run_fixture()):
            answer=exact_extracted('/caller/selected/geostats',PANEL['exact_base'])
        self.assertEqual(answer['rounded_predictions'],[7])
        self.assertEqual(answer['rounded_slope'],1.5)
        self.assertEqual(answer['raw_kernel_replies'][2]['value'],7)
        self.assertIn('four decimals',answer['assurance'])

    def test_unsupported_model_directions_weights_and_fraction_lexemes_do_not_execute(self):
        for overrides in ({'direction':'inverse_point'},{'uncertainty':'pointwise_interval'},
                          {'relative_precisions':[1,1,1]},{'x':['1/2',2,3]}, {'x': [True,2,3]}):
            with self.subTest(overrides=overrides), patch('calibration.subprocess.run') as run:
                with self.assertRaises(ExactInputError):
                    exact_extracted('/unused',{**PANEL['exact_base'],**overrides})
                run.assert_not_called()

    def test_kernel_identity_kind_and_order_are_checked(self):
        for mutate in (lambda rs: rs[0].update(id='other'),
                       lambda rs: rs[1].update(kind='regression_intercept'),
                       lambda rs: rs[2].update(value=float('nan')),
                       lambda rs: rs[0].update(provenance={})):
            with patch('calibration.subprocess.run',side_effect=self.run_fixture(mutate)):
                with self.assertRaises(ValueError):
                    exact_extracted('/unused',PANEL['exact_base'])

    def test_strict_json(self):
        for raw in ('{"x":1,"x":2}','{"x":NaN}'):
            with self.assertRaises(ValueError):
                strict_json(raw)


if __name__=='__main__':
    unittest.main()
