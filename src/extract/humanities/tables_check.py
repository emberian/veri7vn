#!/usr/bin/env python3
"""Transcription check for the humanities kernels' tables (lane S16-humanities).

The HOL constants in Music.thy, Grammar.thy, Mythology.thy, UsHistory.thy, Library.thy and
Government.thy, and the rule-pattern lists in rules.sml, are transcribed from the shipped organ
files. This script loads the organs' own tables (read-only, no bytecode written), parses the HOL
and SML text, and fails on any difference, so the tables cannot drift silently. It is a Python
check of text against files; it is not a proof.

  python3 src/extract/humanities/tables_check.py      # one line per table, exit 1 on a mismatch
"""
from __future__ import annotations

import ast
import importlib
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SPEC = REPO / "upstream/root/specialists"
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", module, "organ_music_v1"):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def theory(name):
    return (HERE / (name + ".thy")).read_text(encoding="utf-8")


TOK = re.compile(r"\s*(STR ''[^']*''|apos|[()\[\],+]|-?\d+|[A-Za-z_][A-Za-z_0-9]*)")


def tokens(text):
    pos, out = 0, []
    while pos < len(text):
        m = TOK.match(text, pos)
        if not m:
            if text[pos:].strip() == "":
                break
            raise ValueError("cannot tokenize near %r" % text[pos:pos + 40])
        out.append(m.group(1))
        pos = m.end()
    return out


def parse_expr(toks, i=0):
    """HOL literal expression -> python (str, int, tuple, list)"""
    def atom(i):
        t = toks[i]
        if t == "(":
            items, i = [], i + 1
            while True:
                v, i = expr(i)
                items.append(v)
                if toks[i] == ",":
                    i += 1
                    continue
                assert toks[i] == ")", toks[i - 3:i + 3]
                return (items[0] if len(items) == 1 else tuple(items)), i + 1
        if t == "[":
            items, i = [], i + 1
            if toks[i] == "]":
                return [], i + 1
            while True:
                v, i = expr(i)
                items.append(v)
                if toks[i] == ",":
                    i += 1
                    continue
                assert toks[i] == "]"
                return items, i + 1
        if t.startswith("STR ''"):
            return t[6:-2], i + 1
        if t == "apos":
            return "'", i + 1
        if re.fullmatch(r"-?\d+", t):
            return int(t), i + 1
        return t, i + 1

    def expr(i):
        v, i = atom(i)
        while i < len(toks) and toks[i] == "+":
            w, i = atom(i + 1)
            v = v + w
        return v, i

    v, j = expr(i)
    return v, j


def hol_def(thy, name):
    m = re.search(r'\n  "%s = (.*?)"\n' % re.escape(name), thy, re.S)
    if not m:
        raise SystemExit("no HOL definition %s" % name)
    toks = tokens(m.group(1))
    v, j = parse_expr(toks)
    assert j == len(toks), (name, toks[j:j + 5])
    return v


