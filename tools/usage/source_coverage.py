#!/usr/bin/env python3
"""Untrusted workflow adapter: asks native coverage executable for snapshot-scoped coverage.

Consumer documentation: tools/usage/specialist/source-coverage/README.md.
No Python completeness checker and no caller-provided 'complete' flag. The oracle-coverage executable uses oracle-core's native cursor traversal.
"""
import argparse
import json
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, help="oracle-coverage executable")
    parser.add_argument("--image", required=True)
    parser.add_argument("--image-sha256", required=True)
    parser.add_argument("--subject", action="append", required=True)
    parser.add_argument("--predicate", required=True)
    parser.add_argument("--direction", choices=["forward", "backward"], default="forward")
    parser.add_argument("--qualifiers", help="complete qualifier JSON object; omitted means all")
    parser.add_argument("--limit", type=int, default=10000)
    args = parser.parse_args()
    request = {
        "subjects": sorted(set(args.subject)), "predicate": args.predicate,
        "direction": args.direction, "qualifiers": json.loads(args.qualifiers) if args.qualifiers else None,
        "traversal_limit": args.limit}
    completed = subprocess.run([args.host, args.image, args.image_sha256],
                               input=json.dumps(request) + "\n", text=True, capture_output=True, check=True)
    print(completed.stdout, end="")


if __name__ == "__main__":
    main()
