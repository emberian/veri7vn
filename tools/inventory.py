"""Inventory actual source and verification scope, without importing the runtime."""
import ast
import collections
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UP = ROOT / "upstream"
ADMITTED = UP / "root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted"
head = json.loads((ADMITTED / "HEAD_MANIFEST.json").read_text())
parts = json.loads((UP / "RELEASE_HASHES.json").read_text())["parts"]
sources = list(UP.rglob("*.py"))
methods = collections.Counter()
folds = []
for name in head["chain_tip_to_base"]:
    path = ADMITTED / (name + ".py")
    tree = ast.parse(path.read_text())
    classes = [n for n in tree.body if isinstance(n, ast.ClassDef)]
    defs = [n.name for c in classes for n in c.body if isinstance(n, ast.FunctionDef)]
    methods.update(defs)
    folds.append({"module": name, "lines": len(path.read_text().splitlines()), "methods": defs})
pack = json.loads((UP / "PACK_MANIFEST.json").read_text())["files"]
out = {
    "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=UP, text=True).strip(),
    "source_files": len(sources),
    "source_lines": sum(len(p.read_text().splitlines()) for p in sources),
    "fold_count": len(folds),
    "fold_lines": sum(f["lines"] for f in folds),
    "overridden_methods": methods.most_common(20),
    "hash_parts": len(parts),
    "core_hashed_parts": [k for k in parts if not k.startswith("specialists/")],
    "unpacked_store_bytes": sum(e["size"] for e in pack),
    "packed_store_count": len(pack),
    "folds": folds,
}
(ROOT / "audit/results/inventory.json").write_text(json.dumps(out, indent=2) + "\n")
print(json.dumps({k: v for k, v in out.items() if k != "folds"}, indent=2))
