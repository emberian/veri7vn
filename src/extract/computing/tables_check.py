#!/usr/bin/env python3
"""Untrusted transcription check for the computing family's tables.

Compares the HOL text (Networking.thy, System.thy, Numerics.thy, Pyref_Table.thy) and the
recognizer's tables with the shipped organ files, read-only (no bytecode written):
  networking : RFC 1918 blocks, loopback / link-local / CGNAT numbers, mask and size formulas for /0../32
  cyber      : character set sizes and labels, digest bit sizes, duration unit seconds
  linux-v2   : the 21-entry signal table, cron field ranges
  git        : original intent order/commands/notes, unchanged patterns and explicit stash extensions
  python     : Pyref_Table.thy regenerates exactly from pyref_v1.json; python and python-r2 ship the same file
  robotics   : (no tables)
Exit 1 on any mismatch.   python3 src/extract/computing/tables_check.py
"""
from __future__ import annotations
import importlib, ipaddress, json, re, subprocess, sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SPEC = REPO / "upstream/root/specialists"
FAILS = []


def thy(name):
    return (HERE / name).read_text(encoding="utf-8")


def load(folder, module):
    for m in ("narrow_v1", "organ_linux_v1", module):
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


def hol_str(s):
    """a HOL string expression made of STR ''..'' pieces and apos / dquote / bsl splices"""
    out = ""
    for part in re.split(r"\s*\+\s*", s.strip()):
        part = part.strip()
        if part == "apos": out += "'"
        elif part == "dquote": out += '"'
        elif part == "bsl": out += "\\"
        else:
            m = re.fullmatch(r"STR ''(.*)''", part)
            if m is None: return None
            out += m.group(1)
    return out


