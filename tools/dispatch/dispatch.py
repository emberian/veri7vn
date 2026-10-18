#!/usr/bin/env python3
"""dispatch - veri7vn's single front door (docs/contracts/answerer.md): JSON lines in, one reply per line out.

UNTRUSTED glue. The dispatcher takes a question and routes it the way Oracle7's
released head does, using the verified family kernels as the organs:

  head order (--order head, the core panel's own route order, from lane B's
  catalogue of the released chain):
    1. the network (w508, a pre-route fold nearest the tip): the fusion
       answerer (tools/fusion/answerer.py over the MLton build of
       Fusion.fdecide). An answer returns as path "network><trace>" (Oracle7
       names the v2 network "network>" and the v3 network "network3>"; this
       build is v3 and uses "network>" for both - a named divergence). A
       VALIDITY decline ("26 hours a day", a negative length) withholds the
       turn exactly as w508 does and stops the cascade. Any other decline
       falls through.
    2. the specialists (w504's standing family, then w525's new family): every
       family binary is asked; the replies that took the turn go through the
       VERIFIED arbitration (var/dispatch/bin/arb_check, the MLton build of
       lane C's exported Arbitration.thy). The winning reply returns with path
       "specialist_call>" + the binary's own path. A Disagree shows both
       replies labelled, as combo_runtime_v1 does.
    3. the relation reader (lane F's answerer over the verified decide binary
       and relations_v1.sqlite3), the head's organ:relation route. Only asked
       when nothing above took the turn (it is the slowest organ).
    4. otherwise the turn is withheld, path "dispatch>declined".

  front order (--order front, the release's composition for a specialist's own
  exam - the organ in front of the head, which is the composition the shipped
  verdicts reproduce under): organs, then network, then reader.

What is verified here: the arbitration decision (Pick/Disagree/Fallthrough) is
made by the exported HOL function; every family reply's value comes from a
proved kernel. What is NOT: this file's reading of the turn (givens, wording,
answer values, declines, context matches - a port of combo_runtime_v1's
oracles), the stage order, and the fan-out plumbing. The counterfactual
dependence count re-asks the winning-candidate binaries with each given nudged
(+7%), as combo_runtime_v1._dependence does.

  dispatch.py [--var-root DIR] [--order head|front] [--organs a,b,c] [--no-reader]
              [--specialist ID[,ID]] [--arb PATH] [--timeout S] [--selftest]

--specialist ID says whose rules apply (a specialist's own exam): every family
binary that accepts `--specialist ID` is started with it, so it asks only that
manifest's organ; the other families run in family mode. Without it every
binary runs in family mode and a stem with several versions (astronomy-v3 and
astronomy-v3-r2) answers by the family's fixed order, so a panel for a
non-default version must name it. A family whose binary has no such flag
(acoustics) runs in family mode with a note on stderr; an ID that is no
shipped specialist at all is an error.

The dispatcher refuses to start (message on stderr naming the stage, exit 2)
when any stage's program is missing: a family binary, the fusion binary or its
answerer.py, the reader's answerer.py (unless --no-reader), or arb_check.

--var-root (default $VERI7VN_VAR, else /Users/ember/dev/o7vn/var): where the
family binaries live, as <var-root>/<slug>/bin/<slug>.
"""
from __future__ import annotations

import argparse
import json
import os
import queue
import re
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
WORKTREE_REPO = Path(__file__).resolve().parents[2]
MAIN_REPO = Path("/Users/ember/dev/o7vn")
UPSTREAM = Path(os.environ.get("PARITY_UPSTREAM", str(MAIN_REPO / "upstream")))

# ---------------------------------------------------------------- combo oracles
# Verbatim port of upstream/root/specialists/_gate/combo_runtime_v1.py's
# oracles (NUM, WORD, ASSUMED, CHECKED_DECLINE, CODE_SPAN, _givens, _perturb,
# _wording, _answer_value, _same_value, _last_sentence) and the READING guard.
# Untrusted by construction; the HOL arbitration takes their readings as inputs.
READING = re.compile(r"^\s*(?:Passage|Context|Article|Text)\s*:|\n\s*(?:Question|Options|Choices)\s*:|(?:^|\n)\s*\(?[A-J]\)\s+\S", re.I)
NUM = re.compile(r"(?<![\w.])-?\d+(?:,\d{3})*(?:\.\d+)?(?:e[+-]?\d+)?", re.I)
WORD = re.compile(r"[a-z0-9]+(?:[.'][a-z0-9]+)*")
ASSUMED = re.compile(r"\b(?:typical(?:ly)?|assum(?:e|ed|ing)|default|standard value)\b", re.I)
CHECKED_DECLINE = re.compile(r"impossible|out_of_range|invalid|cannot|contradict", re.I)
CODE_SPAN = re.compile(r"`[^`]*`|\"[^\"\n]*\"|(?<![A-Za-z])'[^'\n]*'")


