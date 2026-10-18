#!/usr/bin/env python3
"""fetch - UNTRUSTED store and session-state shim for the stores binary (var/stores/bin/stores).

The binary starts this process and speaks JSON lines with it: one request {"op": ...} in, one reply out.
It opens the two shipped stores read-only (file:...?immutable=1) and never writes them:
  nutrition_v1.sqlite3  (USDA SR Legacy, cooking*)       site_fresh.sqlite3 (warehouse*)
Every row reply carries "complete": true, the shim's claim that the query had no LIMIT and returned every stored
row it names; the HOL kernel declines without that claim. REAL columns travel as Python's repr of the stored float
(the shortest decimal that reads back to it), which the binary parses as an exact fraction.

It also keeps the warehouse sessions: a JSON file (--state, default var/stores/state/sessions.json) holding
{"sessions": {session_id: state}, "orders": [...]}. The state itself is computed by the verified kernel; this file
only stores what the binary hands it.

Nothing here decides an answer. Assumed and not checked: the stores are the shipped files; sqlite's scan order for
"ORDER BY rowid" is store order (the organ reads the same tables in the same order)."""
import json
import os
import sqlite3
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"


def ro(path):
    return sqlite3.connect("file:%s?immutable=1" % path, uri=True, check_same_thread=False)


def num(x):
    return repr(float(x)) if isinstance(x, float) else str(x)


class Shim:
    def __init__(self, nutrition, site, state):
        self.np, self.sp, self.state_path = nutrition, site, Path(state)
        self._n = self._s = None
        self.state = None

    @property
    def n(self):
        if self._n is None:
            self._n = ro(self.np)
        return self._n

    @property
    def s(self):
        if self._s is None:
            self._s = ro(self.sp)
        return self._s

    def load_state(self):
        if self.state is None:
            try:
                self.state = json.loads(self.state_path.read_text(encoding="utf-8"))
            except FileNotFoundError:
                self.state = {"sessions": {}, "orders": []}
        return self.state

    def save_state(self):
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.state_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.state, sort_keys=True), encoding="utf-8")
        os.replace(tmp, self.state_path)

    def op(self, r):
        o = r["op"]
        q = self.n.execute if o in ("foods", "nut", "portions") else self.s.execute
        if o == "foods":
            rows = [[f, d] for f, d in q("SELECT fdc_id, description FROM foods ORDER BY rowid")]
        elif o == "nut":
            fids = [int(x) for x in r["fdc"]]
            rows = [[f, num(a), u] for f, a, u in q(
                "SELECT fdc_id, amount, unit FROM nut WHERE key=? AND fdc_id IN (%s) ORDER BY rowid" % ",".join("?" * len(fids)),
                (r["key"], *fids))] if fids else []
        elif o == "portions":
            rows = [[l, num(g)] for l, g in q("SELECT label, grams FROM portions WHERE fdc_id=? ORDER BY rowid", (int(r["fdc"]),))]
        elif o == "site":
            meta = dict(q("SELECT key, value FROM meta"))
            return {"now": meta["now"], "fresh": int(meta["fresh_minutes"]), "complete": True,
                    "items": [[a, b] for a, b in q("SELECT sku, name FROM items ORDER BY rowid")],
                    "zones": [[a, b] for a, b in q("SELECT id, name FROM zones ORDER BY rowid")]}
        elif o == "events":
            rows = [[t, d] for t, d in q("SELECT ts, delta FROM stock_events WHERE sku=? ORDER BY rowid", (r["sku"],))]
        elif o == "item":
            rows = [list(x) for x in q("SELECT i.reorder_level, b.label, b.position, z.name, b.zone_id FROM items i "
                                       "JOIN bins b ON b.id=i.bin_id JOIN zones z ON z.id=b.zone_id WHERE i.sku=?", (r["sku"],))]
        elif o == "next_bin":
            nb = [list(x) for x in q("SELECT id, label FROM bins WHERE zone_id=? AND position=? ORDER BY rowid",
                                     (int(r["zone"]), int(r["pos"])))]
            rows = []
            for bid, lab in nb[:1]:
                its = [[n, [d for (d,) in q("SELECT delta FROM stock_events WHERE sku=? ORDER BY rowid", (s,))]]
                       for s, n in q("SELECT sku, name FROM items WHERE bin_id=? ORDER BY name", (bid,))]
                rows.append([lab, its])
        elif o == "sensor":
            rows = []
            for sid, u, lo, hi in q("SELECT id, unit, lo, hi FROM sensors WHERE zone_id=? AND kind=? ORDER BY rowid",
                                    (int(r["zone"]), r["kind"])):
                rd = [[t, num(v)] for t, v in q("SELECT ts, value FROM readings WHERE sensor_id=? ORDER BY rowid", (sid,))]
                rows.append([u, num(lo), num(hi), rd])
        elif o == "zone_sensors":
            rows = []
            for kind, sid, u, lo, hi in q("SELECT kind, id, unit, lo, hi FROM sensors WHERE zone_id=? ORDER BY rowid",
                                          (int(r["zone"]),)):
                rd = [[t, num(v)] for t, v in q("SELECT ts, value FROM readings WHERE sensor_id=? ORDER BY rowid", (sid,))]
                rows.append([kind, u, num(lo), num(hi), rd])
        elif o == "all_items":
            ev = {}
            for s, d in q("SELECT sku, delta FROM stock_events ORDER BY rowid"):
                ev.setdefault(s, []).append(d)
            rows = [[n, rl, ev.get(s, [])] for s, n, rl in q("SELECT sku, name, reorder_level FROM items ORDER BY rowid")]
        elif o == "self":
            kinds = sorted({k for (k,) in q("SELECT DISTINCT kind FROM sensors")})
            return {"items": q("SELECT count(*) FROM items").fetchone()[0], "zones": q("SELECT count(*) FROM zones").fetchone()[0],
                    "sensors": q("SELECT count(*) FROM sensors").fetchone()[0], "kinds": kinds, "complete": True}
        elif o == "kind_zones":
            rows = [z for (z,) in q("SELECT z.name FROM sensors s JOIN zones z ON z.id=s.zone_id WHERE s.kind=? ORDER BY z.id",
                                    (r["kind"],))]
        elif o == "state_get":
            return {"state": self.load_state()["sessions"].get(r["session"]), "complete": True}
        elif o == "state_put":
            st = self.load_state()
            st["sessions"][r["session"]] = r["state"]
            if r.get("order"):
                st["orders"].append(r["order"])
            self.save_state()
            return {"ok": True, "complete": True}
        else:
            raise ValueError("unknown op %r" % o)
        return {"rows": rows, "complete": True}


def main():
    a = sys.argv[1:]
    opt = {"--nutrition": str(SPEC / "cooking/nutrition_v1.sqlite3"), "--site": str(SPEC / "warehouse/site_fresh.sqlite3"),
           "--state": str(REPO / "var/stores/state/sessions.json")}
    while a:
        k, v, a = a[0], a[1], a[2:]
        if k not in opt:
            sys.exit("fetch: unknown option %s" % k)
        opt[k] = v
    shim = Shim(opt["--nutrition"], opt["--site"], opt["--state"])
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            out = shim.op(json.loads(line))
        except Exception as e:  # noqa: BLE001 - reported to the binary, which declines
            out = {"error": "%s: %s" % (type(e).__name__, e), "complete": False}
        sys.stdout.write(json.dumps(out) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
