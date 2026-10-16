#!/usr/bin/env python3
"""Pin the installed narrow numeral theory closure; hashes locate source, not proof."""
import argparse
import hashlib
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
FILES = [f"src/HOL/Library/{name}.thy" for name in (
    "Code_Target_Numeral", "Code_Target_Nat", "Code_Abstract_Nat", "Code_Target_Int")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--isabelle-home", default=os.environ.get(
        "VERI7VN_ISABELLE_HOME", "/Applications/Isabelle2026-RC1.app/Contents/Resources"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    home = Path(args.isabelle_home).resolve()
    records = [{"path": name, "sha256": hashlib.sha256((home/name).read_bytes()).hexdigest()}
               for name in FILES]
    pin = {"format": "veri7vn.codegen-sources/0", "installed_root": str(home),
           "theory_files": records,
           "source_identity": hashlib.sha256(json.dumps(records, sort_keys=True,
               separators=(",", ":")).encode()).hexdigest()}
    for name in FILES:
        if (HERE / "installed" / Path(name).name).read_bytes() != (home/name).read_bytes():
            raise SystemExit("Local numeral mirror differs from installed source: " + name)
    if (HERE / "installed" / "COPYRIGHT").read_bytes() != (home/"COPYRIGHT").read_bytes():
        raise SystemExit("Upstream copyright notice differs")
    text = json.dumps(pin, indent=2) + "\n"
    target = HERE / "installed-sources.json"
    if args.check:
        if target.read_text() != text:
            raise SystemExit("Installed numeral source pin changed; requalify code setup")
    else:
        target.write_text(text)
    print("Narrow numeral source pin:", pin["source_identity"])


if __name__ == "__main__":
    main()
