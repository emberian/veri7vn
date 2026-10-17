#!/usr/bin/env python3
"""Lane O19 transcription helper (not a trusted part): writes src/extract/facts/Facts_Tables.thy from the
shipped stores. tables_check.py independently re-reads the theory text and compares it with the stores."""
import importlib, json, re, sys
from pathlib import Path
sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[4]
SPEC = REPO / "upstream/root/specialists"
IDS = "literature-v2 worldhistory arthistory medicine-r2 medicine law psychology sociology linguistics poetry botany entomology marinebio ornithology mycology mycelial pets childdev etiquette firesafety-v2 firstaid javascript".split()

def load(folder, module):
    for k in list(sys.modules):
        if k.startswith("facts_") or k in ("narrow_v1", "organ_facts_v1", "organ_medicine_r2"):
            del sys.modules[k]
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)

def text_esc(s):   # value / sentence: HOL text convention, \\ for a backslash, \uXXXX for a non-ASCII code point
    out = []
    for c in s:
        if c == "\\": out.append("\\\\")
        elif ord(c) > 126 or ord(c) < 32: out.append("\\u%04x" % ord(c))
        else: out.append(c)
    return "".join(out)

def sml(s):        # SML string literal of an ASCII string
    assert all(32 <= ord(c) < 127 for c in s), s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

stores, organs = {}, []
for sid in IDS:
    m = json.loads((SPEC / sid / "manifest.json").read_text())
    store = m["organ"]["init"]["store"]
    st = load(sid, store)
    rec = {"kind": getattr(st, "KIND", "fact"), "gate": st.GATE, "block": getattr(st, "BLOCK", None) or None,
           "ask": getattr(st, "ASK", None), "facts": [(p, text_esc(v), text_esc(s)) for p, v, s in st.FACTS]}
    if store in stores:
        assert stores[store] == rec, store
    stores[store] = rec
    boundary = None
    if m["organ"]["class"] == "FactsOrganBoundary":
        om = load(sid, m["organ"]["module"])
        boundary = (om.NOT_MINE.pattern, om.MINE.pattern)
    organs.append((sid, store, boundary))
fo = load("literature-v2", "organ_facts_v1")
DEFAULT_ASK = fo.DEFAULT_ASK

L = []
w = L.append
w("""theory Facts_Tables
  imports "Veri7vn_Facts_Base.Facts_Kernel"
begin

text \\<open>The 21 shipped FactsOrgan stores (22 specialists: medicine and medicine-r2
share one store) as HOL constants. Generated from the store files by the lane's
transcription helper and checked against them by \\<open>tables_check.py\\<close>.

The tables are written as Standard ML string literals because Isabelle's
\\<open>STR ''...''\\<close> syntax admits no backslash, and every guard is a Python regular
expression full of backslashes. The ML below only builds the literal terms; each
constant is introduced by an ordinary definition (\\<open>Specification.definition\\<close>,
as the definition command does), so nothing here is an axiom.

Values and sentences use one escape, so they stay 7-bit: a non-ASCII character
is written \\<open>\\\\uXXXX\\<close> and a backslash \\<open>\\\\\\\\\\<close>; the driver decodes it to UTF-8.\\<close>

ML \\<open>
structure Facts_Tables_Data =
struct
  val default_ask = %s
  type store = {name : string, kind : string, gate : string, block : string option,
                ask : string option, rules : (string * string * string) list}
""" % sml(DEFAULT_ASK))
for name, r in stores.items():
    w("  val %s : store = {name = %s, kind = %s," % (name, sml(name), sml(r["kind"])))
    w("    gate = %s," % sml(r["gate"]))
    w("    block = %s," % ("SOME " + sml(r["block"]) if r["block"] else "NONE"))
    w("    ask = %s," % ("SOME " + sml(r["ask"]) if r["ask"] else "NONE"))
    w("    rules = [")
    for i, (p, v, s) in enumerate(r["facts"]):
        w("      (%s,\n       %s,\n       %s)%s" % (sml(p), sml(v), sml(s), "," if i + 1 < len(r["facts"]) else "]}"))
w("  val organs : (string * string * (string * string) option) list = [")
for i, (sid, store, b) in enumerate(organs):
    bb = "NONE" if b is None else "SOME (%s,\n       %s)" % (sml(b[0]), sml(b[1]))
    w("    (%s, %s, %s)%s" % (sml(sid), sml(store), bb, "," if i + 1 < len(organs) else "]"))
