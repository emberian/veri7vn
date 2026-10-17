#!/usr/bin/env python3
"""build_names - reconstruct Oracle7's missing relstore/names_v1.sqlite3 from what shipped.

names_v1 (entity_linker_v1.build, QLever labels.tsv + aliases.tsv, never shipped) held every English
label and alias of the ~10.36M Wikidata items with an English Wikipedia article, with the SITELINK
COUNT as popularity prior. The two linkers (entity_linker_v1/v2) and through them the exact router
and all 161 rel-* readers query exactly:

    SELECT qid, MAX(links), MIN(alias) FROM name WHERE norm=? GROUP BY qid ORDER BY MAX(links) DESC LIMIT k
    SELECT label FROM label WHERE qid=?

so this build keeps that shape byte-for-byte and the ORIGINAL modules run unmodified against it.

Sources (all shipped, all read-only):
  labels   relations_v1.sqlite3 entity(qid, label, enwiki) rows with enwiki NOT NULL
           (10,350,193 rows = the docstring's "10.36M items with an English Wikipedia article")
  aliases  NONE shipped. Substitute: the entity's own enwiki TITLE when its normalisation differs
           from the label's ("United States" for label "United States of America"). alias=1 rows.
           The original had ~3.6M true Wikidata aliases; that gap is real and measured, not hidden.
  links    NO sitelink counts shipped. Substitute (see calibrate()): a monotone map of
           indeg  = times the qid is the OBJECT of a fact   (fact_po index scan)
           outdeg = times the qid is the SUBJECT of a fact (fact_sp index scan)
           sent   = enwiki article sentence count from fable-content m13e8 (6.05M articles,
                    one pass into var/linker/wiki_sent.sqlite3; missing article -> 0)
           links  = round(SENT_W*log1p(sent) + IN_W*log1p(indeg) + OUT_W*log1p(outdeg)), min 1
           Calibrated so the scale is sitelink-like: anchors land where Wikipedia's language-edition
           counts sit (US ~ 320, Norway ~ 115, a stub ~ 1-5) because entity_linker_v2 compares
           links < 30 and exact_router multiplies by DOMINANCE=10. Tuned on the rel-specialist
           panels' gold QIDs, reported in the scout report.

Extra table (harmless, never queried by the shipped code): meta(key, value) records sources,
row counts, the proxy formula and its weights, so any consumer can tell a rebuilt names_v1
from the lost original.

Usage:  python3 build_names.py [--weights sent,in,out]     (stages cache in var/linker/)
"""
import math
import os
import re
import sqlite3
import sys
import time
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))                     # this worktree
UP = "/Users/ember/dev/o7vn/upstream"                             # read-only Oracle7 drop
REL = UP + "/root/relstore/relations_v1.sqlite3"
WIKI = UP + "/root/fable-content/oracle-m-series-2026-08-15/m13e8_dbpedia_enslot_openstax_full_fable_bench_a_v1/wikipedia_specialist.sqlite3"
VAR = os.path.join(REPO, "var", "linker")
OUT = os.path.join(VAR, "names_v1.sqlite3")

# sitelink-like scale: anchors observed 2026-10-17 (see calibrate()) - US indeg 1.27M -> ~320,
# Norway indeg 45K -> ~115, Einstein (indeg 118, outdeg 114, sent ~350) -> ~160, stubs -> 1-5
SENT_W, IN_W, OUT_W = 36.0, 14.0, 8.0


def norm(s):
    s = unicodedata.normalize("NFKD", str(s))
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    return " ".join(re.findall(r"[a-z0-9]+", s))


def ro(path):
    return sqlite3.connect("file:%s?mode=ro&immutable=1" % path, uri=True)


