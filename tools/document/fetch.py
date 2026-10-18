#!/usr/bin/env python3
"""fetch - UNTRUSTED evidence builder for the verified document-route kernel.

Everything here is glue around Oracle7's own shipped code, imported read-only from
upstream/ (nothing under upstream is written; PYTHONDONTWRITEBYTECODE must be set by
the caller): the recognition regexes and the store reads are the organs' own, so the
evidence cannot drift from the release. The only trusted part is the decision inside
the exported kernel (Document_Route_Code, from src/isabelle/document/Document_Route.thy).

What this fetch assumes, and the kernel takes on trust:

  1. Turn classification (which route the head would take) follows the cascade's order
     as observed on the core panel: the corpus-query rules (base runtime b) before the
     factoid route (w420); the converse organ (w494) speaks where the chain could not
     parse the turn; everything else is the clarify terminal. The head's own guard --
     w420 fires only over a parent decline -- is NOT modelled: where the head clarified
     because something earlier had answered, this fetch may still propose a factoid.
  2. The independent cube CHECK of verified_retrieval_v1 is not ported; `checked` is
     always False, so a weak-route candidate is shown as an unverified passage and
     never asserted. On the measured sample every weak-route reply the head released
     had been downgraded to unverified, so this matches; a port of the cube would be
     the way to also earn `verified:weak|` replies.
  3. Stores: the bench build (m13e7) answers the corpus-query rules; the deep build
     (m13e8) feeds the factoid route and the converse organ. Both are the paths
     oracle7.py sets (ORACLE_BENCH_BUILD / ORACLE_DEEP_BUILD).
"""
from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
sys.setrecursionlimit(100000)          # the w-chain import needs it (oracle7.py: 20000)

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
# the 43 GB upstream/ drop lives in the main checkout, not in a scout worktree
UPSTREAM = REPO / "upstream"
if not UPSTREAM.exists():
    UPSTREAM = REPO.parents[2] / "upstream"      # var/scout-wt/<name> -> the main checkout
os.environ.setdefault("ORACLE7_ROOT", str(UPSTREAM / "root"))
# oracle7.py:51 sets NLTK_DATA to root/nltk_data (the WordNet the converse organ's
# noun_senses needs); without it organ.answer() raises LookupError and every statement
# turn silently degrades to the clarify terminal.
os.environ.setdefault("NLTK_DATA", str(UPSTREAM / "root" / "nltk_data"))

sys.path.insert(0, str(UPSTREAM / "root" / "wander-train"))
sys.path.insert(0, str(UPSTREAM / "root" / "fable-content" / "oracle-m-series-2026-08-15" / "self_loop" / "admitted"))

import organ_converse_v1 as OC                     # noqa: E402  (read-only import)
from oracle_cube_reader_v1_4 import CubeReader     # noqa: E402
import stage5m13e7_benchfold_induction_v1 as BF    # noqa: E402
import verified_retrieval_v1 as VR                 # noqa: E402
import oracle_release_runtime_w420 as W420         # noqa: E402
import oracle_release_runtime_w516 as W516         # noqa: E402  (the chain's presentation passes)
import oracle_release_runtime_w517 as W517         # noqa: E402
import oracle_release_runtime_w518 as W518         # noqa: E402
import oracle_release_runtime_w519 as W519         # noqa: E402
import oracle_release_runtime_w520 as W520         # noqa: E402

PH = UPSTREAM / "root" / "fable-content" / "oracle-m-series-2026-08-15"
BENCH = PH / "m13e7_dbpedia_openstax_full_fable_bench_a_v1" / "wikipedia_specialist.sqlite3"
DEEP = PH / "m13e8_dbpedia_enslot_openstax_full_fable_bench_a_v1" / "wikipedia_specialist.sqlite3"

PROPERTY_OF = next(pat for rid, pat, _ in BF.RULES if rid == "property_of")
FRAGMENT = re.compile(r"^\s*(?:[a-z]|\d{1,4}\s*[)\]])")   # oracle_release_runtime_aa.FRAGMENT, copied


