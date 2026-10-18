"""Load the upstream fold modules (module level only, no Engine, no chat) so the
guard functions can be called on fixtures. Read-only against upstream."""
import importlib.util, os, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]   # the scout worktree
UP = Path(os.environ.get("GT_UPSTREAM", "/Users/ember/dev/o7vn/upstream"))

os.environ.update(PYTHONHASHSEED="0", PYTHONDONTWRITEBYTECODE="1", PYTHONIOENCODING="utf-8")
os.environ.setdefault("ORACLE7_ROOT", str(UP / "root"))
os.environ.setdefault("ORACLE7_STATE", str(REPO / "var" / "guards" / "state"))
sys.dont_write_bytecode = True

def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod

o7 = _load("gt_upstream_oracle7", UP / "oracle7.py")   # module level only: sys.path + env

def fold(name):
    return _load("gt_" + name, UP / "root" / "fable-content" / "oracle-m-series-2026-08-15" /
                 "self_loop" / "admitted" / (name + ".py"))
