"""Independent boundary cases for code-example replay; no requested code executes."""
import copy
import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path
from code_evidence import validate_code, program_operations, SEMANTICS, SCOPE


def fixture():
    source="def f(a0):\n    if type(a0) is not list or any(type(v) is not int for v in a0): raise TypeError('Expected integer-list argument a0')\n    v0 = a0\n    v1 = [v for v in v0 if v % 2 == 0]\n    v2 = [v * v for v in v1]\n    v3 = sum(v2)\n    return v3\n"
    packet={'schema_version':1,'kind':'code_program','checker':'Codekernel.check_program','accepted':True,
      'program':{'base':{'op':'arg','index':0},'moves':[{'op':'even_only'},{'op':'square_each'},{'op':'sum'}]},
      'examples':[{'args':[[-4,-1,0,2,3]],'expected':20},{'args':[[]],'expected':0}],
      'results':[20,0],'function_name':'f','argument_count':1,'program_source':source,
      'matching_candidates':1,'ambiguity_probe_count':6,'assumptions':['The typed examples represent the request.'],
      'scope':SCOPE,'semantics':copy.deepcopy(SEMANTICS)}
    reply={'status':'answered','kind':'code_program','response':'```python\n'+source+'```\nThis candidate matches all 2 supplied examples. The examples do not determine its behavior on other inputs.'}
    return reply,packet


