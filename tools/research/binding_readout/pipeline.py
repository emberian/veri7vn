"""Untrusted frozen-model binding recognizer. Spans are candidates, never evidence of truth.
No model-generated labels, world coverage, graph IDs, or semantic guarantees.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import re


def validate(doc):
    text = doc['text']
    for key in ('entities', 'roles', 'values'):
        for span in doc[key]:
            a, b = span['start'], span['end']
            if not (0 <= a < b <= len(text)) or text[a:b] != span['text']:
                raise ValueError('invalid source span')
    if len(doc['entities']) != 3 or len(doc['roles']) != 3:
        raise ValueError('pilot requires exactly three entities and three roles')
    if 'labels' in doc:
        if len(doc['labels']) != len(doc['values']):
            raise ValueError('label/value mismatch')
        for e, r in doc['labels']:
            if e not in range(3) or r not in range(3):
                raise ValueError('label outside candidate roster')
    return doc


def generate(n=60, seed=19):
    """Group entire binding tables; paraphrases never cross partitions."""
    rng = random.Random(seed)
    sets = {
        'train': (['Ada', 'Basil', 'Cora', 'Drew', 'Eli', 'Faye'], ['maker', 'designer', 'owner']),
        'dev': (['Gita', 'Hugo', 'Iris', 'Jules'], ['maker', 'designer', 'owner']),
        'test_names': (['Kira Vale', 'Liam Moss', 'Mina Reed', 'Noor Lake'], ['maker', 'designer', 'owner']),
        'test_roles': (['Ada', 'Basil', 'Cora', 'Drew'], ['editor', 'curator', 'sponsor']),
        'test_template': (['Ada', 'Basil', 'Cora', 'Drew'], ['maker', 'designer', 'owner']),
    }
    for split, (names, roles) in sets.items():
        for group in range(n):
            entities = rng.sample(names, 3)
            roles = rng.sample(roles, 3)
            cells = [(e, r) for e in range(3) for r in range(3)]
            rng.shuffle(cells)
            values = [f'item-{rng.randrange(10**9):09d}' for _ in cells]
            for variant in range(2):
                text = 'People: ' + ', '.join(entities) + '. Roles: ' + ', '.join(roles) + '. '
                def span(word):
                    start = text.index(word)
                    return dict(start=start, end=start+len(word), text=word)
                es, rs = list(map(span, entities)), list(map(span, roles))
                vs = []
                for (e, r), value in zip(cells, values):
                    if split == 'test_template':
                        sentence = f'For {value}, the {roles[r]} named in the register is {entities[e]}. '
                    elif variant:
                        sentence = f'{value} lists {entities[e]} as its {roles[r]}. '
                    else:
                        sentence = f'{entities[e]} is the {roles[r]} of {value}. '
                    text += sentence
                    vs.append(span(value))
                yield validate(dict(id=f'{split}-{group}-{variant}', group=f'{split}-{group}',
                                    split=split, origin='synthetic', text=text, entities=es,
                                    roles=rs, values=vs, labels=cells))


def token_features(doc, mode, width=128):
    import numpy as np
    if mode == 'position':
        return np.asarray([[v['start']/len(doc['text']), v['end']/len(doc['text']),
                            i/max(1,len(doc['values'])-1), 1.] for i,v in enumerate(doc['values'])])
    # Whole-passage bag intentionally has no access to labels or sentence positions.
    row = np.zeros(width)
    for token in re.findall(r'\w+', doc['text'].lower()):
        idx = int.from_bytes(hashlib.sha256(token.encode()).digest()[:4], 'big') % width
        row[idx] += 1
    return np.repeat(row[None,:], len(doc['values']), axis=0)


def collect(docs, model_path, layer=3, max_tokens=512):
    """Offline local weights only. Frozen forward; no generated answers are trusted."""
    import numpy as np
    import torch
    from transformers import AutoTokenizer, AutoModel
    if not Path(model_path).is_dir():
        raise ValueError('model must be an existing local directory')
    torch.set_num_threads(2)
    tok = AutoTokenizer.from_pretrained(model_path, local_files_only=True, use_fast=True)
    model = AutoModel.from_pretrained(model_path, local_files_only=True).eval()
    for param in model.parameters():
        param.requires_grad_(False)
    rows = []
    for doc in docs:
        encoded = tok(doc['text'], return_offsets_mapping=True, return_tensors='pt', truncation=False)
        offsets = encoded.pop('offset_mapping')[0].tolist()
        if len(offsets) > max_tokens:
            raise ValueError('token cap exceeded; no silent truncation')
        with torch.no_grad():
            output = model(**encoded, output_hidden_states=True, use_cache=False)
        h = output.hidden_states[layer][0].float().cpu().numpy()
        features = []
        for span in doc['values']:
            indices = [i for i,(a,b) in enumerate(offsets) if b>a and a<span['end'] and b>span['start']]
            if not indices:
                raise ValueError('unrepresented candidate span')
            features.append(h[indices].mean(axis=0))
        rows.append(np.asarray(features))
    return rows


def fit(x, labels, penalty=10.):
    import numpy as np
    x = np.asarray(x, dtype=float)
    mean, scale = x.mean(0), x.std(0)
    scale[scale < 1e-8] = 1
    z = np.column_stack(((x-mean)/scale, np.ones(len(x))))
    y = np.eye(9)[np.asarray(labels)[:,0]*3 + np.asarray(labels)[:,1]]
    regularizer = np.eye(z.shape[1])*penalty
    regularizer[-1,-1] = 0
    weights = np.linalg.solve(z.T@z + regularizer, z.T@y)
    return mean, scale, weights


def predict(head, x):
    import numpy as np
    mean, scale, weights = head
    logits = np.column_stack(((x-mean)/scale, np.ones(len(x)))) @ weights
    logits -= logits.max(axis=1, keepdims=True)
    probs = np.exp(logits)
    return probs/probs.sum(axis=1, keepdims=True)


def wilson(right, total):
    if not total:
        return None
    p, z = right/total, 1.96
    mid = (p+z*z/(2*total))/(1+z*z/total)
    half = z*math.sqrt(p*(1-p)/total+z*z/(4*total*total))/(1+z*z/total)
    return [max(0,mid-half), min(1,mid+half)]


def metrics(docs, probabilities, threshold=.5):
    import numpy as np
    total = right = answered = accepted_right = complete = 0
    brier = 0.
    for doc, probs in zip(docs, probabilities):
        labels = np.asarray(doc['labels'])
        truth = labels[:,0]*3+labels[:,1]
        pred = probs.argmax(1)
        accepted = probs.max(1)>=threshold
        correct = pred==truth
        total += len(truth); right += int(correct.sum())
        answered += int(accepted.sum()); accepted_right += int((accepted & correct).sum())
        complete += int(bool(correct.all()))
        brier += float(((probs-np.eye(9)[truth])**2).sum())
    return dict(values=total, tuple_accuracy=right/total if total else None,
                complete_table_accuracy=complete/len(docs) if docs else None,
                answered=answered, coverage=answered/total if total else None,
                tuple_precision=accepted_right/answered if answered else None,
                tuple_recall=accepted_right/total if total else None,
                wrong_binding_rate=(answered-accepted_right)/answered if answered else None,
                selective_accuracy_wilson_descriptive=wilson(accepted_right, answered),
                brier=brier/total if total else None, threshold=threshold,
                interval_limit='Rows share passages; Wilson interval ignores clustering.')


def bridge(doc, probabilities, threshold=.5):
    """Request-local proposals only; NOT native grammar::LearnedCandidate."""
    import numpy as np
    validate(doc)
    probabilities=np.asarray(probabilities,dtype=float)
    if probabilities.shape != (len(doc['values']),9):
        raise ValueError('probability/value shape mismatch')
    if not np.isfinite(probabilities).all() or (probabilities<0).any() or not np.allclose(probabilities.sum(1),1):
        raise ValueError('invalid probabilities')
    out=[]
    for value, probs in zip(doc['values'], probabilities):
        for index, score in enumerate(probs):
            if score >= threshold:
                e,r=divmod(index,3)
                out.append(dict(entity=doc['entities'][e], role=doc['roles'][r], value=value,
                                score=float(score), status='untrusted_proposal'))
    return dict(schema='oracle.binding-candidates.v1', source_id=doc['id'],
                source_sha256=hashlib.sha256(doc['text'].encode()).hexdigest(),
                offset_unit='unicode_codepoint', bindings=out, coverage='unknown',
                graph_resolution='required', empirical_status='experimental')


def evaluate(docs, features, threshold=.5, seed=19):
    import numpy as np
    if not 0 <= threshold <= 1:
        raise ValueError('threshold outside [0,1]')
    if len(features)!=len(docs):
        raise ValueError('feature/document mismatch')
    groups = {}
    for doc,feature in zip(docs,features):
        if len(feature)!=len(doc['values']):
            raise ValueError('feature/value mismatch')
        previous = groups.setdefault(doc['group'], doc['split'])
        if previous != doc['split']:
            raise ValueError('binding-table group crosses split')
    train = [i for i,d in enumerate(docs) if d['split']=='train']
    if not train:
        raise ValueError('no train documents')
    x=np.concatenate([features[i] for i in train])
    labels=np.concatenate([docs[i]['labels'] for i in train])
    head=fit(x,labels)
    shuffled=labels.copy()
    np.random.default_rng(seed).shuffle(shuffled)
    null=fit(x,shuffled)
    result={}
    for split in sorted({d['split'] for d in docs}):
        indices=[i for i,d in enumerate(docs) if d['split']==split]
        subset=[docs[i] for i in indices]
        result[split]={name:metrics(subset,[predict(h,features[i]) for i in indices],threshold)
                       for name,h in [('readout',head),('shuffled_labels',null)]}
    return result,head


def main():
    import numpy as np
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    gen=sub.add_parser('generate'); gen.add_argument('--output',required=True); gen.add_argument('--groups',type=int,default=60)
    export=sub.add_parser('export'); export.add_argument('--report',required=True); export.add_argument('--data',required=True)
    export.add_argument('--id',required=True); export.add_argument('--source-output',required=True); export.add_argument('--proposal-output',required=True)
    run=sub.add_parser('run'); run.add_argument('--data',required=True); run.add_argument('--output',required=True)
    run.add_argument('--model'); run.add_argument('--layer',type=int,default=3)
    run.add_argument('--threshold',type=float,default=.5)
    args=parser.parse_args()
    if args.command=='generate':
        Path(args.output).write_text(''.join(json.dumps(d)+'\n' for d in generate(args.groups)))
        return
    if args.command=='export':
        report=json.loads(Path(args.report).read_text())
        docs=[validate(json.loads(line)) for line in Path(args.data).read_text().splitlines() if line.strip()]
        doc=next(d for d in docs if d['id']==args.id)
        proposal=next(p for p in report.get('candidates',[]) if p['source_id']==args.id)
        if proposal['source_sha256']!=hashlib.sha256(doc['text'].encode()).hexdigest():
            raise ValueError('source digest mismatch')
        Path(args.source_output).write_text(doc['text'])
        Path(args.proposal_output).write_text(json.dumps(proposal,indent=2)+'\n')
        return
    docs=[validate(json.loads(line)) for line in Path(args.data).read_text().splitlines() if line.strip()]
    if len(docs)>1200:
        raise ValueError('pilot cap: 1200 documents')
    report=dict(status='empirical_research_only', model=args.model, layer=args.layer,
                human_prose_present=any(d['origin']=='human' for d in docs), results={})
    for mode in ['position','bow'] + (['activation'] if args.model else []):
        features=collect(docs,args.model,args.layer) if mode=='activation' else [token_features(d,mode) for d in docs]
        result,head=evaluate(docs,features,args.threshold)
        report['results'][mode]=result
        if mode=='activation':
            report['candidates']=[bridge(d,predict(head,x),args.threshold) for d,x in zip(docs,features) if d['split']!='train']
    report['missing_evidence']=[] if report['human_prose_present'] else ['independent human prose absent']
    if not args.model:
        report['missing_evidence'].append('no frozen activations collected')
    Path(args.output).write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':
    main()
