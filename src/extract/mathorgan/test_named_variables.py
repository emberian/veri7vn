"""Selected named-variable producer, replay and guard controls. Not a panel score."""
import copy,json,subprocess,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/dispatch'))
from dispatch import Child
from routes import RouteStages,_terminal
BIN=ROOT/'var/mathorgan/bin/mathorgan'

class NamedVariableTests(unittest.TestCase):
    def raw(self,questions):
        p=subprocess.run([str(BIN),'--route','algebra'],input=''.join(json.dumps({'id':i,'q':q})+'\n'for i,q in enumerate(questions)),text=True,capture_output=True,timeout=30,check=True)
        return [json.loads(x)for x in p.stdout.splitlines()]
    def test_named_unique_and_constant_classifications_through_actual_guards(self):
        cases=[('Solve 3t+2=11 for t.','t','3','unique'),
               ('Solve for y 2y=3?','y','3/2','unique'),
               ('Please find n if (n+1)/2=3.','n','5','unique'),
               ('What is z when 2z=4?','z','2','unique'),
               ('a+1=3','a','2','unique'),
               ('Solve 2*e=4 for e','e','2','unique'),
               ('Solve 1e3t=2000 for t','t','2','unique'),
               ('Solve 3T=9 for T','t','3','unique'),
               ('What is the value of n given n=n?','n',None,'all'),
               ('What is t given t=t+1?','t',None,'none'),
               ('Solve 2=2 for q','q',None,'all'),
               ('Solve 2=3 for q','q',None,'none')]
        with tempfile.TemporaryDirectory() as directory:
            stages=RouteStages(ROOT,ROOT/'var',10,Path(directory),Child,enabled=('mathorgan','guards'))
            try:
                for q,var,value,kind in cases:
                    with self.subTest(q=q):
                        raw=stages.answer_math(1,q,{})
                        self.assertIsNotNone(raw)
                        r=stages.apply_guards(q,raw)
                        self.assertEqual(r['status'],'answered',r)
                        self.assertEqual(r.get('value'),value)
                        self.assertEqual(r['provenance']['request_text'],q)
                        evidence=r['provenance']['evidence']
                        self.assertEqual(evidence['consumer_validation']['status'],'consistent')
                        packet=evidence['checked_computation']
                        self.assertEqual(packet['inputs']['variable'],var)
                        self.assertEqual(packet['result']['classification'],kind)
            finally:stages.close()
    def test_conflicts_foreign_variables_and_malformed_numbers_refuse(self):
        qs=['Solve for x 2t=4 for t','Solve 2t=4 for x','Solve t+y=3 for t',
            'Solve t+y-y=3 for t','Solve t+0*y=3 for t','Solve t=y-y+3 for t',
            'Solve t*t=4 for t','Solve 2e=4 for e','Solve 1e+t=3 for t',
            'Solve 2time=4 for time','Solve t=2 then add 3','Solve t=2 and y=3']
        for q,r in zip(qs,self.raw(qs)):
            with self.subTest(q=q):
                self.assertEqual(r['status'],'withheld',r)
                self.assertTrue(r['provenance']['taken'])
    def test_incidental_equations_fall_through(self):
        qs=['What is the derivative of y=t+1?','Please differentiate y=t+1.',
            'Describe a graph of y=t+1.','In the story t=2 is an assignment.',
            'What is a function with y=x?','Find a derivative when y=x.']
        for q,r in zip(qs,self.raw(qs)):
            with self.subTest(q=q):self.assertFalse(r['provenance']['taken'],r)
    def test_header_ast_and_display_mismatches_reject_actual_packets(self):
        for original in self.raw(['Solve 2t=3 for t','Solve n=n for n','Solve q=q+1 for q']):
            self.assertEqual(_terminal(original)['status'],'answered')
            changed=copy.deepcopy(original);changed['provenance']['evidence']['checked_computation']['inputs']['variable']='x'
            self.assertEqual(_terminal(changed)['status'],'withheld')
            changed=copy.deepcopy(original);p=changed['provenance']['evidence']['checked_computation'];p['inputs']['left']={'op':'var','name':'x'}
            self.assertEqual(_terminal(changed)['status'],'withheld')
            changed=copy.deepcopy(original);v=changed['provenance']['evidence']['checked_computation']['inputs']['variable'];changed['response']=changed['response'].replace(' '+v+' ',' x ')
            self.assertEqual(_terminal(changed)['status'],'withheld')
            changed=copy.deepcopy(original);del changed['provenance']['evidence']
            self.assertEqual(_terminal(changed)['status'],'withheld')

if __name__=='__main__':unittest.main()
