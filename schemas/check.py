#!/usr/bin/env python3
"""Validate descriptor syntax or run schema fixtures; never admit a capability."""

import argparse
import json
from pathlib import Path

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parent


def read_json(path):
    def unique_keys(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key!r}")
            result[key] = value
        return result

    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_keys)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("descriptors", nargs="*", type=Path,
                        help="Package descriptors; omit to check the fixture suite")
    args = parser.parse_args()
    schema = read_json(ROOT / "package.schema.json")
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    failures = 0
    if args.descriptors:
        cases = [(path, True) for path in args.descriptors]
    else:
        index = read_json(ROOT / "fixtures/index.json")
        if index["schema"] != "package.schema.json":
            raise ValueError("Fixture schema does not match the selected schema")
        cases = [(ROOT / case["file"], case["valid"]) for case in index["cases"]]
    for path, expected_valid in cases:
        try:
            errors = list(validator.iter_errors(read_json(path)))
        except (OSError, ValueError) as exc:
            failures += 1
            print(f"ERROR {path}: {exc}")
            continue
        valid = not errors
        if valid != expected_valid:
            failures += 1
            print(f"FAIL {path}: expected valid={expected_valid}, got {valid}")
            for error in errors:
                location = "/" + "/".join(map(str, error.absolute_path))
                print(f"  {location}: {error.message}")
        elif args.descriptors:
            print(f"Descriptor structure valid: {path}")
    if not args.descriptors:
        print(f"Package schema fixtures: {len(cases) - failures}/{len(cases)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