class Fetch:
    def __init__(self):
        self.bench = BF.DBpediaQuery(BENCH)
        self.deep = BF.DBpediaQuery(DEEP)
        self.cube = CubeReader(str(DEEP))
        organ = object.__new__(OC.ConverseOrgan)    # skip __init__: no jokes/recipes stores here
        organ.r = self.cube
        self.organ = organ
        w420 = object.__new__(W420.OracleReleaseRuntimeW420)  # the statics only; stores injected below
        w420.bench_query = self.bench
        w420._s244_deep = self.deep
        self.w420 = w420
        self._declined_res = {"status": "clarification", "path": "act:clarify|vessel:receipt"}

    # ---- helpers ---------------------------------------------------------------------------

    @staticmethod
    def _claim(cid, sentence, page=""):
        return {"id": str(cid), "page": page, "sentence": " ".join(str(sentence).split()),
                "fragment": bool(FRAGMENT.match(str(sentence))),
                "year": bool(W420.YEAR.search(str(sentence))), "tier": None}

    def _base(self, turn, q, topic=""):
        return {"turn": turn, "topic": topic, "asked": q, "future": False,
                "pool": {"resolved": False, "conjunctive": 0, "claims": []},
                "tiers": [], "checked": False, "subject_defines": False,
                "disambiguates": False, "covered": [], "candidate": None}

    # ---- the routes -----------------------------------------------------------------------

    def corpus_turn(self, q):
        """runtime b's property_of rule: exact page + keyword-scored sentence, else conjunctive FTS."""
        ev = self._base("corpus", q)
        stripped = q.rstrip("?.! ").strip()
        m = PROPERTY_OF.match(stripped + "?") or PROPERTY_OF.match(stripped)
        if not m:
            return None
        result = BF.apply_rule(self.bench, "property_of", m)
        if result is None:
            return ev
        cid, fact = result
        ev["candidate"] = self._claim(cid, fact)
        return ev

    def factoid_turn(self, q):
        """w420's own _f420_try over the same two stores, with a synthetic declined parent reply."""
        t0 = time.time()
        out = self.w420._f420_try(" ".join(str(q).split()), dict(self._declined_res), t0)
        if not out:
            return None                          # nothing found: the turn falls through to the terminal
        prov = (out.get("provenance") or {}).get("factoid") or {}
        via = prov.get("via", "page")
        ev = self._base("fts" if via == "fts" else "page", q, topic=str(prov.get("entity") or ""))
        ev["candidate"] = self._claim(_cid_of(out), _sentence_of(out), page=str(prov.get("page") or ""))
        return ev

    def converse_turn(self, q):
        """organ_converse_v1's own answer(): the statement move with its definition and citation."""
        a = None
        try:
            a = self.organ.answer(" ".join(str(q).split()))
        except Exception:                        # noqa: BLE001 - WordNet absent, store hiccup: no statement
            return None
        if not a or a.get("kind") not in ("statement", "request"):
            return None
        text = str(a.get("response") or "")
        # "Got it. Since you mention {about}: {sentence} [cite] Want to know more about it?" -- the first
        # colon after the mention ends the topic; the sentence runs to the citation tag.
        tail = text.split("Since you mention", 1)
        if len(tail) != 2:
            return None
        about, _, rest = tail[1].partition(":")
        m = re.search(r"^(.*?)\s*\[([a-z]+_[0-9a-f]{6,})\]", rest.strip())
        if not m:
            return None
        sentence, cid = m.group(1).strip(), m.group(2)
        about = about.strip()
        ev = self._base("statement", q, topic=about)
        ev["future"] = bool(re.search(r"\b(?:tomorrow|next week|soon|going to|about to|gonna)\b", q, re.I))
        claim = self._claim(cid, sentence)
        ev["pool"] = {"resolved": True, "conjunctive": 0, "claims": [claim]}
        ev["candidate"] = claim
        ev["subject_defines"] = True             # the organ's definition(): the page's own defining sentence
        ev["disambiguates"] = bool(re.search(r"may refer to|can refer to|disambiguation", sentence, re.I))
        ev["covered"] = [w.lower() in sentence.lower() for w in about.split()]
        return ev

    def _factoid_eligible(self, q):
        """w420's own chat gate, read from its chat(): GUARD_Q or a trailing '?' only ENTER the
        function -- the factoid attempt itself fires only for a WH-question shape (is_wh), over
        a parent decline, not about the machine, not a number dump."""
        s = " ".join(str(q).split())
        if not W420.WHQ.match(s):
            return False
        if W420.SELF_Q.search(s) or W420.OWNED_FORMS.search(s):
            return False
        return W420._numbers(s) < 3

    def evidence(self, q):
        """The cascade order as the head runs it: the corpus rules of the base runtime, then
        w420's factoid route over a decline, then the converse organ on an unparseable turn."""
        q = " ".join(str(q).split())
        ev = self.corpus_turn(q)
        if ev is not None:
            return ev, "corpus_query:property_of"
        if self._factoid_eligible(q):
            ev = self.factoid_turn(q)
            if ev is not None:
                return ev, "factoid"
        ev = self.converse_turn(q)
        if ev is not None:
            return ev, "organ:converse"
        return self._base("fallback", q), "terminal"

    def present(self, q, out):
        """The head's own presentation passes, in the chain's order (w516.present, w517.present2,
        w518.present3, w519.present3b, w520.present4), over the kernel's rendered reply. The
        organs' rule is that presentation never changes status, path or what is asserted; running
        the organs' own code keeps the text from drifting."""
        for fn in (W516.present, lambda o: W517.present2(q, o), W518.present3, W519.present3b, W520.present4):
            try:
                out = fn(out)
            except Exception:                    # noqa: BLE001 - presentation never costs the turn
                pass
        return out


def _cid_of(out):
    refs = out.get("references") or []
    return refs[0].get("id") if refs and isinstance(refs[0], dict) else ""


def _sentence_of(out):
    """verified_retrieval_v1._sentence on the w420 reply: tags stripped, first sentence."""
    return VR._sentence(out.get("response", ""))
