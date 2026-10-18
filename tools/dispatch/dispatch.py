#!/usr/bin/env python3
"""JSONL front door around extracted kernels. UNTRUSTED glue.

The explicit runtime registry names specialist owners and non-specialist stages.
The shared capability contract accepts upstream kinds plus reviewed extensions.
An accepted in-domain refusal selected by arbitration ends the turn; an organ
that did not take the question falls through. This deliberately repairs the old
composition which could overwrite a correct refusal with a later answer.

Recognition, manifest matching, stage order, numeric readings used to arbitrate,
and evidence presentation are untrusted. A listed theorem is a kernel-level
claim with assumptions, not proof that this particular question was understood.
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
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
WORKTREE_REPO = Path(__file__).resolve().parents[2]
MAIN_REPO = REPO
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / "tools"))
from runtime_contract import load_registry, acceptance, capability_for, validate_capabilities, enforce_reply_evidence  # noqa: E402
sys.path.insert(0, str(Path(__file__).resolve().parent))
from routes import RouteStages, stage_programs as route_programs  # noqa: E402
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
            acc = acceptance(REPO, UPSTREAM, sid)
            _MANIFESTS[sid] = {
                "kinds": set(acc.get("kinds", [])),
                "declines": set(acc.get("declines_in_domain", [])),
                "ctx": re.compile(acc.get("context_regex", r"(?!x)x"), re.I),
                "declaration": capability_for(REPO, sid).get("evidence", {}),
            }
    return _MANIFESTS[sid]


def specialist_of(path: str):
    """specialist:springs>force -> springs"""
    m = re.match(r"(?:specialist_call>)?specialist:([\w.\-]+)>", str(path or ""))
    return m.group(1) if m else None


def reply_shape_error(reply):
    """Reject malformed metadata; it must never become a no-take fallthrough."""
    if not isinstance(reply, dict):
        return "reply must be an object"
    if "provenance" in reply and not isinstance(reply["provenance"], dict):
        return "provenance must be an object"
    if "evidence" in reply and not isinstance(reply["evidence"], dict):
        return "evidence must be an object"
    # The answerer contract treats every status other than "answered" as
    # non-answering; shipped organs use both "clarify" and "clarification".
    if "error" not in reply and not isinstance(reply.get("status"), str):
        return "status must be a string"
    for field in ("response", "path", "kind"):
        if field in reply and not isinstance(reply[field], str):
            return field + " must be a string"
    provenance = reply.get("provenance", {})
    if "taken" in provenance and type(provenance["taken"]) is not bool:
        return "provenance.taken must be boolean"
    if "evidence" in provenance and not isinstance(provenance["evidence"], dict):
        return "provenance.evidence must be an object"
    return None


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

        proc, replies = self.p, self.q
        def pump():
            try:
                for line in proc.stdout:
                    replies.put(line)
            finally:
                replies.put(None)
        threading.Thread(target=pump, daemon=True).start()

    def ask(self, rid, text, session, timeout=None):
        """-> reply dict, or {"error": ...}; never raises"""
        return self.ask_payload({"id": rid, "q": text, "session": session}, timeout)

    def ask_payload(self, request, timeout=None):
        """Send a complete stage-specific request; only its matching reply is read."""
        rid = request.get("id")
        timeout = self.timeout if timeout is None else timeout
        with self.lock:
            if self.deaths >= 3:
                return {"error": "%s exited 3 times without replying" % self.name}
            if self.p is None or self.p.poll() is not None:
                try:
                    self._start()
                except OSError as e:
                    return {"error": "%s: %s" % (self.name, e)}
            try:
                self.p.stdin.write(json.dumps(request, ensure_ascii=False) + "\n")
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
                    return {"error": "%s returned invalid JSON" % self.name}
                if not isinstance(r, dict):
                    return {"error": "%s reply must be an object" % self.name}
                if r.get("id") != rid:
                    continue
                problem = reply_shape_error(r)
                if problem:
                    return {"error": "%s: %s" % (self.name, problem)}
                self.deaths = 0
                return r

    def _close(self, kill=False):
        p, self.p = self.p, None
        if p is None:
            return
        try:
            if kill:
                # Give adapters a chance to close their own recorded kernel
                # processes before forcing this recorded child to stop.
                p.terminate()
            else:
                p.stdin.close()
            p.wait(timeout=2 if kill else 10)
        except (subprocess.TimeoutExpired, BrokenPipeError, OSError):
            p.kill()
            p.wait()
        finally:
            for stream in (p.stdin, p.stdout):
                if stream is not None:
                    stream.close()

    def close(self):
        with self.lock:
            self._close()
            self.log.close()


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
        finally:
            self.p.stdin.close()
            self.p.stdout.close()


# ---------------------------------------------------------------- the dispatcher
STATE_TRANSITION_KINDS = frozenset({"confirm", "ordered", "cancelled"})

DISAGREE_FMT = ("Two of the specialists read this differently, so I won't pick one silently. "
                "%s says: %s %s says: %s")


# ---------------------------------------------------------------- start-up checks
def selected_families(args):
    """Only explicit specialist entries can participate in the family fan-out."""
    registered = {e["family"]: e for e in load_registry(REPO) if e["role"] == "specialist"}
    names = [s for s in args.organs.split(",") if s] if args.organs else list(registered)
    unknown = [s for s in names if s not in registered]
    if unknown:
        raise ValueError("not registered specialist families: " + ", ".join(unknown))
    if len(names) != len(set(names)):
        raise ValueError("duplicate family in --organs")
    return [registered[name] for name in names]


def binary_path(var, entry):
    """Relocate the registry's var-relative binary under --var-root."""
    return var / Path(entry["binary"]).relative_to("var")