def _is_float(s: str) -> bool:
    try:
        float(s.replace(",", ""))
        return True
    except ValueError:
        return False


def _same_value(a, b, rel=0.005) -> bool:
    if a is None or b is None:
        return a is None and b is None
    return abs(a - b) <= rel * max(abs(a), abs(b), 1e-12)


def _answer_value(resp: str, givens=()):
    gv = [float(g.group(0).replace(",", "")) for g in givens if _is_float(g.group(0))]
    for m in NUM.finditer(resp or ""):
        s = m.group(0).replace(",", "")
        if not _is_float(s):
            continue
        v = float(s)
        if any(_same_value(v, g, rel=1e-9) for g in gv):
            continue
        return v
    return None


def _givens(text: str) -> list:
    masked = CODE_SPAN.sub(lambda m: " " * len(m.group(0)), str(text))
    return list(NUM.finditer(masked))[:6]


def _perturb(text: str, m) -> str:
    s = m.group(0).replace(",", "")
    try:
        v = float(s)
    except ValueError:
        return text
    if re.fullmatch(r"-?\d+", s):
        nv = str(int(round(v * 1.07)) if abs(v) >= 15 else int(v) + 1)
    else:
        dec = len(s.split(".")[1]) if "." in s and "e" not in s.lower() else 3
        nv = ("%.*f" % (max(dec, 2), v * 1.07)) if "e" not in s.lower() else ("%.4g" % (v * 1.07))
    return text[:m.start()] + nv + text[m.end():]


def _wording(text: str, resp: str) -> tuple:
    q = WORD.findall(str(text).lower())
    r = " " + " ".join(WORD.findall(str(resp).lower())) + " "
    hits = [q[i:i + 3] for i in range(len(q) - 2) if " %s %s %s " % tuple(q[i:i + 3]) in r]
    return (sum(1 for h in hits if any(w[0].isdigit() for w in h)), len(hits))


def _last_sentence(text: str) -> str:
    parts = [p for p in re.split(r"(?<=[.?!])\s+", str(text).strip()) if p.strip()]
    return parts[-1] if parts else str(text)


# ---------------------------------------------------------------- manifests (read-only)
_MANIFESTS: dict = {}
_MAN_LOCK = threading.Lock()


def manifest(sid: str):
    """declines_in_domain + context_regex of a specialist, read-only from upstream"""
    with _MAN_LOCK:
        if sid not in _MANIFESTS:
            try:
                m = json.loads((UPSTREAM / "root" / "specialists" / sid / "manifest.json").read_text(encoding="utf-8"))
                acc = m.get("accept") or {}
                _MANIFESTS[sid] = {
                    "kinds": set(acc.get("kinds", [])),
                    "declines": set(acc.get("declines_in_domain", [])),
                    "ctx": re.compile(acc.get("context_regex", r"(?!x)x"), re.I),
                }
            except (OSError, ValueError, re.error):
                _MANIFESTS[sid] = {"declines": set(), "ctx": None}
    return _MANIFESTS[sid]


def specialist_of(path: str):
    """specialist:springs>force -> springs"""
    m = re.match(r"(?:specialist_call>)?specialist:([\w.\-]+)>", str(path or ""))
    return m.group(1) if m else None


