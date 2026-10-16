#!/usr/bin/env python3
"""Differential vectors for the HOL translation of w540's three narrowing guards.

Lifts exactly the module-level constants and the three guard functions out of the shipped w540 source with `ast`
(the fold module itself is never imported, so its 360-class parent chain is never loaded), runs them on the cases
below, and writes src/isabelle/routing/W540_Vectors.thy: one lemma per case stating the HOL guard's verdict equals
the Python verdict. `--check` fails if the theory on disk differs.
"""
from __future__ import annotations

import ast
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w540.py")
OUT = os.path.join(REPO, "src/isabelle/routing/W540_Vectors.thy")
LIFT = {"AGENT_PROPS", "AUX", "SUBJECT_FORM", "READ_BACK", "MATH_PATH", "OWN", "wrong_direction", "read_back",
        "own_thing_on_converse"}

GR = "general_reader:wikidata:P%d:%s>relstore"
CASES = [
    # (question, status, path, response)
    ("Which planet orbits the Moon?", "answered", GR % (397, "fwd"), "Earth"),
    ("Which planet orbits the Moon?", "answered", GR % (397, "inv"), "Earth"),
    ("Which person founded Microsoft?", "answered", GR % (112, "fwd"), "Bill Gates"),
    ("Which river flows through Paris?", "answered", GR % (206, "fwd"), "Seine"),
    ("Which country borders France?", "answered", GR % (47, "fwd"), "Spain"),
    ("Which big city lies near Lyon?", "answered", GR % (131, "fwd"), "x"),
    ("What city hosted the 2012 Olympics?", "answered", GR % (276, "fwd"), "London"),
    ("What is the capital of France?", "answered", GR % (36, "fwd"), "Paris"),
    ("Which is the largest planet?", "answered", GR % (397, "fwd"), "Jupiter"),
    ("which moon was discovered first?", "answered", GR % (61, "fwd"), "x"),
    ("  WHICH Planet ORBITS the Sun", "answered", GR % (397, "fwd"), "x"),
    ("Which planet orbits9 the Moon?", "answered", GR % (397, "fwd"), "x"),
    ("Which planet orbits_ the Moon?", "answered", GR % (397, "fwd"), "x"),
    ("Which planet orbits, the Moon?", "answered", GR % (397, "fwd"), "x"),
    ("Which is-thing orbits the Moon?", "answered", GR % (397, "fwd"), "x"),
    ("Which planet orbits the Moon?", "answered", "Xgeneral_reader:wikidata:P397:fwd>r", "x"),
    ("Which planet orbits the Moon?", "answered", "general_reader:WIKI:P397:fwd>r", "x"),
    ("A 5 kg cube has a density of 0 kg/m3. What is its volume?", "answered", "organ:math>evaluate",
     "I read 0; then evaluate the expression: 0"),
    ("A 5 kg cube has a density of 0 kg/m3. What is its volume?", "answered", "organ:math>evaluate",
     "I read 5; then evaluate the expression: 5"),
    ("A 5 kg cube has a density of 0 kg/m3. What is its volume?", "withheld", "organ:math>evaluate",
     "I read 0; then evaluate the expression: 0"),
    ("A 5 kg cube has a density of 0 kg/m3. What is its volume?", "answered", "chat:resolved>op:mean",
     "Read 0.0; THEN EVALUATE it"),
    ("A 5 kg cube has a density of 0 kg/m3. What is its volume?", "answered", "factoid:x",
     "I read 0; then evaluate the expression: 0"),
    ("What is 0?", "answered", "organ:math>evaluate", "I read 0; then evaluate: 0"),
    ("Evaluate 0 times the mass", "answered", "algebra:linear", "I read 0; then evaluated it"),
    ("Evaluate -0 times the mass please", "answered", "a|algebra:linear", "we read -0; then evaluate"),
    ("Evaluate 00 times the mass please", "answered", "organ:math", "xread 00; then evaluate"),
    ("Evaluate 0.5 times the mass please", "answered", "organ:math", "read 0.5; then evaluate"),
    ("Evaluate 00 times the mass please", "answered", "organ:math", "read 00; then evaluate"),
    ("Evaluate 0 times the big mass", "answered", "x>op:mul", "I read 0; then evaluate."),
    ("Evaluate 0 times the big mass", "answered", "x>op:mul", "I read 0; then evaluate_"),
    ("Evaluate 0 times the big mass", "answered", "x>op:mul", "I read 0 ; then evaluate"),
    ("Who is my favourite singer?", "answered", "organ:converse>request", "Here's what my sources say about singer: a singer is"),
    ("Who is my favourite singer?", "answered", "organ:converse>request", "  Here's what my sources say about singer"),
    ("What is my name?", "answered", "organ:converse>request", "You told me your name is Ben."),
    ("Tell me about our usual route", "answered", "organ:converse>request", "Here's what my sources say about route"),
    ("Tell me about our\nroute, who knows", "answered", "organ:converse>request", "Here's what my sources say about route"),
    ("Who\nknows my route", "answered", "organ:converse>request", "Here's what my sources say about route"),
    ("Where is mycity?", "answered", "organ:converse>request", "Here's what my sources say about mycity"),
    ("Who is my favourite singer?", "answered", "organ:converse>reply", "Here's what my sources say about singer"),
    ("Who is my favourite singer?", "withheld", "organ:converse>request", "Here's what my sources say about singer"),
]


