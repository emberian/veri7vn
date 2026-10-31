"""Manufactured replies for adapter checks; no real-host panel results."""
import copy
import importlib.util
import sys
from pathlib import Path
import unittest
PATH=Path(__file__).resolve().parents[2]/'sequence_translation.py'
sys.path.insert(0,str(PATH.parent))
SPEC=importlib.util.spec_from_file_location('translation_client_test',PATH)
client=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(client)

class Consumer(unittest.TestCase):
    def args(self):
        return {'source':{'schema':client.SOURCE_SCHEMA,'records':[{'label':'source','sequence':'AACATGGGCATCC'}]},
                'features':[{'label':'declared','record_index':0,'start':2,'end':11,'strand':'reverse','frame':0}],
                'genetic_code':client.CODE_ID,'initiation':'literal_codon','remainder':'reject','stops':'include','ambiguity':'reject'}
    def result(self,args):
        source,request=client.identities(args)
        return {'schema':client.SCHEMA,'source_sha256':source,'request_sha256':request,
                'genetic_code':client.CODE_ID,'genetic_code_source':client.CODE_SOURCE,
                **{k:args[k] for k in ('initiation','remainder','stops','ambiguity')},
                'translations':client.reference(args),'complete':True,'codons_examined':3}
    def test_original_reverse_coordinate_check(self):
        got=client.translate(self.result,self.args())['result']['translations'][0]
        self.assertEqual(got['protein'],'MPM')
        self.assertEqual([(c['source']['start'],c['source']['end']) for c in got['codons']],[(8,11),(5,8),(2,5)])
    def test_bad_identity_mapping_table_and_completion_are_rejected(self):
        for mutate in (lambda r:r.update(source_sha256='0'*64),lambda r:r.update(request_sha256='0'*64),
                       lambda r:r.update(complete=False),lambda r:r['translations'][0]['codons'][0]['source'].update(start=7),
                       lambda r:r['translations'][0].update(protein='MMM'),lambda r:r.update(codons_examined=2),
                       lambda r:r['translations'][0]['codons'][0].update(amino_acid_index=False),
                       lambda r:r['translations'][0]['codons'][0]['source'].update(start=8.0)):
            def invoke(args):
                result=self.result(args);mutate(result);return result
            with self.assertRaises(ValueError):client.translate(invoke,self.args())
    def test_iupac_is_unknown_not_set_resolved_and_stop_policy_explicit(self):
        args=self.args();args['source']['records'][0]['sequence']='GCNTAR'
        args['features'][0].update(start=0,end=6,strand='forward');args['ambiguity']='unknown'
        self.assertEqual(client.reference(args)[0]['protein'],'XX')
        args['source']['records'][0]['sequence']='ATGTAA';args['stops']='terminate'
        got=client.reference(args)[0];self.assertEqual(got['protein'],'M');self.assertEqual(got['termination_stop']['source']['start'],3)
    def test_bad_frames_unsupported_tables_and_ambiguous_reject_never_call_host(self):
        for edit in (lambda a:a.update(genetic_code='mitochondrial'),lambda a:a['features'][0].update(frame=3),
                     lambda a:a['source']['records'][0].update(sequence='N'*13)):
            args=copy.deepcopy(self.args());edit(args)
            with self.assertRaises(ValueError):client.translate(lambda _:self.fail('must not call host'),args)

    def test_transport_outage_does_not_score_as_a_valid_input_refusal(self):
        def load(name,file):
            spec=importlib.util.spec_from_file_location(name,Path(__file__).with_name(file))
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
        Organ=load('translation_outage_organ','organ_translation.py').Organ
        ok=load('translation_outage_scorer','scorer.py').ok
        organ=Organ()
        def offline(_):
            raise OSError('manufactured host outage')
        organ.client.invoke=offline
        args=self.args()
        reply=organ.answer('Translate supplied coding intervals: '+client.compact(args),'test')
        self.assertEqual(reply['reason'],'execution_failure')
        self.assertEqual(ok({'valid':False},reply),(False,False))
        args['features'][0]['frame']=3
        refusal=organ.answer('Translate supplied coding intervals: '+client.compact(args),'test')
        self.assertEqual(refusal['reason'],'invalid_input')
        self.assertEqual(ok({'valid':False},refusal),(True,False))

if __name__=='__main__':unittest.main()