def enabled_routes(args):
    if getattr(args, "no_routes", False):
        return []
    return [e["family"] for e in load_registry(REPO)
            if e["role"] in {"math", "word_problem", "guard"}]


def enabled_stage(args, role):
    flag = "no_reader" if role == "relation" else "no_document"
    return not getattr(args, flag, False) and any(e["role"] == role for e in load_registry(REPO))


def stage_programs(args, var, entries):
    progs = [("specialists:" + e["family"], binary_path(var, e)) for e in entries]
    progs += [("network (fusion binary)", var / "fusion/bin/fusion"),
              ("network (fusion answerer)", REPO / "tools/fusion/answerer.py"),
              ("arbitration (arb_check)", Path(args.arb))]
    progs.extend(route_programs(REPO, var, enabled_routes(args)).items())
    if enabled_stage(args, "relation"):
        progs.append(("reader", REPO / "tools/relations/frontdoor.py"))
        progs.append(("reader kernel", var / "relations/bin/decide"))
    if enabled_stage(args, "document"):
        progs.append(("document", REPO / "tools/document/answerer.py"))
        progs.append(("document kernel", var / "document/bin/document"))
        progs.append(("document Python environment", Path(args.adapter_python)))
    return progs


def preflight(args, var, entries=None):
    validate_capabilities(REPO)
    entries = selected_families(args) if entries is None else entries
    for entry in entries:
        for sid in entry["specialists"]:
            manifest(sid)
    missing = [(st, p) for st, p in stage_programs(args, var, entries) if not p.is_file()]
    if not entries:
        raise ValueError("no specialist families selected")
    if missing:
        raise ValueError("; ".join("stage %s is missing its program: %s" % pair for pair in missing))
    return entries


def pin_specialists(entries, spec):
    """Resolve specialist ownership from the registry without executing probe turns."""
    owners = {sid: e for e in entries for sid in e["specialists"]}
    pins = {}
    for sid in [x for x in (spec or "").split(",") if x]:
        if sid not in owners:
            raise ValueError("specialist %s has no selected registered family" % sid)
        entry = owners[sid]
        family = entry["family"]
        if family in pins and pins[family] != sid:
            raise ValueError("cannot pin two specialists in family %s in one process" % family)
        pins[family] = sid
    return pins