def lift():
    tree = ast.parse(open(SRC, encoding="utf-8").read())
    keep = [n for n in tree.body if (isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) and n.targets[0].id in LIFT)
            or (isinstance(n, ast.FunctionDef) and n.name in LIFT)]
    ns = {"re": re, "__builtins__": __builtins__}
    exec(compile(ast.Module(body=keep, type_ignores=[]), SRC, "exec"), ns)  # noqa: S102 - pure regex helpers only
    return ns


def hol_str(s):
    """A HOL string term; newlines and apostrophes are spliced in as characters."""
    if any(ord(c) > 126 or c == "\\" or (ord(c) < 32 and c != "\n") for c in s):
        raise ValueError(s)
    parts, cur = [], ""
    for c in s:
        if c in "\n'":
            if cur:
                parts.append("''%s''" % cur)
            parts.append("[CHR 0x%02X]" % ord(c))
            cur = ""
        else:
            cur += c
    if cur or not parts:
        parts.append("''%s''" % cur)
    return parts[0] if len(parts) == 1 else "(" + " @ ".join(parts) + ")"


def render():
    ns = lift()
    lines = ["(* GENERATED by audit/folds/w540_vectors.py from the shipped w540 source; do not edit. *)",
             "theory W540_Vectors imports W540_Instance begin", "",
             "text \\<open>Each lemma fixes one (question, reply) case and states the HOL guard verdicts that the",
             "shipped Python guards (wrong_direction, read_back, own_thing_on_converse) return on it.\\<close>", ""]
    for i, (q, st, path, resp) in enumerate(CASES):
        out = {"status": st, "path": path, "response": resp}
        d1 = bool(ns["wrong_direction"](q, out))
        n2 = bool(ns["read_back"](q, out))
        g3 = bool(ns["own_thing_on_converse"](q, out))
        hst = {"answered": "Answered", "withheld": "Withheld"}[st]
        r = "\\<lparr>status = %s, path = %s, response = %s\\<rparr>" % (hst, hol_str(path), hol_str(resp))
        lines.append("lemma w540_vector_%02d: \"d1_guard %s %s = %s \\<and> n2_guard %s %s = %s \\<and> g3_guard %s %s = %s\""
                     % (i, hol_str(q), "(%s)" % r, d1, hol_str(q), "(%s)" % r, n2, hol_str(q), "(%s)" % r, g3))
        lines.append("  by code_simp")
        lines.append("")
    lines.append("ML \\<open>")
    lines.append("  val vectors = map (fn i => Proof_Context.get_thm @{context} (\"w540_vector_\" ^ StringCvt.padLeft #\"0\" 2 (string_of_int i))) (0 upto %d);" % (len(CASES) - 1))
    lines.append("  val _ = if exists (fn th => not (null (Thm_Deps.all_oracles [th]))) vectors then error \"w540 vectors depend on an oracle\" else ();")
    lines.append("  val _ = writeln (\"VERI7VN_ROUTING_VECTORS \" ^ string_of_int (length vectors) ^ \" PASS\");")
    lines.append("\\<close>")
    lines.append("")
    lines.append("end")
    return "\n".join(lines) + "\n"


def main(argv):
    text = render()
    if "--check" in argv:
        if not os.path.exists(OUT) or open(OUT, encoding="utf-8").read() != text:
            print("W540_Vectors.thy is stale: rerun python3 audit/folds/w540_vectors.py", file=sys.stderr)
            return 1
        print("W540_Vectors.thy up to date")
        return 0
    open(OUT, "w", encoding="utf-8").write(text)
    print("wrote %s" % os.path.relpath(OUT, REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
