#!/usr/bin/env python3
"""Source-backed fixture checks, independent of native compilation/admission."""
import ast
import importlib.util
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
STORE = ROOT / 'upstream/root/specialists/literature-v2'
sys.path.insert(0, str(STORE))
spec = importlib.util.spec_from_file_location('literature_fixture', STORE / 'facts_literature_v2.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

from organ_facts_v1 import FactsOrgan
organ = FactsOrgan('facts_literature_v2')

def source_select(text):
    if not re.search(module.GATE, text, re.I) or re.search(module.BLOCK, text, re.I) or not re.search(module.ASK, text, re.I):
        return None
    return next(((v, sentence) for pattern, v, sentence in module.FACTS if re.search(pattern, text, re.I)), None)

cases = {
    'Who narrates Moby-Dick?': 'Ishmael',
    'What ship does Ahab command?': 'Pequod',
    'Who wrote Pride and Prejudice?': 'Jane Austen',
    'Who narrates Moby-Dick and what ship does Ahab command?': 'Ishmael',
    'What is the meaning of Pride and Prejudice?': None,
    'What is Pride and Prejudice?': None,
    'Who\n narrates   Moby-Dick?': 'Ishmael',
    'A story begins. It continues. Who narrates Moby-Dick?': None,
    'What ship does Ahab command, and what is its meaning?': None,
}
for question, expected in cases.items():
    result = organ.answer(question)
    assert (result['value'] if result else None) == expected, (question, result)
    if result:
        assert result['status'] == 'answered'
        assert result['response'] == source_select(' '.join(question.split()))[1]

# Exact byte spans identify the original rule expression. These are source data,
# not evidence that the source's statements are true or regexes are native code.
raw = (STORE / 'facts_literature_v2.py').read_bytes()
lines = raw.splitlines(keepends=True)
parsed = ast.parse(raw)
new = next(n.value for n in parsed.body if isinstance(n, ast.Assign)
           and any(isinstance(t, ast.Name) and t.id == 'NEW' for t in n.targets))
for index in (0, 4):
    node = new.elts[index]
    lo = sum(map(len, lines[:node.lineno - 1])) + node.col_offset
    hi = sum(map(len, lines[:node.end_lineno - 1])) + node.end_col_offset
    captured = raw[lo:hi]
    assert captured == ast.get_source_segment(raw.decode('utf-8'), node).encode('utf-8')
    assert module.NEW[index][1].encode('utf-8') in captured
    print(f'SOURCE facts_literature_v2.py NEW:{index} half-open UTF-8 bytes [{lo},{hi})')
assert source_select('What ship does Ahab command?')[1] == "Captain Ahab's ship is the Pequod."
print(f'PASS: {len(cases)} actual upstream FactsOrgan ordered/guarded literature cases; this does not execute native HOL')
