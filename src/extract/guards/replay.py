"""Ground-truth replay of Oracle7's precision guards on the 114 core-panel items.

The panel records (question, status, path); the path names the guard code that
fired and the route it fired on. The organ reply the guard inspected is NOT in
the drop, so this replay synthesizes a minimal reply per item and checks that
the REAL Python guard functions (imported read-only from upstream, no head run)
reproduce the recorded code on (question, route, synthesized reply).

Two strata, because of where specialists enter the chain:
  head    - the route was produced deep in the chain; every guard layer sees it
            (organ:*, factoid:*, arb:*, corpus_*, compose:*, verified:*, ...)
  family  - the route is a specialist_call produced by a family fold above the
            deep guards (w525/w526/w530/w533); only w532, w533-own, w534, w539,
            w540 see it
  deep    - a specialist_call produced below all guard folds (w504's standing
            family); every layer sees it
Usage:  .venv/bin/python -I var/guards/replay.py   (from the worktree root)
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gt_import  # noqa: E402  (loads upstream oracle7.py module level: sys.path + env)

M = {n: gt_import.fold("oracle_release_runtime_" + n)
     for n in ("w510", "w511", "w513", "w514", "w16x", "w517", "w519", "w521", "w531", "w532", "w533", "w534", "w539", "w540")
     if n != "w16x"}
M["w516"] = gt_import.fold("oracle_release_runtime_w516")

ROWS = json.load(open(HERE / "panel114.json"))


class FakeRS:
    """The relstore face the guards use: S1 (entity/is_human), R11 (classes)."""

    ENTITIES = {"Buckingham Palace": "Q5"}
    HUMAN = set()

    def entity(self, name):
        return self.ENTITIES.get(str(name).strip())

    def is_human(self, qid):
        return qid in self.HUMAN

    def classes(self, qid, depth=2):
        return []


class FakeEL:
    """entity_linker_v2 face for G3_date_premise, backed by relation store v1."""

    def __init__(self):
        import sqlite3
        self.db = sqlite3.connect(
            "file:/Users/ember/dev/o7vn/upstream/root/relstore/relations_v1.sqlite3?immutable=1", uri=True)

    def link(self, q, k=3):
        m = M["w532"].PREMISE.match(q)
        if not m:
            return []
        x = re.sub(r"^the\s+", "", m.group(2).strip(), flags=re.I)
        # candidate titles in preference order: as typed (with its "The"), stripped,
        # then case-insensitive; first row that carries a recorded date wins
        # (the real linker ranks candidates; the store has many same-label rows)
        rows = []
        for cand in ("The " + x, m.group(2).strip(), x):
            rows += self.db.execute("select qid, label from entity where label=? limit 6", (cand,)).fetchall()
        rows += self.db.execute("select qid, label from entity where label=? collate nocase limit 6", (x,)).fetchall()
        for qid, label in rows:
            if RV.values(qid, 571) or RV.values(qid, 577) or RV.values(qid, 1191) or RV.values(qid, 575) \
                    or RV.values(qid, 580) or RV.values(qid, 585) or RV.values(qid, 1619):
                return [(m.group(2), [(str(qid), label, "")])]
        return rows and [(m.group(2), [(str(rows[0][0]), rows[0][1], "")])] or []


class FakeRV:
    """relation_spec_v1 face for G3_date_premise: the store's lit dates."""

    PROPS = (571, 577, 1191, 575, 580, 585, 1619)

    def __init__(self):
        import sqlite3
        self.db = sqlite3.connect(
            "file:/Users/ember/dev/o7vn/upstream/root/relstore/relations_v1.sqlite3?immutable=1", uri=True)

    def values(self, qid, p):
        if p not in self.PROPS or not str(qid).isdigit():
            return []
        r = self.db.execute("select lit from fact where s=? and p=? and lit is not null", (int(qid), p)).fetchall()
        return [v[0] for v in r]


RS, EL, RV = FakeRS(), FakeEL(), FakeRV()
for _m in ("w532", "w534"):
    M[_m]._EL, M[_m]._RV = EL, RV      # both folds keep their own linker/spec handles


