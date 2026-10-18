#!/usr/bin/env python3
"""UNTRUSTED transcription check: typed HOL language fields vs source LANGS.
Reads source syntax with ast.literal_eval; never imports or writes upstream.
This checks transcription, not linguistic truth or natural-language recognition.
"""
import ast,re
from pathlib import Path
root=Path(__file__).resolve().parents[3]
source=root/'upstream/root/specialists/linguistics/facts_linguistics_v1.py'
tree=ast.parse(source.read_text())
rows=ast.literal_eval(next(n.value for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='LANGS' for t in n.targets)))
text=Path(__file__).with_name('Language_Fields.thy').read_text()
block=text.split('"language_fields = [',1)[1].split(']"',1)[0]
actual=re.findall(r"\(STR ''([^']*)'', STR ''([^']*)'', STR ''([^']*)''\)",block)
assert actual==rows, 'typed language fields differ from source rows/order'
print(f'{len(rows)} language fields exactly match source LANGS; Basque has no branch row')
