#!/usr/bin/env python3
"""Oracle7 reference answerer (docs/contracts/answerer.md): JSON lines on stdin, one reply per line on stdout.

  oracle7.py                          the shipped head: upstream/oracle7.py's Engine
  oracle7.py --specialist <dir>       the head, then the specialist only where the head did not answer and its path is
                                      fillable, composed by upstream/workbench/exam.py's own fillable and Loaded.reply
                                      (Loaded's constructor is adapted to load shipped manifests; see loaded_class)
  oracle7.py --tip <fold> ...         the head built from an earlier admitted fold, e.g. the head a verdict names
  oracle7.py --specialist <dir> --alone
                                      the specialist alone, no engine: the reply when Loaded.reply takes the question,
                                      otherwise withheld with path "" (used for the LANE, SELF and BUDGET criteria)

The composed reply carries provenance.head (the head's own status/response/path), provenance.consulted and
provenance.specialist_ms (Loaded.reply wall time, measured where exam.py measures it), so one pass gives both the head
and the composed counts. Upstream is only read: engine state goes to --state (default a fresh directory under
var/parity/state/, removed on exit), and bytecode writing is off."""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import shutil
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
UPSTREAM = Path(os.environ.get("PARITY_UPSTREAM", str(REPO / "upstream")))

# the gate measures the core with a fixed hash seed (oracle7.py re-execs only when it is __main__ itself)
if os.environ.get("PYTHONHASHSEED") != "0" or os.environ.get("PYTHONDONTWRITEBYTECODE") != "1":
    os.environ.update(PYTHONHASHSEED="0", PYTHONIOENCODING="utf-8", PYTHONDONTWRITEBYTECODE="1")
    os.execv(sys.executable, [sys.executable, os.path.abspath(__file__)] + sys.argv[1:])
sys.dont_write_bytecode = True


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def _jsonable(x):
    return json.loads(json.dumps(x, default=str))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--specialist", help="specialist folder (composed with the head, or alone with --alone)")
    ap.add_argument("--compose", choices=["exam", "front", "combo"], default="exam",
                    help="exam: head first, specialist only on a fillable decline (workbench/exam.py). front: the "
                         "release's single-specialist composition (spec_runtime): the organ in front of the head, the "
                         "head only where the organ takes nothing; organ loading, accept rule and reading rule are "
                         "_gate/combo_runtime_v1's _Organ, one reply per turn. combo: the same through "
                         "combo_runtime_v1.Combo.reply, which also splits multi-question turns into parts")
    ap.add_argument("--alone", action="store_true", help="the specialist alone, no engine")
    ap.add_argument("--tip", help="build the head from this admitted fold instead of HEAD_MANIFEST's tip "
                                  "(e.g. oracle_release_runtime_w363, the head a shipped verdict names)")
    ap.add_argument("--state", help="ORACLE7_STATE (default: a fresh dir under var/parity/state/, removed on exit)")
    a = ap.parse_args()
    if a.alone and not a.specialist:
        ap.error("--alone needs --specialist")

    # protocol replies go to the real stdout; anything the engine or an organ prints goes to stderr
    proto = os.fdopen(os.dup(1), "w", encoding="utf-8")
    os.dup2(2, 1)
    sys.stdout = sys.stderr

    os.environ.setdefault("ORACLE7_ROOT", str(UPSTREAM / "root"))
    if a.state:
        state, made_state = Path(a.state), None
    else:
        state = made_state = REPO / "var" / "parity" / "state" / ("o7-%d-%d" % (os.getpid(), time.time_ns()))
    state.resolve().relative_to(REPO / "var")  # never inside upstream
    os.environ["ORACLE7_STATE"] = str(state)
    # oracle7.py's module level sets the store environment and sys.path (wander-train, admitted folds) that organs
    # import from; it builds no engine. Imported first, as in the workbench, where the engine exists before any exam.
    o7 = _load("parity_upstream_oracle7", UPSTREAM / "oracle7.py")

    eng = None
    if not a.alone:
        eng = o7.Engine() if not a.tip else TipEngine(o7, a.tip)
        moved = redirect_self_loop(state / "self_loop")
        print("[oracle7 answerer] self_loop writes redirected: %s" % ", ".join(moved), file=sys.stderr, flush=True)
    sp = None
    if a.specialist:
        exam = _load("parity_upstream_exam", UPSTREAM / "workbench" / "exam.py")
        sp = loaded_class(exam)(Path(a.specialist).resolve())
        fillable = exam.fillable
        if a.compose in ("front", "combo") and not a.alone:
            gate = UPSTREAM / "root" / "specialists" / "_gate" / "combo_runtime_v1.py"
            combo_mod = _load("parity_upstream_combo_runtime_v1", gate)
            d = Path(a.specialist).resolve()
            sp = FrontComposed(sp, combo_mod.Combo([str(d / "manifest.json")], [str(d)]), parts=a.compose == "combo")
    if eng is not None:
        print("[oracle7 answerer] head %s%s" % (eng.tip, (" + " + sp.id) if sp else ""), file=sys.stderr, flush=True)

    try:
        for line in sys.stdin:
            if not line.strip():
                continue
            req = json.loads(line)
            rid, q, sess = req.get("id"), str(req.get("q", "")), str(req.get("session", "default"))
            try:
                out = answer(eng, sp, fillable if sp else None, q, sess, a.alone)
            except Exception as e:  # noqa: BLE001 - the harness records it and scores the item as withheld
                out = {"error": "%s: %s" % (type(e).__name__, e), "response": "", "path": ""}
            out["id"] = rid
            proto.write(json.dumps(_jsonable(out), ensure_ascii=False) + "\n")
            proto.flush()
    finally:
        if made_state is not None and made_state.exists():
            shutil.rmtree(made_state)


