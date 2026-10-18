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

What goes in: selected registered specialist families. Modified source directories fail unless
--allow-dirty is explicit; their files and hashes are recorded without claiming a fresh binary build.
Stores requires --include-stores and binaries supporting explicit asset paths. Nothing is written under upstream/."""
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
sys.path.insert(0, str(HERE.parent / "deploy"))
from build_receipt import deployment_receipt_issues, managed_receipt_issues  # noqa: E402

REPO = mo.REPO
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


def matching_linux_receipts(slug, binary_hash):
    """Historical checks are evidence only for the exact binary they hashed."""
    found = []
    for path in sorted((REPO / "var/linux").glob("receipt-%s-*.json" % slug)):
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("binary_sha256") == binary_hash:
            issues = deployment_receipt_issues(data)
            original = data.get("session_receipt", {}).get("path")
            if original and Path(original).is_file():
                live = json.loads(Path(original).read_text(encoding="utf-8"))
                issues.extend(managed_receipt_issues(live, data.get("session")))
            if issues:
                raise ValueError("refusing binary with rejected matched receipt %s: %s" % (path, "; ".join(issues)))
            sources = {name: value for name, value in data.get("source_sha256", {}).items()
                       if Path(name).suffix in (".thy", ".ML", ".sml", ".py") or Path(name).name == "ROOT"}
            changed = [name for name, expected in sources.items()
                       if not (REPO / name).is_file() or sha256(REPO / name) != expected]
            found.append({"path": str(path.relative_to(REPO)), "sha256": sha256(path), "record": data,
                          "current_relevant_sources_match": not changed if sources else None,
                          "changed_relevant_sources": changed,
                          "relevant_source_count": len(sources),
                          "runtime_sources_covered": sorted(sources)})
    return found


def source_snapshot(slug):
    files = sh("git", "ls-files", "--cached", "--others", "--exclude-standard", "--", *source_dirs(slug),
               "src/extract/families.json", "tools/runtime_contract.py").splitlines()
    return {name: sha256(REPO / name) for name in files if (REPO / name).is_file()}


def generated_sml(slug, darwin_dir=None):
    """the exported kernel SML the macOS program was compiled from (kept by each family's build.sh, or beside
    the program as <slug>.generated.sml when tools/organs/macos-from-export.sh made it)"""
    if darwin_dir:
        for name in (slug + ".generated.sml", slug + "_generated.sml"):
            if (Path(darwin_dir) / name).exists():
                return Path(darwin_dir) / name
        return None
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
    ap.add_argument("--family", help="comma-separated family names; default all specialist families")
    ap.add_argument("--platform", action="append", choices=PLATFORMS, help="repeat to select platforms")
    ap.add_argument("--allow-dirty", action="store_true", help="record modified source state; does not certify binary freshness")
    ap.add_argument("--include-stores", action="store_true", help="requires stores binaries with explicit asset-path options")
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
    selected = set(a.family.split(",")) if a.family else set(tables)
    unknown = selected - set(tables)
    if unknown:
        raise SystemExit("unknown specialist families: " + ", ".join(sorted(unknown)))
    platforms = tuple(a.platform or PLATFORMS)
    slugs, excluded = [], {}
    for slug in sorted(tables):
        if slug not in selected:
            excluded[slug] = "not selected"
        elif slug == "stores" and not a.include_stores:
            excluded[slug] = "requires explicit asset-path binaries and --include-stores"
        elif not committed_family(slug) and not a.allow_dirty:
            raise SystemExit("%s source is untracked or modified; use --allow-dirty to record a working snapshot" % slug)
        else:
            slugs.append(slug)
    if not slugs:
        raise SystemExit("no families selected")

    head = sh("git", "rev-parse", "HEAD").strip()
    mtime = int(sh("git", "log", "-1", "--format=%ct").strip())
    stage = out / ("stage-" + a.date) / "specialists"
    if stage.parent.exists():
        raise SystemExit("refusing to overwrite existing stage: %s" % stage.parent)
    shared = stage / "_veri7vn"
    shared.mkdir(parents=True)

    if "stores" in slugs:
        assets = shared / "stores"
        assets.mkdir()
        for src in (REPO / "src/extract/stores/fetch.py",
                    mo.UPSTREAM / "root/specialists/cooking/nutrition_v1.sqlite3",
                    mo.UPSTREAM / "root/specialists/warehouse/site_fresh.sqlite3"):
            shutil.copyfile(src, assets / src.name)
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
        entry["source_snapshot_sha256"] = source_snapshot(slug)
        entry["source_snapshot_scope"] = "family sources, known shared source directories, registry and runtime contract"
        entry["source_modified"] = not committed_family(slug)
        entry["binary_source_binding"] = "not established by packaging; inspect matched build receipts"
        gen = generated_sml(slug, a.darwin_dir)
        entry["generated_sml_sha256_macos"] = sha256(gen) if gen else None
        entry["session_receipt_macos"] = check_native_receipt(e["session"], slug)
        for plat in platforms:
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
                b["matching_build_receipts"] = matching_linux_receipts(slug, b["sha256"])
                stores_runtime = {"src/extract/stores/main.sml", "src/extract/stores/fetch.py",
                                  "src/extract/stores/recognizer.sml", "src/extract/commons/commons.sml"}
                if slug == "stores" and not any(r["current_relevant_sources_match"] is True and
                                                  stores_runtime <= set(r["runtime_sources_covered"])
                                                  for r in b["matching_build_receipts"]):
                    raise SystemExit("stores Linux binary requires a matched current-source receipt for its explicit preview/asset-path CLI")
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
    shutil.copyfile(REPO / "tools/runtime_contract.py", shared / "runtime_contract.py")
    notice = NOTICE_SRC.read_text(encoding="utf-8")
    copied = ["%-24s panel %s (from %s), scorer %s.py (from %s)" % (f["sid"] + "-veri7vn", f["panel"], f["panel_from"], f["scorer"], f["scorer_from"])
              for f in folders]
    (shared / "NOTICE").write_text(notice.replace("@COPIED@", "\n".join(copied)), encoding="utf-8")
    readme = README_SRC.read_text(encoding="utf-8").replace("@DATE@", a.date).replace("@NFOLDERS@", str(len(folders))).replace(
        "@NFAMILIES@", str(len(families))).replace("@COMMIT@", head[:12])
    (shared / "README.md").write_text(readme, encoding="utf-8")
    manifest = {"package": "veri7vn-specialists", "date": a.date, "veri7vn_commit": head, "families": families,
                "folders": sorted(f["sid"] + "-veri7vn" for f in folders), "platforms": list(platforms),
                "excluded": excluded, "source_snapshot_only": True}
    (shared / "MANIFEST.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")

    sums = []
    for p in sorted(stage.rglob("*")):
        if p.is_file() and p.name != "SHA256SUMS":
            sums.append("%s  %s" % (sha256(p), p.relative_to(stage.parent).as_posix()))
    (shared / "SHA256SUMS").write_text("\n".join(sums) + "\n", encoding="utf-8")

    tarpath = out / ("veri7vn-specialists-%s.tar.gz" % a.date)
    with open(tarpath, "xb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, filename="") as gz, \
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
