"""Narrow workflow checks; no claim of Oracle correctness or formal verification."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('document_prepare', ROOT / 'tools/usage/documents/prepare.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class PrepareTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.source = Path(self.tmp.name) / 'source.txt'
        self.source.write_text('The Lumen Archive is in Alderport.\nNira Vale is the director of the Lumen Archive.\nThe Lumen Archive opened in 2018.\n')
        self.questions = [{'id': 'yes-owner', 'question': 'Is Nira Vale the director of the Lumen Archive?'}]

    def test_matches_live_request(self):
        cases, manifest = m.prepare(self.source, self.questions, 'doc-passage')
        baseline = json.loads((ROOT / 'tools/usage/documents/cases.json').read_text())[1]
        self.assertEqual(cases[0], baseline)
        self.assertEqual(manifest['text'], self.source.read_text())

    def test_multiline_duplicate_locations(self):
        text = 'Nira Vale\nleads the archive.\nNira Vale leads the archive.'
        self.assertEqual(m.quote_locations(text, 'Nira Vale leads the archive.'),
                         [{'start_line': 1, 'end_line': 2}, {'start_line': 3, 'end_line': 3}])
        self.assertEqual(m.quote_locations(text, 'Nira Vale founded the archive.'), [])

    def test_byte_limit_no_truncation(self):
        self.source.write_text('é' * 8200)
        with self.assertRaises(ValueError):
            m.prepare(self.source, self.questions, 'doc')
        self.source.write_text('a' * 16300)
        with self.assertRaises(ValueError):
            m.prepare(self.source, self.questions, 'doc')

    def test_invalid_grammar_and_unsupported_task(self):
        with self.assertRaises(ValueError):
            m.prepare(self.source, [{'id': 'x', 'question': 'Is it? Question: Who?'}], 'doc')
        cases, manifest = m.prepare(self.source, [{'id': 'x', 'question': 'Summarize this.'}], 'doc')
        self.assertEqual(len(manifest['warnings']), 1)
        self.assertTrue(cases[0]['text'].endswith('Question: Summarize this.'))

    def test_reply_preserved_and_scope_checked(self):
        cases, manifest = m.prepare(self.source, self.questions, 'doc')
        reply = {'status': 'withheld', 'path': 'other', 'references': [{'id': 'passage', 'text': 'Made up citation.'}]}
        row = dict(cases[0], response={'reply': reply})
        report = m.inspect(manifest, [row])[0]
        self.assertEqual(report['oracle_reply'], reply)
        self.assertFalse(report['passage_route'])
        self.assertEqual(report['quote_occurrences'][0]['locations'], [])
        manifest['text'] += ' Changed.'
        with self.assertRaises(ValueError):
            m.inspect(manifest, [row])
        manifest['text'] = self.source.read_text()
        row['text'] = 'Different document'
        with self.assertRaises(ValueError):
            m.inspect(manifest, [row])


if __name__ == '__main__':
    unittest.main()
