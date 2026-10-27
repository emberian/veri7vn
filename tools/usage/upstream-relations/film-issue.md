At current slim main `0e0e858238cb028b751a85a23f4690a0b0d48483`, the relation type guard searches the entire question for kind words. Consequently a title word such as “Song” makes `kind_conflict(question, 'songs')` false even when the question explicitly requests **the film**. With both title identities linked, the song-domain reader can return its own subject/composer.

Current `relation_spec_v1.py` SHA256: `08f905b8f87cfb8d85256836dfff96a4f69b0d1299f017a0c559ef0c5fee7985`. I freshly downloaded and ran this exact blob. The following calls the actual `answer` function with controlled recognition, type and source-row fixtures; it does not claim the complete current Engine chooses the wrong reply:

```python
import importlib.util, re, sys, types
from unittest.mock import patch
x = types.SimpleNamespace(L=types.SimpleNamespace(STOP=set()),
    norm=lambda s: re.sub(r'[^a-z0-9]+',' ',s.lower()).strip(),
    _show=lambda v,*a:v, TIME_VARIANT=set(), PAST=re.compile(r'\bwas\b'))
spec = importlib.util.spec_from_file_location('reader','root/wander-train/relation_spec_v1.py')
r = importlib.util.module_from_spec(spec)
with patch.dict(sys.modules, {'exact_router_v1':x}): spec.loader.exec_module(r)
r.analyse = lambda q: {'cands':[1,2], 'feats':[('who','composed')]}
r.in_domain = lambda qid,d: (qid,d) in {(1,'films'),(2,'songs')}
r.values = lambda qid,p: frozenset({1:['Film composer'],2:['Song composer']}[qid]) if p==86 else frozenset()
q = 'Who composed the film Song of Dawn?'
for domain in ('films','songs'):
    print(domain, r.kind_conflict(q,domain), r.answer(q,domain,{'fwd|who|composed':[86]}))
```

Observed: both guards return false; films answers `Film composer` for subject 1, songs answers `Song composer` for subject 2. Control: removing “Song” from the title makes the songs guard reject the question. A title's contents must not override the requested entity kind.

**This also affects our pending PR #2**, not just the old generic path. PR head `f5b73e079668af60ceea3e191fcd9e252e68b514` adds the explicit P86 composer reader. That reader strips “the film” for title lookup but loses the kind constraint; the same fixture reproduces both answers there without supplying a mined pattern. In our earlier 4.9-based candidate, an actual read-only store check with “Who composed the film The Song Remains the Same?” returned film Q510381 → Led Zeppelin and song Q152753 → Jimmy Page through the two readers. That is actual reader/store evidence, not an end-to-end 10.0 result.

A narrow proposed follow-up is [composer-guard.patch](https://github.com/emberian/veri7vn/blob/463727e2c350aabc57252ef7d854e26d99155702/tools/usage/relation-audit-consumers/composer-guard.patch), with [four fixtures](https://github.com/emberian/veri7vn/blob/463727e2c350aabc57252ef7d854e26d99155702/tools/usage/relation-audit-consumers/test_composer_guard.py), [actual-store checker](https://github.com/emberian/veri7vn/blob/463727e2c350aabc57252ef7d854e26d99155702/tools/usage/relation-audit-consumers/check_live.py) and [audit report](https://github.com/emberian/veri7vn/blob/463727e2c350aabc57252ef7d854e26d99155702/project/lanes/RELATIONS-CONSUMERS-2026-10-27.md). It retains the explicit film qualifier and refuses a year-qualified composer answer when another eligible candidate lacks a parseable publication date. I applied it to the freshly downloaded PR #2 reader and reran all four fixtures successfully.

That patch targets PR #2's composer path; it **does not** repair the general main-branch `kind_conflict` policy or every relation. The year check is still bounded and source-relative: missing dates cannot exclude a candidate, and a different stored release year is not complete evidence about all releases. Filing this explicitly avoids presenting the narrow patch as a general interpretation proof. Before integration, the explicit-kind constraint and refusal behavior should be checked through actual Engine arbitration and relevant specialist panels; no such new panel or full-Engine result is claimed here.
