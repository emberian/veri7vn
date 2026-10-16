import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/deploy'))
from navigation_assets import attach_navigation

class NavigationAssets(unittest.TestCase):
    def test_only_declared_source_captured_and_native_saved_source_wins(self):
        with tempfile.TemporaryDirectory() as temporary:
            repo=Path(temporary).resolve();(repo/'deployment').mkdir();(repo/'src').mkdir()
            source=repo/'src/A.thy';source.write_text('theory A imports Main begin end\n')
            unrelated=repo/'src/Unrelated.thy';unrelated.write_text('not in declared closure')
            root=repo/'ROOT.saved';root.write_text('session Required = HOL +\n theories A\n')
            (repo/'deployment/navigation-sources.json').write_text(json.dumps(dict(schema='veri7vn-declared-navigation-sources/1',sources=['src/A.thy'],qualification='navigation only')))
            receipt=repo/'receipt.json';receipt.write_text(json.dumps(dict(sources_sha256={})))
            closure=dict(navigation_roots=[dict(directory=str(repo/'src'),snapshot=str(root),sha256=hashlib.sha256(root.read_bytes()).hexdigest())],qualification_receipt='receipt.json')
            spec={'artifacts':[]}
            attach_navigation(spec,repo,closure,repo/'closure.json')
            self.assertEqual(['sessions/src/A.thy'],[entry['path'] for entry in spec['artifacts']])
            self.assertEqual('unqualified-ROOT-declared-header-navigation-only',spec['artifacts'][0]['origin'])
            captured=Path(spec['artifacts'][0]['source']);source.write_text('live source changed later')
            self.assertEqual(b'theory A imports Main begin end\n',captured.read_bytes())
            native={'artifacts':[{'path':'sessions/src/A.thy','origin':'exact saved native source'}]}
            attach_navigation(native,repo,closure,repo/'closure.json')
            self.assertEqual(1,len(native['artifacts']))
            self.assertEqual([],native['associations']['navigation_only_sources']['files'])
    def test_known_qualification_pin_cannot_be_silently_replaced(self):
        with tempfile.TemporaryDirectory() as temporary:
            repo=Path(temporary).resolve();(repo/'deployment').mkdir();(repo/'src').mkdir()
            (repo/'src/A.thy').write_text('later source')
            root=repo/'ROOT.saved';root.write_text('session Required = HOL + theories A')
            (repo/'deployment/navigation-sources.json').write_text(json.dumps(dict(schema='veri7vn-declared-navigation-sources/1',sources=['src/A.thy'],qualification='navigation only')))
            (repo/'receipt.json').write_text(json.dumps(dict(sources_sha256={'src/A.thy':'0'*64})))
            closure=dict(navigation_roots=[dict(directory=str(repo/'src'),snapshot=str(root),sha256=hashlib.sha256(root.read_bytes()).hexdigest())],qualification_receipt='receipt.json')
            with self.assertRaisesRegex(ValueError,'qualified source pin'):
                attach_navigation({'artifacts':[]},repo,closure,repo/'closure.json')