w("end\n\\<close>\n")
w("""ML \\<open>
structure Facts_Tables_Define =
struct
  val lit = HOLogic.mk_literal
  val litT = HOLogic.literalT
  fun some t = Const (\\<^const_name>\\<open>Some\\<close>, fastype_of t --> Type (\\<^type_name>\\<open>option\\<close>, [fastype_of t])) $ t
  fun none T = Const (\\<^const_name>\\<open>None\\<close>, Type (\\<^type_name>\\<open>option\\<close>, [T]))
  fun define name rhs lthy =
    let
      val eq = HOLogic.mk_Trueprop (HOLogic.mk_eq (Free (name, fastype_of rhs), rhs))
      val ((c, _), lthy) =
        Specification.definition {verbose = false} (SOME (Binding.name name, NONE, NoSyn)) [] []
          (Binding.empty_atts, eq) lthy
    in (c, lthy) end
  fun rule (g, v, s) = \\<^const>\\<open>Rule\\<close> $ lit g $ lit v $ lit s
  fun store_const lthy name = Proof_Context.read_const {proper = true, strict = true} lthy name
  fun define_store (s : Facts_Tables_Data.store) lthy =
    let
      val (rules, lthy) = define (#name s ^ "_rules") (HOLogic.mk_list \\<^typ>\\<open>rule\\<close> (map rule (#rules s))) lthy
      val block = case #block s of SOME b => some (lit b) | NONE => none litT
      val ask = case #ask s of SOME a => lit a | NONE => store_const lthy "default_ask"
      val rhs = \\<^const>\\<open>Store\\<close> $ lit (#name s) $ lit (#kind s) $ lit (#gate s) $ block $ ask $ rules
    in snd (define (#name s ^ "_store") rhs lthy) end
  fun ident id = String.translate (fn #"-" => "_" | c => String.str c) id
  fun define_organ (id, store, boundary) lthy =
    let
      val st = store_const lthy (store ^ "_store")
      val b = case boundary of
                SOME (x, y) => some (HOLogic.mk_prod (lit x, lit y))
              | NONE => none (HOLogic.mk_prodT (litT, litT))
      val rhs = \\<^const>\\<open>Organ\\<close> $ lit id $ b $ st
    in snd (define ("organ_" ^ ident id) rhs lthy) end
end
\\<close>

definition default_ask :: String.literal where
  "default_ask = STR ''(see ML)''"
""")
# default_ask needs backslashes too; define it through ML instead (replace the placeholder above)
L[-1] = L[-1].replace("""definition default_ask :: String.literal where
  "default_ask = STR ''(see ML)''"
""", """local_setup \\<open>fn lthy => snd (Facts_Tables_Define.define "default_ask"
  (Facts_Tables_Define.lit Facts_Tables_Data.default_ask) lthy)\\<close>
""")
for name in stores:
    w("local_setup \\<open>Facts_Tables_Define.define_store Facts_Tables_Data.%s\\<close>" % name)
w("")
w("local_setup \\<open>fold Facts_Tables_Define.define_organ Facts_Tables_Data.organs\\<close>")
w("")
ident = lambda s: s.replace("-", "_")
w("text \\<open>The family in the order the binary asks it when no specialist is named.\\<close>")
w("definition organs :: \"organ list\" where")
w("  \"organs = [%s]\"" % ",\n    ".join("organ_" + ident(s) for s, _, _ in organs))
w("")
w("text \\<open>Every transcribed table is well formed: non-empty, every guard and sentence")
w("non-empty, and no guard repeated (a repeated guard would make its later row dead).\\<close>")
for name in stores:
    w("lemma %s_well_formed: \"table_well_formed %s_rules\"" % (name, name))
    w("  by (simp add: table_well_formed_def %s_rules_def)" % name)
    w("")
w("""text \\<open>Table order is part of the specification. On the dev question
\\<open>What is the name of Captain Ahab's ship?\\<close> the recognizer reports exactly two
literature-v2 rows matching (row 4, the Pequod row, and row 24, Captain Ahab -> Moby-Dick).
The shipped order answers Pequod; with those two rows exchanged the same features
answer Moby-Dick.\\<close>
theorem literature_order_matters:
  "let rs = facts_literature_v2_rules; m = (\\<lambda>p. p = guard (rs ! 4) \\<or> p = guard (rs ! 24)) in
     map_option (fact_value \\<circ> snd) (interpret_table m rs) = Some STR ''Pequod'' \\<and>
     map_option (fact_value \\<circ> snd) (interpret_table m (rs[4 := rs ! 24, 24 := rs ! 4])) = Some STR ''Moby-Dick''"
  by (simp add: facts_literature_v2_rules_def Let_def eval_nat_numeral)
""")
w("lemmas tables_well_formed = %s" % " ".join("%s_well_formed" % n for n in stores))
w("\nend\n")
out = "\n".join(L)
assert "\\<" not in out.split("ML \\<open>\nstructure Facts_Tables_Data")[1].split("\\<close>")[0].replace("\\<open>", ""), "symbol escape in table text"
(REPO / "src/extract/facts/Facts_Tables.thy").write_text(out)
lit = stores["facts_literature_v2"]["facts"]
for i, (p, v, s) in enumerate(lit):
    if v in ("Pequod", "Moby-Dick"): print(i, v, p[:70])
print("stores", len(stores), "organs", len(organs), "rules", sum(len(r["facts"]) for r in stores.values()))