# ---- networking
net = load("networking", "organ_networking_v1")
N = thy("Networking.thy")
blocks = re.search(r'priv_blocks = \[(.*?)\]"', N, re.S).group(1)
hol_blocks = [(int(a), int(b)) for a, b in re.findall(r"\((\d+), (\d+)\)", blocks)]
org_blocks = [(int(ipaddress.IPv4Network(x).network_address), ipaddress.IPv4Network(x).prefixlen)
              for x in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")]
check("networking RFC 1918 blocks", hol_blocks == org_blocks, "%s vs %s" % (hol_blocks, org_blocks))
spec = {"2130706432": "127.0.0.0/8", "2851995648": "169.254.0.0/16", "1681915904": "100.64.0.0/10"}
check("networking special blocks (loopback, link-local, CGNAT)",
      all(int(ipaddress.IPv4Network(v).network_address) == int(k) for k, v in spec.items()) and all(k in N for k in spec))
ok = True
for p in range(33):
    nm = ipaddress.IPv4Network("0.0.0.0/%d" % p)
    size = 2 ** (32 - p)
    ok &= int(nm.netmask) == 2 ** 32 - size and int(nm.hostmask) == size - 1
    ok &= net.MASKS[str(nm.netmask)] == p
check("networking mask / wildcard / size formulas for /0../32", ok)

# ---- cyber
cy = load("cyber", "organ_cyber_v1")
T = thy("Numerics.thy")
sizes = {"CS_printable": 95, "CS_alnum": 62, "CS_mixed": 52, "CS_lower": 26, "CS_digits": 10}
hol_sizes = {c: int(v) for c, v in re.findall(r'"csize (CS_\w+) = (\d+)"', T)}
check("cyber set sizes", hol_sizes == sizes, str(hol_sizes))
labels = dict(re.findall(r'"clabel (CS_\w+) = STR \'\'([^\']*)\'\'"', T))
org_labels = {n: lab for _, n, lab in cy.SETS}
check("cyber set labels", sorted(labels.values()) == sorted(org_labels.values()), "%s vs %s" % (labels, org_labels))
rec = thy("recognizer.sml")
dm = re.search(r"val digestBits = \[(.*?)\]", rec, re.S).group(1)
sml_digest = {k: int(v) for k, v in re.findall(r'\("([^"]+)", (\d+)\)', dm)}
check("cyber digest bits (recognizer table)", sml_digest == cy.DIGEST, "%s" % sml_digest)
org_units = [(n, int(v)) for n, v in re.findall(r'\("(\w+)", (\d+)\)', (SPEC / "cyber/organ_cyber_v1.py").read_text().split("def dur")[1].split("class")[0])]
hol_units = re.findall(r"if (\d+) \\<le> s then g_cy \(s / \d+\) \+ STR '' (\w+)''", T)
check("cyber duration unit seconds", [(n, int(v)) for v, n in hol_units] == org_units, "%s vs %s" % (hol_units, org_units))

# ---- linux-v2
lx = load("linux-v2", "organ_linux_v1")
S = thy("System.thy")
hol_sig = [(n, int(v)) for n, v in re.findall(r"\(STR ''(SIG\w+)'', (\d+)\)", S)]
check("linux signal table", hol_sig == sorted(lx.SIG.items(), key=lambda kv: kv[1]) or dict(hol_sig) == lx.SIG, "%d entries" % len(hol_sig))
rg = re.search(r"cron_ranges = \[(.*?)\]\"", S, re.S).group(1)
check("linux cron field ranges", [(int(a), int(b)) for a, b in re.findall(r"\((\d+), (\d+)\)", rg)] == lx.RANGES)

# ---- git
gi = load("git", "organ_git_v1")
hol_cmd = re.findall(r'"gcmd (G_\w+) = (.*)"', S)
hol_body = dict(re.findall(r'"gbody (G_\w+) = (.*)"', S))
hol_warn = set(re.findall(r'"gwarn (G_\w+) = True"', S))
sml_int = re.search(r"val gitIntents = \[(.*?)\]\n\n  fun git ", rec, re.S).group(1)
sml_pats = re.findall(r'\("((?:[^"\\]|\\.)*)", C\.(G_\w+)\)', sml_int)
# Beyond parity intentionally changes four recognition patterns. Keep checking
# every original command/note/warning and unchanged pattern against the organ;
# recognition behavior for the changed patterns is exercised by probes.py.
changed_patterns = {"G_stash_pop", "G_stash", "G_log", "G_cherry_pick"}
extensions = {
    "G_stash_apply": ("git stash apply", "re-applies the latest stash and keeps it in the stash list"),
    "G_stash_list": ("git stash list", "lists the saved stashes without changing the working tree"),
}
commands = {ctor: hol_str(expr) for ctor, expr in hol_cmd}
original = {cmd: (rx, note) for rx, cmd, note in gi.INTENTS}
original_pattern_rows = [(pat, ctor) for pat, ctor in sml_pats if ctor != "G_stash_list"]
check("git original intent order and complete extension inventory",
      len(original) == len(gi.INTENTS) and
      [commands.get(ctor) for _, ctor in original_pattern_rows] == [cmd for _, cmd, _ in gi.INTENTS] and
      set(commands.values()) == set(original) | {cmd for cmd, _ in extensions.values()} and
      len(commands) == len(original) + len(extensions) and
      len(sml_pats) == len(gi.INTENTS) + 1 and
      [ctor for _, ctor in sml_pats].count("G_stash_list") == 1)
errors = []
for pat, ctor in original_pattern_rows:
    cmd = commands.get(ctor)
    if cmd not in original:
        errors.append("unknown command " + ctor)
        continue
    rx, note = original[cmd]
    if ctor not in changed_patterns and pat.replace("\\\\", "\\") != rx:
        errors.append("unexpected pattern change " + ctor)
    want = note[len("WARNING: "):] if note.startswith("WARNING: ") else note
    if hol_str(hol_body[ctor]) != want or (ctor in hol_warn) != note.startswith("WARNING: "):
        errors.append("note/warning " + ctor)
for ctor, (cmd, note) in extensions.items():
    if commands.get(ctor) != cmd or hol_str(hol_body.get(ctor, "")) != note or ctor in hol_warn:
        errors.append("extension " + ctor)
check("git command/note/warning transcription and unchanged patterns", not errors, "; ".join(errors))

# ---- python
before = (HERE / "Pyref_Table.thy").read_text()
r = subprocess.run([sys.executable, "-B", str(HERE / "gen_pyref.py")], capture_output=True, text=True, cwd=REPO)
check("python Pyref_Table.thy equals the regeneration from pyref_v1.json (856 rows)",
      r.returncode == 0 and "856 rows" in r.stdout and (HERE / "Pyref_Table.thy").read_text() == before)
d = json.load(open(SPEC / "python/pyref_v1.json"))
d2 = json.load(open(SPEC / "python-r2/pyref_v1.json"))
check("python and python-r2 ship the same reference file", d == d2)
PT = thy("Pyref_Table.thy")
check("python table row count", len(re.findall(r"(?:\[|,)\n   \(STR", PT)) == len(d["entries"]) == 856)
check("python version stamp", "py_version = STR ''%s''" % d["python"] in PT)

# Lane S15b: table facts the HOL session no longer proves (evaluation is an oracle)
rows = re.findall(r"(?:\[|,)\n   \(STR ''([^']*)'', STR ''([^']*)'', STR ''([^']*)''", PT)
names = [n for n, _, _ in rows]
check("python table names distinct (was py_names_distinct)", len(rows) == 856 and len(set(names)) == len(names))
check("python name = prefix.short or short (was py_names_split)",
      all(n == (sh if pf == "" else pf + "." + sh) for n, pf, sh in rows))
print("%d checks failed" % len(FAILS) if FAILS else "TABLES PASS")
sys.exit(1 if FAILS else 0)
