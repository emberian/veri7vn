"""Exercise original control-flow bodies with inert local dependency doubles.

These demonstrate scoped component behavior, not the full inherited application.
The execution never imports the upstream app, acquires data, or runs a command.
"""
import ast
from pathlib import Path
import threading
import re
from types import SimpleNamespace
import unittest

ROOT=Path(__file__).resolve().parents[2]
ADMITTED=ROOT/'upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted'

def definitions(filename,names,env):
    p=ADMITTED/filename
    tree=ast.parse(p.read_text())
    nodes=[n for n in tree.body if isinstance(n,(ast.FunctionDef,ast.ClassDef)) and n.name in names]
    assert {n.name for n in nodes}==set(names)
    exec(compile(ast.Module(body=nodes,type_ignores=[]),str(p),'exec'),env)
    return env

class DispatchCases(unittest.TestCase):
    def runtime(self,parent_reply,family_reply=None,network_reply=None,narrowed=False):
        events=[]
        class Parent:
            def chat(self,text,session_id='default'):
                events.append(('parent',text,session_id))
                return parent_reply
        class Family:
            def reply(self,text,session_id):
                events.append(('family',text,session_id))
                if isinstance(family_reply,Exception):raise family_reply
                return family_reply
        class Network:
            def solve(self,text):
                events.append(('network',text))
                return network_reply or {'status':'declined'}
        env=definitions('oracle_release_runtime_w525.py',{'_c525_lacks','OracleReleaseRuntimeW525'},
            {'_Base':Parent,'DELIBERATE':('does_not_follow','out_of_fragment','validity'),
             '_c525_narrowed_silent':lambda path,text:narrowed,
             '_c525_family':lambda:Family(),'_c525_network':lambda:Network()})
        return env['OracleReleaseRuntimeW525'](),events

    def test_deliberate_blocker_prevents_fallback(self):
        old={'status':'withheld','path':'logic>validity','response':'not valid'}
        rt,events=self.runtime(old,{'status':'answered','response':'unsafe fallback'})
        self.assertIs(rt.chat('question','s'),old)
        self.assertEqual([e[0] for e in events],['parent'])

    def test_different_fallback_after_unscoped_withholding(self):
        old={'status':'withheld','path':'unknown','response':'unknown'}
        rt,events=self.runtime(old,{'status':'answered','path':'organ','response':'scoped answer','provenance':{'specialist':'fixture'}})
        r=rt.chat('question','s')
        self.assertEqual([e[0] for e in events],['parent','family'])
        self.assertEqual(events[1][2],'core:s')
        self.assertEqual(r['status'],'answered')
        self.assertEqual(r['provenance']['core_path'],'unknown')

    def test_family_disagreement_allows_network(self):
        old={'status':'withheld','path':'unknown'}
        rt,events=self.runtime(old,{'status':'disagree'}, {'status':'answered','response':'network result'})
        r=rt.chat('question')
        self.assertEqual([e[0] for e in events],['parent','family','network'])
        self.assertEqual(r['provenance']['kind'],'specialist_network_v3')

    def test_narrowing_error_restores_old_answer(self):
        # Actual exception path defeats the intended narrowing if family load fails.
        old={'status':'answered','path':'specialist_call>specialist:ocean>pressure','response':'old questionable answer'}
        rt,events=self.runtime(old,RuntimeError('local mock load failure'),narrowed=True)
        self.assertIs(rt.chat('question'),old)
        self.assertEqual([e[0] for e in events],['parent','family'])
        # Required replacement: retain a scoped dependency/narrowing blocker;
        # failing fallback acquisition must not resurrect suppressed authority.

    def test_narrowing_without_error_withholds(self):
        old={'status':'answered','path':'specialist_call>specialist:ocean>pressure','response':'old questionable answer'}
        rt,events=self.runtime(old,narrowed=True)
        r=rt.chat('question')
        self.assertEqual([e[0] for e in events],['parent','family','network'])
        self.assertEqual(r['status'],'withheld')
        self.assertEqual(r['provenance']['withheld_response'],old['response'])

    def test_context_adopts_numeric_result_before_outer_rejection(self):
        p=ROOT/'upstream/root/wander-train/chat_context_v2.py'
        tree=ast.parse(p.read_text())
        selected={'Turn','state','_result_of_reply','update'}
        globals_to_keep={'STATE_CAP','_STATES','WH','TYPED','NUM_UNIT','SOLVED','MATERIAL'}
        nodes=[n for n in tree.body if (isinstance(n,(ast.ClassDef,ast.FunctionDef)) and n.name in selected) or
               (isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in globals_to_keep for t in n.targets))]
        env={'re':re,'recognised':lambda text:False,'_entity_of_question':lambda text:None,
             '_entity_of_reply':lambda text,prefer_person=False:None}
        exec(compile(ast.Module(body=nodes,type_ignores=[]),str(p),'exec'),env)
        cc=SimpleNamespace(split_parts=lambda text:None,rewrite=lambda sid,text:None,
                           update=env['update'],UNRESOLVED='__unresolved__')
        class Parent:
            def chat(self,text,session_id='default'):
                return {'status':'answered','path':'organ:math>evaluate',
                        'response':'The answer is 0. Checked: read 0; then evaluate'}
        inner=definitions('oracle_release_runtime_w529.py',{'OracleReleaseRuntimeW529'},
                          {'_Base':Parent,'_CC':cc})['OracleReleaseRuntimeW529']
        outerp=ADMITTED/'oracle_release_runtime_w540.py'
        outertree=ast.parse(outerp.read_text())
        outer_nodes=[n for n in outertree.body if isinstance(n,(ast.FunctionDef,ast.ClassDef,ast.Assign))]
        outerenv={'_Base':inner,'re':re}
        exec(compile(ast.Module(body=outer_nodes,type_ignores=[]),str(outerp),'exec'),outerenv)
        q='A 5 kg cube has density 0 kg/m3. What is its volume?'
        result=outerenv['OracleReleaseRuntimeW540']().chat(q,'fixture')
        self.assertEqual(result['status'],'withheld')
        self.assertTrue(result['path'].startswith('precision_guard:N2'))
        state=env['state']('fixture')
        self.assertEqual(state.q,q)
        self.assertEqual(state.result,(0.0,''))
        # Original update and outer guard really executed with local reader doubles:
        # answer-derived numeric state survived final rejection. Transcript storage
        # may remain; authoritative adopted result must wait for final arbitration.

    def test_multipart_reports_answered_for_incomplete_whole(self):
        p=ADMITTED/'oracle_release_runtime_w533.py'
        tree=ast.parse(p.read_text())
        keep={'THOUSANDS','MULTI','PARTS_PATHS','QSTART'}
        nodes=[n for n in tree.body if (isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in keep for t in n.targets)) or
               (isinstance(n,ast.FunctionDef) and n.name=='unthousand') or
               (isinstance(n,ast.ClassDef) and n.name=='OracleReleaseRuntimeW533')]
        env={'_Base':object,'re':re}
        exec(compile(ast.Module(body=nodes,type_ignores=[]),str(p),'exec'),env)
        rt=env['OracleReleaseRuntimeW533']()
        def one(q,sid):
            if '#and0' in sid:return {'status':'answered','path':'fixture:first','response':'first answer'}
            return {'status':'withheld','path':'fixture:dependency','response':'missing dependency'}
        rt._c533_one=one
        result=rt.chat('What is first and what is second?','fixture')
        self.assertEqual(result['status'],'answered')
        self.assertEqual(result['path'],'chat:and_parts>1 of 2')
        self.assertEqual(len(result['provenance']['parts']),2)
        self.assertIsNone(result['provenance']['parts'][1]['path'])
        self.assertNotIn('status',result['provenance']['parts'][1])
        self.assertIn("can't verify",result['response'])
        # Partial display is useful. Replacement must retain each outcome/blocker
        # and restrict any whole-answer claim to the completed part.

    def test_timed_out_worker_still_finishes(self):
        env=definitions('oracle_release_runtime_w480.py',{'_run'}, {'threading':threading,'BUDGET_S':0.01})
        started,release,finished=threading.Event(),threading.Event(),threading.Event()
        def worker():
            started.set()
            release.wait(1)
            finished.set()
        try:
            self.assertIsNone(env['_run'](worker))
            self.assertTrue(started.is_set())
            self.assertFalse(finished.is_set())
        finally:
            release.set()
            self.assertTrue(finished.wait(1))
        # Source timeout abandons result, not work. Native publication must
        # independently recheck cancellation/epoch before any state/effect.

if __name__=='__main__':unittest.main()
