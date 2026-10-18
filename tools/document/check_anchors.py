#!/usr/bin/env python3
"""UNTRUSTED focused measurements of the explanatory document consumer.

The source probes and evidence mutations are author-written checks, not a shipped
specialist panel. They can refute the integration; they do not prove source truth.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from anchor_answerer import AnchorAnswerer, DEFAULT_BINARY
from answerer import close_kernel


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=DEFAULT_BINARY)
    parser.add_argument('--out', type=Path, default=HERE.parents[1] / 'var/document/anchors-check.json')
    args = parser.parse_args()
    cases = json.loads((HERE / 'anchor_probes.json').read_text())['cases']
    binary_hash = hashlib.sha256(args.binary.read_bytes()).hexdigest()
    start = time.perf_counter()
    adapter = AnchorAnswerer(args.binary)
    answers = []
    try:
        for i, case in enumerate(cases):
            before = time.perf_counter()
            out = adapter.answer({'id':i,'q':case['q']})
            elapsed = (time.perf_counter() - before)*1000
            ok = not out.get('error') and (out.get('status') == 'answered') == case['answer']
            if case['answer']:
                ok = ok and case['contains'].lower() in out.get('response','').lower() and bool(out.get('cites'))
            answers.append({'case':case,'reply':out,'ok':ok,'latency_ms':elapsed})
            if i == 0:
                first_ms = (time.perf_counter()-start)*1000
        base = adapter.fetch.evidence('What causes earthquakes?')
        date_base = adapter.fetch.evidence('When was penicillin discovered?')
    finally:
        adapter.close()

    cold_start = time.perf_counter()
    cold = subprocess.Popen([sys.executable, '-I', '-B', str(HERE / 'anchor_answerer.py'),
                             '--binary', str(args.binary)], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, text=True)
    try:
        cold.stdin.write(json.dumps({'q':cases[0]['q']}) + '\n'); cold.stdin.flush()
        cold_reply = json.loads(cold.stdout.readline())
        cold_ms = (time.perf_counter() - cold_start)*1000
    finally:
        close_kernel(cold)
    cold_ok = not cold_reply.get('error') and cold_reply.get('status') == 'answered'

    mutations = []
    def check(name, evidence, expected):
        mutations.append((name,evidence,expected))
    for field in ['page_id','source_page_id','page','id']:
        ev=copy.deepcopy(base)
        for row in ev['rows']:
            row[field] = '' if field == 'id' else 'wrong'
        check('wrong_'+field,ev,'no_direct_clause')
    ev=copy.deepcopy(base);ev['aliases'].append(dict(ev['aliases'][0],page_id='wrong'))
    check('ambiguous_alias',ev,'ambiguous_anchor')
    ev=copy.deepcopy(base);ev['aliases']=[]
    check('missing_alias',ev,'missing_anchor')
    ev=copy.deepcopy(base);ev['request']['question']='What does not cause earthquakes?'
    check('question_fields_disagree',ev,'silent')
    for name,sentence in [('negated_clause','Earthquakes are not caused by moonlight.'),
                          ('other_subject','Volcanoes are caused by tectonic movements.'),
                          ('fallback_different_subject','Earthquake is caused by tectonic movements.'),
                          ('empty_clause','Earthquakes are caused by .'),
                          ('generic_cue','Moonlight is a process caused by earthquakes.')]:
        ev=copy.deepcopy(base)
        for row in ev['rows']: row['sentence']=sentence
        check(name,ev,'no_direct_clause')
    for name,sentence in [
            ('subordinate_agent_year','Penicillin was discovered by a scientist who was born in 1900.'),
            ('year_not_date','Penicillin was discovered in 1928 atlas illustrations.'),
            ('second_clause_date','Penicillin was discovered, and Fleming was born in 1881.')]:
        ev=copy.deepcopy(date_base)
        for row in ev['rows']: row['sentence']=sentence
        check(name,ev,'no_direct_clause')
    ev={'request':{'kind':'when','question':'When was Albert Einstein born?',
                   'topic':'Albert Einstein','prefix':'when was','article':'','verb':'born','punctuation':'?'},
        'aliases':[{'alias':'albert einstein','page_id':'synthetic-page','title':'Albert Einstein'}],
        'rows':[{'page_id':'synthetic-page','source_page_id':'synthetic-page','page':'Albert Einstein',
                 'id':'synthetic-claim','sentence':'Albert Einstein was born in Ulm, a city described in a 1900 atlas.'}]}
    check('incidental_city_year',ev,'no_direct_clause')
    for name,fields in [
            ('blank_matching_page',{'page_id':''}), ('blank_matching_title',{'title':''}),
            ('whitespace_matching_page',{'page_id':'   '}), ('whitespace_matching_title',{'title':'   '}),
            ('conflicting_matching_title',{'title':'Different title'})]:
        ev=copy.deepcopy(base);ev['aliases'].append(dict(ev['aliases'][0],**fields))
        check(name,ev,'ambiguous_anchor')
    ev=copy.deepcopy(base);ev['aliases'].append(dict(ev['aliases'][0]))
    check('duplicate_identical_alias',ev,'quoted_clause')
    ev=copy.deepcopy(base);ev['aliases'].append(dict(ev['aliases'][0],alias=''))
    check('unkeyed_row_outside_matching_scope',ev,'quoted_clause')
    for name,field,value in [('whitespace_citation','id','   '),('blank_sentence','sentence','')]:
        ev=copy.deepcopy(base)
        for row in ev['rows']:row[field]=value
        check(name,ev,'no_direct_clause')
    ev=copy.deepcopy(base)
    ev['request'].update(question='What causes -?',topic='-')
    ev['aliases']=[{'alias':'-','page_id':'synthetic-page','title':'-'}]
    ev['rows']=[{'page_id':'synthetic-page','source_page_id':'synthetic-page','page':'-',
                'id':'synthetic-claim','sentence':'- is caused by pressure.'}]
    check('punctuation_only_topic',ev,'silent')
    ev=copy.deepcopy(base);ev.update(resolved=False,checked=False,released=False)
    check('false_flags_do_not_override_checked_fields',ev,'quoted_clause')
    ev=copy.deepcopy(base);ev.update(resolved=True,checked=True,released=True)
    for row in ev['rows']:row['source_page_id']='wrong'
    check('true_flags_cannot_release_wrong_source_page',ev,'no_direct_clause')
    proc = subprocess.Popen([str(args.binary)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    outcomes=[]
    try:
        for name,ev,expected in mutations:
            proc.stdin.write(json.dumps(ev)+'\n');proc.stdin.flush()
            out=json.loads(proc.stdout.readline())
            ok=not out.get('error') and out.get('status')==('answered' if expected=='quoted_clause' else 'withheld') and out.get('provenance',{}).get('kernel_outcome')==expected
            outcomes.append({'name':name,'expected':expected,'reply':out,'ok':ok})
    finally:
        close_kernel(proc)
    if hashlib.sha256(args.binary.read_bytes()).hexdigest() != binary_hash:
        raise RuntimeError('binary changed during checks')
    report={'binary':str(args.binary.resolve()), 'binary_sha256':binary_hash,
            'scope':'Author-written source questions and raw evidence mutations; no specialist panel score',
            'questions':answers,'mutations':outcomes,'question_assertions_passed':sum(x['ok'] for x in answers),
            'question_total':len(answers), 'source_answers':sum(x['reply'].get('status')=='answered' for x in answers),
            'source_withheld':sum(x['reply'].get('status')!='answered' and not x['reply'].get('error') for x in answers),
            'source_errors':sum(bool(x['reply'].get('error')) for x in answers), 'mutation_total':len(outcomes),
            'mutation_passed':sum(x['ok'] for x in outcomes),'in_process_setup_first_reply_ms':first_ms, 'fresh_process_first_reply_ms':cold_ms,
            'fresh_process_answered':cold_ok, 'binary_bytes':args.binary.stat().st_size,
            'warm_p50_ms':statistics.median(x['latency_ms'] for x in answers[1:])}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('questions','mutations')},indent=2))
    raise SystemExit(0 if cold_ok and all(x['ok'] for x in answers+outcomes) else 1)

if __name__=='__main__': main()
