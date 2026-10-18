"""Complete task wording at the actual Math/evidence/Guards boundary."""
import sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/dispatch'))
from dispatch import Child
from routes import RouteStages

class RequestPhrasingTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.stages=RouteStages(ROOT,ROOT/'var',10,Path(self.tmp.name),Child,enabled=('mathorgan','guards'))
    def tearDown(self):
        self.stages.close();self.tmp.cleanup()
    def test_complete_requests_keep_checked_evidence_and_original_binding(self):
        cases=[
            ('Please solve 3(x - 2) = 9 for x.','5','unique'),
            ('Could you solve for x 2x=4?','2','unique'),
            ('Can you please find x if 3x=1?','1/3','unique'),
            ('Would you solve x=x? ',None,'all'),
            ('Please solve 2(x+1)=2x+3.',None,'none'),
            ('Please calculate (1/3+1/6)^3.','1/8',None),
            ('Could you compute (-3/2) squared?','9/4',None),
            ('Would you please evaluate -2^2?','-4',None),
        ]
        for q,value,classification in cases:
            with self.subTest(q=q):
                raw=self.stages.answer_math(1,q,{})
                self.assertIsNotNone(raw)
                r=self.stages.apply_guards(q,raw)
                self.assertEqual(r['status'],'answered',r)
                self.assertEqual(r.get('value'),value)
                self.assertEqual(r['provenance']['request_text'],q)
                evidence=r['provenance']['evidence']
                self.assertEqual(evidence['consumer_validation']['status'],'consistent')
                if classification:self.assertEqual(evidence['checked_computation']['result']['classification'],classification)
    def test_trailing_instructions_and_invalid_math_do_not_become_partial_answers(self):
        for q in ['Please solve 2x=4 and x=3.',
                  'Can you solve 2x=4 then add 5?',
                  'Please calculate 2^2 and explain 7.',
                  'Could you compute 0*(1/0)?',
                  'Please solve 1e+x=3.']:
            with self.subTest(q=q):
                r=self.stages.answer_math(1,q,{})
                self.assertTrue(r is None or r['status']=='withheld',r)
    def test_incidental_assignments_still_fall_through(self):
        for q in ['Please differentiate y=3x+2.',
                  'Could you describe the graph y=x+1?',
                  'In this story please solve means assigning x=2.']:
            with self.subTest(q=q):self.assertIsNone(self.stages.answer_math(1,q,{}))

if __name__=='__main__':unittest.main()