def loaded_class(exam):
    """exam.Loaded with the two loading steps the shipped folders need and exam.py lacks: the manifest's
    __ORACLE7_ROOT__ placeholder is substituted, and the organ is constructed with cwd in its folder, both as the
    release's _gate/combo_runtime_v1._Organ does (including its rule that an init path into specialists/ resolves to
    this folder when the file is here). exam.Loaded.reply, the accept rule, is inherited unchanged."""
    import re

    class ParityLoaded(exam.Loaded):
        def __init__(self, d):
            d = Path(d)
            root = os.environ["ORACLE7_ROOT"]
            m = json.loads((d / "manifest.json").read_text(encoding="utf-8").replace("__ORACLE7_ROOT__", root))
            self.id, self.m = m["id"], m
            if str(d) not in sys.path:
                sys.path.insert(0, str(d))
            init = dict(m["organ"].get("init", {}))
            for k, v in list(init.items()):
                if isinstance(v, str) and v.startswith(root + "/specialists/") and (d / os.path.basename(v)).exists():
                    init[k] = str(d / os.path.basename(v))
            name = "o7local_%s_%s" % (re.sub(r"\W", "_", m["id"]), exam.files_sha(d)[:8])
            cwd = os.getcwd()
            os.chdir(d)
            try:
                spec = importlib.util.spec_from_file_location(name, d / (m["organ"]["module"] + ".py"))
                mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(mod)
                self.organ = getattr(mod, m["organ"]["class"])(**init)
            finally:
                os.chdir(cwd)
            self.kinds = set(m["accept"]["kinds"])
            self.declines = set(m["accept"].get("declines_in_domain", []))
            self.ctx = re.compile(m["accept"].get("context_regex", r"(?!x)x"), re.I)
    return ParityLoaded


class FrontComposed:
    """the release's composition: the specialist (via combo_runtime_v1.Combo) in front, the head behind it. The head
    still answers every item so the head-alone counts come from the same pass."""

    def __init__(self, loaded, combo, parts):
        self.loaded, self.combo, self.id, self.parts = loaded, combo, loaded.id, parts

    def reply(self, text, session_id):
        if self.parts:
            return self.combo.reply(text, session_id)
        chosen, trace = self.combo._one(text, session_id)   # one organ: arbitration returns its reply ("only")
        if chosen is None:
            return None
        r = self.combo._wrap(chosen["response"], "specialist:%s>%s" % (chosen["id"], chosen["kind"]), status=chosen["status"],
                             spec=chosen["id"], move=chosen["kind"], trace=trace)
        r["provenance"]["declined"] = chosen["declined"]
        return r