def layers(stratum):
    """(name, callable(q, out) -> code or None) in application order."""
    out = []

    def L(name, fn):
        out.append((name, fn))

    if stratum in ("head", "deep"):
        L("w510", lambda q, o: M["w510"].guard(q, o))
        L("w511", lambda q, o: M["w511"].guard(q, o))
        L("w513", lambda q, o: M["w513"].guard(q, o))
        L("w514", lambda q, o: M["w514"].guard6(q, o))
        L("w516", lambda q, o: M["w516"].guard(q, o, None, RS))
        L("w517", lambda q, o: M["w517"].guard9(q, o, None, RS, changed=False))
        L("w519", lambda q, o: M["w519"].guard10(q, o, RS))
        L("w521", lambda q, o: M["w521"].guard11(q, o) or
          M["w521"].OracleReleaseRuntimeW521._c521_check(q, o))

        def tex(q, o):
            if M["w531"].TEX.search(q) and not ("Options:" in q and "(A)" in q) \
                    and str(o.get("status")) == "answered" \
                    and not str(o.get("path", "")).startswith(M["w531"].MATHS_AGENTS):
                return "R_tex_not_maths_agent"
            return None
        L("w531", tex)
    L("w532", w532_layer)
    L("w533own", w533_layer)
    def w534(q, o):
        r = M["w534"].final_guards(q, o)
        p = str(r.get("path", ""))
        return p.split("|")[0].replace("precision_guard:", "") if p.startswith("precision_guard:") else None
    L("w534", w534)
    L("w539", lambda q, o: ("N1_name_not_arithmetic" if M["w539"].name_is_not_arithmetic(q, o) else None)
        or ("C1_composed_misses_request" if M["w539"].composed_misses_request(q, o) else None))

    def w540(q, o):
        if M["w540"].wrong_direction(q, o):
            return "D1_question_direction"
        if M["w540"].read_back(q, o):
            return "N2_number_read_back"
        if M["w540"].own_thing_on_converse(q, o):
            return "G3_private_on_converse"
        return None
    L("w540", w540)
    return out


def w532_layer(q, o):
    w = M["w532"]
    path = str(o.get("path", ""))
    reply = str(o.get("response", ""))
    if str(o.get("status")) == "answered":
        if path.startswith("specialist_call>") and w.sign_dropped(q, reply):
            return "G1_sign_kept"
        if path.startswith("factoid:") and w.private_state(q):
            return "G2_private_state"
        try:
            pm = w.premise_years(q)
        except Exception:
            pm = None
        if pm:
            return "G3_date_premise"
    return None


def w533_layer(q, o):
    w = M["w533"]
    path = str(o.get("path", ""))
    reply = str(o.get("response", ""))
    if str(o.get("status")) != "answered":
        return None
    if path.startswith(w.MATH_PATHS):
        if w.echoed(q, reply):
            return "G5_echo"
        if path.startswith("organ:math") and w.unit_symbolic(q, reply):
            return "G6_units_not_variables"
    if path.startswith("specialist_call>") and w.wrong_sense(q, path):
        return "G7_word_sense"
    return None


# ---------------------------------------------------------------- synthesis
def synth(row):
    """(route, reply, stratum) for one panel row: the minimal organ reply on
    which the recorded guard fires."""
    q, under, code = row["q"], row["under"], row["guard"]
    fam = under.startswith("specialist_call")
    if code == "P7_negative_given":
        return under, "It is 30.", "head"
    if code == "P7_private":
        return under, "A person's details are private.", "head"
    if code == "P1_declines_in_words":
        return under, 'I have no admitted entry for "%s".' % q.strip().rstrip("?").lower(), "head"
    if code == "P2_no_number":
        return under, "It is an emotion, not a number.", "head"
    if code == "P4_lookup_for_compute":
        if "pounds in kilograms" in q.lower():
            return under, "A pound is 0.45359237 kilograms.", "head"
        return under, "A cube with this side has a volume of 64 cm3.", "head"
    if code == "Q1_english_as_algebra":
        words = "".join(w for w in re.findall(r"[a-z]+", q.lower())[:4])
        return under, "[ev:derived] 42. read %s; then evaluate." % words, "head"
    if code == "R1_english_as_algebra":
        words = "".join(w for w in re.findall(r"[a-z]+", q.lower())[:3])
        return under, "[ev:derived] 25. read %s; then evaluate." % words, "head"
    if code == "Q3_subject_missing":
        return under, "It is about 2 in the usual units.", "head"
    if code == "R5_subject_missing":
        return under, "Einstein won it in 1921.", "head"
    if code == "R6_math_on_english":
        return under, "[ev:derived] -125. The volume is -125 cm3.", "head"
    if code == "R2_dump_for_slot_question":
        return under, "In simple terms: %s is a famous work. " % q.split()[-1] + \
               "It is studied in schools. [ev:explain_simply]", "head"
    if code == "S1_person_not_human":
        return under, "Buckingham Palace. It is a royal residence. Reached through a page.", "head"
    if code == "G3_evidence_misses_question":
        return under, "It was painted in 1512. Reached through a bridge.", "head"
    if code == "G3s_qualifier_dropped":
        return under, "It was written by Homer.", "deep"
    if code == "G1_sign_kept":
        if "spring" in q.lower():
            return under, "The force is 20 N.", "family"
        return under, "The mass is 5 kg.", "family"
    if code == "G2_private_state":
        return under, "A bank keeps records of that.", "head"
    if code == "G3_date_premise":
        who = {"painted": "painted", "wrote": "wrote", "composed": "composed"}[q.split()[1].lower()]
        return under, "Someone %s it long ago." % who, "family" if fam else "head"
    if code == "G5_echo":
        m = re.search(r"(\d+)\s*/\s*(\d+)", q)
        if m:                                   # the fraction items: organ echoed the fraction
            return under, "[ev:derived] %s/%s. read %s/%s; then evaluate." % (m.group(1), m.group(2), m.group(1), m.group(2)), "head"
        m = re.search(r"at x = (\d+)", q)       # the derivative items: organ echoed the point
        return under, "[ev:derived] x = %s. read 4*x^3; then evaluate." % m.group(1), "head"
    if code == "G6_units_not_variables":
        if "perimeter" in q.lower():
            a, b = re.findall(r"\d+", q)[:2]
            return under, "[ev:derived] %s*m. read %s*m; then evaluate. The perimeter is twenty-two." % (a, a), "head"
        return under, "[ev:derived] 3*g*k/m. read density; then evaluate.", "head"
    if code == "G7_word_sense":
        return under, "Mercury has no known moons of that kind.", "deep"
    raise SystemExit("no synthesis for " + code)


