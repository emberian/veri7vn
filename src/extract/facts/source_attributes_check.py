#!/usr/bin/env python3
"""UNTRUSTED source-field transcription check; not a proof of English entailment.
Checks HOL fields against explicit reviewed interpretations, exact source rows
and associated source portions. Reads upstream without importing or writing it.
"""
import ast,json,re
from pathlib import Path
folder=Path(__file__).resolve().parent
root=next(p for p in folder.parents if (p/'upstream/root/specialists').is_dir())
fields=json.loads((folder/'source_attributes.json').read_text())
actual=re.findall(r"\(\(STR ''([^']*)'',(\d+),(\w+)\), STR ''([^']*)''\)",(folder/'Source_Attributes.thy').read_text())
expected=[(x['store'],str(x['row']),x['attribute'],x['value']) for x in fields]
assert len(actual)==len(expected) and set(actual)==set(expected),'HOL fields differ from reviewed source interpretations'
assert len({(n,i,a) for n,i,a,v in actual})==len(actual),'duplicate source field keys'
for x in fields:
    source=root/'upstream/root/specialists'/x['specialist']/(x['store']+'.py')
    tree=ast.parse(source.read_text())
    rows=ast.literal_eval(next(n.value for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='FACTS' for t in n.targets)))
    sentence=rows[x['row']][2]
    assert sentence==x['source_sentence'],f"source sentence changed: {x}"
    assert x['source_span'] in sentence,f"source portion absent: {x}"
print(f'{len(fields)} source-field interpretations match typed entries and exact source rows; source semantics remain assumptions')
