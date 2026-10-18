#!/usr/bin/env python3
"""Build one veri7vn family on a Linux host, score it there, compare with macOS.

  tools/deploy/linux-family.py <slug> <host> [--from-receipt PATH]

Generalises tools/deploy/linux-build.sh to the families whose build.sh differs
(humanities rules.sml, stores config.sml and fetch shim, variants reusing the
quantity export). Non-specialist batteries have their own runners.
The MLB is read from the family's own build.sh. UNTRUSTED tooling: it decides
nothing about answers; it runs the family binary and diffs replies.

Inputs: src/extract/families.json, a passed managed receipt, and exact native binaries.
--runtime-overlay snapshots current runtime only after proof dependency sources match.
A fresh macOS specialist-panel baseline is generated for each run; historical dumps are not reused.
Outputs: var/linux/linux/<run-id>/ (verdicts, items), a unique receipt and log.
Isabelle and MLton use the same managed host lock; MLton has an 8 GiB cap.
Source/build staging is unique per invocation. No earlier staging is deleted.
Nothing under upstream/ is written; panels are copied to ~/veri7vn-deploy on the host.
"""
import argparse, glob, hashlib, json, os, re, shlex, shutil, subprocess, sys, time
from pathlib import Path
from build_receipt import managed_receipt_issues, validate_export_snapshot, stage_runtime_overlay, stores_runtime_sources, shared_runtime_sources

REPO = Path(__file__).resolve().parents[2]
UP = Path(os.environ.get("PARITY_UPSTREAM", REPO / "upstream"))
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("slug")
parser.add_argument("host")
parser.add_argument("--from-receipt", type=Path, help="reuse a passed managed session receipt and its immutable sources/export")
parser.add_argument("--runtime-overlay", nargs="?", const=REPO, type=Path, help="snapshot runtime sources from this root (default checkout), validating unchanged proof dependencies")
args = parser.parse_args()
if args.runtime_overlay and not args.from_receipt:
    parser.error("--runtime-overlay requires --from-receipt; it never starts Isabelle")
slug, host = args.slug, args.host
SOURCE_REPO = args.runtime_overlay.resolve() if args.runtime_overlay else REPO
LIN = REPO / "var/linux"
RUN_ID = f"{slug}-{int(time.time())}-{os.getpid()}"
LIN.mkdir(parents=True, exist_ok=True)
OUT = LIN / "linux" / RUN_ID
LOG = open(LIN / f"run-{RUN_ID}-{host}.log", "x")
sys.path.insert(0, str(REPO / "tools"))
from runtime_contract import load_registry
ENTRY = next((e for e in load_registry(SOURCE_REPO) if e["family"] == slug), None)
if ENTRY is None:
    raise SystemExit("unknown registered family: " + slug)
SPEC = ENTRY["specialists"]
if not SPEC:
    raise SystemExit("this deployment comparison requires specialist panels; non-specialist batteries use their own runner")
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
    for root in glob.glob(str(SOURCE_REPO / "src/**/ROOT"), recursive=True):
        txt = re.sub(r"\(\*.*?\*\)", " ", Path(root).read_text(), flags=re.S)
        for blk in re.split(r"(?m)^(?=session )", txt):
            h = re.match(r"session\s+(\S+)", blk)
            if h:
                m[h.group(1)] = (str(REPO / Path(root).parent.relative_to(SOURCE_REPO)), set(re.findall(r"Veri7vn_\w+", blk[len(h.group(0)):])))
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
if hashlib.sha256(json.dumps(source_hashes, sort_keys=True).encode()).hexdigest() != build_receipt["source_digest"]:
    raise SystemExit("managed source inventory digest no longer matches its receipt")
prefixes = tuple(str(Path(d).relative_to(REPO)) + "/" for d in [str(REPO / "src/extract" / slug), str(REPO / "src/extract" / SRCDIR), *EXTRA])
rec["source_sha256"] = {k: v for k, v in source_hashes.items() if k.startswith(prefixes)}
for name, expected in rec["source_sha256"].items():
    if sha(SNAPSHOT / name) != expected:
        raise SystemExit("managed snapshot source changed: " + name)
exports = build_receipt.get("export_sha256", {})
if not exports:
    raise SystemExit("managed receipt has no exported-file hashes")
validate_export_snapshot(exp, exports)

if args.runtime_overlay:
    proof_sources = {k: v for k, v in source_hashes.items() if k.startswith(prefixes)
                     and (Path(k).suffix in (".thy", ".ML") or Path(k).name == "ROOT")}
    directories = [str(Path(d).relative_to(REPO)) for d in
                   [str(REPO / "src/extract" / slug), str(REPO / "src/extract" / SRCDIR), *EXTRA]]
    runtime_stage = LIN / "runtime" / RUN_ID
    runtime_files = ["src/extract/families.json", "tools/runtime_contract.py"]
    if 'code_evidence.py' in (SOURCE_REPO / 'tools/runtime_contract.py').read_text():
        runtime_files.append('tools/code_evidence.py')
    runtime_files += shared_runtime_sources(
        (SOURCE_REPO / f"src/extract/{slug}/build.sh").read_text(), slug)
    before = stage_runtime_overlay(SOURCE_REPO, runtime_stage, directories, proof_sources,
                                   runtime_files=runtime_files)
    SNAPSHOT = runtime_stage
    rec["runtime_overlay"] = str(runtime_stage)
    rec["runtime_overlay_input"] = str(SOURCE_REPO)
    rec["proof_dependency_sha256"] = proof_sources
    rec["source_sha256"] = before

