#!/usr/bin/env python3
"""Untrusted offline builder for immutable native reader tables (format version 1).

This is not a trusted recognizer or a runtime pickle loader. It invokes the
pinned Reader6/Reader7 learning functions on plain training JSON, without
constructing KQA or Engine, and emits explicit JSON data for the native image
builder. No question is executed. Source code imports are build-time execution;
use a reviewed, pinned source directory. Existing pickle caches are never read.

Release build:
  PYTHONHASHSEED=0 python3 -B native/tools/export_reader_tables.py \
    --source-dir var/runtime-architecture-20261028/source/workbench/swarm \
    --train /data/train.json --kb /data/kb.json --out /release/reader.json

Deterministic small input, requiring no corpus or upstream imports:
  python3 -B native/tools/export_reader_tables.py --fixture --out /tmp/reader.json

--input-json accepts an already explicit version-1 export and canonicalizes it.
The native importer validates its row/skeleton structure and configured limits.
The exporter preserves all skeleton counts, exact and fallback keys, aliases,
word sets, outer X shapes and allowed answer forms. Clause patches, analogy
indexes and per-question execution caches are not exported by this version.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import os
from pathlib import Path
import sys
import tempfile

FORMAT = "oracle-reader-tables"
VERSION = 1
UNEXPORTED = ["clause101 patches", "analogy index (derivable from outer rows and shapes)",
              "per-question execution cache"]


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def base_export():
    return {"format": FORMAT, "version": VERSION, "metadata": {},
            "policy": {"min_skeleton": 2, "dominance": 0.5, "all_replicated": False,
                       "outer_replicated": True, "form_check": True, "asking_check": True},
            "templates": [], "shapes": [], "aliases": [], "words": [], "forms": []}


def add_table(out, family, level, table):
    for template, hit in table.items():
        for skeleton, support in hit.items():
            out["templates"].append({"family": family, "level": level, "template": template,
                                     "skeleton": json.loads(skeleton), "support": support})


def learn(source_dir, train_path, kb_path):
    if os.environ.get("PYTHONHASHSEED") != "0":
        raise ValueError("release learning requires PYTHONHASHSEED=0 for stable source set iteration")
    source_dir = Path(source_dir).resolve()
    source_names = ["reader_cache10.py", "reader_v4.py", "reader_v6.py", "reader_v7.py",
                    "clause101.py", "steps.py", "steps_kb.py"]
    source_hashes = {name: sha(source_dir / name) for name in source_names}
    # Prevent bytecode writes even when a source directory is read-only.
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(source_dir))
    r6 = importlib.import_module("reader_v6")
    r7 = importlib.import_module("reader_v7")
    r4 = importlib.import_module("reader_v4")
    for module in (r4, r6, r7):
        if Path(module.__file__).resolve().parent != source_dir:
            raise ValueError("reader import escaped pinned source directory")
    training_bytes = Path(train_path).read_bytes()
    training_sha256 = hashlib.sha256(training_bytes).hexdigest()
    train = json.loads(training_bytes)
    del training_bytes
    if not isinstance(train, list) or any(not isinstance(x, dict) or not x.get("program")
                                         or not isinstance(x.get("question"), str) for x in train):
        raise ValueError("training JSON must be question/program records, with nonempty programs")
    # Same sequence as reader_cache10.build; R7 has already installed the
    # possessive normalizer before either level is learned. Aliases are already
    # the canonical (phrase, kind)->normalized literal mapping; KQA is unneeded.
    r6.OPS.clear()
    r6.OPS.update(r6.mine_operators(train))
    aliases = r6.mine_aliases(train)
    out = base_export()
    for level in (0, 1):
        whole, _used = r6.learn6(train, aliases, keys=bool(level))
        add_table(out, "whole", level, whole)
    for level in (0, 1):
        fragment, outer, segment, _used = r7.learn7(train, aliases, keys=bool(level))
        for family, table in (("fragment", fragment), ("outer", outer), ("segment", segment)):
            add_table(out, family, level, table)
        for template, hit in outer.xt.items():
            for roots, support in hit.items():
                out["shapes"].append({"level": level, "template": template,
                                      "roots": list(roots), "support": support})
    out["aliases"] = [{"phrase": phrase, "kind": kind, "canonical": target}
                      for (phrase, kind), target in aliases.items()]
    out["words"] = [{"category": category, "word": word}
                    for category, words in (("operator", r6.OPS), ("keep", r6.KEEPW), ("glue", r7.GLUE))
                    for word in words]
    out["forms"] = [{"opening": opening, "kinds": sorted(kinds)}
                    for opening, kinds in r7.Forms(train).allowed.items()]
    out["policy"] = {"min_skeleton": r6.MIN_SKEL, "dominance": r7.DOM,
                     "all_replicated": r7.ALLREP, "outer_replicated": r7.OUTREP,
                     "form_check": r7.FORMCHECK, "asking_check": r7.ASKING_CHECK}
    out["metadata"] = {"builder": "export_reader_tables.py", "builder_sha256": sha(__file__),
                       "source_sha256": source_hashes, "train_sha256": training_sha256,
                       "kb_sha256": sha(kb_path), "training_rows": len(train),
                       "python_hash_seed": "0", "python_version": sys.version, "unexported": UNEXPORTED,
                       "environment": {k: v for k, v in sorted(os.environ.items()) if k.startswith("O7_")},
                       "normalization": "reader7_possessive" if r7.POSS else "reader4",
                       "fallback_families": sorted(r7.FALLBACK),
                       "plural": r7.PLURAL, "nested": r7.NESTED}
    if source_hashes != {name: sha(source_dir / name) for name in source_names}:
        raise ValueError("reader sources changed during the offline build")
    return out


def fixture():
    out = base_export()
    out["metadata"] = {"fixture": True, "normalization": "reader7_possessive", "unexported": UNEXPORTED}
    slot = ["@", "E", 1, ""]
    program = [{"function": "Find", "dependencies": [], "inputs": [slot]},
               {"function": "What", "dependencies": [0], "inputs": []}]
    add_table(out, "whole", 0, {"who is E1": {json.dumps(program): 3}})
    out["words"] = [{"category": "glue", "word": "the"}, {"category": "keep", "word": "many"}]
    out["aliases"] = [{"phrase": "the bard", "kind": "E", "canonical": "william shakespeare"}]
    out["forms"] = [{"opening": "who", "kinds": ["entity"]}]
    return out


def canonicalize(out):
    if out.get("format") != FORMAT or out.get("version") != VERSION:
        raise ValueError("unsupported reader export format/version")
    for key in ("templates", "shapes", "aliases", "words", "forms"):
        if not isinstance(out.get(key), list):
            raise ValueError("missing reader row array: " + key)
        out[key].sort(key=lambda row: json.dumps(row, sort_keys=True, ensure_ascii=True, separators=(",", ":")))
    return json.dumps(out, sort_keys=True, ensure_ascii=True, separators=(",", ":"), allow_nan=False) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--fixture", action="store_true")
    mode.add_argument("--input-json", type=Path)
    mode.add_argument("--train", type=Path)
    parser.add_argument("--source-dir", type=Path)
    parser.add_argument("--kb", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.fixture:
        out = fixture()
    elif args.input_json:
        with args.input_json.open(encoding="utf-8") as source:
            out = json.load(source)
    else:
        if not args.source_dir or not args.kb:
            parser.error("--train requires --source-dir and --kb")
        out = learn(args.source_dir, args.train, args.kb)
    # A fixture can be bound to a concrete KB for the production image importer.
    if args.fixture and args.kb:
        out["metadata"]["kb_sha256"] = sha(args.kb)
    encoded = canonicalize(out).encode("utf-8")
    # Atomic offline output, refusing to replace an existing release resource.
    args.out.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=args.out.parent, prefix=".reader-", delete=False) as target:
            temporary = Path(target.name)
            target.write(encoded)
            target.flush()
            os.fsync(target.fileno())
        os.link(temporary, args.out)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(json.dumps({"format": FORMAT, "version": VERSION, "sha256": hashlib.sha256(encoded).hexdigest(),
                      "bytes": len(encoded), "rows": {key: len(out[key]) for key in
                      ("templates", "shapes", "aliases", "words", "forms")}}, sort_keys=True))


if __name__ == "__main__":
    main()
