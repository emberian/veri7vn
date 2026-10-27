At current slim main `0e0e858238cb028b751a85a23f4690a0b0d48483`, `relation_spec_v2.answer` checks uniqueness among subjects for **only the first linked target**, not across the plausible targets. Two equally ranked identities for the slot can have different unique subjects; reversing their order changes the answer rather than producing ambiguity.

Freshly downloaded source SHA256: `8c712b9af41aafb3945ca72ddbcd22b019ba4340cb212787b085789b0a3596ac` (`root/wander-train/relation_spec_v2.py`). The same blob is in pending PR #2. No existing discussion covers this target-identity problem.

This small fixture runs the actual reader, substituting only its linker/row/type dependencies. It does not claim a particular live natural-language question or full Engine produces this result:

```python
import importlib.util, re, sys, types
from unittest.mock import patch
x = types.SimpleNamespace(DOMINANCE=10, TIME_VARIANT=set(),
    PAST=re.compile(r'\bwas\b'), _show=lambda v, *a: v)
store = types.SimpleNamespace(label=lambda qid: {102:'First spouse',103:'Second spouse'}[qid])
seen = []
def query(sql, args):
    seen.append(args)
    return {101:[102],201:[103]}[args[1]]
v1 = types.SimpleNamespace(X=x, kind_conflict=lambda *a: False,
    _restates=lambda *a: False, _rs=lambda: store, _q=query)
spec = importlib.util.spec_from_file_location('reader', 'root/wander-train/relation_spec_v2.py')
r = importlib.util.module_from_spec(spec)
with patch.dict(sys.modules, {'relation_spec_v1':v1,
    'relation_readers_v1':types.SimpleNamespace(PROPS={})}):
    spec.loader.exec_module(r)
r.compiled = lambda key: {'prop':26,'fwd':[],
    'inv':[re.compile(r'^who is married to (?P<X>.+?)$')]}
r.in_domain = lambda qid, domain: True
for targets in ([101,201], [201,101]):
    r.slot_candidates = lambda slot: (targets,[10,10])
    seen.clear()
    print(r.answer('Who is married to Target?', 'actors', [26]), seen)
```

Observed: the first order answers subject 102 and queries only `(26,101)`; reverse order answers subject 103 and queries only `(26,201)`. Both target identities are still equally plausible. One subject per target does not establish one answer for the question. The earlier popularity-dominance reduction also does not prove that a discarded sense is impossible.

A bounded proposed repair is published as [inverse-target-appliance.patch](https://github.com/emberian/veri7vn/blob/463727e2c350aabc57252ef7d854e26d99155702/tools/usage/relation-audit-semantics/inverse-target-appliance.patch), with [six focused consumer tests](https://github.com/emberian/veri7vn/blob/463727e2c350aabc57252ef7d854e26d99155702/tools/usage/relation-audit-semantics/test_inverse_patch.py) and [assumptions/limits](https://github.com/emberian/veri7vn/blob/463727e2c350aabc57252ef7d854e26d99155702/project/lanes/RELATIONS-SEMANTICS-2026-10-27.md). It refuses recognized multi-target inverse requests before dominance, carries a specific refusal reason through the 161 copied relation organs, and preserves it through the tested Combo arbitration instead of permitting a rival answer. A fresh `git apply --check` against exact current-main blobs for all 163 changed files succeeded.

This is an issue rather than a release-ready PR because the full head can answer before invoking that Family. The proposed patch's recorded six tests exercise actual organ/Combo consumers with a controlled source, not complete Engine arbitration, shipped panels or source completeness. Missing type facts, temporal qualifiers, six-result linker truncation and intended-identity coverage remain separate assumptions; this repair must not claim to prove them. Integration should preserve the ambiguity refusal through all relevant consumers, then qualify the actual release route.
