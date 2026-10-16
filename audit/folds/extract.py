#!/usr/bin/env python3
"""Catalogue Oracle7's routing cascade: one record per class on the tip's method resolution order.

Reads the fold modules with `ast` only (nothing is imported or executed). Run from anywhere:

    python3 audit/folds/extract.py           # rewrite audit/folds/folds.json
    python3 audit/folds/extract.py --check   # fail if folds.json differs from a fresh extraction

The order is Python's C3 linearisation of the tip class, computed statically: it is the order in which
`super().chat(...)` calls travel from the tip toward the base. Kinds are defined in README.md.
"""
from __future__ import annotations

import ast
import hashlib
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADMITTED = "upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted"
WANDER = "upstream/root/wander-train"
SEARCH = (ADMITTED, WANDER)  # admitted first: identical copies of ao and w54..w75 exist in both
TIP = ("oracle_release_runtime_w540", "OracleReleaseRuntimeW540")
OUT = os.path.join(REPO, "audit/folds/folds.json")
REPLY_CORE = ("status", "path", "response")
MUTATORS = {"append", "pop", "update", "setdefault", "clear", "extend", "insert", "add", "remove", "discard", "popitem"}
REGEX_FUNCS = {"compile", "match", "search", "fullmatch", "sub", "subn", "findall", "finditer", "split"}

_mods: dict = {}


def find(mod):
    for d in SEARCH:
        p = os.path.join(REPO, d, mod + ".py")
        if os.path.exists(p):
            return os.path.join(d, mod + ".py")
    return None


def load(mod):
    if mod in _mods:
        return _mods[mod]
    rel = find(mod)
    if rel is None:
        _mods[mod] = None
        return None
    raw = open(os.path.join(REPO, rel), "rb").read()
    src = raw.decode("utf-8")
    tree = ast.parse(src)
    imports, classes, funcs, consts = {}, {}, {}, {}
    for node in tree.body:
        if isinstance(node, ast.ImportFrom) and node.module:
            for a in node.names:
                imports[a.asname or a.name] = (node.module, a.name)
        elif isinstance(node, ast.Import):
            for a in node.names:
                imports[a.asname or a.name] = (a.name, None)
        elif isinstance(node, ast.ClassDef):
            classes[node.name] = node
        elif isinstance(node, ast.FunctionDef):
            funcs[node.name] = node
        elif isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            consts[node.targets[0].id] = node.value
    info = {"rel": rel, "src": src, "tree": tree, "imports": imports, "classes": classes, "funcs": funcs,
            "consts": consts, "sha256": hashlib.sha256(raw).hexdigest(), "lines": len(src.splitlines())}
    _mods[mod] = info
    return info


def resolve(mod, expr):
    """(module, class) named by a base-class expression inside `mod`."""
    info = load(mod)
    s = ast.unparse(expr)
    if s in info["classes"]:
        return (mod, s)
    head, _, rest = s.partition(".")
    if head in info["imports"]:
        m, n = info["imports"][head]
        if n is None:
            target = rest
        else:
            target = n
        sub = load(m)
        if sub is None:
            return ("?" + m, target)
        if target in sub["classes"]:
            return (m, target)
        return resolve(m, ast.parse(target, mode="eval").body)
    return ("?", s)


def mro(tip):
    """Static C3 linearisation (iterative, so the 361-deep chain does not need a raised recursion limit)."""
    memo = {}
    order = [tip]
    stack = [tip]
    seen = set()
    while stack:  # post-order over the base graph
        k = stack[-1]
        if k in memo:
            stack.pop()
            continue
        if k[0].startswith("?"):
            memo[k] = [k]
            stack.pop()
            continue
        bases = [resolve(k[0], b) for b in load(k[0])["classes"][k[1]].bases]
        pending = [b for b in bases if b not in memo]
        if pending:
            for b in reversed(pending):
                if b not in seen:
                    seen.add(b)
                    stack.append(b)
            if all(b in seen for b in pending) and any(b in stack[:-len(pending)] for b in pending):
                raise SystemExit("cyclic base graph at %r" % (k,))
            continue
        seqs = [list(memo[b]) for b in bases] + [list(bases)]
        out = [k]
        while True:
            seqs = [s for s in seqs if s]
            if not seqs:
                break
            for s in seqs:
                h = s[0]
                if not any(h in t[1:] for t in seqs):
                    break
            else:
                raise SystemExit("no C3 linearisation at %r" % (k,))
            out.append(h)
            for t in seqs:
                if t and t[0] == h:
                    t.pop(0)
        memo[k] = out
        stack.pop()
    del order
    return memo[tip]


# ---------------------------------------------------------------- constant strings for regex sources