mb = Path(os.environ["MACBIN"]) if os.environ.get("MACBIN") else REPO / f"var/{slug}/bin/{slug}"  # MACBIN: a baseline rebuilt from the same sources when var/<slug>/bin is stale
rec["macos_binary_size"] = mb.stat().st_size; rec["macos_binary_sha256"] = sha(mb)

# Freeze the actual macOS baseline before waiting for a remote compiler slot.
# These fresh dumps never inherit historical var/linux/macos/<family> data.
local_run = LIN / "compare" / RUN_ID
local_run.mkdir(parents=True, exist_ok=False)
frozen_mac = local_run / slug
before_mac = sha(mb)
shutil.copyfile(mb, frozen_mac)
frozen_mac.chmod(0o755)
if sha(frozen_mac) != before_mac or sha(mb) != before_mac:
    raise SystemExit("macOS binary changed during snapshot")
rec["macos_binary_sha256"] = before_mac
rec["macos_binary_snapshot"] = str(frozen_mac)
native_inputs = SOURCE_REPO.parent / "native-compile.json"
if not native_inputs.is_file():
    native_inputs = REPO / f"var/{slug}/build/compile-inputs.json"
if native_inputs.exists():
    binding = json.loads(native_inputs.read_text())
    if binding.get("binary_sha256") == before_mac:
        rec["macos_compiler_receipt"] = {"path": str(native_inputs), "record": binding}


# 2. MLB from the family's build.sh
bs = (SNAPSHOT / f"src/extract/{slug}/build.sh").read_text()
if slug == "stores":
    body = ["$(SML_LIB)/basis/basis.mlb", "stores_generated.sml", "config.sml"] + [
        "$REPO/" + name for name in stores_runtime_sources(bs)]
else:
    declaration = re.search(r'\.mlb" <<\'?(\w+)\'?\n(.*?)\n\1\n', bs, re.S)
    if not declaration:
        raise SystemExit("family build layout needs an explicit deployment declaration: " + slug)
    body = declaration.group(2).splitlines()
generated_inputs = [l for l in body if l.endswith("_generated.sml")]
if len(generated_inputs) != 1:
    raise SystemExit("expected exactly one generated SML input in family MLB")
gen_local = generated_inputs[0]
stem = Path(gen_local).name.removesuffix("_generated.sml")
export_names = [name for name in exports if Path(name).name in (stem + ".ML", stem + ".sml")]
if len(export_names) != 1:
    raise SystemExit("expected exactly one matching generated export in receipt inventory: " + stem)
