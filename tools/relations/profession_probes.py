"""Untrusted profession-query checks against supplied rows and actual stores.

These are authored controls, not shipped panel scores or proof of source truth.
Meaningful refusals stay separate from answered capabilities.
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
from request_probes import candidate

PEOPLE = [
    ('actors','actor','Audrey Hepburn',None),
    ('chemists','chemist','Marie Curie',None),
    ('composers','composer','Wolfgang Amadeus Mozart',None),
    ('graphicartists','graphic artist','M. C. Escher','Leeuwarden'),
    ('journalists','journalist','Nellie Bly',None),
    ('musicians','musician','Louis Armstrong',None),
    ('painters','painter','Pablo Picasso',None),
    ('philosophers','philosopher','Immanuel Kant','Königsberg'),
    ('photographers','photographer','Ansel Adams',None),
    ('physicians','physician','Hippocrates','Kos'),
    ('physicists','physicist','Albert Einstein','Ulm'),
    ('poets','poet','Walt Whitman',None),
    ('sculptors','sculptor','Auguste Rodin','Paris'),
    ('singers','singer','Ella Fitzgerald',None),
]
QUESTIONS = [('Where was the '+role+' '+name+' born?', value)
             for _,role,name,value in PEOPLE] + [
    ('Where was the chemist Immanuel Kant born?',None),
    ('Where was the actor Hippocrates born?',None),
    ('Where was the physicist M. C. Escher born?',None),
    ('Where was the composer Auguste Rodin born?',None),
    ('Where was the physicist Albert Einstein and Marie Curie born?',None),
    ('Where was the physicist Albert Einstein in the film born?',None),
    ('Where was the physicist Albert Einstein born and raised?',None),
]


def raw_cases():
    # P20 is enabled in both readers; composer P19 forms 0/1 are explicitly
    # dropped in its shipped spec, independently of occupation evidence.
    for sid,root,other in [('rel-composers',36834,158852),('rel-journalists',1930187,947873)]:
        a=candidate(101,'Person A',[root],[[20,['l','Place A']],[106,['e',501]]])
        b=candidate(102,'Person B',[other],[[20,['l','Place B']],[106,['e',502]]])
        ev={'spec':sid,'kind_conflict':False,'past':False,'qwords':[],'vwords':[],
            'subject_constraint':['any'],'subject_excluded_properties':[],
            'query_constraint':['property_class',106,[root]],
            'query_classes':[[501,[root]],[502,[other]]],
            'attempts':[{'key':'20','dir':'fwd','idx':0,'slot_ok':True,
                         'capped':False,'subjects':[],'candidates':[a,b]}]}
        yield sid+' exact occupation witness',copy.deepcopy(ev),'answer'
        x=copy.deepcopy(ev);x['query_classes']=[[501,[other]],[502,[other]]]
        yield sid+' broad domain does not establish requested profession',x,'silent'
        x=copy.deepcopy(ev);x['query_classes']=[[501,[root]]]
        yield sid+' missing alternative closure cannot create uniqueness',x,'silent'
        x=copy.deepcopy(ev);x['attempts'][0]['candidates'][1]['complete']=False
        yield sid+' incomplete alternative rows cannot create uniqueness',x,'silent'
        x=copy.deepcopy(ev);x['query_classes'][0][0]=599
        yield sid+' unrelated closure cannot establish profession',x,'silent'
        x=copy.deepcopy(ev);x['attempts'][0]['candidates'][0]['rows'][1]=[106,['l','composer']]
        yield sid+' literal word is not an occupation entity',x,'silent'
        x=copy.deepcopy(ev);x['query_classes'][1][1]=[root]
        yield sid+' two eligible conflicting locations refuse',x,'decline'


def main():
    p=argparse.ArgumentParser();p.add_argument('--binary',default='var/relations/bin/decide')
    p.add_argument('--out',required=True,type=Path);a=p.parse_args();rows=[]
    proc=subprocess.Popen([a.binary],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    try:
        for label,ev,want in raw_cases():
            proc.stdin.write(json.dumps(ev)+'\n');proc.stdin.flush()
            reply=json.loads(proc.stdout.readline())
            rows.append({'kind':'raw-evidence','label':label,'evidence':ev,'expected':want,
                         'reply':reply,'passed':reply.get('outcome')==want})
    finally:close_kernel(proc)
    front=FrontDoor(a.binary)
    try:
        for q,want in QUESTIONS:
            reply=front.answer({'q':q})
            passed=not reply.get('error') and (reply.get('status')=='answered' and reply.get('value')==want
                                              if want is not None else reply.get('status')!='answered')
            rows.append({'kind':'source-question','q':q,'expected':want,'reply':reply,'passed':passed})
    finally:front.close()
    a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(rows,indent=2)+'\n')
    print(json.dumps({'passed':sum(r['passed'] for r in rows),'total':len(rows),
                      'source_answers':sum(r['kind']=='source-question' and r['reply'].get('status')=='answered' for r in rows),
                      'failures':[r.get('label',r.get('q')) for r in rows if not r['passed']]}))
    raise SystemExit(0 if all(r['passed'] for r in rows) else 1)


if __name__=='__main__':main()