def const_str(info, node, depth=0):
    if depth > 8:
        return None
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, ast.Name) and node.id in info["consts"]:
        return const_str(info, info["consts"][node.id], depth + 1)
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
        a, b = const_str(info, node.left, depth + 1), const_str(info, node.right, depth + 1)
        return a + b if a is not None and b is not None else None
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Mod):
        fmt = const_str(info, node.left, depth + 1)
        if fmt is None:
            return None
        args = node.right.elts if isinstance(node.right, ast.Tuple) else [node.right]
        vals = [const_str(info, a, depth + 1) for a in args]
        if any(v is None for v in vals):
            return None
        try:
            return fmt % tuple(vals)
        except (TypeError, ValueError):
            return None
    if isinstance(node, ast.JoinedStr):
        return None
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "join" \
            and len(node.args) == 1 and isinstance(node.args[0], (ast.List, ast.Tuple)):
        sep = const_str(info, node.func.value, depth + 1)
        parts = [const_str(info, e, depth + 1) for e in node.args[0].elts]
        if sep is None or any(p is None for p in parts):
            return None
        return sep.join(parts)
    return None


def regex_call(node):
    f = node.func
    return isinstance(node, ast.Call) and isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) \
        and f.value.id == "re" and f.attr in REGEX_FUNCS


def flags_of(call):
    fl = [ast.unparse(k.value) for k in call.keywords if k.arg == "flags"]
    pos = 2 if call.func.attr in ("compile",) else None
    if call.func.attr == "compile" and len(call.args) > 1:
        fl.append(ast.unparse(call.args[1]))
    elif call.func.attr in ("match", "search", "fullmatch", "findall", "finditer", "split") and len(call.args) > 2:
        fl.append(ast.unparse(call.args[2]))
    del pos
    return " | ".join(fl)


def module_regexes(info):
    out = {}
    for name, value in info["consts"].items():
        if isinstance(value, ast.Call) and regex_call(value) and value.func.attr == "compile" and value.args:
            src = const_str(info, value.args[0])
            out[name] = {"name": name, "pattern": src if src is not None else None,
                         "pattern_expr": None if src is not None else ast.unparse(value.args[0]),
                         "flags": flags_of(value)}
    return out


# ---------------------------------------------------------------- reachable code

def own_nodes(fn):
    """Nodes of a function body, not descending into nested defs/lambdas/classes."""
    todo = list(fn.body)
    while todo:
        n = todo.pop()
        yield n
        for c in ast.iter_child_nodes(n):
            if isinstance(c, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda, ast.ClassDef)):
                continue
            todo.append(c)


def class_methods(info, cname):
    return {f.name: f for f in info["classes"][cname].body if isinstance(f, (ast.FunctionDef, ast.AsyncFunctionDef))}


def reachable(info, cname, roots):
    """Functions reachable from `roots` through self.<method> of this class and calls of module-level functions."""
    meths = class_methods(info, cname)
    seen, todo, out = set(), list(roots), []
    while todo:
        fn = todo.pop()
        if id(fn) in seen:
            continue
        seen.add(id(fn))
        out.append(fn)
        for n in ast.walk(fn):
            if isinstance(n, ast.Call):
                f = n.func
                if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == "self" and f.attr in meths:
                    todo.append(meths[f.attr])
                elif isinstance(f, ast.Name) and f.id in info["funcs"]:
                    todo.append(info["funcs"][f.id])
    return sorted(out, key=lambda f: f.lineno)


# ---------------------------------------------------------------- the chat body

def local_imports(fn):
    out = {}
    for n in ast.walk(fn):
        if isinstance(n, ast.ImportFrom) and n.module:
            for a in n.names:
                out[a.asname or a.name] = (n.module, a.name)
    return out


def inner_call(n, chain, here, local=None):
    """Classify a call: ('next', None) for super().chat, ('class', key) for X.chat(self, ...) / super(X, self).chat,
    ('reenter', None) for self.chat, else None."""
    if not (isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "chat"):
        return None
    recv = n.func.value
    mod = here[0]
    if local and isinstance(recv, ast.Name) and recv.id in local and n.args and isinstance(n.args[0], ast.Name) \
            and n.args[0].id == "self":
        m, nm = local[recv.id]
        return ("class", (m, nm))
    if isinstance(recv, ast.Call) and isinstance(recv.func, ast.Name) and recv.func.id == "super":
        if not recv.args:
            return ("next", None)
        k = resolve(mod, recv.args[0])
        return ("after", k)
    if isinstance(recv, ast.Name) and recv.id == "self":
        return ("reenter", None)
    if isinstance(recv, ast.Name) and n.args and isinstance(n.args[0], ast.Name) and n.args[0].id == "self":
        k = resolve(mod, recv)
        return ("class", k)
    return None


def call_text_arg(n, kind):
    args = list(n.args)
    if kind == "helper":
        return args[0] if args else None
    if kind in ("class",):
        args = args[1:]
    if args:
        return args[0]
    for k in n.keywords:
        if k.arg == "text":
            return k.value
    return None


