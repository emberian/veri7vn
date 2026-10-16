"""fetch - UNTRUSTED read-only access to the shipped relation store for the verified reader.

Assumes: relations_v1.sqlite3 is the store (the shipped runtime read relations_v2, absent from the drop); rows of
fact(s, p, o, lit) are the whole truth the reader is judged against; an object id (o) is an entity, a literal
containing ".well-known/genid" is a Wikidata blank node, any other literal is a literal. `complete` is asserted
True only when the query had no LIMIT, i.e. it returned every row of the v1 snapshot for (qid, p in props)."""
import os
import sqlite3
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
STORE = os.environ.get("VERI7VN_RELSTORE", str(REPO / "upstream/root/relstore/relations_v1.sqlite3"))


class Store:
    def __init__(self, path=STORE):
        self.db = sqlite3.connect("file:%s?mode=ro&immutable=1" % path, uri=True, check_same_thread=False)
        self._lab = {}

    def rows(self, qid, props, limit=None):
        """(rows, complete): every (p, value) for subject qid and p in props; complete only when unbounded"""
        q = "SELECT p, o, lit FROM fact WHERE s=? AND p IN (%s)" % ",".join("?" * len(props))
        args = [qid, *props]
        if limit is not None:
            q += " LIMIT ?"
            args.append(limit)
        out = []
        for p, o, lit in self.db.execute(q, args):
            if o is not None:
                out.append([p, ["e", o]])
            elif lit is None or ".well-known/genid" in lit:
                out.append([p, ["b"]])
            else:
                out.append([p, ["l", lit]])
        return out, limit is None

    def label(self, qid):
        if qid not in self._lab:
            r = self.db.execute("SELECT label, enwiki FROM entity WHERE qid=?", (qid,)).fetchone()
            self._lab[qid] = (r[0] or r[1]) if r else None
        return self._lab[qid]

    def by_title(self, title, limit=50):
        """(exact, suffixed): qids whose English Wikipedia title is `title`, and those titled `title (disambiguator)`"""
        ex = [r[0] for r in self.db.execute("SELECT qid FROM entity WHERE enwiki=?", (title,))]
        dis = [r[0] for r in self.db.execute("SELECT qid FROM entity WHERE enwiki>=? AND enwiki<? LIMIT ?",
                                             (title + " (", title + " )", limit))]
        return ex, [q for q in dis if q not in ex]

    def fact_count(self, qid):
        return self.db.execute("SELECT count(*) FROM fact WHERE s=?", (qid,)).fetchone()[0]
