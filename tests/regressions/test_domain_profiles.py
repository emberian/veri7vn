"""Source-profile counterexamples and existing repairs to retain; local only."""
import importlib.util
import contextlib
import re
from types import SimpleNamespace
from itertools import product
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]

def load(relative):
    p=ROOT/'upstream/root/specialists'/relative
    sys.path.insert(0,str(p.parent))
    try:
        spec=importlib.util.spec_from_file_location('audit_'+p.parent.name.replace('-','_'),p)
        m=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        return m
    finally:sys.path.remove(str(p.parent))

class DomainProfileCases(unittest.TestCase):
    def test_negative_edge_is_silently_omitted(self):
        organ=load('algorithms/organ_algorithms_v1.py').AlgorithmsOrgan()
        q='What is the shortest path from A to C with edges A-B 1, B-C -2, A-C 4?'
        r=organ.answer(q)
        self.assertEqual(r['kind'],'shortest_path')
        self.assertEqual(r['value'],4)
        _,parsed=organ._graph(q)
        self.assertEqual(len(parsed),2)
        # Independently supplied graph has A-B-C of cost -1. Required repair
        # rejects the negative-edge model rather than pretending the edge absent.
        self.assertEqual(1+(-2),-1)
        self.assertLess(-1,r['value'])

    def test_directed_edges_accepted_as_mst(self):
        organ=load('algorithms/organ_algorithms_v1.py').AlgorithmsOrgan()
        r=organ.answer('Find the minimum spanning tree: A->B 2, C->B 1')
        self.assertEqual(r['kind'],'mst')
        self.assertEqual(r['value'],3)
        # No vertex reaches all others in the supplied directed graph. An
        # undirected MST result requires a declared/adopted undirected model.
        adjacency={'A':{'B'},'B':set(),'C':{'B'}}
        for start in adjacency:
            reachable={start};frontier=[start]
            while frontier:
                for node in adjacency[frontier.pop()]-reachable:
                    reachable.add(node);frontier.append(node)
            self.assertNotEqual(reachable,set(adjacency))

    def test_impossible_die_face_receives_positive_probability(self):
        organ=load('games-v3/organ_games_v3.py').GamesOrganV3()
        r=organ.answer('What is the probability of at least one 7 in 2 rolls of a 6-sided die?')
        self.assertEqual(r['kind'],'at_least_one')
        self.assertGreater(r['value'],0)
        outcomes=list(product(range(1,7),repeat=2))
        self.assertEqual(sum(7 in outcome for outcome in outcomes),0)
        self.assertEqual(len(outcomes),36)

    def test_real_wrapper_preserves_decline_but_drops_typed_value(self):
        combo=load('_gate/combo_runtime_v1.py')
        folder=ROOT/'upstream/root/specialists/algorithms'
        wrapper=combo._Organ(str(folder/'manifest.json'),str(folder))
        declined=wrapper.reply('Binary search for 2 in [3,1,2]')
        self.assertEqual(declined['status'],'withheld')
        self.assertEqual(declined['kind'],'unsorted')
        answer=wrapper.reply('Sort [3,1,2] ascending')
        self.assertEqual(answer['status'],'answered')
        self.assertEqual(answer['kind'],'sorted')
        self.assertNotIn('value',answer)
        with combo.CALL_LOCK,wrapper._env():
            direct=wrapper.organ.answer('Sort [3,1,2] ascending')
        self.assertEqual(direct['value'],[1.0,2.0,3.0])

    def test_wrapper_internal_typeerror_retries_effectful_answer(self):
        combo=load('_gate/combo_runtime_v1.py')
        effects=[]
        def answer(*args):
            effects.append('local mock effect')
            raise TypeError('internal failure after mock effect')
        wrapper=object.__new__(combo._Organ)
        wrapper.organ=SimpleNamespace(answer=answer)
        wrapper._env=contextlib.nullcontext
        wrapper.id='fixture';wrapper.kinds={'action'};wrapper.declines=set();wrapper.ctx=re.compile('fixture')
        self.assertIsNone(wrapper.reply('fixture'))
        self.assertEqual(len(effects),2)
        # Signature adaptation may not retry after invocation has already begun;
        # internal TypeError must remain failure/unknown effect, not dispatch again.

    def test_statistics_v2_preserves_order_repair(self):
        m=load('statistics-v2/organ_stats_v2.py')
        q='How many ways to choose 12 from 5?'
        self.assertEqual(m.StatsOrgan().answer(q)['value'],792)
        repaired=m.StatsOrganV2().answer(q)
        self.assertEqual(repaired['status'],'withheld')
        self.assertEqual(repaired['kind'],'impossible')
        # Existing source repair must survive migration; never restore V1's
        # input-order swap merely because combinations is symmetric in labels.

if __name__=='__main__':unittest.main()
