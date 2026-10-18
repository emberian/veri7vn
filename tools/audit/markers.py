"""Mechanical checks per Isabelle session (read-only over src/):
1. the theory holding the PASS marker is the session's last theory and the
   marker ML block is its last command (only `end` after it);
2. every named theorem/corollary (and, separately, every named lemma) of the
   session's theories appears in some @{thm}/@{thms} list scanned for oracles;
3. `by eval` / sorry / oops / skip_proof / axiomatization in session theories."""
import re, json, pathlib
ROOT = pathlib.Path('/Users/ember/dev/o7vn')
thms = json.load(open(ROOT/'var/audit/thms.json'))
roots = sorted(list((ROOT/'src/extract').glob('*/ROOT')) + list((ROOT/'src/isabelle').glob('*/ROOT')))
def strip_comments(s):
    out, depth, i = [], 0, 0
    while i < len(s):
        if s.startswith('(*', i): depth += 1; i += 2; continue
        if depth and s.startswith('*)', i): depth -= 1; i += 2; continue
        if not depth: out.append(s[i])
        i += 1
    return ''.join(out)
rows = []
for r in roots:
    txt = strip_comments(r.read_text())
    for m in re.finditer(r'session\s+(\S+)\s*(?:in\s+"?([^"\s]+)"?\s*)?=\s*(\S+)\s*\+(.*?)(?=\bsession\b|\Z)', txt, re.S):
        name, sub, parent, body = m.groups()
        base = r.parent / (sub or '.')
        tm = re.search(r'theories\s+(.*)', body, re.S)
        theories = re.findall(r'"?([A-Za-z_][\w]*)"?', tm.group(1)) if tm else []
        files = [base / (t + '.thy') for t in theories]
        files = [f for f in files if f.exists()]
        if not files: continue
        rels = {str(f.relative_to(ROOT)) for f in files}
        last = files[-1]
        lt = last.read_text()
        # find ML blocks with PASS
        pass_files = [f for f in files if re.search(r'VERI7VN_\w+ PASS', strip_comments(f.read_text()))]
        marker_last = None; after = ''; oracle_scan = None
        if pass_files:
            pf = pass_files[-1]
            t = strip_comments(pf.read_text())
            idx = t.rfind('PASS')
            # end of that ML block
            close = t.find('\\<close>', idx)
            after = t[close+len('\\<close>'):].strip() if close >= 0 else '?'
            marker_last = (pf == last) and after in ('end', '')
            oracle_scan = 'all_oracles' in t
        scanned = set()
        for f in files:
            t = strip_comments(f.read_text())
            for mm in re.finditer(r'@\{thms?\s+([^}]*)\}', t):
                for nm in mm.group(1).split():
                    scanned.add(re.sub(r'\(.*|\[.*', '', nm))
        mine = [x for x in thms if x['file'] in rels and x['name']]
        named_thm = [x['name'] for x in mine if x['kind'] in ('theorem', 'corollary', 'proposition')]
        named_lem = [x['name'] for x in mine if x['kind'] == 'lemma']
        miss_thm = [n for n in named_thm if n not in scanned]
        miss_lem = [n for n in named_lem if n not in scanned]
        bad = []
        for f in files:
            t = re.sub(r'text\s*\\<open>.*?\\<close>', '', strip_comments(f.read_text()), flags=re.S)
            for kw in ('by eval', 'sorry', 'oops', 'skip_proof', 'axiomatization', 'quick_and_dirty'):
                c = len(re.findall(r'\b' + re.escape(kw) + r'\b', t))
                if c: bad.append(f'{f.name}:{kw}x{c}')
        rows.append(dict(session=name, dir=str(r.parent.relative_to(ROOT)), last_theory=last.name,
            pass_theory=pass_files[-1].name if pass_files else None, marker_last=marker_last,
            after_marker=after[:60], oracle_scan=oracle_scan, scanned=sorted(scanned), n_theorem=len(named_thm), theorem_unscanned=miss_thm,
            n_lemma=len(named_lem), lemma_unscanned_count=len(miss_lem), bad=bad))
json.dump(rows, open(ROOT/'var/audit/markers.json', 'w'), indent=1)
for x in rows:
    print(f"{x['session']:32} pass={x['pass_theory']} last={x['last_theory']} marker_last={x['marker_last']} oracle_scan={x['oracle_scan']} thm={x['n_theorem']} unscanned_thm={len(x['theorem_unscanned'])} lem={x['n_lemma']} unscanned_lem={x['lemma_unscanned_count']} bad={x['bad']}")
    if x['marker_last'] is False: print('   AFTER:', repr(x['after_marker']))
    if x['theorem_unscanned']: print('   UNSCANNED THEOREMS:', ' '.join(x['theorem_unscanned'][:40]))
