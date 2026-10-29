#!/usr/bin/env python3
"""organ_algorithms_native - shortest paths and minimum spanning trees on a graph the user states, computed and
checked by veri7vn's native Rust operations (graph.shortest_path, graph.minimum_spanning_forest) loaded in-process
from the oracle_native extension.

The recognizer in this file is UNTRUSTED. It is a hand-written Python reading of question forms taken from the
shipped algorithms panel (no generator for that panel ships with Oracle7); nothing about it is proved. It turns a
question into an exact native request, or declines. What the native side contributes is the computation and an
independent check of it: the shortest-path reply is a certificate (a path plus distance labels, or a reachable set
closed under the edges) that a separate Rust checker accepted, and the spanning-forest reply passed a separate
coverage and cycle-optimality check. This file then re-checks only that the reply fits the request it sent
(the path walks the stated edges and sums to the stated distance; the chosen edges exist and sum to the total).
None of the Rust is Isabelle-verified.

Answers (organ shape {kind, status, response, value}):
  shortest_path  the length and the route, for integer edge weights that are not negative
  unreachable    there is no route between the two named nodes in the stated graph
  mst            the total weight of the minimum spanning tree and the edges it uses (undirected edges only)
  disconnected   the stated graph is in several pieces, so it has no spanning tree
Declines in domain (only on a short direct question, per narrow_v1): underspecified (edges given, no start/end),
no_node (a named start or end is not in the edges), negative (a negative weight in a shortest-path question).
Everything else returns None so the head answers: no edge list, decimal weights, directed edges in a spanning-tree
question, constraints the request cannot carry (via, avoiding, at most, if ...), a stated node or vertex list (it
could name isolated nodes the edges do not show), requests to write code, and narrative turns.

The extension is bin/oracle_native.so beside this file, else $VERI7VN_NATIVE_EXTENSION. The organ refuses to start
unless the file's SHA-256 equals the one the manifest's store.native_extension block records for this platform."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import platform
import re
import threading
from pathlib import Path

from narrow_v1 import narrative, short_direct

HERE = Path(__file__).resolve().parent
ENV = "VERI7VN_NATIVE_EXTENSION"
SHORTEST, FOREST = "graph.shortest_path", "graph.minimum_spanning_forest"
MAX_WEIGHT = 2 ** 53                     # far inside i64; keeps every sum exact

NODE = r"[A-Za-z0-9]{1,3}"
ARROW = r"<->|↔|->|→|-|–"
EDGE = re.compile(r"(?<![A-Za-z0-9.])(?P<a>%s)\s*(?P<op>%s)\s*(?P<b>%s)(?![A-Za-z0-9])"
                  r"(?:\s*[:=(]\s*|\s+(?:with\s+)?(?:weight|cost|length)\s*[:=]?\s*|\s+)"
                  r"(?P<w>-?\d+(?:\.\d+)?)(?:\s*\))?(?![\w])(?!\.\d)" % (NODE, ARROW, NODE))
JOIN = re.compile(r"\s*(?:,\s*and|,|;|and)?\s*")       # between two edges of one list: a comma, "and", or a space
DIRECTED_OPS = {"->", "→"}

SP_CUE = re.compile(r"\bshortest\s+(?:path|distance|route)\b|\bdijkstra\b", re.I)
MST_CUE = re.compile(r"\bminimum\s+spanning\s+(?:tree|forest)\b|\bmst\b", re.I)
ENDPOINTS = re.compile(r"\bfrom\s+(%s)\s+to\s+(%s)\b|\bbetween\s+(%s)\s+and\s+(%s)\b" % (NODE, NODE, NODE, NODE))
# words that change the question into one the native request cannot carry, or ask for something else
OTHER = re.compile(
    r"\b(?:write|function|implement\w*|code|program\w*|python|javascript|java|pseudo-?code|c\+\+|explain\w*|why|"
    r"prove|how\s+does|how\s+do|longest|maximum|max|second|k\s+shortest|all\s+(?:paths|shortest)|how\s+many|"
    r"number\s+of|count|hops?|fewest|unweighted|without|except|avoid\w*|not|closed|blocked|remov\w*|delet\w*|"
    r"add\w*|if|suppose|assum\w*|after|before|through|via|must|only|at\s+most|at\s+least|exactly|bottleneck|"
    r"widest|minimax|product|probabilit\w*|reliab\w*|capacit\w*|flow|cut|degree|nodes?|vertex|vertices|or|"
    r"each|every|other|minus|plus|times|double\w*|half|toll|traffic|time|hours?|minutes?)\b", re.I)


def platform_key():
    """<os>-<arch> as the veri7vn package names its binary folders: darwin-arm64, linux-x86_64"""
    arch = platform.machine().lower()
    arch = {"aarch64": "arm64", "amd64": "x86_64", "x64": "x86_64"}.get(arch, arch)
    return platform.system().lower() + "-" + arch


def extension_path():
    local = HERE / "bin" / "oracle_native.so"
    if local.is_file():
        return local
    env = os.environ.get(ENV)
    if env:
        return Path(env)
    raise FileNotFoundError("oracle_native.so not found: put it at %s or set %s" % (local, ENV))


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_native(path=None, manifest=None):
    """load oracle_native from path after checking its SHA-256 against the manifest; raise if it does not match"""
    path = Path(path or extension_path())
    m = manifest or json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    want = (((m.get("store") or {}).get("native_extension") or {}).get("sha256") or {}).get(platform_key())
    if not want:
        raise RuntimeError("manifest records no oracle_native SHA-256 for %s; refusing to start" % platform_key())
    got = sha256(path)
    if got != want:
        raise RuntimeError("oracle_native at %s has SHA-256 %s, manifest says %s; refusing to start" % (path, got, want))
    spec = importlib.util.spec_from_file_location("oracle_native", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)                     # not placed in sys.modules: the host's own import is untouched
    ops = {op.get("id") for op in json.loads(mod.reasoning_catalog()).get("operations", [])}
    if not {SHORTEST, FOREST} <= ops:
        raise RuntimeError("oracle_native lacks %s; build it with --features reasoning" % ", ".join(sorted({SHORTEST, FOREST} - ops)))
    return mod, got


def parse_edges(t):
    """the one run of stated edges in t: (edges, start, end), edges as (a, op, b, weight-text); None when the edges
    are not one contiguous comma/and-separated list, or there are none"""
    found = list(EDGE.finditer(t))
    if not found:
        return None
    for prev, nxt in zip(found, found[1:]):
        if not JOIN.fullmatch(t[prev.end():nxt.start()]):
            return None                              # two separate edge lists, or edges inside other text
    return [(m["a"], m["op"], m["b"], m["w"]) for m in found], found[0].start(), found[-1].end()


def edge_text(a, op, b, w):
    return "%s%s%s %d" % (a, op, b, w)


class AlgorithmsNativeOrgan:
    def __init__(self, extension=None):
        self.native, self.extension_sha256 = load_native(extension)
        self.lock = threading.Lock()

    def _say(self, kind, text, value=None, status="answered"):
        return {"kind": kind, "status": status, "response": text, "value": value}

    def _call(self, operation, arguments):
        req = json.dumps({"operation": operation, "arguments": arguments}, separators=(",", ":"))
        with self.lock:
            return json.loads(self.native.reasoning_call(req))

    def answer(self, text, session_id="default"):
        r = self._answer(text)
        if r is not None and r["status"] != "answered" and not short_direct(text):
            return None                              # narrow_v1: an organ declines only a short direct question
        return r

    def _answer(self, text):
        t = " ".join(str(text or "").split())
        sp, mst = bool(SP_CUE.search(t)), bool(MST_CUE.search(t))
        if sp == mst:
            return None                              # neither question, or both at once
        parsed = parse_edges(t)
        if parsed is None:
            return None                              # no stated graph: perhaps a real-world route; the head's
        raw, s, e = parsed
        rest = t[:s] + " EDGES " + t[e:]             # the question with its edge list taken out
        if narrative(rest) or OTHER.search(rest):
            return None
        ends = list(ENDPOINTS.finditer(rest))
        if len(ends) > 1:
            return None
        bare = ENDPOINTS.sub(" ", rest)
        if re.search(r"\d", bare) or (re.search(r"\bundirected\b", rest, re.I) and any(op in DIRECTED_OPS for _, op, _, _ in raw)):
            return None
        if re.search(r"(?<![A-Za-z])directed\b", rest, re.I) and any(op not in DIRECTED_OPS for _, op, _, _ in raw):
            return None                              # "directed graph" with "A-B" edges: direction unknown
        if any("." in w for _, _, _, w in raw):
            return None                              # the native operations take integer weights only
        edges = [(a, op, b, int(w)) for a, op, b, w in raw]
        if any(abs(w) > MAX_WEIGHT for *_, w in edges):
            return None
        names = []
        for a, _, b, _ in edges:
            for n in (a, b):
                if n not in names:
                    names.append(n)
        index = {n: i for i, n in enumerate(names)}
        if sp:
            return self._shortest(edges, names, index, ends[0] if ends else None)
        return self._forest(edges, names, index, ends)

    def _shortest(self, edges, names, index, ends):
        if ends is None:
            return self._say("underspecified", "I need the start and end nodes (\"from A to D\") to run that; I won't assume them.",
                             status="withheld")
        src, dst = (ends.group(1), ends.group(2)) if ends.group(1) else (ends.group(3), ends.group(4))
        for n in (src, dst):
            if n not in index:
                if not re.fullmatch(r"[A-Z0-9]{1,3}", n):
                    return None                      # "from home to work": not a node name, not this question
                return self._say("no_node", "%s isn't a node in the edges you gave." % n, status="withheld")
        if any(w < 0 for *_, w in edges):
            return self._say("negative", "Dijkstra doesn't apply with negative edge weights; I won't give a result it can't guarantee.",
                             status="withheld")
        arcs, origin = [], []
        for k, (a, op, b, w) in enumerate(edges):
            arcs.append([index[a], index[b], w])
            origin.append(k)
            if op not in DIRECTED_OPS:
                arcs.append([index[b], index[a], w])
                origin.append(k)
        args = {"vertices": len(names), "edges": arcs, "source": index[src], "target": index[dst]}
        try:
            res = self._call(SHORTEST, args)
            check_path_reply(args, res)
        except Exception:  # noqa: BLE001 - a refused or ill-fitting native reply is a decline to the head
            return None
        directed = any(op in DIRECTED_OPS for _, op, _, _ in edges)
        shape = "%d %s edges" % (len(edges), "stated" if directed else "undirected")
        if res["outcome"] == "unreachable":
            return self._say("unreachable", "There is no path from %s to %s in the graph you gave (Dijkstra on the stated graph, "
                             "%s; the set of nodes reachable from %s was checked closed under the edges and does not contain %s)."
                             % (src, dst, shape, src, dst))
        if res["outcome"] != "finite":
            return None
        route = [src] + [names[arcs[i][1]] for i in res["path"]]
        d = int(res["distance"])
        return self._say("shortest_path", "The shortest path length is %d, via %s (Dijkstra on the stated graph, %s; the path "
                         "and its distance labels passed an independent certificate check)." % (d, " → ".join(route), shape), d)

    def _forest(self, edges, names, index, ends):
        if ends or any(op in DIRECTED_OPS for _, op, _, _ in edges):
            return None                              # endpoints or arrows: not a spanning-tree question we can carry
        args = {"vertices": len(names), "edges": [[index[a], index[b], w] for a, _, b, w in edges]}
        try:
            res = self._call(FOREST, args)
            check_forest_reply(args, res)
        except Exception:  # noqa: BLE001
            return None
        total = int(res["total_weight"])
        used = ", ".join(edge_text(*edges[i]) for i in res["edge_ids"])
        how = ("Kruskal on the %d edges you gave; the forest's coverage and cycle optimality passed an independent check"
               % len(edges))
        if not res["connected"]:
            return self._say("disconnected", "The graph you gave isn't connected (it falls into %d separate parts), so it has no "
                             "spanning tree, only a spanning forest, which totals %d using %s (%s)." % (res["components"], total, used, how))
        return self._say("mst", "The minimum spanning tree weight is %d, using %s (%s)." % (total, used, how), total)


def check_path_reply(args, res):
    """the reply fits the request: a finite path walks the sent arcs from source to target and sums to the distance;
    an unreachable set contains the source, not the target, and is closed under the arcs. Rust checked optimality."""
    n, arcs = args["vertices"], args["edges"]
    outcome = res.get("outcome")
    if outcome == "finite":
        v, total = args["source"], 0
        if len(res["path"]) > n:
            raise ValueError("oversized path")
        for i in res["path"]:
            if not (0 <= i < len(arcs)) or arcs[i][0] != v:
                raise ValueError("path leaves the stated edges")
            v, total = arcs[i][1], total + arcs[i][2]
        labels = res["labels"]
        if (v != args["target"] or total != int(res["distance"]) or len(labels) != n
                or labels[args["source"]] != "0" or labels[args["target"]] != res["distance"]):
            raise ValueError("finite certificate does not fit the request")
    elif outcome == "unreachable":
        r = res["reachable"]
        if (len(r) != n or not r[args["source"]] or r[args["target"]]
                or any(r[a] and not r[b] for a, b, _ in arcs)):
            raise ValueError("unreachable certificate does not fit the request")
    else:
        raise ValueError("outcome %r not expected for nonnegative weights" % outcome)


def check_forest_reply(args, res):
    """the reply fits the request: distinct known edge IDs, V - components of them, summing to total_weight"""
    n, edges, ids = args["vertices"], args["edges"], res["edge_ids"]
    if (res.get("schema") != "oracle-minimum-spanning-forest-v1" or len(set(ids)) != len(ids)
            or any(not (0 <= i < len(edges)) for i in ids) or len(ids) != n - res["components"]
            or sum(edges[i][2] for i in ids) != int(res["total_weight"])
            or res["connected"] != (n > 0 and res["components"] == 1)):
        raise ValueError("forest reply does not fit the request")
