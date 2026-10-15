"""Unpack the pinned release without deleting its compressed distribution files.

Unlike upstream setup(), verify existing destinations too. Safe to resume.
"""
import hashlib
import json
from pathlib import Path

import zstandard

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / "upstream"


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(8 << 20), b""):
            h.update(block)
    return h.hexdigest()


def main():
    manifest = json.loads((UPSTREAM / "PACK_MANIFEST.json").read_text())
    verified = []
    for entry in manifest["files"]:
        dst = UPSTREAM / entry["path"]
        if not dst.exists():
            src = Path(str(dst) + ".zst")
            with src.open("rb") as f:
                if f.read(4) != b"\x28\xb5\x2f\xfd":
                    raise ValueError(f"Not downloaded yet: {src}")
            tmp = dst.with_name(dst.name + ".audit-part")
            with src.open("rb") as fi, tmp.open("wb") as fo:
                zstandard.ZstdDecompressor(max_window_size=2**27).copy_stream(fi, fo)
            if tmp.stat().st_size != entry["size"] or digest(tmp) != entry["sha256"]:
                raise ValueError(f"Hash/size mismatch: {tmp}")
            tmp.rename(dst)
        elif dst.stat().st_size != entry["size"] or digest(dst) != entry["sha256"]:
            raise ValueError(f"Existing store differs: {dst}")
        verified.append(entry)
        print(f"Verified {len(verified)}/{len(manifest['files'])}: {entry['path']}", flush=True)
    (ROOT / "audit/results/stores.json").write_text(json.dumps(verified, indent=2) + "\n")


if __name__ == "__main__":
    main()