def effectful_selection(entries, pins, order):
    """An effectful organ cannot run speculatively against competing candidates.

    Pinned stores use a private preview/commit pair. Unpinned stores can only
    preview. Other families remain available if the pinned organ does not take
    the turn.
    """
    effectful = {e["family"] for e in entries if e.get("state_flag")}
    selected = effectful & pins.keys()
    if selected and (order != "front" or len(pins) != 1):
        raise ValueError("stateful specialists require --order front and exactly one --specialist")
    previewable = {e["family"] for e in entries if e.get("preview_flag")}
    if selected - previewable:
        raise ValueError("stateful pin requires a registered preview protocol")
    skipped = effectful - selected - previewable
    return [e for e in entries if e["family"] not in skipped], sorted(skipped)


class Dispatcher:
    def __init__(self, args):
        self.order = args.order
        var = Path(args.var_root)
        entries = preflight(args, var)
        self.entries = {e["family"]: e for e in entries}
        log_dir = var / "dispatch" / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        self.organs = []
        pins = pin_specialists(entries, args.specialist)
        self.pins = pins
        self.pinned = set(pins)
        active_entries, self.stateful_not_selected = effectful_selection(entries, pins, self.order)
        self.preview_families = {e["family"] for e in active_entries if e.get("state_flag")}
        self.commit_organs = {}
        self.turn_lock = threading.Lock()
        for slug in self.stateful_not_selected:
            sys.stderr.write("dispatch: %s needs a sole --specialist pin with --order front; "
                             "not executed speculatively\n" % slug)
        for entry in active_entries:
            slug = entry["family"]
            argv = [str(binary_path(var, entry))]
            if slug in pins and entry.get("specialist_flag"):
                argv += ["--specialist", pins[slug]]
            if entry.get("state_flag"):
                state_dir = var / "dispatch/state"
                state_dir.mkdir(parents=True, exist_ok=True)
                argv += ["--state", str(state_dir / (slug + "-" + uuid.uuid4().hex + ".json"))]
                if slug in pins:
                    self.commit_organs[slug] = Child(slug + "-commit", list(argv), args.timeout, log_dir)
                argv += ["--preview"]
            self.organs.append((Child(slug, argv, args.timeout, log_dir), slug))
        self.fusion = Child("fusion",
                            [sys.executable, "-B", str(REPO / "tools" / "fusion" / "answerer.py"),
                             "--binary", str(var / "fusion" / "bin" / "fusion")],
                            max(args.timeout, 30.0), log_dir)
        self.reader = None if not enabled_stage(args, "relation") else Child(
            "reader", [sys.executable, "-B", str(REPO / "tools/relations/frontdoor.py"),
                       "--binary", str(var / "relations/bin/decide")],
            max(args.timeout, 120.0), log_dir)
        self.document = None if not enabled_stage(args, "document") else Child(
            "document", [args.adapter_python, "-B", str(REPO / "tools/document/answerer.py"),
                         "--binary", str(var / "document/bin/document")],
            max(args.timeout, 30.0), log_dir)
        self.route_names = set(enabled_routes(args))
        self.routes = RouteStages(REPO, var, args.timeout, log_dir, Child, self.route_names)
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
            return {"status": "withheld", "response": "", "path": "dispatch>network_error",
                    "error": r["error"]}, r
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
            sid = specialist_of(r.get("path", ""))
            if sid not in self.entries[slug]["specialists"]:
                continue
            if slug in self.pins and sid != self.pins[slug]:
                continue
            man = manifest(sid)
            kind = str(r.get("kind", ""))
            # A CLI specialist pin supplies explicit domain context. A family
            # filter alone does not: the family can contain unrelated readers.
            explicit_pin = self.pins.get(slug) == sid
            declined = r.get("status") != "answered"
            pin_context = explicit_pin and declined
            question_context = man["ctx"] is None or bool(man["ctx"].search(text))
            ctx_hit = pin_context or question_context
            # Loaded.reply and Combo's _Organ.reply admit declared normal kinds
            # regardless of status. Refusing a recognized operation must not
            # turn it into fallthrough merely because its kind stayed the same.
            if kind not in man["kinds"] and not (kind in man["declines"] and ctx_hit):
                continue
            cands.append({"ix": len(cands), "slug": slug, "child": child, "sid": sid, "reply": r, "declined": bool(declined),
                          "kind": kind, "checked": bool(declined and CHECKED_DECLINE.search(kind + " " + str(r.get("response", "")))),
                          "assumed": bool(ASSUMED.search(str(r.get("response", "")))),
                          "context_source": ("not_required" if kind in man["kinds"] else
                                             "explicit_specialist_pin" if pin_context else "question"),
                          "ctx": bool((declined and kind in man["declines"] and explicit_pin) or
                                      (man["ctx"] and man["ctx"].search(_last_sentence(text))))})
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
        for candidate in cands:
            problem = reply_shape_error(candidate["reply"])
            if problem:
                return {"status": "withheld", "response": "", "path": "dispatch>specialist_error",
                        "error": problem}
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
                if self.entries[c["slug"]].get("state_flag"):
                    # A hypothetical warehouse order changes state. Do not execute it
                    # merely to rank an answer against another specialist.
                    c["dep_raw"] = 0
                    c["dependence_unavailable"] = "stateful organ"
                else:
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
            provenance = dict(r.get("provenance") or {})
            provenance["dispatch"] = {"stage": "specialists", "rule": "arbitrate",
                                      "cands": [c["sid"] for c in cands],
                                      "acceptance_context": cands[arg].get("context_source", "not_recorded")}
            if any(c.get("dependence_unavailable") for c in cands):
                provenance["dispatch"]["dependence_unavailable"] = [
                    c["sid"] for c in cands if c.get("dependence_unavailable")]
            declaration = manifest(cands[arg]["sid"])["declaration"]
            provenance["evidence"] = {
                **(provenance.get("evidence") or {}),
                "declaration_scope": "registered kernel capabilities; not a checked proof of this question's interpretation",
                "untrusted": ["question recognition", "dispatch composition", "answer rendering"],
                **({"declaration": declaration} if declaration else {}),
            }
            if (self.entries[cands[arg]["slug"]].get("state_flag") and
                    provenance.get("preview") is False and
                    r.get("kind") in STATE_TRANSITION_KINDS):
                provenance["dispatch"]["state_transition_report"] = r["kind"]
            r["provenance"] = provenance
            r = enforce_reply_evidence(r)
            if provenance.get("preview") is True:
                if cands[arg]["slug"] in getattr(self, "commit_organs", {}):
                    if r.get("status") == "answered":
                        # A pinned read also retains its conversation reference.
                        # It still writes only after the preview passes guards.
                        r["provenance"]["dispatch"]["commit_candidate"] = cands[arg]["slug"]
                elif r.get("kind") in STATE_TRANSITION_KINDS:
                    # A speculative proposal without a private committing owner
                    # cannot be presented as an actual warehouse operation.
                    r.update(status="withheld", response="Warehouse operations need an explicitly selected warehouse specialist; this preview did not change its state.",
                             path=str(r.get("path", "")) + ">preview")
                    r.pop("value", None)
                    r["provenance"]["dispatch"]["requires_pinned_front"] = True
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
        """A selected accepted reply, including a refusal, ends this turn."""
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
        failures = {}
        for slug, reply in replies.items():
            problem = reply_shape_error(reply)
            if problem:
                failures[slug] = problem
            elif "error" in reply:
                failures[slug] = reply["error"]
        if failures:
            return {"status": "withheld", "response": "", "path": "dispatch>specialist_error",
                    "error": failures}, None, replies
        cands = self.organ_cands(text, session, rid, replies)
        if not cands:
            # Every stateful organ is still a preview here. An undeclared or
            # out-of-context reading can safely fall through without effects.
            return None, None, replies
        out = self.arbitrate(text, session, rid, cands)
        if out is None:
            return None, None, replies
        out.setdefault("provenance", {}).setdefault("dispatch", {})["decisive"] = True
        return out, None, replies

    def reader_stage(self, text, session, rid):
        if self.reader is None:
            return None
        r = self.reader.ask(rid, text, session)
        if "error" in r:
            return r
        prov = r.get("provenance") or {}
        return r if r.get("status") == "answered" or prov.get("taken") else None

    def commit_selected(self, slug, rid, text, session, preview, guarded):
        """Commit one selected, guarded preview against exclusively owned state.

        The preview child reloads the state before each turn, while one committing
        child is the only writer. No retry is attempted on an uncertain result.
        """
        raw = self.commit_organs[slug].ask(rid, text, session)
        observations = {"attempted": True, "retries": 0,
                        "preview_kind": preview.get("kind"),
                        "preview_status": preview.get("status"),
                        "guards_ran": "precision_guards" in guarded.get("provenance", {}),
                        "state_ownership": "private file, one writer, serialized turns"}
        if "error" not in raw and (raw.get("provenance") or {}).get("preview") is not False:
            raw = {**raw, "error": "committing warehouse reply did not identify committed mode"}
        if "error" in raw:
            return {"id": rid, "status": "withheld", "response": "The warehouse operation's result is uncertain; it was not retried.",
                    "path": "dispatch>commit_error", "error": raw["error"],
                    "provenance": {"dispatch": {"commit": observations}, "commit_reply": raw}}
        candidates = self.organ_cands(text, session, rid, {slug: raw})
        if not candidates:
            return {"id": rid, "status": "withheld", "response": "The warehouse returned an undeclared result; it was not retried.",
                    "path": "dispatch>commit_error", "error": "committing reply was not accepted",
                    "provenance": {"dispatch": {"commit": observations}, "commit_reply": raw}}
        actual = self.arbitrate(text, session, rid, candidates)
        observations["matches_preview"] = all(raw.get(key) == preview.get(key)
                                               for key in ("status", "kind", "response", "value"))
        provenance = actual.setdefault("provenance", {})
        if "precision_guards" in guarded.get("provenance", {}):
            provenance["precision_guards"] = dict(guarded["provenance"]["precision_guards"], checked_before_commit=True)
        provenance.setdefault("dispatch", {})["commit"] = observations
        provenance["dispatch"]["decisive"] = True
        # Report what the committing program actually returned. In particular,
        # no later narrowing may conceal an already performed state transition.
        return actual

    def document_stage(self, text, session, rid):
        if self.document is None:
            return None
        r = self.document.ask(rid, text, session)
        if "error" in r:
            return r
        prov = r.get("provenance") or {}
        return r if r.get("status") == "answered" or prov.get("taken") else None

    # -- one turn
    def turn(self, rid, text, session):
        # A private state file has one committing child. Serialize the entire
        # preview -> selection -> guards -> commit path, including API callers.
        with self.turn_lock:
            return self._turn(rid, text, session)

    def _turn(self, rid, text, session):
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

        def extra(name, callback):
            def run():
                t = time.perf_counter()
                r = callback()
                ms[name] = round(1000 * (time.perf_counter() - t), 3)
                return r
            run.__name__ = name
            return run

        math = extra("math", lambda: self.routes.answer_math(rid, text, session))
        wordprob = extra("wordprob", lambda: self.routes.answer_wordprob(rid, text, session))
        document = extra("document", lambda: self.document_stage(text, session, rid))
        math_guard = extra("math_guard", lambda: self.routes.fallback_math_decline(rid, text, session))
        fallback = None
        tail = []
        if "mathorgan" in getattr(self, "route_names", set()):
            tail.append(math)
        if "wordprob" in getattr(self, "route_names", set()):
            tail.append(wordprob)
        if getattr(self, "reader", None) is not None:
            tail.append(rel)
        if getattr(self, "document", None) is not None:
            tail.append(document)
        if "mathorgan" in getattr(self, "route_names", set()):
            tail.append(math_guard)
        seq = (([net, specs] if head_first else [specs, net]) + tail) if out is None else []
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
        out["id"] = rid
        if "error" in out:
            out.setdefault("status", "withheld")
            out.setdefault("response", "")
            out.setdefault("path", "dispatch>stage_error")
        preview = out
        commit_slug = (out.get("provenance", {}).get("dispatch") or {}).get("commit_candidate")
        if out.get("status") == "answered" and "guards" in getattr(self, "route_names", set()):
            t = time.perf_counter()
            out = self.routes.apply_guards(text, out)
            ms["guards"] = round(1000 * (time.perf_counter() - t), 3)
            stages.append("guards")
        if commit_slug and out.get("status") == "answered" and "error" not in out:
            t = time.perf_counter()
            out = self.commit_selected(commit_slug, rid, text, session, preview, out)
            ms["commit"] = round(1000 * (time.perf_counter() - t), 3)
            stages.append("commit")
        elif commit_slug:
            out.setdefault("provenance", {}).setdefault("dispatch", {})["commit"] = "not attempted; preview was withheld"
        prov = out.get("provenance") if isinstance(out.get("provenance"), dict) else {}
        prov["dispatch"] = {**(prov.get("dispatch") or {}), "stages_run": stages,
                            "ms": dict(ms, total=round(1000 * (time.perf_counter() - t0), 3))}
        if getattr(self, "stateful_not_selected", []):
            prov["dispatch"]["stateful_not_selected"] = self.stateful_not_selected
        out["provenance"] = prov
        out["id"] = rid
        return out

    def close(self):
        for ch, _ in self.organs:
            ch.close()
        for child in self.commit_organs.values():
            child.close()
        self.fusion.close()
        if self.reader:
            self.reader.close()
        if self.document:
            self.document.close()
        self.routes.close()
        self.arb.close()
        self.pool.shutdown(wait=True)


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
        good = got_s == case["want"]
        print("%s want=%-14s got=%s" % ("ok " if good else "FAIL", case["want"], got_s))
        ok = ok and good
    arb.close()
    return ok