def is_text_preserving(expr, names):
    """str(text), str(text or ''), text or '' over a name already known to carry the text unchanged."""
    if isinstance(expr, ast.Name):
        return expr.id in names
    if isinstance(expr, ast.BoolOp) and isinstance(expr.op, ast.Or):
        return is_text_preserving(expr.values[0], names) and all(isinstance(v, ast.Constant) for v in expr.values[1:])
    if isinstance(expr, ast.Call) and isinstance(expr.func, ast.Name) and expr.func.id == "str" and len(expr.args) == 1:
        return is_text_preserving(expr.args[0], names)
    return False


def _strip_chain(expr, names):
    """X, X.strip(), str(X).strip(), X.lower() ... over a text-carrying name."""
    while isinstance(expr, ast.Call) and isinstance(expr.func, ast.Attribute) and not expr.args \
            and expr.func.attr in ("strip", "lstrip", "rstrip"):
        expr = expr.func.value
    return is_text_preserving(expr, names)


def is_normalizing(expr, names):
    """' '.join(<text>.split()) with optional str()/strip() around the text, or <text>.strip()."""
    if _strip_chain(expr, names) and not is_text_preserving(expr, names):
        return True
    if isinstance(expr, ast.Call) and isinstance(expr.func, ast.Attribute) and expr.func.attr == "join" \
            and isinstance(expr.func.value, ast.Constant) and expr.func.value.value == " " and len(expr.args) == 1:
        sp = expr.args[0]
        if isinstance(sp, ast.Call) and isinstance(sp.func, ast.Attribute) and sp.func.attr == "split" and not sp.args:
            return _strip_chain(sp.func.value, names)
    return False


def statuses_set_on(fn_nodes, name, skip_ids=frozenset(), call_status=None):
    """Status literals written onto local `name` (dict literal, update({...}), name['status'] = ..., dict(x, status=...))."""
    st, keys, opaque = set(), set(), False

    def from_dict(d):
        nonlocal opaque
        for k, v in zip(d.keys, d.values):
            if k is None:
                continue
            if isinstance(k, ast.Constant):
                keys.add(str(k.value))
                if k.value == "status":
                    st.add(v.value if isinstance(v, ast.Constant) else "computed")
    for n in fn_nodes:
        if isinstance(n, ast.Assign):
            for t in n.targets:
                if isinstance(t, ast.Name) and t.id == name and id(n.value) not in skip_ids:
                    v = n.value
                    if isinstance(v, ast.Dict):
                        from_dict(v)
                        if not any(k == "status" for k in keys):
                            st.add("unset")
                    elif isinstance(v, ast.Call) and isinstance(v.func, ast.Name) and v.func.id == "dict":
                        for kw in v.keywords:
                            if kw.arg:
                                keys.add(kw.arg)
                                if kw.arg == "status":
                                    st.add(kw.value.value if isinstance(kw.value, ast.Constant) else "computed")
                    elif isinstance(v, ast.Call) and call_status is not None and call_status(v):
                        st.update(call_status(v))
                    else:
                        opaque = True
                if isinstance(t, ast.Subscript) and isinstance(t.value, ast.Name) and t.value.id == name \
                        and isinstance(t.slice, ast.Constant):
                    keys.add(str(t.slice.value))
                    if t.slice.value == "status":
                        st.add(n.value.value if isinstance(n.value, ast.Constant) else "computed")
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name) \
                and n.func.value.id == name and n.func.attr in ("update", "setdefault", "pop"):
            if n.func.attr == "update":
                if n.args and isinstance(n.args[0], ast.Dict):
                    from_dict(n.args[0])
                elif n.args:
                    opaque = True
                for kw in n.keywords:
                    if kw.arg:
                        keys.add(kw.arg)
                        if kw.arg == "status":
                            st.add(kw.value.value if isinstance(kw.value, ast.Constant) else "computed")
            elif n.args and isinstance(n.args[0], ast.Constant):
                keys.add(str(n.args[0].value))
    return st, keys, opaque


def helper_statuses(fn):
    """Status literals a helper can return: dict literals with 'status', and writes onto any local."""
    st = set()
    for n in ast.walk(fn):
        if isinstance(n, ast.Dict):
            for k, v in zip(n.keys, n.values):
                if isinstance(k, ast.Constant) and k.value == "status":
                    st.add(v.value if isinstance(v, ast.Constant) else "computed")
        if isinstance(n, ast.Assign):
            for t in n.targets:
                if isinstance(t, ast.Subscript) and isinstance(t.slice, ast.Constant) and t.slice.value == "status":
                    st.add(n.value.value if isinstance(n.value, ast.Constant) else "computed")
        if isinstance(n, ast.keyword) and n.arg == "status":
            st.add(n.value.value if isinstance(n.value, ast.Constant) else "computed")
    return st


