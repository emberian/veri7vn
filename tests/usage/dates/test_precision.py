"""Narrow metadata, rendering, importer and date-order regressions; no panel claim."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(os.environ.get('DATE_TEST_SOURCE', ROOT/'var/ap1-upstream-slim/root/wander-train'))
sys.path.insert(0, str(SOURCE))
import date_precision_v1 as D
import knowledge_composer_v1 as K
spec = importlib.util.spec_from_file_location('date_importer', ROOT/'tools/usage/dates/import_precision.py')
I = importlib.util.module_from_spec(spec); spec.loader.exec_module(I)
G, J = list(D.CALENDARS)
LITERAL = '1919-01-01T00:00:00Z'


def statement(time='+1919-01-01T00:00:00Z', precision=11, calendar=G, literal=LITERAL, rank='normal', qualifiers=None, id='Q1$abc'):
    t={'time':time,'precision':precision,'calendarmodel':calendar,'timezone':0,'before':0,'after':0}
    return {'id':id,'rank':rank,'mainsnak':{'property':'P569','snaktype':'value','datatype':'time','datavalue':{'type':'time','value':t}},
            'rdf_time':{'timeValue':literal,'timePrecision':str(precision),'timeCalendarModel':calendar,'timeTimezone':'0'},
            'qualifiers':qualifiers or {},'references':[]}


def item(qid):
    return {'snaktype':'value','datavalue':{'type':'wikibase-entityid','value':{'id':qid}}}


class PrecisionTests(unittest.TestCase):
    def setUp(self):
        self.old=D._CACHE
        self.bind([statement()])

    def tearDown(self):
        D._CACHE=self.old

    def bind(self, statements, literal=LITERAL):
        D._CACHE={('Q1','P569'):{'subject':'Q1','property':'P569','statements':statements,
            'bindings':[{'legacy_literal':s['rdf_time']['timeValue'],'statement_id':s['id']} for s in statements],
            'source':{'revision':1}}}

    def render(self,q='When was X born?',literal=LITERAL):
        return D.render(literal,q,1,569)

    def test_true_january_first_preserved(self):
        self.assertEqual(self.render(),'1 January 1919 (Gregorian calendar)')

    def test_precision_is_not_inferred_from_day_one(self):
        self.bind([statement(precision=9)])
        self.assertEqual(self.render(),'1919 (Gregorian calendar; month and day unspecified)')

    def test_month_precision_returns_supported_month_even_for_exact_day_question(self):
        self.bind([statement('+1564-04-00T00:00:00Z',10,J)])
        self.assertEqual(self.render('What is the exact birth date?'),'April 1564 (Julian calendar; day unspecified)')

    def test_requested_year_does_not_require_day(self):
        self.assertEqual(self.render('In what year was X born?'),'1919 (Gregorian calendar)')

    def test_historical_bce_comes_from_json_not_rdf(self):
        self.bind([statement('-0106-01-03T00:00:00Z',11,J)])
        self.assertEqual(self.render(),'3 January 106 BCE (Julian calendar)')

    def test_century_is_not_an_exact_year(self):
        self.bind([statement('-0650-00-00T00:00:00Z',7,J,qualifiers={'P4241':[item('Q40719766')]})])
        self.assertEqual(self.render(),'7th century BCE (Julian calendar); date refinement: end of')

    def test_preferred_rank_and_requested_calendar(self):
        a=statement('+1642-12-25T00:00:00Z',11,J,rank='preferred')
        b=statement('+1643-01-04T00:00:00Z',11,G,id='Q1$def')
        self.bind([a,b])
        self.assertIn('25 December 1642 (Julian',self.render())
        self.assertIn('4 January 1643 (Gregorian',self.render('When, in the Gregorian calendar?'))

    def test_deprecated_statement_never_becomes_birth_date(self):
        self.bind([statement(rank='deprecated')])
        self.assertIn('unavailable',self.render())

    def test_mismatched_preferred_record_does_not_promote_normal(self):
        self.bind([statement(),statement(rank='preferred',literal='1920-01-01T00:00:00Z',id='Q1$new')])
        self.assertIn('unavailable',self.render())

    def test_missing_context_or_different_subject_does_not_borrow_precision(self):
        self.assertIn('unavailable',D.render(LITERAL))
        self.assertIn('unavailable',D.render(LITERAL,'',2,569))
        self.assertIn('unavailable',self.render(literal='1919-01-02T00:00:00Z'))

    def test_rdf_json_mismatch_does_not_render_exact(self):
        s=statement();s['rdf_time']['timePrecision']='9';self.bind([s])
        self.assertIn('unavailable',self.render())

    def test_calendar_unknown_is_visible(self):
        self.bind([statement(calendar='http://example.invalid/calendar')])
        self.assertIn('unavailable',self.render())

    def test_circa_qualifier_visible_and_not_used_for_order(self):
        self.bind([statement('+1098-00-00T00:00:00Z',9,J,qualifiers={'P1480':[item('Q5727902')]})])
        self.assertIn('sourcing circumstances: circa',self.render())
        self.assertIsNone(D.interval(LITERAL,1,569))

    def test_unrecognized_qualifier_is_retained_and_blocks_order(self):
        self.bind([statement(qualifiers={'P9999':[item('Q42')]})])
        self.assertIn('P9999: Q42',self.render())
        self.assertIsNone(D.interval(LITERAL,1,569))

    def test_nonzero_uncertainty_is_visible_and_blocks_order(self):
        s=statement();s['mainsnak']['datavalue']['value']['before']=1;self.bind([s])
        self.assertIn('before=1',self.render());self.assertIsNone(D.interval(LITERAL,1,569))

    def test_invalid_gregorian_leap_day_does_not_render(self):
        self.bind([statement('+1900-02-29T00:00:00Z',11,G)])
        self.assertIn('unavailable',self.render())
        self.bind([statement('+1900-02-29T00:00:00Z',11,J)])
        self.assertIn('29 February 1900 (Julian',self.render())

    def test_non_dates_unchanged(self):
        self.assertEqual(D.render('Warsaw','',1,19),'Warsaw')

    def test_month_and_year_intervals_include_unknown_days(self):
        self.bind([statement('+1564-04-00T00:00:00Z',10,J)])
        self.assertEqual(D.interval(LITERAL,1,569),(J,(1564,4,1),(1564,4,30)))
        self.bind([statement('+1564-00-00T00:00:00Z',9,J)])
        self.assertEqual(D.interval(LITERAL,1,569),(J,(1564,1,1),(1564,12,31)))

    def test_earliest_latest_bounds_preserved(self):
        def bound(time):
            return {'snaktype':'value','datavalue':{'type':'time','value':statement(time,9,J)['mainsnak']['datavalue']['value']}}
        self.bind([statement('-0650-00-00T00:00:00Z',7,J,qualifiers={'P1319':[bound('-0630-00-00T00:00:00Z')],'P1326':[bound('-0612-00-00T00:00:00Z')]})])
        self.assertIn('earliest date: 630 BCE',self.render());self.assertIn('latest date: 612 BCE',self.render())
        self.assertEqual(D.interval(LITERAL,1,569),(J,(-629,1,1),(-611,12,31)))

    def test_order_requires_nonoverlap_and_same_calendar(self):
        def run(ia,ib):
            with patch.object(K,'_exact',side_effect=[1,2]),patch.object(K,'_date',side_effect=[(569,[LITERAL],ia),(569,[LITERAL],ib)]),patch.object(K.R,'label',side_effect=lambda x:str(x)),patch.object(K.R,'_load',return_value={'plabel':{569:'birth date'}}):
                return K.order('Who is older, A or B?')
        self.assertIsNone(run((G,(1900,1,1),(1900,12,31)),(G,(1900,4,1),(1900,4,30))))
        self.assertIsNone(run((G,(1800,1,1),(1800,1,1)),(J,(1900,1,1),(1900,1,1))))
        self.assertEqual(run((G,(1800,1,1),(1800,12,31)),(G,(1900,1,1),(1900,12,31)))['answer'],'1')


    def test_malformed_valid_json_shapes_fail_closed(self):
        base={'schema':'oracle7-date-precision-v1','version':1,'records':[]}
        bad_records=[None,{}, {'subject':'Q1','property':'P569','statements':[None],'bindings':[]},
                     {'subject':'Q1','property':'P569','statements':[],'bindings':[None]},
                     {'subject':'Q1','property':'P569','statements':{},'bindings':[]}]
        documents=[[],None,'text',17,dict(base,records=[None])]
        documents += [dict(base,records=[record]) for record in bad_records]
        with tempfile.TemporaryDirectory(prefix='date-shape-') as folder:
            path=Path(folder)/'sidecar.json'
            for document in documents:
                with self.subTest(document=document):
                    path.write_text(json.dumps(document));D._CACHE=None
                    with patch.dict(os.environ,{'ORACLE7_DATE_PRECISION':str(path)}):
                        self.assertIn('unavailable',self.render())
                        self.assertFalse(D.available(LITERAL,'',1,569))

    def test_malformed_used_nested_fields_fail_closed(self):
        for field,value in [('mainsnak',None),('mainsnak',[]),('rdf_time',None),('rdf_time',[]),('qualifiers',[None])]:
            with self.subTest(field=field,value=value):
                s=statement();s[field]=value
                self.bind([statement()])
                D._CACHE[('Q1','P569')]['statements']=[s]
                self.assertIn('unavailable',self.render())
                self.assertFalse(D.available(LITERAL,'',1,569))

    def test_missing_metadata_specialist_uses_decline_contract(self):
        import relation_spec_v2 as S
        D._CACHE = {}
        with patch.object(S,'slot_candidates',return_value=([1],[100])),patch.object(S,'in_domain',return_value=True),patch.object(S.V1,'values',return_value=frozenset([LITERAL])):
            reply=S.answer('When was Example Person born?','actors',[569])
        self.assertTrue(reply['decline'])
        self.assertEqual(reply['reason'],'date_precision_unavailable')
        self.assertNotIn('answer',reply)

    def test_missing_metadata_reach_does_not_assert_a_timestamp(self):
        R=K.R
        D._CACHE = {}
        with patch.object(R,'fragment',return_value=False),patch.object(R,'unexplained',return_value=[]),patch.object(R,'values',return_value={LITERAL}):
            self.assertEqual(R._agree('When was Example Person born?','Example Person',[(1,100,'Example Person')],569,'fwd'),(None,None))

    def test_missing_metadata_exact_router_does_not_revive_date(self):
        from types import SimpleNamespace
        X=K.R.XR
        D._CACHE = {}
        store=SimpleNamespace(props_of=lambda qid:[(569,None,LITERAL)])
        with patch.object(X,'_load',return_value=({('when','*'):569},store)),patch.object(X.L,'link',return_value=[('Example Person',[(1,100,'Example Person')])]),patch.object(X,'hop',return_value=False),patch.object(X,'subject_ok',return_value=True),patch.object(X,'features',return_value={('when','*')}):
            self.assertIsNone(X.answer('When was Example Person born?'))


class ActiveComparisonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Load only the edited consumer method: no engine, stores or parent chain.
        import ast
        import re
        import time
        admitted=SOURCE.parent/'fable-content/oracle-m-series-2026-08-15/self_loop/admitted'
        sys.path.insert(0,str(admitted))
        path=admitted/'oracle_release_runtime_w426.py'
        tree=ast.parse(path.read_text())
        assignments=[n for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ('CMP_EARLIER','CMP_FIRST') for t in n.targets)]
        klass=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='OracleReleaseRuntimeW426')
        method=next(n for n in klass.body if isinstance(n,ast.FunctionDef) and n.name=='_c426_compare')
        namespace={'re':re,'time':time}
        exec(compile(ast.Module(body=assignments+[method],type_ignores=[]),str(path),'exec'),namespace)
        cls.compare=staticmethod(namespace['_c426_compare'])

    def setUp(self):
        from types import SimpleNamespace
        self.consumer=SimpleNamespace(_c426_answer=lambda res,text,refs,prov,t0:dict(status='answered',response=text,references=refs,provenance=prov),
            _c426_first_sentence=lambda *a: self.fail('unrelated prose dates must not be read'))
        self.res={'status':'withheld','response':'old','path':'unverified:factoid','references':[{'id':'old','text':'old'}]}

    def test_active_consumer_uses_contextual_dates_not_unrelated_prose_years(self):
        value={'answer':'A','receipt':'A birth April 1564; B birth December 1642',
               'steps':[{'subject_qid':1,'property':569,'display':'April 1564; day unspecified'},
                        {'subject_qid':2,'property':569,'display':'25 December 1642'}]}
        with patch.object(K,'order',return_value=value):
            out=self.compare(self.consumer,'Who is older, Alice or Bob?',self.res,0)
        self.assertEqual(out['status'],'answered')
        self.assertIn('day unspecified',out['references'][0][1])
        self.assertEqual(out['provenance']['method'],'source_date_intervals')
        self.assertNotIn('by 78 years',out['response'])

    def test_unknown_dates_produce_terminal_refusal_not_prose_fallback(self):
        from runtime_refusal_guard import terminal_refusal
        with patch.object(K,'order',return_value=None):
            out=self.compare(self.consumer,'Who is older, Alice or Bob?',self.res,0)
        self.assertEqual(out['status'],'withheld');self.assertTrue(terminal_refusal(out))
        self.assertEqual(out['references'],[])

    def test_reader_failure_cannot_revive_prose_years(self):
        with patch.object(K,'order',side_effect=ValueError('invalid metadata')):
            out=self.compare(self.consumer,'Who is older, Alice or Bob?',self.res,0)
        self.assertTrue(out['refusal']['terminal'])

    def test_unrelated_both_question_does_not_enter_date_comparison(self):
        with patch.object(K,'order',side_effect=AssertionError('not a date comparison')):
            self.assertIsNone(self.compare(self.consumer,'Are A and B both novelists?',self.res,0))

    def test_explicit_birth_order_requires_birth_property(self):
        with patch.object(K,'_exact',side_effect=[1,2]),patch.object(K,'_date',side_effect=[(577,[LITERAL],(G,(1900,1,1),(1900,1,1))),(577,[LITERAL],(G,(2000,1,1),(2000,1,1))) ]):
            self.assertIsNone(K.order('Who was born earlier, A or B?'))

    def test_birth_order_and_plain_order_select_same_supported_event(self):
        def run(question):
            with patch.object(K,'_exact',side_effect=[1,2]),patch.object(K,'_date',side_effect=[(569,[LITERAL],(G,(1900,1,1),(1900,1,1))),(569,[LITERAL],(G,(2000,1,1),(2000,1,1)))]),patch.object(K.R,'label',side_effect=lambda x:str(x)),patch.object(K.R,'_load',return_value={'plabel':{569:'birth date'}}):
                return K.order(question)
        self.assertEqual(run('Who was born earlier, A or B?')['answer'],'1')
        self.assertEqual(run('Who was born later, A or B?')['answer'],'2')


class ImportTests(unittest.TestCase):
    def test_no_binding_from_a_similar_timestamp(self):
        s=statement();entity={'id':'Q1','claims':{'P569':[s]}}
        rdf={(s['id'].lower(),'P569'):s['rdf_time']}
        r=I.compile_record(entity,'P569',rdf,{'1919-01-02T00:00:00Z'},{})
        self.assertEqual(r['bindings'],[])
        self.assertEqual(len(r['statements']),1)

    def test_source_metadata_disagreement_rejected(self):
        s=statement();rdf=copy.deepcopy(s['rdf_time']);rdf['timePrecision']='9'
        with self.assertRaises(ValueError):
            I.compile_record({'id':'Q1','claims':{'P569':[s]}},'P569',{(s['id'].lower(),'P569'):rdf},{LITERAL},{})

    def test_rdf_snapshot_revision_must_match(self):
        data=b'<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:s="http://schema.org/"><rdf:Description><s:version>1</s:version></rdf:Description></rdf:RDF>'
        with self.assertRaises(ValueError):I.rdf_times(data,'Q1',['P569'],2)

    def test_full_deprecated_claim_and_qualifiers_retained(self):
        s=statement(rank='deprecated',qualifiers={'P1480':[item('Q5727902')]});e={'id':'Q1','claims':{'P569':[s]}}
        r=I.compile_record(e,'P569',{(s['id'].lower(),'P569'):s['rdf_time']},{LITERAL},{})
        self.assertEqual(r['statements'][0],s)


if __name__=='__main__':unittest.main()
