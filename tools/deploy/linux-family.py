#!/usr/bin/env python3
"""Build one veri7vn family on a Linux host, score it there, compare with macOS.

  tools/deploy/linux-family.py <slug> <host>

Generalises tools/deploy/linux-build.sh to the families whose build.sh differs
(humanities rules.sml, stores config.sml and fetch shim, variants reusing the
quantity export, fusion with extra session dirs and no per-specialist panels).
The MLB is read from the family's own build.sh. UNTRUSTED tooling: it decides
nothing about answers; it runs the family binary and diffs replies.

Inputs:  var/linux/specialists.json (ids per family), a macOS baseline harness
run in var/linux/macos/<slug> (see var/linux/macos-baseline.sh).
Outputs: var/linux/linux/<slug>/ (verdicts, items), var/linux/receipt-<slug>.json.
Nothing under upstream/ is written; panels are copied to ~/veri7vn-deploy on the host.
"""
import glob, hashlib, json, os, re, shlex, subprocess, sys, time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
UP = Path(os.environ.get("PARITY_UPSTREAM", REPO / "upstream"))
slug, host = sys.argv[1], sys.argv[2]
LIN = REPO / "var/linux"
OUT = LIN / "linux" / slug
LOG = open(LIN / f"run-{slug}-{host}.log", "w")
SPEC = json.load(open(LIN / "specialists.json")).get(slug, [])
SESSION = {"humanities": "Veri7vn_Humanities", "anatomyagri": "Veri7vn_AnatomyAgri", "geostats": "Veri7vn_GeoStats",
           "variants": "Veri7vn_Quantity"}.get(slug, "Veri7vn_" + slug.capitalize())
SRCDIR = "quantity" if slug == "variants" else slug


def session_dirs():
    """session name -> (ROOT dir, referenced session names), over every src/ ROOT"""
    m = {}
    for root in glob.glob(str(REPO / "src/**/ROOT"), recursive=True):
        txt = re.sub(r"\(\*.*?\*\)", " ", Path(root).read_text(), flags=re.S)
        for blk in re.split(r"(?m)^(?=session )", txt):
            h = re.match(r"session\s+(\S+)", blk)
            if h:
                m[h.group(1)] = (os.path.dirname(root), set(re.findall(r"Veri7vn_\w+", blk[len(h.group(0)):])))
    return m


def extra_dirs(own):
    m = session_dirs(); seen, todo, dirs = set(), [SESSION], set()
    while todo:
        x = todo.pop()
        if x in seen or x not in m:
            continue
        seen.add(x); d, refs = m[x]; dirs.add(d); todo += list(refs)
    return sorted(d for d in dirs if d != own)


EXTRA = extra_dirs(str(REPO / "src/extract" / SRCDIR))
RROOT = "veri7vn-builds/" + REPO.name
t_all = time.time()
rec = {"slug": slug, "host": host, "session": SESSION, "specialists": SPEC}


def run(cmd, **kw):
    LOG.write("$ %s\n" % (cmd if isinstance(cmd, str) else " ".join(map(shlex.quote, cmd)))); LOG.flush()
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, shell=isinstance(cmd, str), cwd=REPO, **kw)
    LOG.write(p.stdout); LOG.flush()
    return p


def ssh(script, args=()):
    return run(["ssh", "-o", "BatchMode=yes", host, "sh", "-s"] + list(args), input=script)


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


home = ssh('echo "$HOME"').stdout.strip().splitlines()[-1]
D = home + "/veri7vn-deploy"
R = D + "/stage"   # sources and the fetched export are staged here; remote-build deletes its own tree

# 1. session build on the host
marker = None
for f in glob.glob(str(REPO / "src/extract" / SRCDIR / "*.thy")):
    m = re.search(r"VERI7VN_[A-Z0-9_]+ PASS", Path(f).read_text(errors="replace"))
    if m:
        marker = m.group(0)
t0 = time.time()
cmd = ["tools/dev/remote-build", host, f"src/extract/{SRCDIR}", SESSION, "--expect", marker]
for e in EXTRA:
    cmd += ["-d", os.path.relpath(e, REPO)]
