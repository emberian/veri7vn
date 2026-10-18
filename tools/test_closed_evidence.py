"""Independent closed rational AST replay and malformed-boundary checks."""
import copy,unittest
from fractions import Fraction
import runtime_contract as c
validate=c._validate_closed_evidence
def rat(x):
 q=Fraction(x);return {'num':str(q.numerator),'den':str(q.denominator)}
def const(x):return {'op':'const','value':rat(x)}
def fixture(expr,result):
 q=Fraction(result);value=str(q.numerator) if q.denominator==1 else f'{q.numerator}/{q.denominator}'
 return ({'kind':'closed_expression','status':'answered','value':value,'response':f'[ev:derived] {value}.'},
 {'checker':'Mathkernel.check_closed','accepted':True,'inputs':{'expression':expr},'result':rat(q),'assumptions':[]})
class ClosedTests(unittest.TestCase):
 def test_shared_boundary_requires_packet_and_canonical_version(self):
  r,p=fixture({'op':'pow','base':const(5),'exponent':2},25)
  p.update(schema_version=1,kind='closed_expression')
  r['provenance']={'evidence':{'checked_computation':p}}
  self.assertEqual(c.enforce_reply_evidence(r)['status'],'answered')
  for mutation in ('absent','version','different_kind','malformed'):
   changed=copy.deepcopy(r)
   if mutation=='absent':del changed['provenance']['evidence']['checked_computation']
   elif mutation=='version':changed['provenance']['evidence']['checked_computation']['schema_version']=True
   elif mutation=='different_kind':changed['kind']='legacy'
   else:changed['provenance']['evidence']='bad'
   with self.subTest(mutation=mutation):
    actual=c.enforce_reply_evidence(changed)
    self.assertEqual(actual['status'],'withheld')
    self.assertTrue(actual['provenance']['taken'])
 def test_independent_rational_arithmetic(self):
  values=[Fraction(-3,2),Fraction(-1),Fraction(0),Fraction(1,3),Fraction(2)]
  for x in values:
   for power in (2,3):
    r,p=fixture({'op':'pow','base':const(x),'exponent':power},x**power)
    self.assertEqual(validate(r,p)['status'],'consistent')
   for y in values:
    for op,fn in [('add',lambda:x+y),('sub',lambda:x-y),('mul',lambda:x*y),('div',lambda:x/y)]:
     if op=='div' and not y:continue
     r,p=fixture({'op':op,'left':const(x),'right':const(y)},fn())
     self.assertEqual(validate(r,p)['status'],'consistent')
 def test_original_tree_and_display_mutations_rejected(self):
  for field in ('input','result','value','response','checker','accepted','kind','status'):
   r,p=fixture({'op':'pow','base':const(-3),'exponent':3},-27)
   if field=='input':p['inputs']['expression']['base']=const(3)
   elif field=='result':p['result']=rat(27)
   elif field in ('value','response'):r[field]='27'
   elif field=='checker':p[field]='Other.check'
   elif field=='accepted':p[field]=False
   else:r[field]='other'
   with self.subTest(field=field),self.assertRaises(c.ContractError):validate(r,p)
 def test_invalid_operators_shapes_and_domains(self):
  bad=[{'op':'var','name':'x'}, {'op':'pow','base':const(2),'exponent':True},
       {'op':'pow','base':const(2),'exponent':-1},{'op':'pow','base':const(2),'exponent':4},
       {'op':'const','value':{'num':'1','den':'0'}},
       {'op':'div','left':const(1),'right':const(0)},
       {'op':'div','left':const(0),'right':{'op':'sub','left':const(2),'right':const(2)}},
       {'op':'const','value':rat(2),'ignored':True}]
  for tree in bad:
   r,p=fixture(tree,0)
   with self.subTest(tree=tree),self.assertRaises(c.ContractError):validate(r,p)
 def test_work_bound_precedes_hidden_cancellation(self):
  tree=const(10**200)
  for _ in range(6):tree={'op':'pow','base':tree,'exponent':3}
  r,p=fixture({'op':'sub','left':tree,'right':copy.deepcopy(tree)},0)
  with self.assertRaisesRegex(c.ContractError,'work limit'):validate(r,p)
 def test_deep_and_wide_trees_rejected(self):
  tree=const(1)
  for _ in range(34):tree={'op':'neg','arg':tree}
  r,p=fixture(tree,1)
  with self.assertRaisesRegex(c.ContractError,'depth limit'):validate(r,p)
  tree=const(1)
  for _ in range(7):tree={'op':'add','left':tree,'right':copy.deepcopy(tree)}
  r,p=fixture(tree,128)
  with self.assertRaisesRegex(c.ContractError,'node or depth'):validate(r,p)
if __name__=='__main__':unittest.main()
