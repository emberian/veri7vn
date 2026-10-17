#!/usr/bin/env python3
"""Transcription check for the conversation kernel's tables (scout conversation).

The HOL constants in Converse.thy (predicate_of, referential_nps, summarize's
wording) are transcribed from the shipped meta-fold runtime
upstream/root/wander-train/oracle_release_runtime_ao.py. That module imports
the whole letter chain, so instead of importing it this script parses the two
dict/tuple literals out of its source text (read-only), parses the HOL text,
and fails on any difference, so the tables cannot drift silently.

  python3 src/extract/converse/tables_check.py     # prints one line per table, exit 1 on a mismatch
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
if not (REPO / "upstream").exists():
    REPO = Path("/Users/ember/dev/o7vn")          # a scout worktree: upstream lives in the main checkout
AO = (REPO / "upstream/root/wander-train/oracle_release_runtime_ao.py").read_text(encoding="utf-8")
THY = (Path(__file__).resolve().parent / "Converse.thy").read_text(encoding="utf-8")
FAILS: list[str] = []


def organ_predicate_of() -> dict[str, str]:
    """the PREDICATE_OF dict literal from the organ's source ({t} appears
    inside the template strings, so the block ends at the line that is just })"""
    m = re.search(r"PREDICATE_OF\s*=\s*\{(.*?)\n\}", AO, re.S)
    rows = re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', m.group(1))
    return dict(rows)


def organ_referential() -> list[str]:
    """the three noun phrases _topic_or_referent treats as references"""
    m = re.search(r'in \("the big one", "the small one", "the other one"\)', AO)
    return ["the big one", "the small one", "the other one"] if m else []


def thy_predicate_of() -> dict[str, tuple[str, str]]:
    """(key, prefix, suffix) rows from the HOL literal, keyed like the organ"""
    m = re.search(r"predicate_of =\s*\[(.*?)\]", THY, re.S)
    rows: dict[str, tuple[str, str]] = {}
    for key, pre, suf in re.findall(r"\(STR ''([^'']*)'', STR ''([^'']*)'', STR ''([^'']*)''\)", m.group(1)):
        rows[key] = (pre, suf)
    return rows


def thy_referential() -> list[str]:
    m = re.search(r"referential_nps = \[(.*?)\]", THY, re.S)
    return re.findall(r"STR ''([^'']*)''", m.group(1))


def check(name: str, ok: bool, detail: str = "") -> None:
    print(f"{name}: {'OK' if ok else 'DIFFERS ' + detail}")
    if not ok:
        FAILS.append(name)


def main() -> int:
    organ = organ_predicate_of()
    thy = thy_predicate_of()
    # every organ row must appear with the template split at the {t} hole
    bad = {k: (organ[k], thy.get(k)) for k in organ
           if k not in thy or thy[k] != tuple(organ[k].split("{t}"))}
    check(f"predicate_of rows ({len(organ)})", not bad and len(thy) == len(organ), str(bad))

    check("referential_nps", thy_referential() == organ_referential(),
          f"{thy_referential()} vs {organ_referential()}")

    # summarize's wording, from the organ's f-string
    m = re.search(r'f"Summarize \{t\}\."', AO)
    m2 = re.search(r"summarize t = STR ''Summarize '' \+ t \+ STR ''\.''", THY)
    check("summarize wording", bool(m and m2))

    if FAILS:
        print(f"tables_check: {len(FAILS)} table(s) differ", file=sys.stderr)
        return 1
    print("tables_check: all tables match the organ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