for attempt in range(4):  # other lanes share the host's Isabelle user state; a concurrent build of the same session collides in sqlite
    p = run(cmd)
    blog = (REPO / f"var/{SRCDIR}/remote-build.log").read_text(errors="replace")
    got = any((REPO / f"var/{SRCDIR}/export-remote/{SESSION}").rglob("*.ML")) or any((REPO / f"var/{SRCDIR}/export-remote/{SESSION}").rglob("*.sml"))
    if p.returncode == 0 and got:
        break
    if p.returncode != 0 and "SQLITE" not in blog and "MISSING" not in blog:
        break  # a real session failure, not a collision with another lane's build
    rec["retries"] = attempt + 1
    time.sleep(90)
rec["session_build_s"] = round(time.time() - t0, 1)
rec["marker"] = marker
rec["session_build_ok"] = p.returncode == 0
if p.returncode == 0:
    # The PASS marker is only visible on a fresh build; record whether this run saw it.
    found = marker in (REPO / f"var/{SRCDIR}/remote-build.log").read_text(errors="replace")
    rec["marker_found"] = found  # false on a cached session: RC1 keeps no messages of a successful build
if p.returncode:
    json.dump(rec, open(LIN / f"receipt-{slug}-{host}.json", "w"), indent=1); sys.exit("session build failed")
exp = REPO / f"var/{SRCDIR}/export-remote/{SESSION}"

# 2. MLB from the family's build.sh
bs = (REPO / f"src/extract/{slug}/build.sh").read_text()
genpat = re.search(r"-name '([^']+)'", bs).group(1)
body = re.search(r'\.mlb" <<\'?(\w+)\'?\n(.*?)\n\1\n', bs, re.S).group(2).splitlines()
gen_local = [l for l in body if l.endswith("_generated.sml")][0]
Q = f"{R}/src/extract/quantity"
lines = []
for l in body:
    l = l.replace("\\$(SML_LIB)", "$(SML_LIB)").replace("$SRC", f"{R}/src/extract/{slug}").replace("$Q", Q).replace("$REPO", R)
    lines.append(l)
mlb = "\n".join(lines) + "\n"
build_script = f'''set -eu
D={D}; R={R}; slug={slug}
MLTON=$(ls -d "$HOME"/tools/isabelle-rc1/Isabelle2026-RC1/contrib/mlton-*/x86_64-linux/bin/mlton | head -n 1)
B=$D/build/$slug; mkdir -p $D/bin $B; rm -f $B/*
GEN=$R/gen/{gen_local}
cp "$GEN" "$B/{gen_local}"
cat > $B/$slug.mlb <<'MLBEOF'
{mlb}MLBEOF
'''
if slug == "stores":
    build_script += f"printf 'structure Config = struct val repo = \"%s\" end\\n' {D}/stores-repo > $B/config.sml\n"
if slug == "variants":
    build_script += ("sed -e 's/^structure Recognizer :/structure RecognizerBase :/' "
        "-e 's/^  val organs : string list$/  val organs : string list\\n  val densities : string -> Quantity.request option\\n  val unitsV2 : string -> Quantity.request option\\n  val unitsV3 : string -> Quantity.request option/' "
        f"{Q}/recognizer.sml > $B/recognizer_base.sml\n")
build_script += f'''cd $B
s=$(date +%s)
swarm-build "$MLTON" -output $D/bin/$slug $slug.mlb
echo COMPILE_S=$(( $(date +%s)-s ))
sha256sum $D/bin/$slug $B/{gen_local}
stat -c 'SIZE=%s' $D/bin/$slug
echo ISABELLE=$($HOME/tools/isabelle-rc1/Isabelle2026-RC1/bin/isabelle version)
echo MLTON=$("$MLTON" 2>&1 | head -1)
echo GLIBC=$(ldd --version | head -1)
echo KERNEL=$(uname -srm)
echo PYTHON=$(python3 --version)
'''
run(["ssh", "-o", "BatchMode=yes", host, f"mkdir -p {R}/gen"])
run(["rsync", "-a", "--delete", "--exclude", "__pycache__", f"{REPO}/src/", f"{host}:{R}/src/"])
_g = [x for x in exp.rglob(genpat)][0]
run(["rsync", "-a", str(_g), f"{host}:{R}/gen/{gen_local}"])
p = ssh(build_script)
if p.returncode:
    sys.exit("mlton step failed")
