"""Lift relation-reader declarations; share pure matches without reordering routes.

The residual database, domain and arbitration operations are deliberately explicit
in the IR, but are not yet executed here. This is a compiler for the MATCH stage.
"""
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / "upstream"


def lift(root=UPSTREAM):
    root = Path(root)
    sys.path.insert(0, str(root / "root/wander-train"))
    import relation_readers_v1 as readers
    nodes, ids, programs, sources = [], {}, [], {}
    def source(p):
        sources[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    source(root / "root/wander-train/relation_readers_v1.py")
    source(root / "root/wander-train/relation_spec_v2.py")
    source(root / "root/wander-train/relation_spec_v1.py")
    domains_path = root / "root/relstore/relation_domains_v2.json"
    domains = {d["id"]: d for d in json.loads(domains_path.read_text())}
    source(domains_path)
    for mp in sorted((root / "root/specialists").glob("*/manifest.json")):
        manifest = json.loads(mp.read_text())
        if manifest.get("organ", {}).get("class") not in ("RelationOrganV2", "RelationOrganV2G"):
            continue
        source(mp)
        source(mp.parent / (manifest["organ"]["module"] + ".py"))
        init = manifest["organ"]["init"]
        rp = mp.parent / init.get("readers", "readers.json")
        pp = mp.parent / init.get("patterns", "patterns.json")
        source(rp)
        r = json.loads(rp.read_text())
        dropped = {(str(k), d, int(i)) for k, d, i in r.get("dropped", [])}
        rules = []
        for k in r["keys"]:
            key = int(k) if str(k).lstrip("-").isdigit() else k
            entry = readers.PROPS[key]
            for direction in ("fwd", "inv"):
                for i, pattern in enumerate(entry.get(direction, [])):
                    regex = "^" + pattern + "$"
                    if regex not in ids:
                        ids[regex] = len(nodes)
                        nodes.append({"op": "regex_match", "pattern": regex, "flags": 0})
                    rules.append({"match": ids[regex], "reader": str(k), "direction": direction,
                                  "ordinal": i, "property": int(entry.get("prop", key)),
                                  "dropped": (str(k), direction, i) in dropped})
        if pp.exists():
            source(pp)
        programs.append({"id": manifest["id"], "domain": init["domain"],
                         "domain_predicate": domains.get(init["domain"]),
                         "manifest_domain": manifest.get("domain"), "rules": rules,
                         "post_guard": "pronoun_title" if manifest["organ"]["class"] == "RelationOrganV2G" else None,
                         "fallback_patterns": json.loads(pp.read_text()) if pp.exists() else {},
                         "accept": manifest["accept"],
                         "residual_pipeline": ["kind_conflict", "link_slot", "popularity_dominance",
                                               "domain_membership", "forward_consensus_or_inverse_unique",
                                               "restate_guard", "temporal_guard", "render_receipt"]})
    return {"schema": "o7ir.relation-match.v1", "semantics": "ordered matches; no database execution",
            "sources": sources, "match_nodes": nodes, "specialists": programs}


def check_certificate(ir, root=UPSTREAM):
    """Translation validation: reconstruct every ordered source reader occurrence.

    Uses source declarations directly, independently of lift's node assignment.
    Hoisting is valid only for the deterministic, effect-free regex match stage.
    """
    root = Path(root)
    import relation_readers_v1 as readers
    expected_ids = []
    for mp in sorted((root / "root/specialists").glob("*/manifest.json")):
        manifest = json.loads(mp.read_text())
        if manifest.get("organ", {}).get("class") in ("RelationOrganV2", "RelationOrganV2G"):
            expected_ids.append(manifest["id"])
    if [s["id"] for s in ir["specialists"]] != expected_ids:
        raise ValueError("Specialist list differs from source")
    for path, sha in ir["sources"].items():
        if hashlib.sha256((root / path).read_bytes()).hexdigest() != sha:
            raise ValueError(f"Source changed: {path}")
    for specialist in ir["specialists"]:
        base = root / "root/specialists" / specialist["id"]
        manifest = json.loads((base / "manifest.json").read_text())
        src = json.loads((base / manifest["organ"]["init"].get("readers", "readers.json")).read_text())
        dropped = {(str(k), d, int(i)) for k, d, i in src.get("dropped", [])}
        expected = []
        for key in src["keys"]:
            native_key = int(key) if str(key).lstrip("-").isdigit() else key
            p = readers.PROPS[native_key]
            for direction in ("fwd", "inv"):
                for ordinal, rx in enumerate(p.get(direction, [])):
                    expected.append((str(key), direction, ordinal, int(p.get("prop", native_key)),
                                     (str(key), direction, ordinal) in dropped, "^" + rx + "$", 0))
        actual = [(r["reader"], r["direction"], r["ordinal"], r["property"], r["dropped"],
                   ir["match_nodes"][r["match"]]["pattern"], ir["match_nodes"][r["match"]]["flags"])
                  for r in specialist["rules"]]
        if actual != expected:
            raise ValueError(f"Reader semantics changed: {specialist['id']}")
    return True


class Matcher:
    def __init__(self, ir):
        self.ir = ir
        self.regexes = [re.compile(n["pattern"], n["flags"]) for n in ir["match_nodes"]]
        # A source-occurrence index: reconstruct only matched occurrences, in
        # source order. Empty domains remain in the returned map.
        self.users = [[] for _ in self.regexes]
        for p in ir["specialists"]:
            for rank, r in enumerate(p["rules"]):
                self.users[r["match"]].append((p["id"], rank, r))

    @staticmethod
    def normalise(q):
        # This boundary remains an opaque legacy operation until lifted separately.
        import relation_spec_v2
        return relation_spec_v2.normalise(q)

    @staticmethod
    def record(rule, match, original):
        a, b = match.span("X")
        return (rule["reader"], rule["direction"], rule["ordinal"], rule["property"],
                rule["dropped"], original[a:b].strip(" \"'"))

    def legacy(self, q):
        """Unshared declaration interpreter, matching original loop nesting."""
        result = {}
        for program in self.ir["specialists"]:
            original, low = self.normalise(q)
            result[program["id"]] = found = []
            for rule in program["rules"]:
                m = self.regexes[rule["match"]].match(low)
                if m:
                    found.append(self.record(rule, m, original))
        return result

    def compiled(self, q):
        original, low = self.normalise(q)
        found = {p["id"]: [] for p in self.ir["specialists"]}
        for i, rx in enumerate(self.regexes):
            m = rx.match(low)
            if m:
                for sid, rank, rule in self.users[i]:
                    found[sid].append((rank, self.record(rule, m, original)))
        return {sid: [value for _, value in sorted(rows)] for sid, rows in found.items()}