def run(row, stratum):
    route, reply, _ = synth(row)
    o = {"status": "answered", "path": route, "response": reply}
    for name, fn in layers(stratum):
        try:
            code = fn(row["q"], o)
        except Exception as e:  # noqa: BLE001
            code = "ERR:%s:%s" % (name, e)
        if code:
            return name, code
    return None, None


def main():
    ok, bad = 0, []
    out_rows = []
    for row in ROWS:
        strat = synth(row)[2] if not row["under"].startswith("specialist_call") else None
        tried = []
        if strat is None:                        # specialist routes: try both strata
            for s in ("family", "deep"):
                name, code = run(row, s)
                tried.append((s, name, code))
                if code == row["guard"]:
                    strat = s
                    break
        else:
            name, code = run(row, strat)
            tried.append((strat, name, code))
        good = strat is not None and any(t[2] == row["guard"] for t in tried)
        hit = next((t for t in tried if t[2] == row["guard"]), (None, None, None))
        if good:
            ok += 1
        else:
            bad.append((row, tried))
        out_rows.append(dict(row, stratum=strat, layer=hit[1],
                             reply=synth(row)[1], route=synth(row)[0]))
    json.dump(out_rows, open(HERE / "fixtures114.json", "w"), indent=1)
    print("reproduced %d / %d" % (ok, len(ROWS)))
    for row, tried in bad:
        print("MISS %-26s want=%-26s got=%s | %s" % (row["guard"], row["guard"], tried, row["q"][:60]))
    if "--emit-inputs" in sys.argv:
        emit_inputs(json.load(open(HERE / "fixtures114.json")))
    return 0 if not bad else 1


TAGS = re.compile(r"\[ev:[a-z_]+\]|\[[a-z]+_[0-9a-f]{6,}\]|\[\d+\]")


def s1_human(reply):
    """w516 S1's relstore answer: resolve the reply's first sentence, ask the store."""
    vis = " ".join(TAGS.sub(" ", str(reply)).split())
    value = vis.split(". ", 1)[0].strip()
    qid = RS.entity(value)
    return [None, True, False][1 if qid and RS.is_human(qid) else (2 if qid else 0)]


def premise_raw(q):
    """w532/w534 G3's premise WITHOUT the tolerance check (the kernel checks it):
    (label, asked year, recorded years) when the question is a dated-creation
    premise and the store has dates for the linked item."""
    w = M["w532"]
    m = w.PREMISE.match(q)
    if not m:
        return None
    x, year = m.group(2).strip(), int(m.group(3))
    try:
        spans = EL.link(q, k=3)
    except Exception:
        return None
    cands = [c for s, cs in spans if s.lower().lstrip("the ").strip() == x.lower().lstrip("the ").strip()
             for c in cs[:1]]
    if not cands:
        return None
    qid, _, label = cands[0]
    years = set()
    for p in RV.PROPS:
        for v in RV.values(qid, p):
            y = re.match(r"^[+]?(-?\d{1,4})-", str(v))
            if y:
                years.add(int(y.group(1)))
    if not years:
        return None
    return {"label": label, "year": year, "years": sorted(years)}


def emit_inputs(fixtures):
    """inputs114.json: the binary's stdin, one JSON object per line. human and
    premise are the relstore facts (recognizer-side inputs, untrusted); the
    rest is raw text the binary's recognizer reads itself."""
    lines = []
    for fx in fixtures:
        lines.append(json.dumps({
            "id": fx["idx"], "q": fx["q"], "route": fx["route"], "reply": fx["reply"],
            "status": "answered", "human": s1_human(fx["reply"]),
            "premise": premise_raw(fx["q"])}))
    dst = HERE / "inputs114.jsonl"
    dst.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote %s (%d lines)" % (dst, len(lines)))


if __name__ == "__main__":
    sys.exit(main())