def analyse_chat(fn, info, cname, chain, idx):
    here = chain[idx]
    param = fn.args.args[1].arg if len(fn.args.args) > 1 else "text"
    nodes = list(own_nodes(fn))
    # text aliases, in source order
    same, normed = {param}, set()
    for n in sorted((n for n in nodes if isinstance(n, ast.Assign)), key=lambda n: (n.lineno, n.col_offset)):
        if len(n.targets) == 1 and isinstance(n.targets[0], ast.Name):
            t = n.targets[0].id
            if is_text_preserving(n.value, same):
                same.add(t)
            elif is_text_preserving(n.value, normed) or is_normalizing(n.value, same | normed):
                normed.add(t)
    local = local_imports(fn)
    owner_of = {}

    def dispatches(name, start, depth):
        """(owner index, inner-call kind) when self.<name>, looked up from chain[start], reaches an inner chat call."""
        if depth > 4:
            return None
        for j in range(start, len(chain)):
            k = chain[j]
            if k[0].startswith("?"):
                continue
            m = class_methods(load(k[0]), k[1]).get(name)
            if m is None:
                continue
            for x in own_nodes(m):
                kk = inner_call(x, chain, k, local_imports(m))
                if kk is not None and kk[0] != "reenter":
                    return (j, kk)
            for x in own_nodes(m):
                if isinstance(x, ast.Call) and isinstance(x.func, ast.Attribute) and isinstance(x.func.value, ast.Name) \
                        and x.func.value.id == "self" and x.func.attr not in ("chat", name):
                    r = dispatches(x.func.attr, j, depth + 1)
                    if r is not None:
                        return r
            return None
        return None

    def helper_dispatch(n):
        """self.m(...) whose body (found along the chain) reaches the next fold's chat: an indirect inner call."""
        if not isinstance(n, ast.Call):
            return None
        f = n.func
        if not (isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == "self" and f.attr != "chat"):
            return None
        r = dispatches(f.attr, idx, 0)
        if r is None:
            return None
        owner_of[id(n)] = (f.attr, r[0])
        return ("helper", r)

    calls = []
    for n in nodes:
        k = inner_call(n, chain, here, local) or helper_dispatch(n)
        if k is None:
            continue
        arg = call_text_arg(n, k[0])
        if arg is None:
            how = "rewritten"
        elif is_text_preserving(arg, same):
            how = "same"
        elif is_text_preserving(arg, normed) or is_normalizing(arg, same | normed):
            how = "normalized"
        else:
            how = "rewritten"
        target = None
        if k[0] == "helper":
            j, kk = k[1]
            if kk[0] == "next":
                target = j + 1
            elif kk[1] in chain:
                target = chain.index(kk[1]) + (1 if kk[0] == "after" else 0)
        elif k[0] == "next":
            target = idx + 1
        elif k[0] in ("after", "class"):
            if k[1] in chain:
                target = chain.index(k[1]) + (1 if k[0] == "after" else 0)
        calls.append({"node": n, "kind": k[0], "how": how, "target": target, "pos": (n.lineno, n.col_offset),
                      "arg": ast.unparse(arg) if arg is not None else None,
                      "helper": owner_of.get(id(n), (None,))[0]})
    calls.sort(key=lambda c: c["pos"])
    call_ids = {id(c["node"]) for c in calls}
    # names holding an inner reply
    holders, reassigned = set(), set()
    for n in nodes:
        if isinstance(n, ast.Assign) and len(n.targets) == 1 and isinstance(n.targets[0], ast.Name):
            if id(n.value) in call_ids:
                holders.add(n.targets[0].id)
            else:
                reassigned.add(n.targets[0].id)
    pure = holders - reassigned
    mutated = {}
    for h in pure:
        st, keys, opq = statuses_set_on(nodes, h, call_ids)
        if keys or opq:
            mutated[h] = (st, keys, opq)
    meths = class_methods(info, cname)

    def call_status(v):
        """Statuses a call can return, when the callee is a helper we can read (this class, deeper on the chain, module)."""
        f = v.func
        helper = None
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == "self":
            for k in chain[idx:]:
                if k[0].startswith("?"):
                    continue
                m = class_methods(load(k[0]), k[1])
                if f.attr in m:
                    helper = m[f.attr]
                    break
        elif isinstance(f, ast.Name):
            helper = info["funcs"].get(f.id)
        if helper is None:
            return None
        return helper_statuses(helper) or {"opaque"}

    def classify_value(v):
        """-> list of ('pass'|'annotate'|'own', statuses)"""
        if isinstance(v, ast.IfExp):
            return classify_value(v.body) + classify_value(v.orelse)
        if isinstance(v, ast.BoolOp):
            return [x for e in v.values for x in classify_value(e)]
        if id(v) in call_ids:
            return [("pass", set())]
        if isinstance(v, ast.Name) and v.id in pure:
            if v.id in mutated:
                st, keys, opq = mutated[v.id]
                if opq or set(keys) & set(REPLY_CORE):
                    return [("own", st or ({"opaque"} if opq else {"inherited"}))]
                return [("annotate", set())]
            return [("pass", set())]
        if isinstance(v, ast.Dict):
            st = set()
            for k, x in zip(v.keys, v.values):
                if isinstance(k, ast.Constant) and k.value == "status":
                    st.add(x.value if isinstance(x, ast.Constant) else "computed")
            return [("own", st or {"unset"})]
        if isinstance(v, ast.Name):
            st, keys, opq = statuses_set_on(nodes, v.id, call_ids, call_status)
            st = set(st)
            if opq:
                st.add("opaque")
            if not st:
                st = {"opaque"} if not keys else {"inherited"}
            return [("own", st)]
        if isinstance(v, ast.Call):
            return [("own", call_status(v) or {"opaque"})]
        if isinstance(v, ast.Constant) and v.value is None:
            return [("own", {"none"})]
        return [("own", {"opaque"})]

    # taint: names whose value derives from an inner reply
    tainted = set(holders)
    changed = True
    while changed:
        changed = False
        for n in nodes:
            if isinstance(n, ast.Assign):
                used = {x.id for x in ast.walk(n.value) if isinstance(x, ast.Name)} | \
                       ({"<call>"} if any(id(x) in call_ids for x in ast.walk(n.value)) else set())
                if used & (tainted | {"<call>"}):
                    for t in n.targets:
                        for x in ast.walk(t):
                            if isinstance(x, ast.Name) and x.id not in tainted:
                                tainted.add(x.id)
                                changed = True
    # dominance: a return reached only after an unconditional inner call earlier in its own or an enclosing block
    dominated = {}

    def has_call(stmt):
        return any(id(x) in call_ids for x in ast.walk(stmt))

    def walk_block(stmts, flag):
        for st in stmts:
            if isinstance(st, ast.Return):
                dominated[id(st)] = flag
            for field in ("body", "orelse", "finalbody"):
                sub = getattr(st, field, None)
                if isinstance(sub, list) and sub and isinstance(sub[0], ast.stmt):
                    walk_block(sub, flag)
            for h in getattr(st, "handlers", []) or []:
                walk_block(h.body, flag)
            if isinstance(st, (ast.Assign, ast.AugAssign, ast.AnnAssign, ast.Expr)) and has_call(st):
                flag = True
            if isinstance(st, (ast.With, ast.Try)) and any(has_call(x) for x in st.body if not isinstance(x, ast.Return)):
                flag = True
    walk_block(fn.body, False)

    returns = []
    for n in nodes:
        if isinstance(n, ast.Return) and n.value is not None:
            contains_call = any(id(x) in call_ids for x in ast.walk(n.value))
            uses_taint = any(isinstance(x, ast.Name) and x.id in tainted for x in ast.walk(n.value))
            after = dominated.get(id(n), False) or contains_call or uses_taint
            for kind, st in classify_value(n.value):
                returns.append({"pos": (n.lineno, n.col_offset), "kind": kind, "statuses": sorted(st), "after": after,
                                "delegate": contains_call})
    first_call = calls[0]["pos"] if calls else None
    first_ret = min((r["pos"] for r in returns if not r["delegate"]), default=None)
    pre = [r for r in returns if r["kind"] == "own" and not r["after"]]
    post = [r for r in returns if r["kind"] == "own" and r["after"]]
    return {"calls": calls, "returns": returns, "pre": pre, "post": post, "first_call": first_call, "first_ret": first_ret,
            "annotates": sorted({k for h, (st, keys, o) in mutated.items() for k in keys if not set(keys) & set(REPLY_CORE)})}