class TipEngine:
    """oracle7.Engine with the head built from a named admitted fold (oracle7.load with the tip replaced): same
    single dedicated thread, same runtime constructor arguments"""

    def __init__(self, o7, tip):
        from concurrent.futures import ThreadPoolExecutor
        self._ex = ThreadPoolExecutor(max_workers=1, thread_name_prefix="oracle7")

        def load():
            o7.setup()
            mod = importlib.import_module(tip)
            want = "OracleReleaseRuntimeW" + tip.rsplit("_w", 1)[-1]
            name = want if hasattr(mod, want) else sorted(x for x in dir(mod) if x.startswith("OracleReleaseRuntimeW"))[-1]
            return tip, getattr(mod, name)(state_root=o7.STATE / "runtime", wikipedia_build=o7.PH / "m13e5_simplewiki_build_a_v1")
        self.tip, self._rt = self._ex.submit(load).result()

    def chat(self, text, session_id="default"):
        return self._ex.submit(self._rt.chat, text, session_id).result()


SELF_LOOP_FILES = ("vessels.json", "vessels_events.jsonl", "curriculum_requests.jsonl", "vessels.sqlite3")


def redirect_self_loop(dst):
    """The head's reception folds (w175 vessels.json / vessels_events.jsonl / curriculum_requests.jsonl, w480
    vessels.sqlite3) write next to the admitted modules, inside upstream/, in runtimes without the correctness repair
    (the old upstream/ checkout, head w540). They resolve those paths as module globals and open them lazily, so after
    the engine is built every such global that points into upstream is repointed into the answerer's state dir. The dir
    starts empty, which is the shipped state (the release carries none of these files).
    A runtime with the repair (upstream 10.0 and later) already resolves them under ORACLE7_STATE/vessels. Those are
    left alone and reported. The answerer refuses to start only when it finds no such path at all, or when one of them
    still lies inside upstream and cannot be moved."""
    dst.mkdir(parents=True, exist_ok=True)
    up = UPSTREAM.resolve()
    state = dst.resolve().parent
    moved, honoured = [], []
    for mname, mod in list(sys.modules.items()):
        f = getattr(mod, "__file__", None)
        if not f or up not in Path(f).resolve().parents:
            continue
        for k, v in list(vars(mod).items()):
            if not (isinstance(v, Path) and v.name in SELF_LOOP_FILES):
                continue
            rv = v.resolve()
            if up in rv.parents:
                setattr(mod, k, dst / v.name)
                moved.append("%s.%s" % (mname, k))
            elif state in rv.parents:
                honoured.append("%s.%s" % (mname, k))
    if not moved and not honoured:
        raise SystemExit("[oracle7 answerer] found no self_loop paths to redirect; refusing to write into upstream")
    if not moved:
        return ["none needed, the runtime already writes under ORACLE7_STATE: " + ", ".join(honoured)]
    return moved


def answer(eng, sp, fillable, q, sess, alone):
    if alone:
        t0 = time.perf_counter()
        r = sp.reply(q, sess)
        ms = 1000 * (time.perf_counter() - t0)
        if r is None:
            return {"status": "withheld", "response": "", "path": "", "provenance": {"specialist_ms": ms, "taken": False}}
        return {"status": r.get("status", "answered"), "response": r.get("response", ""), "path": r.get("path", ""),
                "kind": (r.get("provenance") or {}).get("move"), "provenance": {"specialist_ms": ms, "taken": True}}
    r = eng.chat(q, session_id=sess)
    head = {"status": r.get("status"), "response": r.get("response", ""), "path": r.get("path", "")}
    out = {"status": r.get("status"), "response": r.get("response", ""), "path": r.get("path", ""),
           "provenance": {"tip": eng.tip}}
    if r.get("references"):
        out["references"] = r.get("references")
    if sp is None:
        return out
    prov = {"tip": eng.tip, "head": head, "consulted": False, "specialist_ms": None}
    out["provenance"] = prov
    if isinstance(sp, FrontComposed):
        prov["compose"] = "combo" if sp.parts else "front"
        prov["consulted"] = True
        t0 = time.perf_counter()
        c = sp.reply(q, sess)
        prov["specialist_ms"] = 1000 * (time.perf_counter() - t0)
        if c is not None:
            return {"status": c.get("status", "answered"), "response": c.get("response", ""), "path": c.get("path", ""),
                    "kind": (c.get("provenance") or {}).get("move"), "provenance": prov}
        return out
    if r.get("status") != "answered" and fillable(r.get("path")):
        prov["consulted"] = True
        t0 = time.perf_counter()
        c = sp.reply(q, sess)
        prov["specialist_ms"] = 1000 * (time.perf_counter() - t0)
        if c is not None:
            return {"status": c.get("status", "answered"), "response": c.get("response", ""), "path": c.get("path", ""),
                    "kind": (c.get("provenance") or {}).get("move"), "provenance": prov}
    return out


if __name__ == "__main__":
    main()
