"""link - UNTRUSTED entity linker for the verified reader: entity_linker_v2's span rules over a different index.

entity_linker_v2 reads relstore/names_v1.sqlite3 (every English label and alias, with sitelink counts); that index is
not in the drop. This port keeps v2's span enumeration, R1 (case agreement), R2 (titles), R3 (numbers) and its score
formula, but proposes candidates from the v1 store's own `entity.enwiki` index: the span text as an English Wikipedia
title, or that title with a "(disambiguator)" suffix. Popularity is the subject's fact count in the store, standing in
for the sitelink count. Gaps: no aliases, no accent/case normalization beyond the first letter, a different
popularity prior (so the dominance rule and thresholds fire differently). Because fact counts are a weak prior
(Vega the star has 6 facts, "Vega (Aller)" 12), the unsuffixed title - Wikipedia's primary topic for that name -
is ranked first, then suffixed senses by fact count."""
import math
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "upstream/root/wander-train"))
import entity_linker_v2 as L2  # noqa: E402  (its index is opened lazily and never here)

STOP, FUNCTION, NUMERIC, norm = L2.STOP, L2.FUNCTION, L2.NUMERIC, L2.norm


def candidates(store, raw_span, k, surface=None):
    titles = [t for x in (surface, raw_span) if x for t in (x, x[:1].upper() + x[1:])]
    qids, primary = [], set()
    for t in dict.fromkeys(titles):
        ex, dis = store.by_title(t)
        primary.update(ex)
        qids += [q for q in ex + dis if q not in qids]
    c = sorted(((q, store.fact_count(q)) for q in qids), key=lambda x: (x[0] not in primary, -x[1]))
    return [(q, n, store.label(q)) for q, n in c[:k]]


def link(store, question, k=3, max_len=8):
    ms = list(re.finditer(r"[A-Za-z0-9][\w'.\-]*", str(question)))
    raw = [m.group(0) for m in ms]
    toks = [norm(t) for t in raw]
    spans = []
    for i in range(len(toks)):
        for j in range(i + 1, min(len(toks), i + max_len) + 1):
            words = toks[i:j]
            if not words[0] or not words[-1] or all(w in STOP for w in words):
                continue
            content = [w for w in words if w not in STOP and w != "no"]
            if not content or all(NUMERIC.match(w) for w in content):
                continue
            cap = [r[:1].isupper() or r[:1].isdigit() for r in raw[i:j]]
            titled = len(words) >= 2 and cap[0] and cap[-1] and all(c or w in FUNCTION for c, w in zip(cap, words))
            caps = titled or all(c for c, w in zip(cap, words) if w not in STOP)
            if words[-1] in (FUNCTION if titled else STOP):
                continue
            if words[0] in STOP and not titled:
                continue
            if len(words) == 1 and not caps and (len(words[0]) < 4 or words[0] in STOP):
                continue
            c = candidates(store, " ".join(raw[i:j]), max(k, 6), str(question)[ms[i].start():ms[j - 1].end()])
            if not c:
                continue
            if len(words) == 1 and not caps:
                c = [x for x in c if x[2] and x[2][:1].islower()]
                if not c or c[0][1] < 30:
                    continue
            c = c[:k]
            score = math.log1p(c[0][1]) + 3.0 * len(words) + (8.0 if caps else 0.0)
            spans.append((score, i, j, c))
    spans.sort(key=lambda s: -s[0])
    taken, out = set(), []
    for score, i, j, c in spans:
        if any(x in taken for x in range(i, j)):
            continue
        taken.update(range(i, j))
        out.append((" ".join(raw[i:j]), c, score))
    out.sort(key=lambda s: -s[2])
    return [(s, c) for s, c, _ in out]
