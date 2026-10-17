#!/usr/bin/env python3
"""Build var/rel-novels/norm_index.sqlite3: a labels-only stand-in for Oracle7's missing names_v1.sqlite3.

names_v1 held every English label AND alias with sitelink counts; neither it nor linking_src/ shipped. The v1
relation store's own entity table (qid, label, enwiki) is what we have. This index normalises each label and
each enwiki title (entity_linker_v1's norm: NFKD, strip combining, lowercase, [a-z0-9]+ runs) and stores
(norm, qid, src) with src 0 = label, 1 = enwiki title. Popularity is read per candidate later as the subject's
fact count (lane F's stand-in for sitelinks). Aliases do not exist here; that gap is reported, not hidden.
Read-only against upstream/. UNTRUSTED glue.
"""
import os
import re
import sqlite3
import sys
import time
import unicodedata

REPO = "/Users/ember/dev/o7vn"                # the main checkout; this worktree has no upstream/
SRC = os.path.join(REPO, "upstream/root/relstore/relations_v1.sqlite3")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "var/rel-novels", "norm_index.sqlite3")


def norm(s):
    s = unicodedata.normalize("NFKD", str(s))
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    return " ".join(re.findall(r"[a-z0-9]+", s))


def main():
    if os.path.exists(OUT):
        os.remove(OUT)
    db = sqlite3.connect(OUT)
    db.execute("CREATE TABLE name (norm TEXT, qid INTEGER, src INTEGER)")
    src = sqlite3.connect("file:%s?mode=ro&immutable=1" % SRC, uri=True)
    t0 = time.time()
    batch, total, ents = [], 0, 0
    for qid, label, enwiki in src.execute("SELECT qid, label, enwiki FROM entity"):
        ents += 1
        for text, s in ((label, 0), (enwiki, 1)):
            if text:
                k = norm(text)
                if k:
                    batch.append((k, qid, s))
        if len(batch) >= 200000:
            db.executemany("INSERT INTO name VALUES (?,?,?)", batch)
            total += len(batch)
            batch = []
            print("%d rows from %d entities (%.0fs)" % (total, ents, time.time() - t0), flush=True)
    if batch:
        db.executemany("INSERT INTO name VALUES (?,?,?)", batch)
        total += len(batch)
    db.execute("CREATE INDEX name_norm ON name(norm)")
    db.commit()
    n = db.execute("SELECT COUNT(*) FROM name").fetchone()[0]
    print("done: %d rows (%d inserted pre-index), %d entities, %.0fs" % (n, total, ents, time.time() - t0))


if __name__ == "__main__":
    sys.exit(main())