class CodeEvidenceTests(unittest.TestCase):
    def test_complete_examples_and_source_are_checked(self):
        r,p=fixture();o=validate_code(r,p)
        self.assertEqual(o['status'],'consistent')
        self.assertIn('displayed_source_matches',o['checks'])

    def test_mutated_evidence_or_rendered_source_rejected(self):
        for field in ('input','expected','result','ast','accepted','source','response','count','scope','semantics','value'):
            r,p=fixture()
            if field=='input':p['examples'][0]['args'][0][0]=-6
            elif field=='expected':p['examples'][0]['expected']=21
            elif field=='result':p['results'][0]=21
            elif field=='ast':p['program']['moves'][0]['op']='odd_only'
            elif field=='accepted':p['accepted']=False
            elif field=='source':p['program_source']+='print("extra")\n'
            elif field=='response':r['response']=r['response'].replace('sum(v2)','max(v2)')
            elif field=='count':p['results'].pop()
            elif field=='scope':p['scope']='This program is correct for all inputs.'
            elif field=='semantics':p['semantics']['unique']='retain first occurrence'
            else:r['value']=20
            with self.subTest(field=field),self.assertRaises((ValueError,TypeError)):validate_code(r,p)

    def test_bool_not_integer_and_bounded_examples(self):
        for change in ('boolinput','boolresult','size','integer','arity','empty','name','extra','candidatecount'):
            r,p=fixture()
            if change=='boolinput':p['examples'][0]['args']=[True]
            elif change=='boolresult':p['results'][1]=False
            elif change=='size':p['examples'][0]['args']=[[1]*257]
            elif change=='integer':p['examples'][0]['args']=[[10**31]]
            elif change=='arity':p['argument_count']=True
            elif change=='empty':p['examples']=[];p['results']=[]
            elif change=='name':p['function_name']='f():\n    print(1)'
            elif change=='extra':p['program']['moves'][0]['ignored']=1
            else:p['matching_candidates']=False
            with self.subTest(change=change),self.assertRaises((ValueError,TypeError)):validate_code(r,p)

    def test_primitive_semantics_on_independent_values(self):
        cases=[('reverse',[1,2,1],[1,2,1]),('sort',[3,-1,2],[-1,2,3]),('sort_desc',[3,-1,2],[3,2,-1]),
          ('unique',[1,2,1],[2,1]),('square_each',[-2,3],[4,9]),('abs_each',[-2,3],[2,3]),
          ('negate_each',[-2,3],[2,-3]),('even_only',[-3,-2,0,1],[-2,0]),('odd_only',[-3,-2,0,1],[-3,1]),
          ('positive_only',[-1,0,2],[2]),('negative_only',[-1,0,2],[-1]),('sum',[-2,3],1),
          ('product',[],1),('length',[2,3],2),('maximum',[-2,-3],-2),('minimum',[-2,-3],-3),
          ('all_same',[],True),('all_unique',[1,2,1],False),('is_sorted',[1,1,2],True),
          ('absolute',-3,3),('square',-3,9),('cube',-3,-27),('negate',-3,3),('is_even',-2,True),('is_odd',-3,True)]
        for op,x,want in cases:
            run,_,_=program_operations({'base':{'op':'arg','index':0},'moves':[{'op':op}]},1)
            with self.subTest(op=op):self.assertEqual(run([x]),want);self.assertIs(type(run([x])),type(want))
        for op in ('maximum','minimum'):
            run,_,_=program_operations({'base':{'op':'arg','index':0},'moves':[{'op':op}]},1)
            with self.assertRaises(ValueError):run([[]])

    def test_parameter_and_binary_domains(self):
        for op,k,want in [('add_each',2,[1,2,5]),('multiply_each',-2,[2,0,-6]),('above',0,[3]),('below',0,[-1]),('take',2,[-1,0]),('drop',2,[3])]:
            run,_,_=program_operations({'base':{'op':'arg','index':0},'moves':[{'op':op,'constant':k}]},1)
            self.assertEqual(run([[-1,0,3]]),want)
        for op,args,want in [('add',[2,3],5),('subtract',[2,3],-1),('multiply',[-2,3],-6),('concat',[[1],[2,3]],[1,2,3]),('zip_add',[[1,2],[3]],[4]),('zip_multiply',[[1,2],[3]],[3])]:
            run,_,_=program_operations({'base':{'op':op,'left':0,'right':1},'moves':[]},2)
            self.assertEqual(run(args),want)
        for bad in [{'op':'take','constant':-1},{'op':'drop','constant':True},{'op':'add_each','constant':1001},{'op':'execute'}]:
            with self.assertRaises(ValueError):program_operations({'base':{'op':'arg','index':0},'moves':[bad]},1)
        run,_,_=program_operations({'base':{'op':'arg','index':0},'moves':[{'op':'square'}]},1)
        with self.assertRaises(ValueError):run([True])
        run,_,_=program_operations({'base':{'op':'concat','left':0,'right':1},'moves':[{'op':'sum'}]},2)
        self.assertEqual(run([[1,2],[3,4]]),10)

    def test_intermediate_work_bound(self):
        run,_,_=program_operations({'base':{'op':'arg','index':0},'moves':[{'op':'cube'}]*4},1)
        with self.assertRaises(ValueError):run([10**30])

    def test_function_name_cannot_shadow_generated_global_dependencies(self):
        for name in ('sum', 'type', 'math', 'int', 'list', 'sorted', 'zip'):
            r,p=fixture();p['function_name']=name
            with self.subTest(name=name),self.assertRaises(ValueError):validate_code(r,p)

    def test_shared_hook_requires_packet_and_loads_relocated_sibling(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory=Path(temporary)
            for filename in ('runtime_contract.py','code_evidence.py'):
                shutil.copyfile(Path(__file__).with_name(filename),directory/filename)
            spec=importlib.util.spec_from_file_location('isolated_code_contract',directory/'runtime_contract.py')
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            r,p=fixture();r['provenance']={'evidence':{'checked_computation':p}}
            checked=module.enforce_reply_evidence(r)
            self.assertEqual(checked['status'],'answered')
            self.assertEqual(checked['provenance']['evidence']['consumer_validation']['status'],'consistent')
            del r['provenance']
            self.assertEqual(module.enforce_reply_evidence(r)['status'],'withheld')
            module._code_checker.cache_clear();(directory/'code_evidence.py').unlink()
            r['provenance']={'evidence':{'checked_computation':p}}
            self.assertEqual(module.enforce_reply_evidence(r)['status'],'withheld')


if __name__=='__main__':unittest.main()