# ---------------------------------------------------------------- child processes
class Child:
    """one answerer subprocess speaking JSON lines; a reply that does not arrive in time restarts it"""

    def __init__(self, name, argv, timeout, log_dir):
        self.name, self.argv, self.timeout = name, argv, timeout
        self.p, self.q = None, None
        self.lock = threading.Lock()
        self.deaths = 0
        self.log = open(log_dir / ("%s.stderr" % name), "a", encoding="utf-8")

    def _start(self):
        self.p = subprocess.Popen(self.argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.log,
                                  text=True, encoding="utf-8", bufsize=1)
        self.q = queue.Queue()

        def pump():
            try:
                for line in self.p.stdout:
                    self.q.put(line)
            finally:
                self.q.put(None)
        threading.Thread(target=pump, daemon=True).start()

    def ask(self, rid, text, session, timeout=None):
        """-> reply dict, or {"error": ...}; never raises"""
        timeout = timeout or self.timeout
        with self.lock:
            if self.deaths >= 3:
                return {"error": "%s exited 3 times without replying" % self.name}
            if self.p is None or self.p.poll() is not None:
                try:
                    self._start()
                except OSError as e:
                    return {"error": "%s: %s" % (self.name, e)}
            try:
                self.p.stdin.write(json.dumps({"id": rid, "q": text, "session": session}, ensure_ascii=False) + "\n")
                self.p.stdin.flush()
            except (BrokenPipeError, OSError) as e:
                self._close()
                return {"error": "%s pipe: %s" % (self.name, e)}
            deadline = time.monotonic() + timeout
            while True:
                try:
                    line = self.q.get(timeout=max(0.01, min(1.0, deadline - time.monotonic())))
                except queue.Empty:
                    if time.monotonic() >= deadline:
                        self._close(kill=True)
                        return {"error": "%s timeout after %ss" % (self.name, timeout)}
                    continue
                if line is None:
                    self._close()
                    self.deaths += 1
                    return {"error": "%s exited" % self.name}
                try:
                    r = json.loads(line)
                except ValueError:
                    continue
                if r.get("id") != rid:
                    continue
                self.deaths = 0
                return r

    def _close(self, kill=False):
        p, self.p = self.p, None
        if p is None:
            return
        try:
            if kill:
                p.kill()
            else:
                p.stdin.close()
            p.wait(timeout=30)
        except Exception:  # noqa: BLE001
            p.kill()
            p.wait()

    def close(self):
        with self.lock:
            self._close()


# ---------------------------------------------------------------- the arbitration binary
SCALE = 10 ** 6


