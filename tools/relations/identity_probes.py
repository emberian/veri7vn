#!/usr/bin/env python3
"""Authored identity/coverage policy checks and source-relative capability probes.

Not a shipped panel or a proof of source truth. Meaningful questions that require
clarification/withholding remain unanswered-valid, even when a policy test passes.
"""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from answerer import close_kernel
from frontdoor import FrontDoor
from request_probes import candidate, QUESTIONS as PRIOR_QUESTIONS


def raw_cases():
    target = candidate(101, "Target")
    actor = candidate(102, "Actor", [33999], [[26, ["e", 101]]])
    e = {"id": "raw", "spec": "rel-actors", "kind_conflict": False, "past": False,
         "qwords": [], "vwords": [], "subject_constraint": ["occupation", [33999]],
         "subject_excluded_properties": [], "attempts": [{"key": "26", "dir": "inv", "idx": 0,
          "slot_ok": True, "capped": False, "candidates": [target], "subjects": [actor]}]}
    yield "raw identity edge supports requested actor", copy.deepcopy(e), "answer"
    other = copy.deepcopy(e); other['attempts'][0]['candidates'].append(candidate(104,'Another target'))
    other['attempts'][0]['subjects'][0]['rows'].append([26,['e',104]])
    yield "two target identities share one eligible subject", other, "answer"
    other = copy.deepcopy(e); other['attempts'][0]['candidates'].insert(0,candidate(104,'Popular target'))
    yield "only less popular target has the unique subject", other, "answer"
    other = copy.deepcopy(e); other['attempts'][0]['subjects'][0]['rows']=[[26,['l','Target']]]
    yield "equal label is not a raw identity edge", other, "silent"
    other = copy.deepcopy(e); other['attempts'][0]['subjects'][0]['rows']=[[26,['e',999]]]
    yield "edge to unlinked target does not qualify", other, "silent"
    other = copy.deepcopy(e); other['attempts'][0]['subjects'].append(candidate(103,'Actor',[33999],[[26,['e',101]]]))
    yield "different IDs with same label are ambiguous", other, "ambiguous"
    other = copy.deepcopy(e); other['subject_constraint']=['instance',[5]]
    other['attempts'][0]['subjects'].append(candidate(103,'Unclassified human',[],[[26,['e',101]]]))
    yield "unowned human remains a global alternative", other, "ambiguous"
    other = copy.deepcopy(e); c=candidate(103,'Unknown classification',[],[[26,['e',101]]]);c['dom']=False
    other['attempts'][0]['subjects'].append(c)
    yield "incomplete alternative classification cannot be omitted", other, "silent"
    other = copy.deepcopy(e); other['attempts'][0]['subjects'][0]['complete']=False
    yield "incomplete subject rows do not answer", other, "silent"
    other = copy.deepcopy(e); other['attempts'][0]['subjects'].append(copy.deepcopy(actor))
    yield "duplicate supplied IDs are malformed evidence", other, "silent"
    other = copy.deepcopy(e); other['attempts'][0]['capped']=True
    yield "overflow does not claim complete union", other, "silent"
    other = copy.deepcopy(e); other['subject_constraint']=['unknown']
    yield "unknown requested kind does not answer", other, "silent"
    other = copy.deepcopy(e); other['subject_excluded_properties']=[576]
    other['attempts'][0]['subjects'][0]['rows'].append([576,['l','1900']])
    yield "explicit source-property exclusion narrows eligibility", other, "silent"
    other = copy.deepcopy(e); other['subject_constraint']=['both',['occupation',[33999]],['value',21,['e',6581072]]]
    yield "occupation does not imply gender", other, "silent"
    other = copy.deepcopy(other);other['attempts'][0]['subjects'][0]['rows'].append([21,['e',6581072]])
    yield "exact gender property permits same identity", other, "answer"
    other = copy.deepcopy(e);c=candidate(103,'',[33999],[[26,['e',101]]]);c['label']=['b']
    other['attempts'][0]['subjects'].append(c)
    yield "missing alternative label must not erase its ID", other, "ambiguous"


# The global source pool includes Latvia and Latvian SSR for Riga. The latter
# has no stored dissolution row, so the supplied data cannot justify omitting it.
QUESTIONS = [(q, None if q == 'Riga is the capital of which country?' else v)
             for q,v in PRIOR_QUESTIONS] + [
    ('Who is married to John Williams?',None), ('Who is married to John Adams?',None),
    ('Who is married to John Smith?',None), ('Who is married to William Morris?',None),
    ('Who is married to Elizabeth Taylor?',None), ('Who is married to Yoko Ono?',None),
    ('Which writer is married to John Williams?','Sue Cook'),
]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--binary',required=True);p.add_argument('--out',required=True,type=Path)
    a=p.parse_args();rows=[]
    proc=subprocess.Popen([a.binary],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    try:
        for name,ev,expected in raw_cases():
            proc.stdin.write(json.dumps(ev)+'\n');proc.stdin.flush();out=json.loads(proc.stdout.readline())
            rows.append(dict(kind='evidence-policy',name=name,expected=expected,reply=out,ok=out.get('outcome')==expected))
    finally:close_kernel(proc)
    front=FrontDoor(a.binary)
    try:
        for q,value in QUESTIONS:
            out=front.answer({'q':q})
            ok=(out['status']=='answered' and out.get('value')==value) if value is not None else out['status'] in ('withheld','clarify') and out['provenance']['taken']
            rows.append(dict(kind='meaningful-question',q=q,expected=value,reply=out,ok=ok))
        for q,expected_query,expected_answer in [
            ('What is the capital of Austria?', 'Q40', None),
            ('Who wrote Leaves of Grass?', None, None),
            ('Which actor is married to Yoko Ono?', None, 'Q1203')]:
            out=front.answer({'q':q});meta=out.get('provenance',{}).get('conversation',{})
            ok=out.get('status')=='answered' and bool(meta)
            if expected_query:ok=ok and meta.get('query_entity',{}).get('qid')==expected_query
            if expected_answer:ok=ok and meta.get('answer_entity',{}).get('qid')==expected_answer
            if expected_query=='Q40':ok=ok and meta.get('query_entity',{}).get('entity_kind')=='thing'
            rows.append(dict(kind='conversation-policy',q=q,reply=out,ok=ok))
        for binding,expected in [({'qid':'Q40','surface':'Austria'},'answered'),
                                 ({'qid':'Q40','surface':'Germany'},'withheld'),
                                 ({'qid':'Q183','surface':'Germany'},'withheld')]:
            out=front.answer({'q':'What is the capital of Austria?','bound_query_entity':binding})
            rows.append(dict(kind='binding-policy',binding=binding,expected=expected,reply=out,
                             ok=out.get('status')==expected and (out.get('value')=='Vienna' if expected=='answered' else
                                'BINDING_MISMATCH' in out.get('path',''))))
    finally:front.close()
    a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
    questions=[r for r in rows if r['kind']=='meaningful-question']
    summary={'assertions_passed':sum(r['ok'] for r in rows),'assertions_total':len(rows),
             'answered_expected':sum(r['ok'] and r['reply']['status']=='answered' for r in questions),
             'unanswered_valid':sum(r['reply']['status']!='answered' for r in questions),
             'failed':[r.get('name',r.get('q')) for r in rows if not r['ok']]}
    print(json.dumps(summary));raise SystemExit(bool(summary['failed']))
if __name__=='__main__':main()
