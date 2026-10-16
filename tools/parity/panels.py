"""Read-only loading of Oracle7 specialist folders: manifests, panels, scorers, the core panel.

Nothing here writes. Bytecode writing is switched off before any upstream module is imported, so loading a
scorer does not leave a __pycache__ entry in the specialist folder."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

REPO = Path(__file__).resolve().parents[2]
UPSTREAM = Path(os.environ.get("PARITY_UPSTREAM", str(REPO / "upstream")))
ROOT = UPSTREAM / "root"
SPECIALISTS = ROOT / "specialists"
CORE_PANEL = UPSTREAM / "workbench" / "data" / "core_panel.json"
PLACEHOLDER = "__ORACLE7_ROOT__"
SPLITS = ("dev", "heldout")


def subst(s, root=None):
    """replace the __ORACLE7_ROOT__ placeholder that shipped manifests use"""
    return str(s).replace(PLACEHOLDER, str(root or ROOT))


def read_manifest(d):
    try:
        return json.loads((Path(d) / "manifest.json").read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001 - same tolerance as exam.read_manifest
        return None


def specialist_ids(base=None):
    """every folder under specialists/ that has a readable manifest, sorted (skips _gate, _cards)"""
    base = Path(base or SPECIALISTS)
    return sorted(p.name for p in base.iterdir() if p.is_dir() and read_manifest(p))


def specialist_dir(sid, base=None):
    return Path(base or SPECIALISTS) / sid


def panel_path(d, m, root=None):
    """the manifest's panel path with the placeholder substituted; relative paths are relative to the folder.
    None when the manifest declares no panel (exam.py would then look for panel.json)."""
    p = Path(subst((m.get("panel") or {}).get("path", "panel.json"), root))
    return p if p.is_absolute() else Path(d) / p


def load_panel(d, m=None, root=None):
    m = m or read_manifest(d)
    p = panel_path(d, m, root)
    if not p.exists():
        return None
    return json.loads(p.read_text(encoding="utf-8"))


def split_items(panel, split):
    """both shipped shapes: {"dev": [...], "heldout": [...]} or a flat list whose items carry "split"."""
    if panel is None:
        return []
    if isinstance(panel, dict):
        return list(panel.get(split) or [])
    return [it for it in panel if it.get("split") == split]


def items(d, split, m=None, root=None):
    return split_items(load_panel(d, m, root), split)


def panel_sha(items_):
    """exam.py's held-out fingerprint: sha256 of json.dumps(items, sort_keys=True)"""
    return hashlib.sha256(json.dumps(items_, sort_keys=True).encode()).hexdigest()


def expected(it):
    """the item's expected answer, whichever key it uses"""
    return it["a"] if "a" in it else it.get("expect")


def excluded_kinds(m):
    """item kinds the release gate v2 left out of the composed score (manifest panel.exclude_kinds_composed).
    exam.py ignores this field; the harness reports both counts."""
    return set((m.get("panel") or {}).get("exclude_kinds_composed") or [])


def load_scorer(d, m):
    """<scorer_module>.<scorer_fn> from the folder, as exam._scorer does: ok(item, reply) -> (good, asserted)"""
    pm = m.get("panel") or {}
    mod_name = pm.get("scorer_module", "scorer")
    path = Path(d) / (mod_name + ".py")
    spec = importlib.util.spec_from_file_location("parity_score_%s" % re.sub(r"\W", "_", m["id"]), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return getattr(mod, pm.get("scorer_fn", "ok"))


def budget_ms(m):
    return float((m.get("budgets") or {}).get("latency_p50_ms", 200))


def core_items(path=None):
    return json.loads(Path(path or CORE_PANEL).read_text(encoding="utf-8"))["items"]


def shipped_verdict(d):
    """the shipped verdict_heldout.json normalised to exam.py terms, from either format:
    exam.py's (head/with_specialist/n) or the release gate v2's (domain.head/domain.spec/core/self)."""
    p = Path(d) / "verdict_heldout.json"
    if not p.exists():
        return None
    v = json.loads(p.read_text(encoding="utf-8"))
    return normalise_verdict(v)


def normalise_verdict(v):
    if "with_specialist" in v:                    # exam.py format
        return {"format": "exam", "decision": v.get("decision"), "reasons": v.get("reasons", []), "n": v.get("n"),
                "head": dict(v["head"]), "with_specialist": dict(v["with_specialist"]),
                "core_taken": (v.get("core") or {}).get("taken"), "self_ok": v.get("self_ok"),
                "p50_ms": v.get("p50_ms"), "core_head": v.get("core_head")}
    dom = v.get("domain") or {}

    def side(s):
        s = s or {}
        return {"ok": s.get("correct"), "fy": s.get("false_yes"), "wrong": s.get("wrong")}
    core = v.get("core") or {}
    selfs = v.get("self")
    return {"format": "gate_v2", "decision": v.get("decision"), "reasons": v.get("reasons", []),
            "n": (dom.get("spec") or {}).get("n"), "head": side(dom.get("head")), "with_specialist": side(dom.get("spec")),
            "core_taken": len(core.get("taken_by_specialist") or []) if "taken_by_specialist" in core else None,
            "self_ok": all(x.get("same") for x in selfs) if isinstance(selfs, list) else None,
            "p50_ms": (dom.get("spec") or {}).get("p50_ms"), "core_head": v.get("head")}