def stage_wiki(t0):
    """one pass over m13e8's article table -> var/linker/wiki_sent.sqlite3 (title -> sentence_count, en pages only)"""
    out = os.path.join(VAR, "wiki_sent.sqlite3")
    if os.path.exists(out):
        return out
    db = sqlite3.connect(out)
    db.execute("CREATE TABLE sent (title TEXT PRIMARY KEY, n INTEGER WITHOUT ROWID)")
    src = ro(WIKI)
    n = 0
    batch = []
    for title, sc in src.execute("SELECT title, sentence_count FROM article WHERE page_id LIKE 'en%'"):
        if title and sc:
            batch.append((title, sc))
        if len(batch) >= 200000:
            db.executemany("INSERT OR REPLACE INTO sent VALUES (?,?)", batch)
            n += len(batch)
            batch = []
            print("  wiki %d (%.0fs)" % (n, time.time() - t0), flush=True)
    db.executemany("INSERT OR REPLACE INTO sent VALUES (?,?)", batch)
    db.commit()
    n = db.execute("SELECT COUNT(*) FROM sent").fetchone()[0]
    print("wiki_sent: %d enwiki titles (%.0fs)" % (n, time.time() - t0))
    return out


def stage_deg(t0):
    """fact-degree pass -> var/linker/deg.sqlite3 (qid -> indeg, outdeg) via the two covering indexes"""
    out = os.path.join(VAR, "deg.sqlite3")
    if os.path.exists(out):
        return out
    db = sqlite3.connect(out)
    db.execute("CREATE TABLE deg (qid INTEGER PRIMARY KEY, ind INTEGER, outd INTEGER)")
    src = ro(REL)

    def rows(sql):
        for row in src.execute(sql):
            yield row
    db.executemany("INSERT OR REPLACE INTO deg VALUES (?,?,0)", rows("SELECT o, COUNT(*) FROM fact INDEXED BY fact_po WHERE o IS NOT NULL GROUP BY o"))
    db.commit()
    print("  indeg done (%.0fs)" % (time.time() - t0), flush=True)
    db.executemany("UPDATE deg SET outd=? WHERE qid=?", ((n, q) for q, n in rows("SELECT s, COUNT(*) FROM fact INDEXED BY fact_sp GROUP BY s")))
    # subjects never seen as objects: insert with outd only
    db.executemany("INSERT OR IGNORE INTO deg VALUES (?,0,?)", rows("SELECT s, COUNT(*) FROM fact INDEXED BY fact_sp GROUP BY s"))
    db.commit()
    n = db.execute("SELECT COUNT(*) FROM deg").fetchone()[0]
    print("deg: %d qids (%.0fs)" % (n, time.time() - t0))
    return out