def reply_keys_used(fns, reply_keys):
    keys = set()
    for fn in fns:
        for n in ast.walk(fn):
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "get" and n.args \
                    and isinstance(n.args[0], ast.Constant) and isinstance(n.args[0].value, str):
                if not (isinstance(n.func.value, ast.Attribute) and isinstance(n.func.value.value, ast.Name)
                        and n.func.value.value.id == "self"):
                    keys.add(n.args[0].value)
            if isinstance(n, ast.Subscript) and isinstance(n.slice, ast.Constant) and isinstance(n.slice.value, str) \
                    and isinstance(n.ctx, ast.Load):
                keys.add(n.slice.value)
    return sorted(keys & reply_keys)


def state_writes(fns):
    attrs = set()
    for fn in fns:
        if fn.name == "__init__":
            continue
        for n in ast.walk(fn):
            targets = []
            if isinstance(n, (ast.Assign, ast.AugAssign, ast.AnnAssign)):
                targets = n.targets if isinstance(n, ast.Assign) else [n.target]
            for t in targets:
                base = t
                while isinstance(base, (ast.Subscript, ast.Attribute)):
                    if isinstance(base, ast.Attribute) and isinstance(base.value, ast.Name) and base.value.id == "self":
                        attrs.add(base.attr)
                        break
                    base = base.value
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr in MUTATORS:
                base = n.func.value
                while isinstance(base, (ast.Subscript, ast.Attribute, ast.Call)):
                    if isinstance(base, ast.Attribute) and isinstance(base.value, ast.Name) and base.value.id == "self":
                        attrs.add(base.attr)
                        break
                    base = base.func if isinstance(base, ast.Call) else base.value
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == "setattr" and n.args \
                    and isinstance(n.args[0], ast.Name) and n.args[0].id == "self":
                attrs.add("<setattr>")
    return sorted(attrs)


