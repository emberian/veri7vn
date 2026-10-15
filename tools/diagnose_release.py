"""Check required stores and relation-domain declarations without mutating upstream."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
UP = ROOT / "upstream"

def main():
    domains = {d["id"] for d in json.loads((UP / "root/relstore/relation_domains_v2.json").read_text())}
    missing = []
    for mp in sorted((UP / "root/specialists").glob("*/manifest.json")):
        m = json.loads(mp.read_text())
        if m.get("organ", {}).get("class") in ("RelationOrganV2", "RelationOrganV2G"):
            did = m["organ"]["init"]["domain"]
            if did not in domains: missing.append({"specialist": m["id"], "domain": did})
    result = {
        "revision": subprocess.check_output(["git", "-C", str(UP), "rev-parse", "HEAD"], text=True).strip(),
        "required_missing": [p for p in ("root/relstore/relations_v2.sqlite3", "root/relstore/names_v1.sqlite3",
                                            "root/relstore/linking_src/labels.tsv", "root/relstore/linking_src/aliases.tsv")
                             if not (UP / p).exists()],
        "unregistered_domains": missing,
        "v2_description": "v1 plus 27.7M facts over 2,456 more properties (upstream w524 docstring)",
        "names_description": "English labels/aliases and sitelink counts; builder inputs absent",
        "interpretation": "Release completeness failure; successful published hash verification does not check these dependencies.",
    }
    (ROOT / "audit/results/availability.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"missing_files": result["required_missing"], "missing_domains": len(missing)}, indent=2))

if __name__ == "__main__": main()