generated_export = exp / export_names[0]
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
sha256sum "$B/$slug" "$B/{gen_local}"
stat -c 'SIZE=%s' "$B/$slug"
echo ISABELLE=$($HOME/tools/isabelle-rc1/Isabelle2026-RC1/bin/isabelle version)
echo MLTON=$("$MLTON" 2>&1 | head -1)
echo GLIBC=$(ldd --version | head -1)
echo KERNEL=$(uname -srm)
echo PYTHON=$(python3 --version)
python3 - <<'INPUTREC'
import hashlib,json
from pathlib import Path
b=Path("{D}/build/{RUN_ID}")
inputs={{}}
for name in (b/"{slug}.mlb").read_text().splitlines():
    if not name.strip() or name.startswith("$(SML_LIB)"): continue
    path=Path(name) if Path(name).is_absolute() else b/name
    inputs[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest()
print("INPUTS_JSON="+json.dumps(inputs,sort_keys=True))
INPUTREC
'''
sys.path.insert(0, str(REPO / "tools/organs"))
import make_organ as organs
organs.REPO = SNAPSHOT if args.runtime_overlay else REPO
organs.REGISTRY = {entry["family"]: entry for entry in load_registry(SNAPSHOT if args.runtime_overlay else REPO) if entry["specialists"]}
organs.family_tables()
index = organs.shipped_index()
panel_root = local_run / "specialists"
for sid in SPEC:
    made = organs.make_organ(panel_root, slug, sid, index[sid], quiet=True)
    if "error" in made:
        raise SystemExit("could not prepare " + sid + ": " + made["error"])
rec["panel_files_sha256"] = {str(path.relative_to(panel_root)): sha(path)
                             for path in panel_root.rglob("*") if path.is_file()}
smoke = local_run / "smoke.py"
shutil.copyfile(REPO / "tools/organs/package_smoke.py", smoke)
rec["smoke_sha256"] = sha(smoke)
mac_dump = local_run / "macos.json"
mac_env = os.environ.copy()
mac_env.update({"VERI7VN_" + slug.upper() + "_BIN": str(frozen_mac), "PYTHONDONTWRITEBYTECODE": "1"})
p = run([sys.executable, "-B", str(smoke), "--root", str(panel_root), "--dump", str(mac_dump)], env=mac_env)
if p.returncode:
    raise SystemExit("fresh macOS specialist smoke failed; see deployment log")

run(["ssh", "-o", "BatchMode=yes", host, f"mkdir -p {R}/gen"])
run(["rsync", "-a", "--exclude", "__pycache__", f"{SNAPSHOT}/src/", f"{host}:{R}/src/"])
_g = generated_export
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
rec["compiler_inputs_sha256"] = json.loads(g("INPUTS_JSON"))
rec["isabelle"] = g("ISABELLE"); rec["mlton"] = g("MLTON"); rec["glibc"] = g("GLIBC"); rec["kernel"] = g("KERNEL"); rec["python"] = g("PYTHON")
shas = re.findall(r"^([0-9a-f]{64})  (\S+)", out, re.M)
rec["binary_sha256"] = [s for s, f in shas if f == f"{D}/build/{RUN_ID}/{slug}"][0]
rec["generated_sha256"] = [s for s, f in shas if f.endswith("_generated.sml")][0]
rec["generated_sha256_macos"] = rec.get("macos_compiler_receipt", {}).get("record", {}).get("generated_sha256")
rec["generated_sha256_expected_baseline"] = sha(generated_export)
# Every file and acceptance rule is copied identically to the remote run.
for local, remote in ((panel_root, R + "/specialists"), (smoke, R + "/smoke.py"),
                      (mac_dump, R + "/macos.json")):
    dest = remote + "/" if local.is_dir() else remote
    if run(["rsync", "-a", str(local) + ("/" if local.is_dir() else ""), host + ":" + dest]).returncode:
        raise SystemExit("panel staging failed")
if slug == "stores":
    # Preserved for explicit direct stores deployments; final stores refresh is already owned separately.
    ssh(f"mkdir -p {D}/stores-repo/upstream/root/specialists/cooking {D}/stores-repo/upstream/root/specialists/warehouse {D}/stores-repo/src/extract/stores")
    for rel in ("cooking/nutrition_v1.sqlite3", "warehouse/site_fresh.sqlite3"):
        run(["rsync", "-a", str(UP / "root/specialists" / rel), f"{host}:{D}/stores-repo/upstream/root/specialists/{rel}"])
    run(["rsync", "-a", str(SNAPSHOT / "src/extract/stores/fetch.py"), f"{host}:{D}/stores-repo/src/extract/stores/fetch.py"])
t0 = time.time()
p = ssh(f"cd {R} && VERI7VN_{slug.upper()}_BIN={D}/build/{RUN_ID}/{slug} PYTHONDONTWRITEBYTECODE=1 python3 -B smoke.py --root specialists --dump linux.json --compare macos.json")
rec["score_s"] = round(time.time() - t0, 1)
rec["harness_rc"] = p.returncode
OUT.mkdir(parents=True, exist_ok=True)
run(["rsync", "-a", f"{host}:{R}/linux.json", str(OUT / "linux.json")])
run(["rsync", "-a", f"{host}:{D}/build/{RUN_ID}/{slug}", str(OUT / slug)])
if not (OUT / slug).is_file() or sha(OUT / slug) != rec["binary_sha256"]:
    raise SystemExit("copied Linux binary differs from exact compiled artifact")
rec["local_binary"] = str(OUT / slug)
rec["remote_binary"] = f"{D}/build/{RUN_ID}/{slug}"
mac = json.loads(mac_dump.read_text())
linux = json.loads((OUT / "linux.json").read_text()) if (OUT / "linux.json").exists() else {}
expected = {sid + "-veri7vn" for sid in SPEC}
coverage = set(mac["replies"]) == expected == set(linux.get("replies", {}))
coverage = coverage and all(set(mac["replies"][sid]) == {"dev", "heldout"} == set(linux["replies"][sid]) for sid in expected)
rec["expected_specialists"] = sorted(expected)
rec["complete_panel_coverage"] = coverage
rec["comparison"] = "accepted specialist-panel status and response, freshly scored on both platforms; no head/core/lane/self sweep"
rec["macos_dump"] = str(mac_dump)
rec["linux_dump"] = str(OUT / "linux.json")
rec["panel_totals_macos"] = mac["totals"]
rec["panel_totals_linux"] = linux.get("totals")
rec["replies_compared"] = sum(len(v) for sp in mac["replies"].values() for v in sp.values())
rec["replies_identical"] = coverage and rec["replies_compared"] > 0 and mac["replies"] == linux.get("replies")
rec["wall_s"] = round(time.time() - t_all, 1)
rec["git_head"] = run(["git", "rev-parse", "HEAD"]).stdout.strip()
receipt_out = LIN / f"receipt-{slug}-{host}-{RUN_ID}.json"
receipt_out.write_text(json.dumps(rec, indent=2) + "\n")
print(json.dumps({"family": slug, "receipt": str(receipt_out), "coverage": coverage,
                  "identical": rec["replies_identical"], "totals": rec["panel_totals_linux"]}))
sys.exit(0 if p.returncode == 0 and rec["replies_identical"] else 1)