def module_patches(info):
    """Module-level statements that change another module's globals or a shared table at import time."""
    mods = {k for k, (m, n) in info["imports"].items() if n is None or (load(m) and n not in load(m)["classes"])}
    for node in info["tree"].body:  # names bound to another loaded module through sys.modules
        for n in ast.walk(node) if not isinstance(node, (ast.FunctionDef, ast.ClassDef)) else []:
            if isinstance(n, ast.Assign) and "sys.modules" in ast.unparse(n.value):
                mods |= {t.id for t in n.targets if isinstance(t, ast.Name)}
    mods -= {"sys"}
    out = []
    for node in info["tree"].body:
        for n in ast.walk(node) if not isinstance(node, (ast.FunctionDef, ast.ClassDef)) else []:
            if isinstance(n, ast.Assign):
                for t in n.targets:
                    if isinstance(t, ast.Attribute) and isinstance(t.value, ast.Name) and t.value.id in mods:
                        out.append(ast.unparse(t))
                    if isinstance(t, ast.Attribute) and "sys.modules" in ast.unparse(t.value):
                        out.append(ast.unparse(t))
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr in MUTATORS \
                    and isinstance(n.func.value, ast.Name) and n.func.value.id in mods:
                out.append(ast.unparse(n.func))
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == "setattr" and n.args:
                out.append("setattr(%s, %s)" % (ast.unparse(n.args[0]), ast.unparse(n.args[1]) if len(n.args) > 1 else ""))
    return sorted(set(out))


class _StripConstants(ast.NodeTransformer):
    def visit_Constant(self, node):
        return ast.Constant(value="K")


def template_key(chat, guards):
    """Same chat shape (constants blanked) and same guard regexes: copies of one generated fold."""
    shape = ast.dump(_StripConstants().visit(ast.parse(ast.unparse(chat))))
    pats = json.dumps([(g["pattern"], g["flags"]) for g in guards])
    return hashlib.sha256((shape + pats).encode()).hexdigest()[:16]


def guard_returns_unconditional(chat):
    """Every return of an own reply sits directly in the body of a top-level `if` of chat: once that
    `if` is entered, the fold answers without consulting anything else."""
    tops = [st for st in chat.body if isinstance(st, ast.If)]
    direct = {id(x) for st in tops for x in st.body if isinstance(x, ast.Return)}
    own = [n for n in own_nodes(chat) if isinstance(n, ast.Return) and n.value is not None
           and not any(isinstance(x, ast.Call) and isinstance(x.func, ast.Attribute) and x.func.attr == "chat"
                       for x in ast.walk(n.value))]
    return bool(own) and all(id(n) in direct for n in own)


SAME_QUESTION = {"narrow", "pre_route", "post_replace", "hook", "helper", "empty", "join", "module_patch", "state_only",
                 "transparent"}
HOL = {"narrow": "Narrow", "pre_route": "PreRoute", "post_replace": "Post", "rewrite": "Rewrite",
       "post_redispatch": "Redispatch", "probe_rewrite": "ProbeRewrite", "replace": "Replace", "base": "Replace",
       "pre_and_post": "PreRoute then Post", "hook": "Pass", "helper": "Pass", "empty": "Pass", "join": "Pass", "module_patch": "Pass",
       "state_only": "Pass", "transparent": "Pass"}
OWN_ANSWER = {"answered", "computed", "opaque", "unset"}


