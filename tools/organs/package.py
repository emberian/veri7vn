#!/usr/bin/env python3
"""package - build the veri7vn specialist package for Oracle7's author.

One tarball, var/organs/veri7vn-specialists-<date>.tar.gz, that unpacks into an Oracle7 `root/` as
`root/specialists/`: one folder per specialist (`<id>-veri7vn`, written by make_organ.py in packaged mode) and one
shared `_veri7vn/` folder holding the built programs, their checksums and receipts, the README, the NOTICE and a
smoke test. It needs no veri7vn checkout once built. Layout and rules: docs/handoff/organ-package.md.

  python3 -B tools/organs/package.py [--date YYYY-MM-DD] [--out var/organs]
        [--darwin-dir DIR]   macOS programs; default each family's registry binary (var/<slug>/bin/<slug>)
        [--linux-dir DIR]    Linux x86-64 programs pulled from the build host, with linux-info.json
        [--pull-linux HOST]  first copy ~/veri7vn-deploy/bin/* and their facts from HOST into --linux-dir
        [--allow-missing]    a platform without a program for some family is a warning, not an error

What goes in: the committed families of src/extract/families.json except `stores` (its program spawns a
python fetcher by checkout path), i.e. only families whose directory is tracked and unmodified in git.
Untracked directories (earth, finance today) are never read. Nothing is written under upstream/."""
from __future__ import annotations

import argparse
import datetime
import gzip
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import make_organ as mo  # noqa: E402

REPO = mo.REPO
EXCLUDE_FAMILIES = {"stores"}                       # the binary needs the checkout path and a python fetcher
PLATFORMS = ("darwin-arm64", "linux-x86_64")
README_SRC = HERE / "package_readme.md"
NOTICE_SRC = HERE / "package_notice.txt"
SMOKE_SRC = HERE / "package_smoke.py"


def sh(*argv, **kw):
    return subprocess.run(argv, check=True, capture_output=True, text=True, cwd=kw.pop("cwd", REPO), **kw).stdout


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def committed_family(slug):
    """True when src/extract/<slug>/ is tracked by git and has no local modification"""
    d = "src/extract/%s" % slug
    if not sh("git", "ls-files", d).strip():
        return False
    return not sh("git", "status", "--porcelain", "--", d).strip()


def source_dirs(slug):
    dirs = ["src/extract/%s" % slug]
    if slug == "variants":
        dirs.append("src/extract/quantity")
    if (REPO / dirs[0] / "ROOT").exists() and "Veri7vn_Commons" in (REPO / dirs[0] / "ROOT").read_text(encoding="utf-8") \
            or slug == "variants":
        dirs.append("src/extract/commons")
    return dirs


def check_native_receipt(session, slug):
    """newest passed check-native receipt for the session, and whether its recorded theory hashes still match"""
    best = None
    for f in (REPO / "var/native-scaffold/sessions").glob("*/receipt.json"):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except ValueError:
            continue
        if d.get("session") == session and d.get("status") == "passed":
            if best is None or d.get("started_utc", "") > best[1].get("started_utc", ""):
                best = (f, d)
    if best is None:
        return None
    f, d = best
    prefixes = tuple("%s/" % x for x in source_dirs(slug))
    thy = {k: v for k, v in d.get("sources_sha256", {}).items() if k.startswith(prefixes) and (k.endswith(".thy") or k.endswith("/ROOT"))}
    changed = []
    for k, v in sorted(thy.items()):
        p = REPO / k
        if not p.exists() or sha256(p) != v:
            changed.append(k)
    return {"path": str(f.relative_to(REPO)), "attempt_id": d.get("attempt_id"), "status": d["status"],
            "started_utc": d.get("started_utc"), "isabelle_version": d.get("isabelle_version"),
            "host": d.get("host"), "expected_markers": d.get("expected_markers"),
            "receipt_sha256": sha256(f), "theory_files_checked": len(thy),
            "theory_files_changed_since": changed}


def generated_sml(slug, darwin_dir=None):
    """the exported kernel SML the macOS program was compiled from (kept by each family's build.sh, or beside
    the program as <slug>.generated.sml when tools/organs/macos-from-export.sh made it)"""
    if darwin_dir and (Path(darwin_dir) / (slug + ".generated.sml")).exists():
        return Path(darwin_dir) / (slug + ".generated.sml")
    b = REPO / "var" / slug / "build"
    for name in ("%s_generated.sml" % slug, "quantity_generated.sml"):
        if (b / name).exists():
            return b / name
    return None


