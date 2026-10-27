"""Narrow regression checks; no engine startup or specialist panel claim."""
import importlib.util
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
MODULE = Path(os.environ.get('ORACLE_OPERATOR_SPECS', ROOT / 'var/ap1-upstream-slim/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_operator_specs_v1.py'))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


op = load('computing_test_operator', MODULE)
workflow = load('computing_workflow', ROOT / 'tools/usage/computing/base_workflow.py')


class BaseConversionRepair(unittest.TestCase):
    def check(self, prompt, expected, value, source):
        args = op._base_parse(prompt)
        self.assertEqual((args['n'], args['frm']), (value, source))
        actual, _ = op._base_fn(args)
        self.assertEqual(actual, expected)
        self.assertEqual(op._base_ref(args), expected)

    def test_real_wrong_answer_and_explicit_source(self):
        self.check('Convert binary 11111111 to decimal.', '255', 255, 2)
        self.check('Convert 11111111 from base 2 to base 10.', '255', 255, 2)
        self.check('Convert 17 from base 8 to base 10.', '15', 15, 8)
        self.check('Convert 0010 from base 2 to base 10.', '2', 2, 2)

    def test_hexadecimal_words_and_prefix(self):
        for text in ('Convert hex ff to binary.', 'Convert ff from hexadecimal to binary.',
                     'What is 0xff in binary?', 'Convert +0xff to binary.'):
            self.check(text, '11111111', 255, 16)
        self.check('Convert 0b1010 to decimal.', '10', 10, 2)
        self.check('Convert 0o17 to decimal.', '15', 15, 8)
        self.check('Convert 1010 in binary to decimal.', '10', 10, 2)

    def test_decimal_control_and_zero(self):
        self.check('Convert 255 to hexadecimal.', 'ff', 255, 10)
        self.check('Write 0 in binary.', '0', 0, 10)
        self.check('Express +15 as hex.', 'f', 15, 10)
        self.check('Convert decimal 255 to hex.', 'ff', 255, 10)

    def test_declines_invalid_digits_signs_and_conflicting_bases(self):
        for text in ('Convert 102 from base 2 to base 10.', 'Convert binary 102 to decimal.',
                     'Convert -10 to binary.', 'Convert -0xff to binary.',
                     'Convert 0x to decimal.', 'Convert 19 from base 8 to decimal.',
                     'Convert 10 from base 1 to decimal.', 'Convert 10 to base 37.',
                     'Convert binary 11 from base 8 to decimal.',
                     'Convert decimal 0xff to binary.'):
            with self.subTest(text=text), self.assertRaises(op.OutOfFragment):
                op._base_parse(text)

    def test_never_takes_a_suffix_of_malformed_or_compound_input(self):
        for text in ('Convert - 10 to binary.', 'Convert 12.5 to binary.',
                     'Convert 10 to binary and 20 to hexadecimal.',
                     'Convert 1011/2 to decimal.', 'Convert 0b102 to decimal.',
                     'Convert --10 to binary.', 'Convert ++10 to binary.'):
            with self.subTest(text=text), self.assertRaises(op.OutOfFragment):
                op._base_parse(text)

    def test_every_source_target_base_with_independent_integer_values(self):
        # 35*35*5 known source values; output decoding is stdlib int rather
        # than either target-encoding implementation under test.
        for source in range(2, 37):
            for target in range(2, 37):
                for digits in ('0', '1', '10', '11', '101'):
                    args = op._base_parse(f'Convert {digits} from base {source} to base {target}.')
                    expected = {'0': 0, '1': 1, '10': source,
                                '11': source+1, '101': source*source+1}[digits]
                    output, _ = op._base_fn(args)
                    self.assertEqual(int(output, target), expected)
                    self.assertEqual(op._base_ref(args), output)

    def test_arithmetic_does_not_reuse_a_corrupted_decimal_binding(self):
        args = op._base_parse('Convert binary 11111111 to decimal.')
        args['n'] = 11111111
        self.assertEqual(op._base_fn(args)[0], '255')
        self.assertEqual(op._base_ref(args), '255')


class CallerWorkflow(unittest.TestCase):
    def test_source_binding_is_checked_despite_verified_flag(self):
        packet = workflow.prepare('11111111', 2, 10)
        record = {'text': packet['cases'][0]['text'], 'http_status': 200,
                  'response': {'reply': {'status': 'answered',
                    'response': '11111111 in base 10 is 11111111.',
                    'provenance': {'verified': True}}}}
        report = workflow.inspect(packet, record)
        self.assertEqual(report['assessment'], 'wrong_input_binding')
        self.assertIs(report['oracle_record'], record)

    def test_refusal_is_not_promoted_to_success(self):
        packet = workflow.prepare('11111111', 2, 10)
        record = {'text': packet['cases'][0]['text'], 'http_status': 200,
                  'response': {'reply': {'status': 'withheld', 'response': '255'}}}
        self.assertEqual(workflow.inspect(packet, record)['assessment'], 'not_answered')

    def test_local_values_and_input_rejection(self):
        self.assertEqual(workflow.prepare('FF', 16, 2)['expectation']['output_digits'], '11111111')
        self.assertEqual(workflow.prepare('000', 2, 16)['expectation']['output_digits'], '0')
        for args in [('102', 2, 10), ('-1', 10, 2), ('0xff', 16, 2),
                     ('1', True, 2), ('1', 2, 37), ('1'*129, 2, 10)]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                workflow.prepare(*args)

    def test_distinguishes_response_failures(self):
        packet = workflow.prepare('10', 2, 10)
        record = {'text': packet['cases'][0]['text'], 'http_status': 200,
                  'response': {'reply': {'status': 'answered', 'response': '2 in base 10 is 2.'}}}
        self.assertEqual(workflow.inspect(packet, record)['assessment'], 'matches_local_check')
        record['response']['reply']['response'] = '2 in base 10 is 3.'
        self.assertEqual(workflow.inspect(packet, record)['assessment'], 'wrong_value')
        record['response']['reply']['response'] = 'A prose answer.'
        self.assertEqual(workflow.inspect(packet, record)['assessment'], 'unsupported_reply_shape')
        record['http_status'] = 503
        self.assertEqual(workflow.inspect(packet, record)['assessment'], 'no_successful_transport')
        record['text'] = 'different question'
        self.assertEqual(workflow.inspect(packet, record)['assessment'], 'request_mismatch')


if __name__ == '__main__':
    unittest.main()
