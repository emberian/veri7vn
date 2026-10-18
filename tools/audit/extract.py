"""Extract every theorem/lemma (name, statement, proof) from the .thy files of
each family directory. Read-only over src/. Writes var/audit/thms.json."""
import json, re, sys, pathlib
ROOT = pathlib.Path('/Users/ember/dev/o7vn')
DIRS = sorted([p for p in (ROOT/'src/extract').iterdir() if p.is_dir()] +
              [p for p in (ROOT/'src/isabelle').iterdir() if p.is_dir()])
KW = re.compile(r'^\s*(theorem|lemma|corollary|proposition|lemmas)\b')
TOP = re.compile(r'^(definition|fun|function|primrec|lemma|theorem|corollary|proposition|text|section|subsection|subsubsection|datatype|type_synonym|ML|ML_file|export_code|end|value|abbreviation|record|locale|context|declare|lemmas|code_printing|code_identifier|setup|instantiation|instance|global_interpretation|interpretation|termination|notation|consts|axiomatization|hide_const|hide_type|hide_fact|bundle|named_theorems|method|inductive|partial_function|qualified|private|chapter|paragraph|unbundle|typedef|lift_definition|specification|code_datatype|nonterminal|syntax|translations|\(\*)')
STMT_END = re.compile(r'^\s*(by|proof|apply|unfolding|using|including|supply|subgoal|done|\.|\.\.)\b')
out = []
for d in DIRS:
    for f in sorted(d.rglob('*.thy')):
        lines = f.read_text(errors='replace').split('\n')
        i = 0
        while i < len(lines):
            m = KW.match(lines[i])
            if not m or lines[i].startswith(' ') and False:
                i += 1; continue
            # only top-level (column 0 or small indent inside context)
            indent = len(lines[i]) - len(lines[i].lstrip())
            if indent > 2:
                i += 1; continue
            start = i
            j = i + 1
            while j < len(lines):
                l = lines[j]
                if l and not l[0].isspace() and TOP.match(l):
                    break
                j += 1
            block = lines[start:j]
            # split statement / proof
            head = block[0]
            k = 1
            # statement may include proof on the same line? rare
            while k < len(block) and not STMT_END.match(block[k]):
                k += 1
            stmt = '\n'.join(block[:k]).strip()
            proof = '\n'.join(b for b in block[k:] if b.strip()).strip()
            mm = re.match(r'\s*(theorem|lemma|corollary|proposition|lemmas)\s+([A-Za-z_][\w\'.]*)?', head)
            name = mm.group(2) if mm and mm.group(2) and not head.split()[1].startswith('"') else ''
            if name in ('assumes','shows','fixes'): name=''
            out.append(dict(dir=str(d.relative_to(ROOT)), file=str(f.relative_to(ROOT)),
                            line=start+1, kind=m.group(1), name=name, stmt=stmt,
                            proof=proof, plines=len([b for b in block[k:] if b.strip()])))
            i = j
out = [o for o in out if '"' in o['stmt'] and o['kind'] != 'lemmas']  # drop prose lines inside text blocks
json.dump(out, open(ROOT/'var/audit/thms.json','w'), indent=0)
from collections import Counter
c = Counter(o['dir'] for o in out)
for k,v in sorted(c.items()): print(k, v)
print('total', len(out))