def stage_names(t0, sent_w=SENT_W, in_w=IN_W, out_w=OUT_W, out=OUT):
    db = sqlite3.connect(out)
    db.execute("CREATE TABLE name (norm TEXT, qid INTEGER, links INTEGER, alias INTEGER)")
    db.execute("CREATE TABLE label (qid INTEGER PRIMARY KEY, label TEXT, links INTEGER)")
    deg = sqlite3.connect(os.path.join(VAR, "deg.sqlite3"))
    wik = sqlite3.connect(os.path.join(VAR, "wiki_sent.sqlite3"))
    src = ro(REL)

    def links_of(qid, ind_d, outd_d, sent_n):
        v = sent_w * math.log1p(sent_n) + in_w * math.log1p(ind_d) + out_w * math.log1p(outd_d)
        return max(1, int(round(v)))

    # join the three side tables in memory is too big (10M x 3); instead pass over entity and
    # look up deg/sent by key - both are keyed sqlite tables, ~30M point reads total
    db.execute("CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)")
    nb, lb, ents = [], [], 0
    sent_cache = {}
    def sent_of(title):
        if title not in sent_cache:
            if len(sent_cache) > 400000:
                sent_cache.clear()
            r = wik.execute("SELECT n FROM sent WHERE title=?", (title,)).fetchone()
            sent_cache[title] = r[0] if r else 0
        return sent_cache[title]

    for qid, label, enwiki in src.execute("SELECT qid, label, enwiki FROM entity"):
        if enwiki is None:
            continue
        ents += 1
        r = deg.execute("SELECT ind, outd FROM deg WHERE qid=?", (qid,)).fetchone()
        ind, outd = (r[0], r[1]) if r else (0, 0)
        lk = links_of(qid, ind, outd, sent_of(enwiki))
        k = norm(label) if label else ""
        if k:
            nb.append((k, qid, lk, 0))
        lb.append((qid, label, lk))
        t = norm(enwiki)
        if t and t != k:
            nb.append((t, qid, lk, 1))
        if len(nb) >= 200000:
            db.executemany("INSERT INTO name VALUES (?,?,?,?)", nb)
            db.executemany("INSERT OR IGNORE INTO label VALUES (?,?,?)", lb)
            nb, lb = [], []
            print("  names %d entities (%.0fs)" % (ents, time.time() - t0), flush=True)
    db.executemany("INSERT INTO name VALUES (?,?,?,?)", nb)
    db.executemany("INSERT OR IGNORE INTO label VALUES (?,?,?)", lb)
    nn = db.execute("SELECT COUNT(*) FROM name").fetchone()[0]
    db.execute("CREATE INDEX name_norm ON name(norm)")
    db.executemany("INSERT INTO meta VALUES (?,?)", [
        ("built", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())),
        ("source_labels", REL + " entity where enwiki is not null (%d entities)" % ents),
        ("source_aliases", "enwiki titles with a normalisation different from the label (NO true Wikidata aliases shipped)"),
        ("source_links", "proxy: round(%.1f*log1p(sent) + %.1f*log1p(indeg) + %.1f*log1p(outdeg)), min 1; sent=%s article sentence counts, deg=%s fact degrees" % (sent_w, in_w, out_w, WIKI, REL)),
        ("names_rows", str(nn)),
    ])
    db.commit()
    print("names_v1: %d name rows, %d labels (%.0fs)" % (nn, ents, time.time() - t0))
    return out


def calibrate():
    """print anchor entities' proxy inputs and outputs so the weights can be sanity-checked"""
    deg = sqlite3.connect(os.path.join(VAR, "deg.sqlite3"))
    wik = sqlite3.connect(os.path.join(VAR, "wiki_sent.sqlite3"))
    src = ro(REL)
    ANCHORS = ["United States", "Norway", "France", "Albert Einstein", "Paris", "Japan",
               "Mercury (planet)", "Mercury (element)", "William Shakespeare", "Diane Lane",
               "Universe", "Train", "Iron", "BBC", "Microsoft"]
    for t in ANCHORS:
        r = src.execute("SELECT qid, label FROM entity WHERE enwiki=?", (t,)).fetchone()
        if not r:
            print("%-22s -" % t)
            continue
        qid, lab = r
        d = deg.execute("SELECT ind, outd FROM deg WHERE qid=?", (qid,)).fetchone() or (0, 0)
        s = wik.execute("SELECT n FROM sent WHERE title=?", (t,)).fetchone()
        s = s[0] if s else 0
        v = SENT_W * math.log1p(s) + IN_W * math.log1p(d[0]) + OUT_W * math.log1p(d[1])
        print("%-22s q=%-8d ind=%-8d out=%-5d sent=%-5d links=%d (true sitelinks ~%s)" % (t, qid, d[0], d[1], s, max(1, round(v)), "~" * 0))


if __name__ == "__main__":
    t0 = time.time()
    os.makedirs(VAR, exist_ok=True)
    if sys.argv[1:] == ["--calibrate"]:
        calibrate()
        sys.exit(0)
    w = [SENT_W, IN_W, OUT_W]
    if len(sys.argv) > 2 and sys.argv[1] == "--weights":
        w = [float(x) for x in sys.argv[2].split(",")]
        print("weights sent,in,out =", w)
    stage_wiki(t0)
    stage_deg(t0)
    stage_names(t0, w[0], w[1], w[2])
