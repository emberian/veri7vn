#!/usr/bin/env python3
"""Build one veri7vn family on a Linux host, score it there, compare with macOS.

  tools/deploy/linux-family.py <slug> <host> [--from-receipt PATH]

Generalises tools/deploy/linux-build.sh to the families whose build.sh differs
(humanities rules.sml, stores config.sml and fetch shim, variants reusing the
quantity export, fusion with extra session dirs and no per-specialist panels).
The MLB is read from the family's own build.sh. UNTRUSTED tooling: it decides
nothing about answers; it runs the family binary and diffs replies.

Inputs:  src/extract/families.json (explicit family registry), a macOS baseline harness
run in var/linux/macos/<slug> (see var/linux/macos-baseline.sh).
Outputs: var/linux/linux/<run-id>/ (verdicts, items), a unique receipt and log.
Isabelle and MLton use the same managed host lock; MLton has an 8 GiB cap.
Source/build staging is unique per invocation. No earlier staging is deleted.
Nothing under upstream/ is written; panels are copied to ~/veri7vn-deploy on the host.
"""
import argparse, glob, hashlib, json, os, re, shlex, subprocess, sys, time
from pathlib import Path
from build_receipt import managed_receipt_issues

REPO = Path(__file__).resolve().parents[2]
UP = Path(os.environ.get("PARITY_UPSTREAM", REPO / "upstream"))
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("slug")
parser.add_argument("host")
parser.add_argument("--from-receipt", type=Path, help="reuse a passed managed session receipt and its immutable sources/export")
args = parser.parse_args()
slug, host = args.slug, args.host
LIN = REPO / "var/linux"
RUN_ID = f"{slug}-{int(time.time())}-{os.getpid()}"
LIN.mkdir(parents=True, exist_ok=True)
OUT = LIN / "linux" / RUN_ID
LOG = open(LIN / f"run-{RUN_ID}-{host}.log", "x")
sys.path.insert(0, str(REPO / "tools"))
from runtime_contract import load_registry
ENTRY = next((e for e in load_registry(REPO) if e["family"] == slug), None)
if ENTRY is None:
    raise SystemExit("unknown registered family: " + slug)
SPEC = ENTRY["specialists"]
SESSION = ENTRY["session"]
if args.from_receipt:
    initial_receipt = json.loads(args.from_receipt.read_text())
    issues = managed_receipt_issues(initial_receipt, SESSION)
    if issues:
        raise SystemExit("refusing managed receipt: " + "; ".join(issues))
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
rec = {"slug": slug, "host": host, "session": SESSION, "specialists": SPEC, "run_id": RUN_ID, "local_output": str(OUT)}


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
R = D + "/stage/" + RUN_ID   # sources and the fetched export are staged here; managed snapshot is retained for evidence

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
if args.from_receipt:
    receipt_path = args.from_receipt.resolve()
    build_rc = 0
    rec["reused_session_receipt"] = True
else:
    if marker is None:
        raise SystemExit("no expected session marker found")
    p = run(cmd)
    build_rc = p.returncode
    match = re.search(r"remote-build: .*; receipt (.+)$", p.stdout, re.M)
    receipt_path = Path(match.group(1).strip()) if match else None
rec["session_build_s"] = round(time.time() - t0, 1)
rec["marker"] = marker
build_receipt = json.loads(receipt_path.read_text()) if receipt_path and receipt_path.exists() else {}
rec["receipt_issues"] = managed_receipt_issues(build_receipt, SESSION)
rec["session_build_ok"] = build_rc == 0 and not rec["receipt_issues"]
rec["session_receipt"] = {"path": str(receipt_path), "record": build_receipt}
rec["marker"] = build_receipt.get("expect", marker)
if not rec["session_build_ok"]:
    json.dump(rec, open(LIN / f"receipt-{slug}-{host}-{RUN_ID}.json", "w"), indent=1)
    sys.exit("session build failed or produced no managed receipt")
SNAPSHOT = receipt_path.parent
exp = SNAPSHOT / "results/export" / SESSION
source_hashes = json.loads((SNAPSHOT / "source-sha256.json").read_text())
prefixes = tuple(str(Path(d).relative_to(REPO)) + "/" for d in [str(REPO / "src/extract" / slug), str(REPO / "src/extract" / SRCDIR), *EXTRA])
rec["source_sha256"] = {k: v for k, v in source_hashes.items() if k.startswith(prefixes)}
for name, expected in rec["source_sha256"].items():
    if sha(SNAPSHOT / name) != expected:
        raise SystemExit("managed snapshot source changed: " + name)
exports = build_receipt.get("export_sha256", {})
if not exports:
    raise SystemExit("managed receipt has no exported-file hashes")
actual = {str(p.relative_to(exp)): sha(p) for p in exp.rglob("*") if p.is_file()}
if actual != exports:
    raise SystemExit("managed exports no longer match their receipt")

