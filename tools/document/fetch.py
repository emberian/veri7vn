#!/usr/bin/env python3
"""fetch - UNTRUSTED evidence builder for the verified document-route kernel.

Everything here is glue around Oracle7's own shipped code, imported read-only from
upstream/ (nothing under upstream is written; PYTHONDONTWRITEBYTECODE must be set by
the caller): the recognition regexes and the store reads are the organs' own, so the
evidence cannot drift from the release. The only trusted part is the decision inside
the exported kernel (Document_Route_Code, from src/isabelle/document/Document_Route.thy).

What this fetch assumes, and the kernel takes on trust:

  1. Turn classification follows the head's cascade order as read from its sources: the
     corpus-query rules (base runtime b), their decline included; else runtime S's arbiter capture (arbiter v3, family
     "definitional", canonical surface "What is a <topic>?" over the bench anchor store, the
     redispatch read with runtime c / w193's own _definitional_turn); then w420's factoid
     route; then the converse organ (w494) where nothing spoke; else the clarify terminal.
     The base chain's other organs (relation reader, specialists, maths) are not consulted:
     a turn they would have taken is not a document-route turn.
  2. When the arb redispatch is not a definitional lead, the head's document_runtime answered
     it with text this fetch cannot see; the candidate is then empty and the path label is
     "arb:definitional->document_runtime|substitution_disclosed" (runtime z discloses the
     substitution whenever the turn is a what-is question, which is what the recorded panel
     shows on every such item).
  3. The cube CHECK of verified_retrieval_v1 is not ported, and no flag stands in for it: the
     kernel asserts a weak-route sentence only by the definition test it reads off the text.
  4. Flags the kernel cannot read itself: the DEF_Q shape of the question and its asked term
     (verified_reach_v1.DEF_Q / RELATIVE), w468's pointer phrase (DEICTIC, then POINTER),
     w511's P4 shape (the question gives numbers and asks for a number, and the route that took
     it is a lookup that answered), and the displaced path label. The kernel re-checks what it
     can: the pointer must occur in the question, the P4 question must carry a numeral, and
     the computation gateway reads the question itself, whatever this fetch says.
  5. Stores: the bench build (m13e7) answers the corpus-query rules and holds the arbiter's
     anchor titles; the deep build (m13e8) feeds the factoid route and the converse organ.
     Every store is opened read-only with immutable=1 by the organs' own classes.
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
import oracle_release_runtime_d as RD              # noqa: E402  (the anchor store)
import oracle_release_runtime_q as RQ              # noqa: E402  (the canonical surface)
import oracle_release_runtime_z as RZ              # noqa: E402  (substitution disclosure)
import oracle_release_runtime_w193 as W193         # noqa: E402  (the head's _definitional_turn)
import oracle_release_runtime_w468 as W468         # noqa: E402  (the door's pointer)
import oracle_release_runtime_w511 as W511         # noqa: E402  (P4's number shapes)
import stage5m17_release_arbiter_v3 as ARB         # noqa: E402  (runtime S's arbiter)
import verified_reach_v1 as VREACH                 # noqa: E402  (DEF_Q, RELATIVE)

PH = UPSTREAM / "root" / "fable-content" / "oracle-m-series-2026-08-15"
BENCH = PH / "m13e7_dbpedia_openstax_full_fable_bench_a_v1" / "wikipedia_specialist.sqlite3"
DEEP = PH / "m13e8_dbpedia_enslot_openstax_full_fable_bench_a_v1" / "wikipedia_specialist.sqlite3"

PROPERTY_OF = next(pat for rid, pat, _ in BF.RULES if rid == "property_of")
FRAGMENT = re.compile(r"^\s*(?:[a-z]|\d{1,4}\s*[)\]])")   # oracle_release_runtime_aa.FRAGMENT, copied
# w511 guard(): the second half of asks_number, inline there (copied verbatim)
WHAT_NUMBER = re.compile(
    r"^\s*what(?:'s| is| was) the (?:kinetic |potential )?(?:area|volume|circumference|perimeter|energy|momentum|force|speed|"
    r"velocity|density|mass|weight|power|resistance|current|pressure|work|cost|price|average|mean|hypotenuse|ph|"
    r"square root|cube root|sum|product|value)\b", re.I)


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
        self.anchors = RD.AnchorStore(self.bench.connection)      # runtime d: titles of the bench build
        q = object.__new__(RQ.OracleReleaseRuntimeQ)               # statics + anchors only
        q.anchors = self.anchors
        self.arb_q = q
        c = object.__new__(W193.OracleReleaseRuntimeW193)          # _definitional_turn through the head's MRO
        c.bench_query = self.bench
        c.anchors = self.anchors
        self.defn = c

    # ---- helpers ---------------------------------------------------------------------------

    @staticmethod
    def _claim(cid, sentence, page=""):
        return {"id": str(cid), "page": page, "sentence": " ".join(str(sentence).split()),
                "fragment": bool(FRAGMENT.match(str(sentence))),
                "year": bool(W420.YEAR.search(str(sentence))), "tier": None}

    def _base(self, turn, q, topic=""):
        m = VREACH.DEF_Q.match(q)
        x = ((m.group(1) or m.group(2) or "").strip()) if m else ""
        point = W468.DEICTIC.search(q) or W468.POINTER.search(q)
        return {"turn": turn, "topic": topic, "asked": q, "future": False,
                "pool": {"resolved": False, "conjunctive": 0, "claims": []},
                "tiers": [], "candidate": None,
                "term": x, "def_question": bool(x) and not VREACH.RELATIVE.search(x),
                "pointer": point.group(0) if point else None,
                "lookup_for_compute": False, "displaced": ""}

    @staticmethod
    def _p4_shape(q):
        """w511's P4 question side: the question gives numbers, and asks for a number."""
        return bool(W511._nums(q)) and bool(W511.NUMQ.search(q) or WHAT_NUMBER.match(q))

    def _answered_by(self, ev, path):
        """the lookup route answered in the head (before verified retrieval): name its path, and
        mark P4's shape"""
        ev["displaced"] = path
        ev["lookup_for_compute"] = self._p4_shape(ev["asked"])
        return ev

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
        return self._answered_by(ev, "corpus_query:property_of")

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
        return self._answered_by(ev, "factoid:fts" if via == "fts" else "factoid:page")

    def arb_turn(self, q):
        """runtime S's capture: arbiter v3 bids "definitional" with a clean margin, the canonical
        surface "What is a <topic>?" names a bench title, and the redispatch is read with the
        head's own _definitional_turn (runtime c, widened by w193). Runtime z's disclosure is
        applied to the lead it found."""
        rec = ARB.arbitrate(" ".join(q.split()))
        if rec.clarification_floor_applied or rec.winner != "definitional":
            return None
        canonical = self.arb_q._canonical_surface("definitional", q)
        if not canonical:
            return None
        try:
            d = self.defn._definitional_turn(canonical)
        except Exception:                        # noqa: BLE001 - no lead: the document runtime answers
            d = None
        ev = self._base("arbdef", q)
        asked = RZ.ASK_WHAT_IS.match(" ".join(q.strip().split()))
        if d:
            path = "arb:definitional->" + str(d.get("path"))
            body = str(d.get("response") or "")
            found = RZ.DEFINED_TERM.match(body.strip())
            if asked and found and RZ._norm(found.group("term")) != RZ._norm(asked.group("t")):
                path += "|substitution_disclosed"
            prov = d.get("provenance") or {}
            ev["candidate"] = self._claim(prov.get("claim_id") or "", VR._sentence(body), page=str(prov.get("page") or ""))
        else:
            path = "arb:definitional->document_runtime" + ("|substitution_disclosed" if asked else "")
        return self._answered_by(ev, path)

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
        ev["term"] = about                       # the kernel checks it is named by the question and the sentence
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
        """The cascade order as the head runs it (see the module docstring, item 1)."""
        q = " ".join(str(q).split())
        ev = self.corpus_turn(q)
        if ev is not None:
            # w420 fires over a parent decline, and a corpus decline is one; but on the core panel the head
            # keeps the corpus decline on 21 of the 25 such items (the four it does not are cube volumes
            # with a number, guarded by P4 over a factoid:page). Which fold makes the difference was not
            # found; the decline is kept, and those four are named misses.
            return ev, "corpus_query:property_of"
        ev = self.arb_turn(q)
        if ev is not None:
            return ev, "arb:definitional"
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
