"""Independent fixtures: these are not specialist panels or model evidence."""
import importlib.util
from pathlib import Path
import unittest

PATH=Path(__file__).resolve().parents[2]/'tools/research/binding_readout/pipeline.py'
spec=importlib.util.spec_from_file_location('binding_readout',PATH)
b=importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


def fixture():
    text='Ada, Ben, Cy; owner, maker, editor. Ben, rather than Ada, owns the blue vase.'
    def span(s):
        a=text.index(s)
        return dict(start=a,end=a+len(s),text=s)
    return dict(id='independent',group='independent',split='test_prose',origin='author_written',
                text=text,entities=list(map(span,['Ada','Ben','Cy'])),
                roles=list(map(span,['owner','maker','editor'])),
                values=[span('blue vase')],labels=[[1,0]])


class BindingTests(unittest.TestCase):
    def test_independent_reverse_binding(self):
        import numpy as np
        d=fixture()
        p=np.zeros((1,9)); p[0,3]=1
        out=b.bridge(d,p)
        self.assertEqual(out['bindings'][0]['entity']['text'],'Ben')
        self.assertEqual(out['bindings'][0]['role']['text'],'owner')
        self.assertEqual(out['coverage'],'unknown')
        self.assertEqual(b.metrics([d],[p])['complete_table_accuracy'],1)
        p[0,3]=0; p[0,0]=1
        self.assertEqual(b.metrics([d],[p])['wrong_binding_rate'],1)

    def test_uncertain_declines(self):
        import numpy as np
        d=fixture(); p=np.full((1,9),1/9)
        self.assertEqual(b.bridge(d,p)['bindings'],[])
        self.assertIsNone(b.metrics([d],[p])['tuple_precision'])

    def test_span_integrity(self):
        d=fixture(); d['values'][0]['start']+=1
        with self.assertRaises(ValueError): b.validate(d)

    def test_paraphrase_groups_do_not_leak(self):
        docs=list(b.generate(2)); groups={}
        for d in docs:
            b.validate(d)
            self.assertEqual(groups.setdefault(d['group'],d['split']),d['split'])
        train={s['text'] for d in docs if d['split']=='train' for s in d['entities']}
        held={s['text'] for d in docs if d['split']=='test_names' for s in d['entities']}
        self.assertFalse(train & held)

    def test_features_have_no_label_access(self):
        import numpy as np
        d=fixture()
        for mode in ['position','bow']:
            x=b.token_features(d,mode)
            d['labels']=[[2,2]]
            np.testing.assert_array_equal(x,b.token_features(d,mode))

    def test_fit_generalizes_independent_separable_points(self):
        import numpy as np
        x=np.repeat(np.eye(9),3,axis=0)
        y=np.repeat(np.array([(i//3,i%3) for i in range(9)]),3,axis=0)
        head=b.fit(x,y,penalty=.1)
        self.assertEqual(b.predict(head,np.eye(9)*.9).argmax(1).tolist(),list(range(9)))

if __name__=='__main__': unittest.main()