# 2. MLB from the family's build.sh
bs = (SNAPSHOT / f"src/extract/{slug}/build.sh").read_text()
if slug == "stores":
    genpat = "stores*"
    body = ["$(SML_LIB)/basis/basis.mlb", "stores_generated.sml", "config.sml",
            "$REPO/src/extract/commons/commons.sml", "$SRC/json.sml", "$SRC/recognizer.sml", "$SRC/main.sml"]
else:
    pattern = re.search(r"-name '([^']+)'", bs)
    declaration = re.search(r'\.mlb" <<\'?(\w+)\'?\n(.*?)\n\1\n', bs, re.S)
    if not pattern or not declaration:
        raise SystemExit("family build layout needs an explicit deployment declaration: " + slug)
    genpat = pattern.group(1)
    body = declaration.group(2).splitlines()
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
B=$D/build/{RUN_ID}; mkdir -p "$D/bin" "$B"
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
mkdir -p "$HOME/veri7vn-builds/managed"
(
  flock -x 9
  SWARM_MEM_MAX=8G swarm-build "$MLTON" -output "$B/$slug" "$slug.mlb"
  cp "$B/$slug" "$D/bin/$slug"
  mkdir -p "$D/build/$slug"
  cp "$B/{gen_local}" "$D/build/$slug/{gen_local}"
) 9>"$HOME/veri7vn-builds/managed/build.lock"
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
run(["rsync", "-a", "--exclude", "__pycache__", f"{SNAPSHOT}/src/", f"{host}:{R}/src/"])
_g = [x for x in exp.rglob(genpat)][0]
run(["rsync", "-a", str(_g), f"{host}:{R}/gen/{gen_local}"])
p = ssh(build_script)
if p.returncode:
    rec["compile_ok"] = False
    json.dump(rec, open(LIN / f"receipt-{slug}-{host}-{RUN_ID}.json", "w"), indent=1)
    sys.exit("mlton step failed")
rec["compile_ok"] = True
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
    run(["ssh", host, f"mkdir -p {D}/stores-repo/src/extract/stores {D}/stores-repo/var/stores/state"])
    run(["rsync", "-a", f"{SNAPSHOT}/src/extract/stores/fetch.py", f"{host}:{D}/stores-repo/src/extract/stores/"])

# 4. score on the host
mainsml = (SNAPSHOT / f"src/extract/{SRCDIR}/main.sml").read_text()
per_spec = "--specialist" in mainsml
cmdline = f"{D}/build/{RUN_ID}/{slug}" + (" --specialist {id}" if per_spec else "")
if slug == "stores":
    cmdline += f" --state {D}/stores-repo/var/stores/state/{RUN_ID}.json"
t0 = time.time()
if slug == "fusion":
    qs = json.load(open(UP / "workbench/data/core_panel.json"))["items"]
    inp = "\n".join(json.dumps({"id": "c%d" % i, "q": x["q"], "session": "c%d" % i}) for i, x in enumerate(qs)) + "\n"
    (LIN / "fusion-core.jsonl").write_text(inp)
    run(["rsync", "-a", f"{REPO}/tools/fusion/answerer.py", f"{LIN}/fusion-core.jsonl", f"{host}:{D}/"])
    p = ssh(f"cd {D} && mkdir -p out/{RUN_ID} && PYTHONDONTWRITEBYTECODE=1 python3 -B answerer.py --binary {D}/build/{RUN_ID}/fusion < fusion-core.jsonl > out/{RUN_ID}/core.replies.jsonl")
else:
    p = ssh(f'''set -eu
cd {D}; export PARITY_UPSTREAM={D}/upstream PYTHONDONTWRITEBYTECODE=1
mkdir -p out/{RUN_ID}
python3 -B parity/harness.py --answerer "{cmdline}" --lane-answerer "{cmdline}" --specialist "{",".join(SPEC)}" --split both --out out/{RUN_ID}
python3 -B coldstart.py {D}/build/{RUN_ID}/{slug} {D}/upstream/root/specialists {SPEC[0]}
''')
rec["score_s"] = round(time.time() - t0, 1)
rec["harness_rc"] = p.returncode
m = re.search(r"cold.*", p.stdout, re.I | re.S)
rec["coldstart_text"] = p.stdout.strip().splitlines()[-1] if p.stdout.strip() else ""
os.makedirs(OUT, exist_ok=True)
run(["rsync", "-a", f"{host}:{D}/out/{RUN_ID}/", f"{OUT}/"])

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
json.dump(rec, open(LIN / f"receipt-{slug}-{host}-{RUN_ID}.json", "w"), indent=1)
print(slug, host, "replies", total, "divergent", diffs, "verdicts_equal", rec.get("verdicts_equal"), "panel", rec.get("panel_ok"), "/", rec.get("panel_items"))

sys.exit(0 if rec["harness_rc"] == 0 and diffs == 0 and rec.get("verdicts_equal", True) else 1)