def annotate_semantics(folds):
    """HOL constructor, static non-adding verdict, and dead copies of generated pre-routes."""
    for f in folds:
        direct = [c for c in f["inner_calls"] if c["via"] in ("next", "after", "class") and c["target_index"] is not None]
        depth = max([c["target_index"] - f["index"] - 1 for c in direct], default=0)
        hol = HOL[f["kind"]]
        if f["kind"] == "probe_rewrite":
            hol = "ProbeRewrite %d" % depth
        elif depth > 0:
            hol = "Skip %d (%s)" % (depth, hol)
        f["hol"] = hol
        own = set(f["own_statuses_before"]) | set(f["own_statuses_after"])
        f["may_answer_on_own"] = bool(own & OWN_ANSWER) or f["kind"] in (
            "rewrite", "probe_rewrite", "post_redispatch", "replace", "base")
        f["same_question"] = (f["kind"] in SAME_QUESTION and not f["skips"] and not f["reenters"]
                              and f["inner_text"] in (None, "same", "normalized"))
    landings = [(f["index"], c["target_index"]) for f in folds for c in f["inner_calls"]
                if c["target_index"] is not None and c["target_index"] > f["index"] + 1]
    last = {}
    for f in folds:
        key = f.pop("_template", None)
        f["template"] = None
        f["shadowed_by"] = None
        if key is None:
            continue
        prev = last.get(key)
        last[key] = f
        f["template"] = key
        if prev is None or not (prev["answers_whenever_guard_fires"] and f["answers_whenever_guard_fires"]):
            continue
        between = folds[prev["index"] + 1:f["index"]]
        if not all(b["same_question"] for b in between):
            continue
        if any(src < prev["index"] < dst <= f["index"] for src, dst in landings):
            continue
        f["shadowed_by"] = prev["index"]


def first_line(doc):
    return doc.strip().splitlines()[0].strip() if doc and doc.strip() else None