out = p.stdout
g = lambda k: re.search(k + r"=(.*)", out).group(1).strip()
rec["compile_s"] = int(g("COMPILE_S")); rec["size"] = int(g("SIZE"))
rec["isabelle"] = g("ISABELLE"); rec["mlton"] = g("MLTON"); rec["glibc"] = g("GLIBC"); rec["kernel"] = g("KERNEL"); rec["python"] = g("PYTHON")
shas = re.findall(r"^([0-9a-f]{64})  (\S+)", out, re.M)
rec["binary_sha256"] = [s for s, f in shas if f.endswith("/bin/" + slug)][0]
rec["generated_sha256"] = [s for s, f in shas if f.endswith("_generated.sml")][0]
mac_gen = REPO / f"var/{SRCDIR}/build/{gen_local}"
rec["generated_sha256_macos"] = sha(mac_gen) if mac_gen.exists() else None
mb = Path(os.environ["MACBIN"]) if os.environ.get("MACBIN") else REPO / f"var/{slug}/bin/{slug}"  # MACBIN: a baseline rebuilt from the same sources when var/<slug>/bin is stale
rec["macos_binary_size"] = mb.stat().st_size; rec["macos_binary_sha256"] = sha(mb)

# 3. stage harness + panels
run(["ssh", "-o", "BatchMode=yes", host, f"mkdir -p {D}/upstream/root/specialists {D}/upstream/workbench/data"])
run(["rsync", "-a", "--exclude", "__pycache__", "--exclude", "*.pyc", f"{REPO}/tools/parity/", f"{host}:{D}/parity/"])
run(["rsync", "-a", f"{REPO}/tools/deploy/coldstart.py", f"{host}:{D}/"])
run(["rsync", "-a", f"{UP}/workbench/data/core_panel.json", f"{host}:{D}/upstream/workbench/data/"])
for i in SPEC:
    run(["rsync", "-a", "--exclude", "__pycache__", "--exclude", "*.pyc", f"{UP}/root/specialists/{i}/", f"{host}:{D}/upstream/root/specialists/{i}/"])
for extra in ("narrow_v1.py",):
    pass
if slug == "stores":
    run(["ssh", host, f"mkdir -p {D}/stores-repo/upstream/root/specialists/cooking {D}/stores-repo/upstream/root/specialists/warehouse"])
    for rel in ("cooking/nutrition_v1.sqlite3", "warehouse/site_fresh.sqlite3"):
        run(["rsync", "-a", f"{UP}/root/specialists/{rel}", f"{host}:{D}/stores-repo/upstream/root/specialists/{rel}"])
    run(["ssh", host, f"mkdir -p {D}/stores-repo/src/extract/stores {D}/stores-repo/var/stores/state; rm -f {D}/stores-repo/var/stores/state/*"])
    run(["rsync", "-a", f"{REPO}/src/extract/stores/fetch.py", f"{host}:{D}/stores-repo/src/extract/stores/"])

# 4. score on the host
mainsml = (REPO / f"src/extract/{SRCDIR}/main.sml").read_text()
per_spec = "--specialist" in mainsml
cmdline = f"{D}/bin/{slug}" + (" --specialist {id}" if per_spec else "")
t0 = time.time()
if slug == "fusion":
    qs = json.load(open(UP / "workbench/data/core_panel.json"))["items"]
    inp = "\n".join(json.dumps({"id": "c%d" % i, "q": x["q"], "session": "c%d" % i}) for i, x in enumerate(qs)) + "\n"
    (LIN / "fusion-core.jsonl").write_text(inp)
    run(["rsync", "-a", f"{REPO}/tools/fusion/answerer.py", f"{LIN}/fusion-core.jsonl", f"{host}:{D}/"])
    p = ssh(f"cd {D} && mkdir -p out/fusion && PYTHONDONTWRITEBYTECODE=1 python3 -B answerer.py --binary {D}/bin/fusion < fusion-core.jsonl > out/fusion/core.replies.jsonl")
else:
    p = ssh(f'''set -eu
cd {D}; export PARITY_UPSTREAM={D}/upstream PYTHONDONTWRITEBYTECODE=1
rm -rf out/{slug}
python3 -B parity/harness.py --answerer "{cmdline}" --lane-answerer "{cmdline}" --specialist "{",".join(SPEC)}" --split both --out out/{slug}
python3 -B coldstart.py {D}/bin/{slug} {D}/upstream/root/specialists {SPEC[0]}
''')
rec["score_s"] = round(time.time() - t0, 1)
rec["harness_rc"] = p.returncode
m = re.search(r"cold.*", p.stdout, re.I | re.S)
rec["coldstart_text"] = p.stdout.strip().splitlines()[-1] if p.stdout.strip() else ""
os.makedirs(OUT, exist_ok=True)
run(["rsync", "-a", "--delete", f"{host}:{D}/out/{slug}/", f"{OUT}/"])

