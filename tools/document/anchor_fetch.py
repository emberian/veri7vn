#!/usr/bin/env python3
"""UNTRUSTED, read-only witnesses for a checked explanatory document route.

This does not choose the first title alias. All rows for the requested normalized
title (and the explicit singular fallback) are returned, including ambiguity.
The decision must check the complete question shape, alias/page agreement and
claim page membership. Source authenticity and alias-query completeness remain
assumptions; source sentence selection is not a proof of natural-language truth.
Unlike the legacy document adapter this module imports no Oracle7 runtime chain.
"""
from pathlib import Path
import re
import sqlite3
import unicodedata

REPO = Path(__file__).resolve().parents[2]
DEFAULT_STORE = REPO / "upstream/root/fable-content/oracle-m-series-2026-08-15/m13e7_dbpedia_openstax_full_fable_bench_a_v1/wikipedia_specialist.sqlite3"
TOPIC = r"[A-Za-z0-9][A-Za-z0-9' -]*?"
FORMS = [
    ("discourse", re.compile(r"^(?P<prefix>i am interested in|i like|tell me about|i want to learn about) (?P<article>)(?P<topic>" + TOPIC + r")(?P<punct>[?.]?)$", re.I)),
    ("cause", re.compile(r"^(?P<prefix>what causes|what makes) (?P<article>a |an |the |)(?P<topic>" + TOPIC + r")(?P<punct>[?.]?)$", re.I)),
    ("process", re.compile(r"^(?P<prefix>how does|how do|how is|how are|how can) (?P<article>a |an |the |)(?P<topic>" + TOPIC + r") (?P<verb>work|works|erupt|erupts|happen|happens|form|forms|occur|occurs|made|grow|grows|move|moves|function|functions)(?P<punct>[?.]?)$", re.I)),
    ("when", re.compile(r"^(?P<prefix>when did|when was|when were|when does|when do) (?P<article>the |)(?P<topic>" + TOPIC + r") (?P<verb>start|begin|end|happen|occur|founded|built|discovered|invented|born|die)(?P<punct>[?.]?)$", re.I)),
]


def title_key(text):
    """Match the shipped title index; this normalization is untrusted."""
    return " ".join(re.findall(r"[^\W_]+(?:[-'][^\W_]+)?", unicodedata.normalize("NFKC", text).casefold()))


def propose(question):
    normalized = " ".join(str(question).split())
    for kind, pattern in FORMS:
        matched = pattern.fullmatch(normalized)
        if matched:
            fields = matched.groupdict()
            return {"question": normalized, "kind": kind, "topic": fields["topic"],
                    "prefix": fields["prefix"].lower(), "article": fields["article"].lower(),
                    "verb": fields.get("verb", "").lower(), "punctuation": fields["punct"]}
    return None


class AnchorFetch:
    def __init__(self, path=DEFAULT_STORE):
        self.path = Path(path).resolve()
        self.db = sqlite3.connect(self.path.as_uri() + "?mode=ro&immutable=1", uri=True)

    def close(self):
        self.db.close()

    def evidence(self, question):
        request = propose(question)
        if request is None:
            return None
        key = title_key(request["topic"])
        keys = [key]
        if len(key) > 3 and key.endswith("s") and not key.endswith("ss"):
            keys.append(key[:-1])
        aliases = []
        for alias in keys:
            aliases += [{"alias": source_alias, "page_id": pid, "title": title, "url": url}
                        for source_alias, pid, title, url in self.db.execute(
                            "SELECT t.normalized_title,coalesce(t.page_id,''),coalesce(a.title,''),coalesce(a.canonical_url,'') FROM title_alias t "
                            "LEFT JOIN article a ON a.page_id=t.page_id WHERE t.normalized_title=? "
                            "ORDER BY a.page_id", (alias,))]
        # No arbitrary page is selected when a surface names multiple pages.
        rows = []
        pages = sorted({a["page_id"] for a in aliases})
        if len(pages) == 1:
            title = next(a["title"] for a in aliases if a["page_id"] == pages[0])
            rows = [{"page_id": pid, "source_page_id": source_pid, "id": cid, "page": title, "sentence": sentence,
                     "ordinal": ordinal, "source_hash": digest}
                    for pid, source_pid, cid, sentence, ordinal, digest in self.db.execute(
                        "SELECT p.page_id,s.page_id,s.claim_id,s.fact,p.sentence_ordinal,s.fact_sha256 "
                        "FROM page_sentence p JOIN source_rows s ON s.rowid=p.source_rowid "
                        "WHERE p.page_id=? ORDER BY p.sentence_ordinal LIMIT 60", (pages[0],))]
        stat = self.path.stat()
        return {"request": request, "aliases": aliases, "rows": rows,
                "source_scope": {"path": str(self.path), "size": stat.st_size, "mtime_ns": stat.st_mtime_ns,
                    "alias_keys": keys, "row_limit": 60, "returned_rows": len(rows),
                    "assumptions": ["all matching title-alias rows were returned",
                                    "exact requested alias-to-canonical-title association is trusted; fallback requires literal requested topic",
                                    "article and page-sentence rows belong to this source snapshot",
                                    "source assertions are not proved by quotation"],
                    "untrusted": ["question proposal", "title-key normalization", "SQLite fetch"]}}