def dup_keys(path, varname):
    """keys occurring twice in the organ's dict literal (a python dict would silently drop one)"""
    tree = ast.parse(Path(path).read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(getattr(t, "id", None) == varname for t in node.targets) \
                and isinstance(node.value, ast.Dict):
            ks = [k.value for k in node.value.keys if isinstance(k, ast.Constant)]
            return sorted({k for k in ks if ks.count(k) > 1})
    return None


def sml_list(text, name):
    m = re.search(r"val %s = \[(.*?)\n  \]?\s*\n" % name, text, re.S)
    body = re.search(r"val %s = \[(.*?)\]\s*\n\s*(?:val|end)" % name, text, re.S).group(1)
    return body


def sml_strings(text, name):
    body = sml_list(text, name)
    return [ast.literal_eval('"%s"' % s.replace('\\\\', '\\\\\\\\')) if False else bytes(s, "utf-8").decode("unicode_escape")
            for s in re.findall(r'"((?:[^"\\]|\\.)*)"', body)]


# ------------------------------------------------------------------ music
mu = load("music-v2", "organ_music_v1")
M = theory("music/Music")
LET = {"N_C": "C", "N_D": "D", "N_E": "E", "N_F": "F", "N_G": "G", "N_A": "A", "N_B": "B"}


def note_names(lst):
    return [LET[l] + {0: "", 1: "#", -1: "b"}[a] for l, a in lst]


for hol, py in (("sharp_maj", mu.SHARP_MAJ), ("flat_maj", mu.FLAT_MAJ), ("sharp_min", mu.SHARP_MIN), ("flat_min", mu.FLAT_MIN)):
    check("music %s" % hol, note_names(hol_def(M, hol)) == py, str(note_names(hol_def(M, hol))))

check("music nat_pc", all(("\"nat_pc N_%s = %d\"" % (k, v)) in M for k, v in mu.NAT.items()))
rows = hol_def(M, "qual_rows")
QW = {"Q_dim": "diminished", "Q_min": "minor", "Q_maj": "major", "Q_perf": "perfect", "Q_aug": "augmented"}
NUMW = ["unison", "second", "third", "fourth", "fifth", "sixth", "seventh", "octave"]
got = {s: {n: "%s %s" % (QW[q], NUMW[s]) for (s2, n, q) in rows if s2 == s} for s in sorted({r[0] for r in rows})}
check("music qual_rows = QUAL", got == mu.QUAL, "")
order = sorted(mu.IVL, key=len, reverse=True)
check("music ivl_order = sorted IVL", hol_def(M, "ivl_order") == [(n, mu.IVL[n][1]) for n in order])
# the organ's inline note-name list for MIDI numbers
src = (SPEC / "music-v2/organ_music_v1.py").read_text()
nm = re.search(r'names = (\[[^\]]*\])', src).group(1)
check("music chroma = organ's MIDI names", note_names(hol_def(M, "chroma")) == ast.literal_eval(nm))
steps_src = re.search(r"steps = (\[[^\]]*\]) if minor else (\[[^\]]*\])", src)
steps_src = re.search(r"steps = (\[[^\]]*\]) if minor else (\[[^\]]*\])", src)
check("music steps minor", re.search(r'if m then \[%s\]' % re.escape(", ".join(map(str, ast.literal_eval(steps_src.group(1))))), M) is not None)
check("music steps major", re.search(r'else \[%s\]\)"' % re.escape(", ".join(map(str, ast.literal_eval(steps_src.group(2))))), M) is not None)
dur_hol = dict(re.findall(r'"beats_of D_(\w+) = (\d+(?: / \d+)?)"', M))
from fractions import Fraction as Fr
check("music durations", {k.replace("_", "-"): Fr(v.replace(" ", "")) for k, v in dur_hol.items()} == {k: Fr(str(v)) for k, v in mu.DUR.items()})
# the organ's reference note text "NAT" letters and the accidental words
check("music letters", mu.LETTERS == "CDEFGAB")
rec = (HERE / "recognizer.sml").read_text(encoding="utf-8")
def sml_val(text, name):
    m = re.search(r'val %s = "((?:[^"\\]|\\.)*)"' % name, text)
    return bytes(m.group(1), "utf-8").decode("unicode_escape") if m else None
strip_sharps = lambda p: p.replace("|\u266f|\u266d", "").replace("\u266f\u266d", "")
check("music NOTE pattern = organ's (sharp/flat signs normalised first)", sml_val(rec, "NOTE") == strip_sharps(mu.NOTE))
key_src = re.search(r're\.search\(r"(\\b\(\[A-G\]\).*?)", t\)', src).group(1)
check("music KEY pattern = organ's", sml_val(rec, "KEY") == strip_sharps(key_src), key_src)
v2src = (SPEC / "music-v2/organ_music_v2.py").read_text()
check("music REL pattern = organ's (lower case)", sml_val(rec, "REL") == re.search(r'REL = re.compile\(r"(.*?)", re.I\)', v2src).group(1).lower().replace("[a-g]", "[a-g]"))
check("music REF pattern = organ's (lower case)", sml_val(rec, "REF") == re.search(r'REF = re.compile\(r"(.*?)", re.I\)', v2src).group(1).lower())
r2src = (SPEC / "music-v2-r2/organ_music_v2_r2.py").read_text()
check("music-v2-r2 NOT_MINE pattern", sml_val(rec, "NOT_MINE") == re.search(r'NOT_MINE = re.compile\(r"""(.*?)""", re.I\)', r2src).group(1).lower())
check("music-v2-r2 MINE pattern", sml_val(rec, "MINE") == re.search(r'\nMINE = re.compile\(r"""(.*?)""", re.I\)', r2src).group(1).lower())

# ------------------------------------------------------------------ grammar
gr = load("grammar", "organ_grammar_v1")
G = theory("facts/Grammar")
def alts(s): return s.split("/")
hv = hol_def(G, "verbs")
check("grammar verbs", hv == [(k, (alts(v[0]), alts(v[1]))) for k, v in gr.VERBS.items()])
check("grammar plurals", hol_def(G, "plurals") == [(k, alts(v)) for k, v in gr.PLURALS.items()])
check("grammar compares", hol_def(G, "compares") == [(k, (alts(v[0]), alts(v[1]))) for k, v in gr.COMPARE.items()])
for var in ("VERBS", "PLURALS", "COMPARE"):
    check("grammar no duplicate keys in %s" % var, dup_keys(SPEC / "grammar/organ_grammar_v1.py", var) == [], str(dup_keys(SPEC / "grammar/organ_grammar_v1.py", var)))

# ------------------------------------------------------------------ mythology
my = load("mythology", "organ_mythology_v1")
Y = theory("facts/Mythology")
g2r = hol_def(Y, "g2r_rows")
check("mythology g2r_rows", g2r == [(k, k.capitalize(), v, v.lower()) for k, v in my.G2R.items()])
derived = [(r[3], r[2], r[1]) for r in g2r if r[3] != r[0]] + [("apollo", "Apollo", "Apollo")]
check("mythology r2g derivation = organ's R2G", derived == [(k, k.capitalize(), v) for k, v in my.R2G.items()])
check("mythology greek domain", hol_def(Y, "greek_domain") == list(my.DOMAIN["greek"].items()))
check("mythology norse domain", hol_def(Y, "norse_domain") == list(my.DOMAIN["norse"].items()))
check("mythology roles", hol_def(Y, "roles") == [(k, k.capitalize(), v) for k, v in my.ROLE.items()])
for var in ("G2R", "ROLE"):
    check("mythology no duplicate keys in %s" % var, dup_keys(SPEC / "mythology/organ_mythology_v1.py", var) == [])

# ------------------------------------------------------------------ ushistory
us = load("ushistory", "organ_ushistory_v1")
U = theory("facts/UsHistory")
check("ushistory presidents", hol_def(U, "presidents") == us.PRES)
amb = lambda rx: bool(re.search(r"civil war|bill of rights|constitution|declaration of independence", rx))
check("ushistory events", [(y, s, ("True" if amb(rx) else "False")) for rx, y, s in us.EVENTS]
      == [(y, s, b) for (y, s, b) in hol_def(U, "events")])
rules = (HERE / "rules.sml").read_text(encoding="utf-8")
check("ushistory event patterns (rules.sml)", sml_strings(rules, "events") == [rx for rx, y, s in us.EVENTS])

# ------------------------------------------------------------------ library
li = load("library", "organ_library_v1")
L = theory("facts/Library")
check("library lcc classes", hol_def(L, "lcc_classes") == list(li.LCC.items()))
check("library lcc subclasses (two-letter keys, with parent letter)",
      hol_def(L, "lcc_subs") == [(k, v, k[0]) for k, v in li.SUB.items() if len(k) == 2])
check("library SUB's other keys never reach the two-letter branch", [k for k in li.SUB if len(k) != 2] == ["Z"])
check("library unused letters", hol_def(L, "unused_letters") == list("IOWXY"))
check("library alphabet", hol_def(L, "alphabet") == [chr(c) for c in range(65, 91)])
subj = sorted(li.SUBJECT, key=len, reverse=True)
desc = lambda code: li.SUB.get(code) if len(code) == 2 else li.LCC.get(code)
check("library subject order", hol_def(L, "subject_order") == [(s, li.SUBJECT[s], desc(li.SUBJECT[s])) for s in subj])
for var in ("LCC", "SUB", "SUBJECT"):
    d = dup_keys(SPEC / "library/organ_library_v1.py", var)
    check("library no duplicate keys in %s" % var, d == [] or var == "SUB" and d == ["QP"], str(d))

# ------------------------------------------------------------------ government
gv = load("government", "organ_government_v1")
V = theory("facts/Government")
check("government amendments", hol_def(V, "amendments") == [gv.AMEND[i] for i in range(1, 28)])
check("government articles", hol_def(V, "articles") == [gv.ARTICLE[i] for i in range(1, 8)])
check("government topic numbers", hol_def(V, "topic_nums") == [n for rx, n in gv.TOPIC])
check("government fact rows", hol_def(V, "fact_rows") == [(v, s) for rx, v, s in gv.FACTS])
check("government topic patterns (rules.sml)", sml_strings(rules, "topics") == [rx for rx, n in gv.TOPIC])
check("government fact patterns (rules.sml)", sml_strings(rules, "facts") == [rx for rx, v, s in gv.FACTS])
ords = sorted(gv.ORD, key=len, reverse=True)
body = sml_list(rules, "ords")
check("government ordinals (rules.sml)", re.findall(r'\("([^"]*)", (\d+)\)', body) == [(w, str(gv.ORD[w])) for w in ords])
check("government ROMAN covers articles", gv.ROMAN == {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7})

print("\nTABLES_CHECK %s (%d failures)" % ("FAIL" if FAILS else "PASS", len(FAILS)))
sys.exit(1 if FAILS else 0)