# 5. compare with macOS
TIMING = ("ms", "rtt_ms", "specialist_ms", "binary_ms")


def strip(x):
    if isinstance(x, dict):
        return {k: strip(v) for k, v in x.items() if k not in TIMING}
    if isinstance(x, list):
        return [strip(v) for v in x]
    return x


def norm(path):
    return [(r.get("id"), strip(r.get("reply", r))) for r in map(json.loads, open(path, encoding="utf-8"))]


total = diffs = 0; examples = []
if slug == "fusion":
    mac = LIN / "macos/fusion"; mac.mkdir(parents=True, exist_ok=True)
    subprocess.run(f"PYTHONDONTWRITEBYTECODE=1 python3 -B tools/fusion/answerer.py --binary var/fusion/bin/fusion < var/linux/fusion-core.jsonl > {mac}/core.replies.jsonl", shell=True, cwd=REPO, check=True)
    pairs = [("core.replies.jsonl", OUT / "core.replies.jsonl", mac / "core.replies.jsonl")]
else:
    pairs = []
    for new in sorted(glob.glob(str(OUT / "*.items.jsonl")) + glob.glob(str(OUT / "*.lane.jsonl"))):
        pairs.append((os.path.basename(new), Path(new), LIN / "macos" / slug / os.path.basename(new)))
for name, new, old in pairs:
    if not old.exists():
        diffs += 1; examples.append("no counterpart " + name); continue
    a, b = norm(new), norm(old)
    if len(a) != len(b):
        diffs += 1; examples.append("length %s %d vs %d" % (name, len(a), len(b))); continue
    for (ai, ar), (bi, br) in zip(a, b):
        total += 1
        if (ai, ar) != (bi, br):
            diffs += 1
            if len(examples) < 8:
                examples.append({"file": name, "id": ai, "linux": json.dumps(ar)[:300], "macos": json.dumps(br)[:300]})
rec["replies_compared"] = total; rec["replies_divergent"] = diffs; rec["divergence_examples"] = examples

# verdict counts, both sides
def verdicts(d):
    r = {}
    for f in sorted(glob.glob(str(Path(d) / "*.json"))):
        if f.endswith("run.json"): continue
        v = json.load(open(f))
        if "with_specialist" not in v: continue
        c = v["with_specialist"]; core = v.get("core") or {}
        r["%s.%s" % (v["id"], v["split"])] = {"n": v["n"], "ok": c["ok"], "wrong": c["wrong"], "fy": c["fy"], "core_taken": core.get("taken"),
            "errors": v.get("errors"), "statuses": v.get("statuses"), "decision": v.get("decision"), "panel_sha": v.get("panel_sha"), "fails": len(v.get("fails") or [])}
    return r
if slug != "fusion":
    vl, vm = verdicts(OUT), verdicts(LIN / "macos" / slug)
    rec["verdicts_linux"] = vl; rec["verdicts_macos"] = vm; rec["verdicts_equal"] = vl == vm
    rec["panel_items"] = sum(v["n"] for v in vl.values())
    rec["panel_ok"] = sum(v["ok"] for v in vl.values()); rec["panel_wrong"] = sum(v["wrong"] for v in vl.values()); rec["panel_fy"] = sum(v["fy"] for v in vl.values())
else:
    for tag, d in (("linux", OUT), ("macos", LIN / "macos/fusion")):
        rs = [json.loads(l) for l in open(d / "core.replies.jsonl")]
        rec["fusion_answered_" + tag] = sum(1 for r in rs if r.get("status") == "answered")
rec["wall_s"] = round(time.time() - t_all, 1)
rec["git_head"] = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, text=True, stdout=subprocess.PIPE).stdout.strip()
json.dump(rec, open(LIN / f"receipt-{slug}-{host}.json", "w"), indent=1)
print(slug, host, "replies", total, "divergent", diffs, "verdicts_equal", rec.get("verdicts_equal"), "panel", rec.get("panel_ok"), "/", rec.get("panel_items"))
