#!/usr/bin/env python3
"""fetch - UNTRUSTED evidence builder for the verified document-route kernel.

This legacy fallback wraps Oracle7's shipped code, imported read-only from
upstream/ (nothing under upstream is written; PYTHONDONTWRITEBYTECODE must be set by
the caller): the recognition regexes and the store reads are the organs' own, so the
source fetch stays outside HOL. Convenient-word converse statements are disabled;
whole-request discourse uses anchor_fetch.py and the extracted anchor kernel first.
The checked decision inside this legacy path is
the exported kernel (Document_Route_Code, from src/isabelle/document/Document_Route.thy).

What this fetch assumes, and the kernel takes on trust:

  1. Turn classification follows the head's cascade order as read from its sources: the
     corpus-query rules (base runtime b), their decline included; else runtime S's arbiter capture (arbiter v3, family
     "definitional", canonical surface "What is a <topic>?" over the bench anchor store, the
     redispatch read with runtime c / w193's own _definitional_turn); then w420's factoid
     route; else the clarify terminal. The old converse organ no longer admits statements.
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
     (verified_reach_v1.DEF_Q / RELATIVE), a whole reference-only request's pointer,
     w511's P4 shape (the question gives numbers and asks for a number, and the route that took
     it is a lookup that answered), and the displaced path label. The kernel re-checks what it
     can: the pointer must occur in the question, the P4 question must carry a numeral, and
     the computation gateway reads the question itself, whatever this fetch says.
  5. Stores: the bench build (m13e7) answers the corpus-query rules and holds the arbiter's
     anchor titles; the deep build (m13e8) feeds the factoid route.
     Every store is opened read-only with immutable=1 by the organs' own classes (the arbiter's
     ConceptNet connection, which v3 opens with mode=ro only, is opened here with immutable=1
     and handed to it first).
  6. The capability captures (lane W5-18). Runtime S's arbiter capture also takes the families
     "timeline" and "explain_simply" (canonical surfaces "Give me a timeline of <topic>." and
     "Explain <topic> simply."), redispatched to the capability turns the tip's MRO owns (runtime
     AC's _timeline_turn over J's, AC's _simply_turn); runtime AO rewrites a bare phrase that
     nothing answered (AO.BARE, at most four words, no question mark, not a continuation) into
     "Summarize <phrase>." for runtime F's _summarize_turn. The organs run here on an object of
     runtime AC's class with the bench store, the anchor store, the Wiktionary build and an empty
     user corpus (a fresh session). The kernel is handed each capability's own material: F's and
     AC's gated bundle of the topic's anchor page (AC's Wiktionary gloss as one more claim), J's
     gated page sentences. The kernel ports none of the compositions (summary paragraph,
     timeline, simple register) and withholds on every capture. The organ's own reply is used
     here only to keep the head's order: what w420 does over it (w420_over, its chat read from
     source), and whether w426's bridge is tried (only over a declined parent). The arbiter's
     verdict and the anchor topic are this fetch's; the kernel checks that the topic's tokens
     occur in the question, reads the bare-phrase shape itself, and counts dated statements.
  7. The bridge as the tip owns it (w430's _c426_bridge: w426's two hops with a first-hop floor
     of one half), tried over a declined parent after w420, and only where w426 tries it: not a
     comparison or both-form (their rules are not ported, so those turns get no bridge here),
     not a derived-fact question (DERIVED_Q: w426 reads its derived store first, which is not
     opened here), not about the machine, fewer than three numbers. Its reply is a weak-route
     sentence, shown and not asserted unless the kernel's definition test releases it. The
     search runs under w420's own 4 s budget, so on a slower machine it can find less.
  8. Over a capture's reply, w420's factoid try is the tip's (w424's _f420_try, through the bridge
     object); over the terminal it is still w420's own, as W5-17 measured it.
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
# Retain the upstream runtime chain's configured lexical resources. The old
# converse organ is no longer constructed or called by this fetch.
os.environ.setdefault("NLTK_DATA", str(UPSTREAM / "root" / "nltk_data"))

sys.path.insert(0, str(UPSTREAM / "root" / "wander-train"))
sys.path.insert(0, str(UPSTREAM / "root" / "fable-content" / "oracle-m-series-2026-08-15" / "self_loop" / "admitted"))

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
import oracle_release_runtime_w511 as W511         # noqa: E402  (P4's number shapes)
import stage5m17_release_arbiter_v3 as ARB         # noqa: E402  (runtime S's arbiter)
import sqlite3                                     # noqa: E402
if ARB._connection is None and ARB.CONCEPTNET_DB.exists():   # immutable=1: no -shm write under upstream
    ARB._connection = sqlite3.connect(ARB.CONCEPTNET_DB.resolve().as_uri() + "?mode=ro&immutable=1", uri=True)
import oracle_release_runtime_ao as RAO            # noqa: E402  (the bare-phrase rewrite)
import oracle_release_runtime_f as RF              # noqa: E402  (summarize)
import oracle_release_runtime_j as RJ              # noqa: E402  (timeline)
import oracle_release_runtime_m as RM              # noqa: E402  (explain simply: SIMPLY, the gloss)
import oracle_release_runtime_ac as RAC           # noqa: E402  (the capability turns, as the tip's MRO owns them)
import oracle_release_runtime_w426 as W426         # noqa: E402  (the bridge's gates)
import oracle_release_runtime_w430 as W430         # noqa: E402  (the tip's bridge: first-hop floor one half)
from stage5m13e8_relevance_gate_v1 import gate_bundle  # noqa: E402
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

# UNTRUSTED proposal for the legacy door. A pronoun anywhere in a request does
# not establish missing context: the same turn may already name its subject.
# Only these complete reference-only forms propose a pointer. Shared dialogue
# handles supported contextual bindings before this stateless fallback.
REFERENCE_ONLY = re.compile(
    r"\s*(?:(?:what|who|where)\s+(?:is|are|was|were)\s+"
    r"(?P<subject>it|this|that|they|these|those)|"
    r"what\s+(?:is|was)\s+(?P<possessive>its|their)\s+[a-z]+|"
    r"(?:tell me about|describe|explain)\s+(?P<object>it|this|that|them|these|those))"
    r"\s*[?.!]?\s*", re.I)


class Fetch:
    def __init__(self):
        self.bench = BF.DBpediaQuery(BENCH)
        self.deep = BF.DBpediaQuery(DEEP)
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
        # the bridge as the tip owns it (w430's _c426_bridge; w426's hops; w424's factoid try), stores injected
        b = object.__new__(W430.OracleReleaseRuntimeW430)
        b.bench_query = self.bench
        b._s244_deep = self.deep
        self.bridge = b
        # the capability turns as the tip owns them: F's _summarize_turn, AC's _timeline_turn (over J's) and
        # _simply_turn, d's _bundle, M's _gloss; no user documents in a fresh session
        cap = object.__new__(RAC.OracleReleaseRuntimeAC)
        cap.bench_query = self.bench
        cap.anchors = self.anchors
        cap.user_corpus = _NoUserCorpus()
        cap._wikt = (sqlite3.connect(RM.WIKT.resolve().as_uri() + "?mode=ro&immutable=1", uri=True)
                     if RM.WIKT.exists() else None)
        self.cap = cap

    # ---- helpers ---------------------------------------------------------------------------

    @staticmethod
    def _claim(cid, sentence, page=""):
        return {"id": str(cid), "page": page, "sentence": " ".join(str(sentence).split()),
                "fragment": bool(FRAGMENT.match(str(sentence))),
                "year": bool(W420.YEAR.search(str(sentence))), "tier": None}

    def _base(self, turn, q, topic=""):
        m = VREACH.DEF_Q.match(q)
        x = ((m.group(1) or m.group(2) or "").strip()) if m else ""
        point = REFERENCE_ONLY.fullmatch(q)
        return {"turn": turn, "topic": topic, "asked": q, "future": False,
                "pool": {"resolved": False, "conjunctive": 0, "claims": []},
                "tiers": [], "candidate": None,
                "term": x, "def_question": bool(x) and not VREACH.RELATIVE.search(x),
                "pointer": next((value for value in point.groups() if value), None) if point else None,
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

    def factoid_turn(self, q, out=None):
        """w420's own _f420_try over the same two stores, with a synthetic declined parent reply."""
        t0 = time.time()
        if out is None:
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
        applied to the lead it found. A "timeline" or "explain_simply" bid is redispatched to
        runtime AC's own turn (module docstring, item 6). Returns (ev, the redispatch's reply) or None."""
        rec = ARB.arbitrate(" ".join(q.split()))
        if rec.clarification_floor_applied or rec.winner not in ("definitional", "timeline", "explain_simply"):
            return None
        canonical = self.arb_q._canonical_surface(rec.winner, q)
        if not canonical:
            return None
        if rec.winner == "timeline":
            return self.timeline_turn(q, canonical)
        if rec.winner == "explain_simply":
            return self.explain_turn(q, canonical)
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
        return self._answered_by(ev, path), {"status": "answered", "path": path}

    # ---- the capability captures (W5-18) ------------------------------------------------------

    def _anchor_rows(self, topic, n):
        """runtime d's _bundle: the anchor page's first n sentences (bench build)"""
        return self.cap._bundle(topic, n=n)

    def _capture(self, q, turn, topic, admitted, arb, out):
        ev = self._base(turn, q, topic=topic)
        claims = [self._claim(c["claim_id"], c["sentence"], page=str(c.get("page") or "")) for c in admitted]
        ev["pool"] = {"resolved": False, "conjunctive": 0, "claims": claims}
        ev["arb"] = arb
        return ev, out

    def summarize_turn(self, q):
        """runtime AO's bare-phrase rewrite, then runtime F's own _summarize_turn on "Summarize <q>.". The
        kernel is handed F's material (the gated bundle of eight anchor sentences). Returns (ev, F's reply)."""
        s = " ".join(str(q).split())
        if not (RAO.BARE.match(s) and len(s.split()) <= 4 and not s.endswith("?") and not RAO.CONTINUATION.match(s)):
            return None
        out = self.cap._summarize_turn("Summarize %s." % s, SESSION)
        if out is None:
            return None
        topic = str((out.get("provenance") or {}).get("topic") or s)
        admitted, _ = gate_bundle(topic, self._anchor_rows(topic, 8))
        return self._capture(s, "summarize", topic, admitted, False, out)

    def timeline_turn(self, q, canonical):
        """runtime AC's own _timeline_turn (over J's) on the canonical surface. The kernel is handed J's
        material: the anchor page's first forty sentences, gated. Returns (ev, the organ's reply)."""
        out = self.cap._timeline_turn(canonical, SESSION)
        m = RJ.TIMELINE.match(canonical.strip())
        if out is None or not m:
            return None
        topic = m.group("t").strip()
        page = self.anchors.resolve(topic)
        deep = []
        if page:
            title = self.anchors.page_to_title.get(page, topic)
            deep = [{"claim_id": c, "page": title, "sentence": x} for c, x in self.bench.page_sentences(page)[:40]]
        admitted, _ = gate_bundle(topic, deep)
        out = dict(out, path="arb:timeline->" + str(out.get("path")))        # runtime S's prefix
        return self._capture(q, "timeline", topic, admitted, True, out)

    def explain_turn(self, q, canonical):
        """runtime AC's own _simply_turn on the canonical surface. The kernel is handed AC's material: the gated
        bundle of eight anchor sentences and the Wiktionary gloss (one claim, cited as AC cites it)."""
        out = self.cap._simply_turn(canonical, SESSION)
        m = RM.SIMPLY.match(canonical.strip())
        if out is None or not m:
            return None
        topic = (m.group("t") or m.group("t2") or "").strip()
        admitted, _ = gate_bundle(topic, self._anchor_rows(topic, 8))
        gloss = self.cap._gloss(topic)
        if gloss:
            admitted = list(admitted) + [{"claim_id": "wiktionary:%s:sense1" % topic.lower(), "page": "Wiktionary",
                                          "sentence": str(gloss)}]
        out = dict(out, path="arb:explain_simply->" + str(out.get("path")))  # runtime S's prefix
        return self._capture(q, "explain_simply", topic, admitted, True, out)

    def w420_over(self, q, res):
        """w420's chat over the parent reply `res` (the capture's organ reply, or the terminal's), read from its
        source: over a decline, a WH-question gets the factoid try; over an answered capability reply, a
        WH-question gets it when the reply is a dump route for a question with a proper noun (and the try covers
        the question), or when the reply covers under half of the question's terms. Returns w424's factoid reply
        (the tip's _f420_try) or None. The factoid:withheld receipt w420 gives an uncovered non-WH turn is not
        modelled (the capture's own withhold stands, status withheld either way)."""
        w = self.bridge                           # the tip's w420/w424 methods with the stores injected
        s = " ".join(str(q).split())
        is_wh = bool(W420.WHQ.match(s))
        if not is_wh and not (s.endswith("?") or W420.GUARD_Q.match(s)):
            return None
        if W420.SELF_Q.search(s) or W420.OWNED_FORMS.search(s) or W420._numbers(s) >= 3 \
                or str(res.get("path", "")).startswith(W420.OPERATOR_PATHS):
            return None
        t0 = time.time()
        if w._f420_declined(res):
            return w._f420_try(s, res, t0) if is_wh else None
        cap = w._f420_spans(s, lower=False)
        spans = cap or w._f420_spans(s)
        if not spans:
            return None
        kind, noun = w._f420_type(s)
        span_toks = set()
        for sp in cap:
            span_toks |= W420._toks(sp)
        constraints = [t for t in W420._qterms(s) if t not in span_toks and t != noun and not W420.YEAR.match(t)]
        if not cap and (W420.ANAPHORA.search(s) or len(constraints) + (1 if noun else 0) < 2):
            return None
        guard_terms = constraints + ([noun] if noun else [])
        path = str(res.get("path", ""))
        if is_wh and cap and path.startswith(W420.DUMP_PATHS) and kind != "any":
            out = w._f420_try(s, res, t0)
            cov = (((out or {}).get("provenance") or {}).get("factoid") or {}).get("coverage")
            if out and cov is not None and (cov or 0) >= W420.FULL:
                return out
        if w._f420_uncovered(res, guard_terms, cap) and is_wh:
            return w._f420_try(s, res, t0)
        return None

    def bridge_turn(self, q):
        """the tip's _c426_bridge (w430's) over a declined parent, where w426 would try it (module docstring,
        item 7)."""
        s = " ".join(str(q).split())
        if W426.CMP_EARLIER.match(s) or W426.CMP_FIRST.match(s) or W426.BOTH.match(s) or W426.DERIVED_Q.search(s):
            return None
        if W420.SELF_Q.search(s) or W420._numbers(s) >= 3:
            return None
        t0 = time.time()
        out = self.bridge._c426_bridge(s, dict(self._declined_res), t0)
        if not out:
            return None
        ev = self._base("bridge", s, topic=str(((out.get("provenance") or {}).get("compose") or {}).get("bridge") or ""))
        ev["candidate"] = self._claim(_cid_of(out), _sentence_of(out))
        return self._answered_by(ev, "compose:bridge")

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
        """The cascade order as the head runs it (see the module docstring, items 1, 6 and 7): the corpus rules,
        runtime S's capture, runtime AO's bare-phrase rewrite, w420 (w424's try), w426 (w430's bridge), then
        the terminal when none of these paths has evidence."""
        q = " ".join(str(q).split())
        ev = self.corpus_turn(q)
        if ev is not None and (ev.get("candidate") is not None or self.summarize_turn(q) is None):
            # w420 fires over a parent decline, and a corpus decline is one; but on the core panel the head
            # keeps the corpus decline on 21 of the 25 such items (the four it does not are cube volumes
            # with a number, guarded by P4 over a factoid:page). Which fold makes the difference was not
            # found; the decline is kept, and those four are named misses.
            return ev, "corpus_query:property_of"
        got = self.arb_turn(q)
        if got is not None and got[0]["turn"] == "arbdef":
            return got[0], "arb:definitional"
        if got is None or got[1].get("status") != "answered":
            summ = self.summarize_turn(q)        # runtime AO: the probe did not answer, the phrase is bare
            if summ is not None:
                got = summ
        parent, res = got if got is not None else (None, dict(self._declined_res))
        out = self.w420_over(q, res) if parent is not None else (
            self.w420._f420_try(q, res, time.time()) if self._factoid_eligible(q) else None)
        if out:
            return self.factoid_turn(q, out), "factoid"
        if self.bridge._f420_declined(res):
            ev = self.bridge_turn(q)
            if ev is not None:
                return ev, "compose:bridge"
        if parent is not None:
            return parent, "capture:" + parent["turn"]
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


SESSION = "veri7vn-document"


class _NoUserCorpus:
    """a fresh session: no documents taught, so the capability turns' user claims are empty"""

    @staticmethod
    def bundle(session_id, topic):
        return []


def _cid_of(out):
    refs = out.get("references") or []
    return refs[0].get("id") if refs and isinstance(refs[0], dict) else ""


def _sentence_of(out):
    """verified_retrieval_v1._sentence on the w420 reply: tags stripped, first sentence."""
    return VR._sentence(out.get("response", ""))
