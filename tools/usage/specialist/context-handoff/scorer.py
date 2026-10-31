#!/usr/bin/env python3
"""Independent literal-gold scorer; no native transition implementation imported."""
import argparse
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from context_handoff import Client


def score(expected, reply):
    scalar = reply.get("scalar")
    value = scalar.get("value", {}) if type(scalar) is dict else {}
    right = (reply.get("status") == expected["status"] and value.get("number") == expected["number"]
             and (expected["number"] is None or value.get("origin") == expected["origin"]))
    return {"right": right, "wrong": not right and reply.get("status") == "answered",
            "false_yes": expected["status"] == "withheld" and reply.get("status") == "answered"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--prefix", required=True, help="fresh conversation/request prefix")
    parser.add_argument("--tenant", default="context-panel")
    args = parser.parse_args()
    client = Client(args.url, args.tenant, args.prefix)
    client.discover()
    panel = json.loads(Path(__file__).with_name("panel.json").read_text())
    records = []
    totals = {"right": 0, "wrong": 0, "false_yes": 0, "execution_errors": 0}
    for version, case in enumerate(panel["cases"]):
        try:
            turn = client.prepare(f"{args.prefix}-{version}", version, case["command"])
            reply = client.send(turn)
            replay = client.send(turn)
            if reply["core_reply_json"] != replay["core_reply_json"]:
                raise ValueError("exact retained retry changed")
            result = score(case["expect"], reply)
        except Exception as error:
            result = {"execution_errors": 1, "detail": str(error)}
        records.append({"id": case["id"], **result})
        for key in totals:
            totals[key] += int(result.get(key, 0))
    print(json.dumps({"scope": panel["scope"], "totals": totals, "cases": records}, indent=2))
    return int(totals["right"] != len(records) or totals["wrong"] or totals["false_yes"] or totals["execution_errors"])


if __name__ == "__main__":
    raise SystemExit(main())