def extract():
    chain = mro(TIP)
    # reply schema: keys of dict literals that carry both status and path, across every module on the chain
    reply_keys = set()
    for mod in sorted({k[0] for k in chain if not k[0].startswith("?")}):
        for n in ast.walk(load(mod)["tree"]):
            if isinstance(n, ast.Dict):
                ks = {k.value for k in n.keys if isinstance(k, ast.Constant) and isinstance(k.value, str)}
                if {"status", "path"} <= ks:
                    reply_keys |= ks
    manifest = json.load(open(os.path.join(REPO, ADMITTED, "HEAD_MANIFEST.json")))
    on_manifest = set(manifest["chain_tip_to_base"])
    primary = []
    k = TIP
    while True:  # first-base walk: the chain a reader follows by hand
        primary.append(k)
        c = load(k[0])["classes"][k[1]]
        if not c.bases:
            break
        k = resolve(k[0], c.bases[0])
        if k[0].startswith("?"):
            break
    primary_set = set(primary)
    folds = []
    for idx, key in enumerate(chain):
        mod, cname = key
        info = load(mod)
        cls = info["classes"][cname]
        meths = class_methods(info, cname)
        chat = meths.get("chat")
        bases = [resolve(mod, b) for b in cls.bases]
        rec = {"index": idx, "module": mod, "class": cname,
               "base_module": bases[0][0] if bases else None,
               "bases": ["%s.%s" % b for b in bases],
               "file": info["rel"], "sha256": info["sha256"], "lines": info["lines"],
               "class_lines": [cls.lineno, cls.end_lineno],
               "doc_head": first_line(ast.get_docstring(cls)) or first_line(ast.get_docstring(info["tree"])),
               "on_manifest_chain": mod in on_manifest,
               "on_first_base_walk": key in primary_set,
               "methods": sorted(meths)}
        roots = [chat] if chat is not None else list(meths.values())
        fns = reachable(info, cname, roots)
        regs = module_regexes(info)
        used_names = {n.id for fn in fns for n in ast.walk(fn) if isinstance(n, ast.Name)}
        guards = [regs[n] for n in sorted(regs) if n in used_names]
        for fn in fns:
            for n in ast.walk(fn):
                if isinstance(n, ast.Call) and regex_call(n) and n.args:
                    src = const_str(info, n.args[0])
                    if src is not None and not (isinstance(n.args[0], ast.Name) and n.args[0].id in regs):
                        guards.append({"name": "inline:%s:%d" % (fn.name, n.lineno), "pattern": src, "pattern_expr": None,
                                       "flags": flags_of(n)})
        rec["guards"] = guards
        rec["reads"] = reply_keys_used(fns, reply_keys)
        rec["state_writes"] = state_writes(fns)
        rec["touches_state"] = bool(rec["state_writes"])
        rec["module_patches"] = module_patches(info) if (idx == 0 or chain[idx - 1][0] != mod) else []
        hooks = []
        for m in sorted(meths):
            if m in ("chat", "__init__"):
                continue
            for deeper in chain[idx + 1:]:
                if deeper[0].startswith("?"):
                    continue
                if m in class_methods(load(deeper[0]), deeper[1]):
                    hooks.append({"method": m, "overrides": "%s.%s" % deeper})
                    break
        rec["overrides"] = hooks
        if chat is None:
            rec.update({"defines_chat": False, "calls_super_first": None, "inner_text": None, "rewrites_text": False,
                        "inner_calls": [], "skips": [], "probe_skips": False,
                        "reenters": any(isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
                                        and n.func.attr == "chat" and isinstance(n.func.value, ast.Name)
                                        and n.func.value.id == "self" for f in fns for n in ast.walk(f)), "own_statuses_before": [],
                        "own_statuses_after": [], "annotates": [], "answers_whenever_guard_fires": None})
            if not bases:
                kind = "base"
            elif hooks:
                kind = "hook"
            elif rec["module_patches"]:
                kind = "module_patch"
            elif len(bases) > 1:
                kind = "join"
            elif [m for m in meths if m != "__init__"]:
                kind = "helper"
            else:
                kind = "empty"
            rec["kind"] = kind
            folds.append(rec)
            continue
        a = analyse_chat(chat, info, cname, chain, idx)
        rec["defines_chat"] = True
        hows = [c["how"] for c in a["calls"] if c["kind"] != "reenter"]
        rec["inner_calls"] = [dict({"line": c["pos"][0], "via": c["kind"], "text": c["how"], "arg": c["arg"],
                                    "target_index": c["target"]}, **({"helper": c["helper"]} if c["helper"] else {}))
                              for c in a["calls"]]
        skips = []
        for c in a["calls"]:  # only classes that define chat are actually passed over
            if c["target"] is not None and c["target"] > idx + 1:
                skips.extend("%s.%s" % chain[j] for j in range(idx + 1, c["target"])
                             if not chain[j][0].startswith("?") and "chat" in class_methods(load(chain[j][0]), chain[j][1]))
        rec["skips"] = sorted(set(skips), key=lambda s: [x for x in range(len(chain)) if "%s.%s" % chain[x] == s][0])
        rec["reenters"] = any(isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "chat"
                              and isinstance(n.func.value, ast.Name) and n.func.value.id == "self"
                              for f in fns for n in ast.walk(f))
        rec["calls_super_first"] = bool(a["calls"]) and not a["pre"]
        rec["inner_text"] = "rewritten" if "rewritten" in hows else ("normalized" if "normalized" in hows else
                                                                     ("same" if hows else None))
        rec["rewrites_text"] = "rewritten" in hows
        rec["own_statuses_before"] = sorted({s for r in a["pre"] for s in r["statuses"]})
        rec["own_statuses_after"] = sorted({s for r in a["post"] for s in r["statuses"]})
        rec["annotates"] = a["annotates"]
        probe = any(c["kind"] == "class" and c["target"] is not None and c["target"] > idx + 1 for c in a["calls"]) \
            and any(c["kind"] == "next" for c in a["calls"])
        rec["probe_skips"] = probe
        first = a["calls"][0] if a["calls"] else None
        if not a["calls"] and not bases:
            kind = "base"
        elif not [c for c in a["calls"] if c["kind"] != "reenter"]:
            kind = "replace"
        elif rec["rewrites_text"]:
            if probe:
                kind = "probe_rewrite"
            elif first["how"] != "rewritten":
                kind = "post_redispatch"
            else:
                kind = "rewrite"
        else:
            pre_own, post_own = bool(a["pre"]), bool(a["post"])
            post_withheld_only = post_own and set(rec["own_statuses_after"]) <= {"withheld"}
            if pre_own and post_own:
                kind = "pre_and_post"
            elif pre_own:
                kind = "pre_route"
            elif post_withheld_only:
                kind = "narrow"
            elif post_own:
                kind = "post_replace"
            elif len([c for c in a["calls"] if c["kind"] != "reenter"]) > 1 or rec["reenters"]:
                kind = "post_redispatch"
            else:
                kind = "state_only" if rec["touches_state"] or rec["annotates"] else "transparent"
        rec["kind"] = kind
        rec["answers_whenever_guard_fires"] = guard_returns_unconditional(chat) if kind == "pre_route" else None
        rec["_template"] = template_key(chat, rec["guards"]) if kind == "pre_route" else None
        folds.append(rec)
    annotate_semantics(folds)
    by_kind = {}
    for f in folds:
        by_kind[f["kind"]] = by_kind.get(f["kind"], 0) + 1
    modules = sorted({f["module"] for f in folds})
    return {
        "schema": "veri7vn-fold-catalogue-v1",
        "tip": "%s.%s" % TIP,
        "search_path": list(SEARCH),
        "order": "C3 method resolution order of the tip class, tip first",
        "counts": {"classes": len(folds), "modules": len(modules),
                   "lines": sum(load(m)["lines"] for m in modules),
                   "first_base_walk": len(primary),
                   "manifest_chain_tip_to_base": len(manifest["chain_tip_to_base"]),
                   "manifest_orphaned_admitted": sorted(manifest.get("orphaned_admitted", [])),
                   "by_kind": dict(sorted(by_kind.items()))},
        "reply_keys": sorted(reply_keys),
        "folds": folds,
    }


def render(doc):
    return json.dumps(doc, indent=1, sort_keys=False, ensure_ascii=False) + "\n"


def main(argv):
    text = render(extract())
    if "--check" in argv:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            print("folds.json is stale: rerun python3 audit/folds/extract.py", file=sys.stderr)
            return 1
        print("folds.json up to date")
        return 0
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("wrote %s" % os.path.relpath(OUT, REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
