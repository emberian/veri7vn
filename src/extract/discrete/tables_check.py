#!/usr/bin/env python3
"""Check the tables transcribed into the HOL theories against the organs.

This is a Python check of the HOL text, not a proof. It compares
  * games-v3: the poker hand counts (HANDS), the card kinds and their sizes (CARDS),
  * logic-v3: the named argument forms (names and validity flags),
  * algorithms: the complexity table (COMPLEXITY, ASCII for the superscript two),
  * dataformats: the SHA-256 / SHA-1 / MD5 constants (recomputed from their
    definitions: cube and square roots of primes, sines), the base64 alphabet,
    the percent-encoding safe set, the weekday names,
against upstream/root/specialists/*/organ_*.py. Nothing under upstream/ is
written."""
import importlib, math, re, sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
SPEC = HERE.parents[2] / "upstream/root/specialists"
fails = []
checks = 0


def check(name, ok, detail=""):
    global checks
    checks += 1
    if not ok:
        fails.append((name, detail))
        print("FAIL", name, detail)


def load(folder, module):
    for m in ("narrow_v1",):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def thy(name):
    return (HERE / name).read_text()


# ---- games
g1 = load("games-v3", "organ_games_v1")
gt = thy("Disc_Games.thy")
hand_map = [("royal flush", "H_royal"), ("straight flush", "H_straight_flush"), ("four of a kind", "H_four"),
            ("full house", "H_full_house"), ("flush", "H_flush"), ("straight", "H_straight"),
            ("three of a kind", "H_three"), ("two pair", "H_two_pair"), ("one pair", "H_pair")]
for pyname, hol in hand_map:
    m = re.search(r'"hand_count %s = (.+?)"' % hol, gt)
    check("hand_count " + hol, m is not None)
    if m:
        expr = re.sub(r"cm (\d+) (\d+)", r"math.comb(\1,\2)", m.group(1)).replace("^", "**")
        check("hand_count value " + hol, eval(expr) == g1.HANDS[pyname], "%s vs %s" % (expr, g1.HANDS[pyname]))
    nm = re.search(r'"hand_name %s = STR \'\'(.+?)\'\'"' % hol, gt)
    check("hand_name " + hol, nm is not None and nm.group(1) == pyname)
check("hand order", [h for _, h in hand_map] == re.findall(r"H_\w+", re.search(r'"hand_list = \[(.+?)\]"', gt, re.S).group(1)))
check("poker total", "hand_total = cm 52 5" in gt)
card_map = [("ace", "C_ace"), ("king", "C_king"), ("queen", "C_queen"), ("jack", "C_jack"), ("face card", "C_face"),
            ("heart", "C_heart"), ("spade", "C_spade"), ("diamond", "C_diamond"), ("club", "C_club"),
            ("red card", "C_red"), ("black card", "C_black")]
check("card count", len(g1.CARDS) == len(card_map))
for (rx, good, lab), (pylab, hol) in zip(g1.CARDS, card_map):
    check("card label " + hol, lab == pylab)
    m = re.search(r'"card_good %s = (\d+)"' % hol, gt)
    check("card_good " + hol, m is not None and int(m.group(1)) == good)
    m = re.search(r'"card_label %s = STR \'\'(.+?)\'\'"' % hol, gt)
    check("card_label " + hol, m is not None and m.group(1) == lab)

# ---- logic
l1 = load("logic-v3", "organ_logic_v1")
lt = thy("Disc_Logic.thy")
form_hol = ["F_mp", "F_mt", "F_ac", "F_da", "F_hs", "F_ds"]
valid_text = re.search(r"theorem form_table:\s*\"(.+?)\"", lt, re.S).group(1)
for (name, valid, rx), hol in zip(l1.FORMS, form_hol):
    m = re.search(r'"form_name %s = STR \'\'(.+?)\'\'"' % hol, lt)
    check("form_name " + hol, m is not None and m.group(1) == name)
    neg = re.search(r"\\<not> form_valid %s\b" % hol, valid_text) is not None
    pos = re.search(r"(?<!\\<not> )form_valid %s\b" % hol, valid_text) is not None
    check("form validity " + hol, (pos and not neg) == valid and (neg or pos))

# ---- algorithms
a1 = load("algorithms", "organ_algorithms_v1")
at = thy("Disc_Algos.thy")
rows = re.findall(r"\(STR \'\'([^']+?)\'\', STR \'\'([^']+?)\'\',\s*STR \'\'([^']+?)\'\'\)", at.split("complexity_table")[2])
check("complexity rows", len(rows) == len(a1.COMPLEXITY), "%d vs %d" % (len(rows), len(a1.COMPLEXITY)))
for (n, w, a), (pn, (pw, pa)) in zip(rows, a1.COMPLEXITY.items()):
    check("complexity " + pn, (n, w, a) == (pn, pw.replace("²", "^2"), pa.replace("²", "^2")), repr((n, w, a, pw, pa)))

# ---- dataformats
ft = thy("Disc_Formats.thy")


def primes(n):
    ps, c = [], 2
    while len(ps) < n:
        if all(c % p for p in ps):
            ps.append(c)
        c += 1
    return ps


def iroot(n, k):
    lo, hi = 0, 1 << 200
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if mid ** k <= n:
            lo = mid
        else:
            hi = mid - 1
    return lo


def nums(name):
    m = re.search(r'definition %s :: "nat list" where\s*"%s = \[(.+?)\]"' % (name, name), ft, re.S)
    return [int(x) for x in m.group(1).replace("\n", " ").split(",")]


ps = primes(64)
check("sha256 K", nums("k256") == [iroot(p << 96, 3) & 0xffffffff for p in ps])
check("sha256 H", nums("h256") == [iroot(p << 64, 2) & 0xffffffff for p in ps[:8]])
check("md5 T", nums("t_md5") == [int(abs(math.sin(i + 1)) * 2 ** 32) & 0xffffffff for i in range(64)])
check("sha1 H", nums("h1") == [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0])
check("md5 H", nums("h5") == [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476])
alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


def b64c(i):
    return 65 + i if i < 26 else 71 + i if i < 52 else i - 4 if i < 62 else 43 if i == 62 else 47


check("base64 alphabet", "".join(chr(b64c(i)) for i in range(64)) == alpha)
check("b64c text", "b64c i = (if i < 26 then 65 + i else if i < 52 then 71 + i else if i < 62 then i - 4" in ft)
check("sha1 k", all(str(k) in ft for k in (1518500249, 1859775393, 2400959708, 3395469782)))
check("weekday names", re.findall(r"STR ''(\w+day)''", ft.split("definition day_name")[1].split("theorem")[0])
      == ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
check("url safe", "(65 \\<le> c \\<and> c \\<le> 90) \\<or> (97 \\<le> c \\<and> c \\<le> 122) \\<or> (48 \\<le> c \\<and> c \\<le> 57)" in ft
      and "c = 95 \\<or> c = 46 \\<or> c = 45 \\<or> c = 126" in ft)
import urllib.parse
check("url safe set", all(urllib.parse.quote(chr(c), safe="") == chr(c) for c in list(range(65, 91)) + list(range(97, 123)) + list(range(48, 58)) + [95, 46, 45, 126]))

if fails:
    print("TABLES_CHECK FAIL", len(fails), "of", checks)
    sys.exit(1)
print("TABLES_CHECK PASS", checks, "checks")