class Arb:
    """the verified rule: var/dispatch/bin/arb_check (arb_driver.sml over Veri7vn_Gate).
    Speaks its own one-line text protocol, not the answerer contract."""

    def __init__(self, path):
        self.lock = threading.Lock()
        self.p = subprocess.Popen([str(path)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  text=True, encoding="utf-8")

    def decide(self, g, cands):
        """cands: list of dicts with declined,checked,dep,assumed,wording,ctx,val; -> ('PICK',i)|('DISAGREE',a,b)|('FALLTHROUGH',None)"""
        fields = [str(int(g))]
        for c in cands:
            v = c["val"]
            fields += [str(c["ix"]), str(int(c["declined"])), str(int(c["checked"])), str(int(c["dep"])),
                       str(int(c["assumed"])), str(c["wording"][0]), str(c["wording"][1]),
                       str(int(c["ctx"])), "?" if v is None else str(int(round(v * SCALE)))]
        with self.lock:
            self.p.stdin.write(" ".join(fields) + "\n")
            self.p.stdin.flush()
            line = self.p.stdout.readline()
        out = line.split()
        if out and out[0] == "PICK":
            return ("PICK", int(out[1]))
        if out and out[0] == "DISAGREE":
            return ("DISAGREE", (int(out[1]), int(out[2])))
        if out and out[0] == "FALLTHROUGH":
            return ("FALLTHROUGH", None)
        raise RuntimeError("arb_check said %r" % line)

    def close(self):
        try:
            self.p.stdin.close()
            self.p.wait(timeout=10)
        except Exception:  # noqa: BLE001
            self.p.kill()
            self.p.wait()


# ---------------------------------------------------------------- the dispatcher
DISAGREE_FMT = ("Two of the specialists read this differently, so I won't pick one silently. "
                "%s says: %s %s says: %s")


# ---------------------------------------------------------------- start-up checks
def stage_programs(args, var, slugs):
    """[(stage, path)] for every program a turn can need"""
    progs = [("specialists:%s" % s, var / s / "bin" / s) for s in slugs]
    progs += [("network (fusion binary)", var / "fusion" / "bin" / "fusion"),
              ("network (fusion answerer)", REPO / "tools" / "fusion" / "answerer.py"),
              ("arbitration (arb_check)", Path(args.arb))]
    if not args.no_reader:
        progs.append(("reader", MAIN_REPO / "tools" / "reader" / "answerer.py"))
    return progs


def preflight(args, var):
    """refuse to start when a stage's program is missing (a copy without tools/fusion/ once
    lost the whole network stage silently, 58 answers, with the error only in a log)"""
    if args.organs:
        slugs = [s for s in args.organs.split(",") if s]
    else:
        slugs = sorted(p.name for p in var.iterdir() if p.is_dir() and p.name not in Dispatcher.EXCLUDE_SLUGS
                       and (p / "bin" / p.name).is_file() and os.access(p / "bin" / p.name, os.X_OK))
    missing = [(st, p) for st, p in stage_programs(args, var, slugs) if not p.is_file()]
    if not slugs:
        missing.append(("specialists (no family binary under %s)" % var, var / "<slug>" / "bin" / "<slug>"))
    for st, p in missing:
        sys.stderr.write("dispatch: stage %s is missing its program: %s\n" % (st, p))
    if missing:
        sys.exit(2)


def _probe(binp, sid):
    try:
        r = subprocess.run([str(binp), "--specialist", sid], input='{"id": "probe", "q": "", "session": "p"}\n',
                           capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return r.returncode == 0 and '"probe"' in r.stdout


def accepts_specialist(binp, sid):
    """True when the family binary honours `--specialist sid`: it starts and answers a probe line
    for sid, and exits non-zero for an id that does not exist (a binary that ignores its
    arguments, as acoustics does, would accept anything and is not pinned)"""
    return _probe(binp, sid) and not _probe(binp, "no-such-specialist")


def pin_specialists(var, slugs, spec):
    """{slug: id} for the families that accept --specialist id; exits 2 if some id has no family"""
    pins = {}
    for sid in [x for x in (spec or "").split(",") if x]:
        owners = [s for s in slugs if s not in pins and accepts_specialist(var / s / "bin" / s, sid)]
        if not owners:
            if (UPSTREAM / "root" / "specialists" / sid / "manifest.json").is_file():
                sys.stderr.write("dispatch: note: no family binary takes --specialist %s; "
                                 "its family runs in family mode\n" % sid)
                continue
            sys.stderr.write("dispatch: no specialist %s (no manifest, no family binary accepts it)\n" % sid)
            sys.exit(2)
        for s in owners:
            pins[s] = sid
    return pins


class Dispatcher:
    EXCLUDE_SLUGS = {"fusion"}                 # the network stage, not an organ

    def __init__(self, args):
        self.order = args.order
        var = Path(args.var_root)
        preflight(args, var)
        log_dir = REPO / "var" / "dispatch" / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        if args.organs:
            slugs = [s for s in args.organs.split(",") if s]
        else:
            slugs = sorted(p.name for p in var.iterdir()
                           if p.is_dir() and (p / "bin" / p.name).is_file()
                           and os.access(p / "bin" / p.name, os.X_OK)
                           and p.name not in self.EXCLUDE_SLUGS)
        self.organs = []                       # (Child, slug) for the family binaries
        pins = pin_specialists(var, slugs, args.specialist)
        self.pinned = set(pins)                # slugs started with --specialist (front order asks them alone first)
        for slug in slugs:
            binp = var / slug / "bin" / slug
            argv = [str(binp)] + (["--specialist", pins[slug]] if slug in pins else [])
            self.organs.append((Child(slug, argv, args.timeout, log_dir), slug))
        self.fusion = Child("fusion",
                            [sys.executable, str(REPO / "tools" / "fusion" / "answerer.py"),
                             "--binary", str(var / "fusion" / "bin" / "fusion")],
                            max(args.timeout, 30.0), log_dir)
        self.reader = None if args.no_reader else Child(
            "reader", [sys.executable, str(MAIN_REPO / "tools" / "reader" / "answerer.py")],
            max(args.timeout, 120.0), log_dir)
        self.arb = Arb(Path(args.arb))
        self.pool = ThreadPoolExecutor(max_workers=max(8, len(self.organs) + 2))
        self.n = 0

    # -- stages
    def fan_out(self, text, session, rid, organs, timeout=None):
        """ask every family binary in parallel; -> {slug: reply}"""
        futs = {slug: self.pool.submit(lambda ch=ch: ch.ask(rid, text, session, timeout)) for ch, slug in organs}
        return {slug: f.result() for slug, f in futs.items()}

    def ask_fusion(self, text, session, rid):
        r = self.fusion.ask(rid, text, session)
        if "error" in r:
            return None, r
        p = str(r.get("path", ""))
        if r.get("status") == "answered" and p.startswith("veri7vn:fusion>") and "validity" not in p:
            out = dict(r)
            out["path"] = "network>" + p[len("veri7vn:fusion>"):]
            return out, r
        if p.endswith("validity"):
            return {"status": "withheld", "response": r.get("response", ""), "path": "network>validity",
                    "provenance": {"stage": "network", "kind": "validity_stop"}}, r
        return None, r                            # declined: fall through

    def organ_cands(self, text, session, rid, replies):
        """the organs that took the turn, as arbitration candidates"""
        cands = []
        for child, slug in self.organs:
            r = replies.get(slug)
            if not r or "error" in r:
                continue
            prov = r.get("provenance") if isinstance(r.get("provenance"), dict) else {}
            if not prov.get("taken"):
                continue                          # the organ did not take the turn
            sid = specialist_of(r.get("path", "")) or slug
            man = manifest(sid)
            kind = str(r.get("kind", ""))
            ctx_hit = man["ctx"] is None or bool(man["ctx"].search(text))
            # the manifest accept rule of combo_runtime_v1._Organ.reply: the reply counts
            # only when its kind is one the specialist answers, or it is an in-domain
            # decline whose context matches the turn (a binary's own "taken" is not enough)
            declined = r.get("status") != "answered" and kind in man["declines"] and ctx_hit
            if kind not in man["kinds"] and not declined:
                continue
            cands.append({"ix": len(cands), "slug": slug, "child": child, "sid": sid, "reply": r, "declined": bool(declined),
                          "kind": kind, "checked": bool(declined and CHECKED_DECLINE.search(kind + " " + str(r.get("response", "")))),
                          "assumed": bool(ASSUMED.search(str(r.get("response", "")))),
                          "ctx": bool(man["ctx"] and man["ctx"].search(_last_sentence(text)))})
        return cands

    @staticmethod
    def _dep(child, reply, text, givens, rid):
        """counterfactual dependence: nudge each given, re-ask, count moves (combo_runtime_v1._dependence)"""
        base_v = _answer_value(reply.get("response", ""), givens)
        dep = 0
        for k, m in enumerate(givens):
            alt = child.ask("%s-dep%d" % (rid, k), _perturb(text, m), "counterfactual")
            if "error" in alt:
                dep += 1
                continue
            prov = alt.get("provenance") if isinstance(alt.get("provenance"), dict) else {}
            if not prov.get("taken"):
                dep += 1                          # the nudge changed whether it takes the turn at all
            elif alt.get("kind") != reply.get("kind") or alt.get("status") != reply.get("status"):
                dep += 1
            elif base_v is None:
                dep += alt.get("response", "") != reply.get("response", "")
            elif not _same_value(base_v, _answer_value(alt.get("response", ""), _givens(_perturb(text, m))), rel=1e-4):
                dep += 1
        return dep

    def arbitrate(self, text, session, rid, cands):
        """-> final reply dict for the specialist stage; the decision is the exported HOL rule's"""
        givens = _givens(text)
        g = len(givens)
        for c in cands:
            c["wording"] = _wording(text, c["reply"].get("response", ""))
            c["val"] = None if c["declined"] else _answer_value(c["reply"].get("response", ""), givens)
        # the agreement shortcut and the single-candidate case need no counterfactuals; faithful
        # mirrors of the HOL rule (HOL re-decides anyway - if a mirror says yes, the binary's
        # own shortcut/single case fires too and the keys are never compared)
        answers = [c for c in cands if not c["declined"]]
        shortcut = len(cands) == 1 or (
            len(answers) >= 2 and answers[0]["val"] is not None
            and all(_same_value(answers[0]["val"], a["val"]) for a in answers[1:]))
        if not shortcut and givens:
            for c in cands:
                c["dep_raw"] = self._dep(c["child"], c["reply"], text, givens, rid)
        else:
            for c in cands:
                c["dep_raw"] = 0
        for c in cands:
            c["dep"] = g if (c["declined"] and c["checked"]) else (c["dep_raw"] if g else 0)
        rule, arg = self.arb.decide(g, cands)
        if rule == "PICK":
            r = dict(cands[arg]["reply"])
            r["path"] = "specialist_call>" + str(r.get("path", ""))
            r.setdefault("provenance", {})["dispatch"] = {"stage": "specialists", "rule": "arbitrate",
                                                          "cands": [c["sid"] for c in cands]}
            return r
        if rule == "DISAGREE":
            a, b = cands[arg[0]], cands[arg[1]]
            ra, rb = a["reply"], b["reply"]
            text_out = DISAGREE_FMT % (a["sid"], ra.get("response", ""), b["sid"], rb.get("response", ""))
            return {"status": "withheld", "response": text_out,
                    "path": "specialist_call>disagree>%s|%s" % (a["sid"], b["sid"]),
                    "provenance": {"dispatch": {"stage": "specialists", "rule": "disagree",
                                                "cands": [c["sid"] for c in cands]}}}
        return None

    def organs_stage(self, text, session, rid):
        """-> (answered reply | None, in-domain decline fallback | None): an organ's ANSWER
        or a Disagree ends the turn; an in-domain decline is kept as the fallback while the
        head's own routes (the reader) still get the turn, exactly as the released cascade
        continues past a family decline to organ:relation."""
        organs = self.organs
        fallback = None
        if self.order == "front" and self.pinned:
            # the release's exam composition: the pinned specialist alone first; only when it
            # does not answer does the rest of the cascade (the other families through the
            # arbitration, then network, reader) get the turn. Arbitration is untouched.
            first = [(ch, sl) for ch, sl in self.organs if sl in self.pinned]
            organs = [(ch, sl) for ch, sl in self.organs if sl not in self.pinned]
            out, fallback, replies = self._arbitrated(text, session, rid, first)
            if out is not None:
                return out, None, replies
        out, dec, replies = self._arbitrated(text, session, rid, organs)
        return out, dec or fallback, replies

    def _arbitrated(self, text, session, rid, organs):
        replies = self.fan_out(text, session, rid, organs)
        cands = self.organ_cands(text, session, rid, replies)
        if not cands:
            return None, None, replies
        out = self.arbitrate(text, session, rid, cands)
        if out is None:
            return None, None, replies
        if out.get("status") == "answered" or ">disagree>" in str(out.get("path", "")):
            return out, None, replies
        return None, out, replies

    def reader_stage(self, text, session, rid):
        if self.reader is None:
            return None
        r = self.reader.ask(rid, text, session)
        if "error" in r or r.get("status") != "answered":
            return None
        return r

    # -- one turn
    def turn(self, rid, text, session):
        t0 = time.perf_counter()
        ms = {}
        out = None
        stages = []
        if READING.search(str(text or "")):
            out = {"status": "withheld", "response": "", "path": "dispatch>declined:reading"}
            stages.append("reading_guard")
        head_first = self.order == "head"

        def net():
            t = time.perf_counter()
            o, raw = self.ask_fusion(text, session, rid)
            ms["network"] = round(1000 * (time.perf_counter() - t), 3)
            return o

        def specs():
            t = time.perf_counter()
            o, dec, _ = self.organs_stage(text, session, rid)
            ms["specialists"] = round(1000 * (time.perf_counter() - t), 3)
            return o, dec

        def rel():
            t = time.perf_counter()
            o = self.reader_stage(text, session, rid)
            ms["reader"] = round(1000 * (time.perf_counter() - t), 3)
            return o

        fallback = None
        seq = ([net, specs, rel] if head_first else [specs, net, rel]) if out is None else []
        for stage in seq:
            r = stage()
            if stage is specs:
                out, fallback = r
            else:
                out = r
            stages.append(stage.__name__)
            if out is not None:
                break
        if out is None:
            out = fallback or {"status": "withheld", "response": "", "path": "dispatch>declined"}
        prov = out.get("provenance") if isinstance(out.get("provenance"), dict) else {}
        prov["dispatch"] = {**(prov.get("dispatch") or {}), "stages_run": stages,
                            "ms": dict(ms, total=round(1000 * (time.perf_counter() - t0), 3))}
        out["provenance"] = prov
        out["id"] = rid
        return out

    def close(self):
        for ch, _ in self.organs:
            ch.close()
        self.fusion.close()
        if self.reader:
            self.reader.close()
        self.arb.close()


SELFTEST = [
    # (givens, cands, expected) - cases from Specialists_Tests.thy and combo_runtime_v1
    dict(g=0, cands=[dict(ix=0, declined=0, checked=0, dep=0, assumed=0, wording=(0, 0), ctx=0, val=None),
                     dict(ix=1, declined=0, checked=0, dep=0, assumed=0, wording=(0, 0), ctx=0, val=None)],
         want="PICK 0"),                                     # single answer among two none-valued: first
    dict(g=2, cands=[dict(ix=0, declined=0, checked=0, dep=2, assumed=0, wording=(0, 3), ctx=1, val=75.0),
                     dict(ix=1, declined=0, checked=0, dep=1, assumed=1, wording=(1, 3), ctx=0, val=75.4)],
         want="PICK 0"),                                     # more givens used wins (agree within 0.5%)
    dict(g=0, cands=[dict(ix=0, declined=1, checked=1, dep=0, assumed=0, wording=(0, 0), ctx=1, val=None),
                     dict(ix=1, declined=0, checked=0, dep=0, assumed=0, wording=(0, 0), ctx=0, val=7.0)],
         want="PICK 0"),                                     # a checked in-domain decline beats a foreign answer
    dict(g=0, cands=[dict(ix=0, declined=0, checked=0, dep=0, assumed=0, wording=(0, 0), ctx=0, val=100.0),
                     dict(ix=1, declined=0, checked=0, dep=0, assumed=0, wording=(0, 0), ctx=0, val=100.8)],
         want="DISAGREE 0 1"),                               # tied, answers, values differ by > 0.5%
    dict(g=0, cands=[], want="FALLTHROUGH"),
]


def selftest(arb_path):
    arb = Arb(Path(arb_path))
    ok = True
    for case in SELFTEST:
        got = arb.decide(case["g"], [dict(c) for c in case["cands"]])
        got_s = "%s %d" % (got[0], got[1]) if isinstance(got[1], int) else \
            ("%s %d %d" % (got[0], got[1][0], got[1][1]) if got[1] else got[0])
        good = got_s.split()[0] == case["want"].split()[0]
        print("%s want=%-14s got=%s" % ("ok " if good else "FAIL", case["want"], got_s))
        ok = ok and good
    arb.close()
    return ok


def main():
    ap = argparse.ArgumentParser(description="veri7vn dispatcher (untrusted glue; see module docstring)")
    ap.add_argument("--var-root", default=os.environ.get("VERI7VN_VAR", "/Users/ember/dev/o7vn/var"))
    ap.add_argument("--order", choices=["head", "front"], default="head")
    ap.add_argument("--organs", help="comma-separated slugs (default: every var/<slug>/bin/<slug> found)")
    ap.add_argument("--no-reader", action="store_true")
    ap.add_argument("--specialist", default="",
                    help="whose rules apply: pass --specialist ID to every family binary that accepts it")
    ap.add_argument("--arb", default=str(REPO / "var" / "dispatch" / "bin" / "arb_check"))
    ap.add_argument("--timeout", type=float, default=10.0, help="seconds per organ reply")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(0 if selftest(a.arb) else 1)
    d = Dispatcher(a)
    try:
        for line in sys.stdin:
            if not line.strip():
                continue
            req = json.loads(line)
            rid, q, sess = req.get("id"), str(req.get("q", "")), str(req.get("session", "default"))
            try:
                out = d.turn(rid, q, sess)
            except Exception as e:  # noqa: BLE001 - one broken turn never costs the process
                out = {"id": rid, "error": "dispatch: %s: %s" % (type(e).__name__, e), "response": "", "path": ""}
            sys.stdout.write(json.dumps(out, ensure_ascii=False, default=str) + "\n")
            sys.stdout.flush()
    finally:
        d.close()


if __name__ == "__main__":
    main()