def main():
    ap = argparse.ArgumentParser(description="veri7vn dispatcher (untrusted glue; see module docstring)")
    ap.add_argument("--var-root", default=os.environ.get("VERI7VN_VAR", str(REPO / "var")))
    ap.add_argument("--order", choices=["head", "front"], default="head")
    ap.add_argument("--organs", help="comma-separated registered specialist families (default: all)")
    ap.add_argument("--no-reader", action="store_true")
    ap.add_argument("--no-document", action="store_true")
    ap.add_argument("--no-routes", action="store_true", help="disable math, word-problem and precision-guard stages")
    ap.add_argument("--specialist", default="",
                    help="pin the registered family owner to this specialist ID")
    ap.add_argument("--arb", default=str(REPO / "var" / "dispatch" / "bin" / "arb_check"))
    ap.add_argument("--adapter-python", default=str(REPO / ".venv/bin/python")
                    if (REPO / ".venv/bin/python").is_file() else sys.executable,
                    help="Python with document adapter dependencies (default: repository .venv when present)")
    ap.add_argument("--timeout", type=float, default=10.0, help="seconds per organ reply")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(0 if selftest(a.arb) else 1)
    try:
        d = Dispatcher(a)
    except (ValueError, OSError) as exc:
        ap.error(str(exc))
    try:
        for line in sys.stdin:
            if not line.strip():
                continue
            rid = None
            try:
                req = json.loads(line)
                if not isinstance(req, dict):
                    raise ValueError("request must be a JSON object")
                rid, q, sess = req.get("id"), str(req.get("q", "")), str(req.get("session", "default"))
                out = d.turn(rid, q, sess)
            except Exception as e:  # noqa: BLE001 - one broken turn never costs the process
                out = {"id": rid, "status": "withheld", "error": "dispatch: %s: %s" % (type(e).__name__, e),
                       "response": "", "path": "dispatch>error"}
            sys.stdout.write(json.dumps(out, ensure_ascii=False, default=str) + "\n")
            sys.stdout.flush()
    finally:
        d.close()


if __name__ == "__main__":
    main()