def pull_linux(host, dest):
    """copy ~/veri7vn-deploy/bin/* from host into dest and record what the host says about each"""
    dest.mkdir(parents=True, exist_ok=True)
    script = r'''
set -eu
D=$HOME/veri7vn-deploy
echo "HOST $(hostname) $(uname -srm)"
echo "GLIBC $(ldd --version | head -1)"
echo "MLTON $(ls -d $HOME/tools/isabelle-rc1/Isabelle2026-RC1/contrib/mlton-* | head -1)"
for f in "$D"/bin/*; do
  s=$(basename "$f")
  gen=$(ls "$D/build/$s/"*_generated.sml 2>/dev/null | head -1 || true)
  g=""; [ -n "$gen" ] && g=$(sha256sum "$gen" | cut -d' ' -f1)
  echo "BIN $s $(sha256sum "$f" | cut -d' ' -f1) $(stat -c %s "$f") $(stat -c %Y "$f") ${g:-none} $(ldd "$f" | awk '/=>/ {print $1}' | tr '\n' ',')"
done
'''
    out = subprocess.run(["ssh", "-o", "BatchMode=yes", host, "sh", "-s"], input=script, check=True, capture_output=True, text=True).stdout
    info = {"host": host, "bins": {}}
    for line in out.splitlines():
        k, _, rest = line.partition(" ")
        if k == "HOST":
            info["uname"] = rest
        elif k == "GLIBC":
            info["glibc"] = rest
        elif k == "MLTON":
            info["mlton"] = rest.rsplit("/", 1)[-1]
        elif k == "BIN":
            slug, sha, size, when, gen, libs = rest.split(" ", 5)
            info["bins"][slug] = {"sha256": sha, "size": int(size), "built": datetime.datetime.fromtimestamp(int(when), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "generated_sml_sha256": gen,
                                  "shared_libraries": [x for x in libs.strip().split(",") if x]}
    old = dest / "linux-info.json"
    if old.exists():                                # keep hand-recorded notes (session_built_on) across pulls
        info["session_built_on"] = json.loads(old.read_text(encoding="utf-8")).get("session_built_on", {})
    subprocess.run(["rsync", "-a", "%s:veri7vn-deploy/bin/" % host, str(dest) + "/"], check=True)
    for slug, b in info["bins"].items():            # the copy must be the bytes the host hashed
        if sha256(dest / slug) != b["sha256"]:
            raise SystemExit("pull_linux: %s differs from the host's hash after copying" % slug)
    (dest / "linux-info.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    return info


def add_bytes(tar, name, data, mode, mtime):
    ti = tarfile.TarInfo(name)
    ti.size, ti.mode, ti.mtime, ti.uid, ti.gid, ti.uname, ti.gname = len(data), mode, mtime, 0, 0, "", ""
    tar.addfile(ti, io.BytesIO(data))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--out", default=str(REPO / "var/organs"))
    ap.add_argument("--darwin-dir")
    ap.add_argument("--linux-dir", default=str(REPO / "var/organs/linux-x86_64"))
    ap.add_argument("--pull-linux", metavar="HOST")
    ap.add_argument("--allow-missing", action="store_true")
    a = ap.parse_args()
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

    out = Path(a.out)
    linux_dir = Path(a.linux_dir)
    if a.pull_linux:
        info = pull_linux(a.pull_linux, linux_dir)
        print("pulled %d Linux programs from %s" % (len(info["bins"]), a.pull_linux))
    linux_info = json.loads((linux_dir / "linux-info.json").read_text(encoding="utf-8")) if (linux_dir / "linux-info.json").exists() else {"bins": {}}

    registry = {e["family"]: e for e in json.loads((REPO / "src/extract/families.json").read_text(encoding="utf-8"))["families"]}
    tables = mo.family_tables()
    slugs = []
    for slug in sorted(tables):
        if slug in EXCLUDE_FAMILIES:
            print("skip %s: its program needs the checkout path (stores)" % slug)
        elif not committed_family(slug):
            print("skip %s: not committed (untracked or modified in git)" % slug)
        else:
            slugs.append(slug)

    head = sh("git", "rev-parse", "HEAD").strip()
    mtime = int(sh("git", "log", "-1", "--format=%ct").strip())
    stage = out / ("stage-" + a.date) / "specialists"
    if stage.parent.exists():
        shutil.rmtree(stage.parent)
    shared = stage / "_veri7vn"
    shared.mkdir(parents=True)

    idx = mo.shipped_index()
    folders, errors = [], []
    for slug in slugs:
        for sid in tables[slug]:
            if sid not in idx:
                errors.append("no shipped manifest for %s" % sid)
                continue
            r = mo.make_organ(stage, slug, sid, idx[sid], packaged=True)
            (errors if "error" in r else folders).append(r if "error" not in r else "%s: %s" % (sid, r["error"]))
    if errors:
        raise SystemExit("organ folders failed:\n  " + "\n  ".join(map(str, errors)))

    families, problems = {}, []
    for slug in slugs:
        e = registry[slug]
        entry = {"family": slug, "session": e["session"], "specialists": tables[slug], "source_commit": sh(
            "git", "log", "-1", "--format=%H %cI", "--", *source_dirs(slug)).strip(), "binaries": {}}
        gen = generated_sml(slug, a.darwin_dir)
        entry["generated_sml_sha256_macos"] = sha256(gen) if gen else None
        entry["session_receipt_macos"] = check_native_receipt(e["session"], slug)
        for plat in PLATFORMS:
            if plat == "darwin-arm64":
                src = Path(a.darwin_dir) / slug if a.darwin_dir else REPO / e["binary"]
            else:
                src = linux_dir / slug
            if not src.exists():
                problems.append("%s: no %s program at %s" % (slug, plat, src))
                continue
            dst = shared / "bin" / plat / slug
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)
            os.chmod(dst, 0o755)
            b = {"sha256": sha256(dst), "size": dst.stat().st_size}
            if plat == "linux-x86_64":
                li = linux_info["bins"].get(slug)
                if li and li["sha256"] != b["sha256"]:
                    problems.append("%s: linux-info.json hash differs from the program in %s" % (slug, linux_dir))
                b["built_on"] = {k: linux_info.get(k) for k in ("host", "uname", "glibc", "mlton")}
                b["built"] = (li or {}).get("built")
                b["generated_sml_sha256"] = (li or {}).get("generated_sml_sha256")
                b["shared_libraries"] = (li or {}).get("shared_libraries")
                rb = REPO / "var" / slug / "remote-build.log"
                marker = ("%s PASS" % e["session"]).upper().replace("-", "_")
                b["session_receipt"] = {"kind": "remote-build on %s, exit 0 with marker found" % (linux_info.get("session_built_on", {}).get(slug) or linux_info.get("host")),
                                        "marker": marker, "log": str(rb.relative_to(REPO)) if rb.exists() else None,
                                        "log_sha256": sha256(rb) if rb.exists() else None}
                if b["generated_sml_sha256"] and entry["generated_sml_sha256_macos"] and \
                        b["generated_sml_sha256"] != entry["generated_sml_sha256_macos"]:
                    problems.append("%s: the Linux and macOS kernels were generated from different SML" % slug)
            entry["binaries"][plat] = b
        families[slug] = entry

    for p in problems:
        print(("warning: " if a.allow_missing else "ERROR: ") + p, file=sys.stderr)
    if problems and not a.allow_missing:
        raise SystemExit(1)

    for slug, entry in families.items():
        (shared / "receipts").mkdir(exist_ok=True)
        (shared / "receipts" / (slug + ".json")).write_text(json.dumps(entry, indent=1), encoding="utf-8")
    shutil.copyfile(SMOKE_SRC, shared / "smoke.py")
    notice = NOTICE_SRC.read_text(encoding="utf-8")
    copied = ["%-24s panel %s (from %s), scorer %s.py (from %s)" % (f["sid"] + "-veri7vn", f["panel"], f["panel_from"], f["scorer"], f["scorer_from"])
              for f in folders]
    (shared / "NOTICE").write_text(notice.replace("@COPIED@", "\n".join(copied)), encoding="utf-8")
    readme = README_SRC.read_text(encoding="utf-8").replace("@DATE@", a.date).replace("@NFOLDERS@", str(len(folders))).replace(
        "@NFAMILIES@", str(len(families))).replace("@COMMIT@", head[:12])
    (shared / "README.md").write_text(readme, encoding="utf-8")
    manifest = {"package": "veri7vn-specialists", "date": a.date, "veri7vn_commit": head, "families": families,
                "folders": sorted(f["sid"] + "-veri7vn" for f in folders), "platforms": list(PLATFORMS),
                "excluded": {"stores": "its program spawns a python fetcher by checkout path",
                             "untracked": "earth and finance were never committed, so not packaged"}}
    (shared / "MANIFEST.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")

    sums = []
    for p in sorted(stage.rglob("*")):
        if p.is_file() and p.name != "SHA256SUMS":
            sums.append("%s  %s" % (sha256(p), p.relative_to(stage.parent).as_posix()))
    (shared / "SHA256SUMS").write_text("\n".join(sums) + "\n", encoding="utf-8")

    tarpath = out / ("veri7vn-specialists-%s.tar.gz" % a.date)
    with open(tarpath, "wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, filename="") as gz, \
            tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as tar:
        for p in sorted(stage.rglob("*")):
            rel = p.relative_to(stage.parent).as_posix()
            if p.is_dir():
                ti = tarfile.TarInfo(rel)
                ti.type, ti.mode, ti.mtime = tarfile.DIRTYPE, 0o755, mtime
                tar.addfile(ti)
            else:
                add_bytes(tar, rel, p.read_bytes(), 0o755 if os.access(p, os.X_OK) else 0o644, mtime)
    print("%d specialist folders in %d families -> %s (%d bytes, sha256 %s)" % (
        len(folders), len(families), tarpath, tarpath.stat().st_size, sha256(tarpath)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
