#!/usr/bin/env python3
"""Untrusted document preparation and quotation lookup, not an entailment verifier.

Writes actual Oracle7 Passage/Question requests. Never supplies an answer,
changes a reply's status, ingests a document, or consults outside knowledge.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re

IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,80}\Z")
YESNO = re.compile(r"^(?:is|are|was|were|does|do|did|can|could|has|have|had|will|would|should)\b", re.I)


def normalize(text):
    return " ".join(text.split())


def prepare(source: Path, questions: list, conversation: str):
    """Prepare bounded UTF-8 text without truncation; each question repeats it."""
    if not IDENTIFIER.fullmatch(conversation):
        raise ValueError("invalid conversation ID")
    with source.open("rb") as stream:
        raw = stream.read(16385)
    if len(raw) > 16384:
        raise ValueError("source alone exceeds the 16 KiB request limit; choose an explicit smaller document")
    text = raw.decode("utf-8")
    if not normalize(text):
        raise ValueError("empty document")
    if not isinstance(questions, list) or not 1 <= len(questions) <= 30:
        raise ValueError("provide 1..30 questions")
    cases, warnings, seen = [], [], set()
    for item in questions:
        if not isinstance(item, dict) or set(item) != {"id", "question"}:
            raise ValueError("each question needs exactly id and question")
        ident, question = item['id'], item['question']
        if not isinstance(ident, str) or not IDENTIFIER.fullmatch(ident) or ident in seen:
            raise ValueError("question IDs must be unique valid identifiers")
        if not isinstance(question, str) or not question.strip():
            raise ValueError("empty question")
        seen.add(ident)
        if re.search(r"\bQuestion\s*:", question):
            raise ValueError("question contains a second Question: delimiter")
        surface = f"Passage: {normalize(text)} Question: {normalize(question)}"
        case = {"id": ident, "conversation_id": conversation, "text": surface}
        request = {"request_id": ident, "conversation_id": conversation, "text": surface}
        size = len(json.dumps(request, ensure_ascii=False, separators=(',', ':')).encode('utf-8'))
        if size > 16384:
            raise ValueError(f"{ident}: complete request is {size} bytes, exceeding 16 KiB; nothing was truncated")
        if not YESNO.match(question.strip()):
            warnings.append(f"{ident}: the current inline reader supports yes/no questions; this task may not reach it")
        cases.append(case)
    manifest = {"schema": 1, "source": str(source.resolve()), "sha256": hashlib.sha256(raw).hexdigest(),
                "text": text, "cases": cases, "warnings": warnings,
                "limits": "Not ingestion or persistent memory. Quotes establish source occurrence, not truth or entailment. Conflicting versions can produce wrong answers."}
    return cases, manifest


def quote_locations(text, quote):
    """Match normalized whitespace and retain original line ranges, all occurrences."""
    tokens = list(re.finditer(r"\S+", text))
    normalized = ' '.join(t.group() for t in tokens)
    char_positions = []
    for index, token in enumerate(tokens):
        if index:
            char_positions.append(token.start())
        char_positions.extend(range(token.start(), token.end()))
    needle = normalize(quote)
    if not needle:
        return []
    result, start = [], 0
    while (at := normalized.find(needle, start)) != -1:
        end = at + len(needle) - 1
        result.append({"start_line": text.count('\n', 0, char_positions[at]) + 1,
                       "end_line": text.count('\n', 0, char_positions[end]) + 1})
        start = at + 1
    return result


def inspect(manifest, rows):
    """Retain original replies and annotate quotations; never turn failure into success."""
    if hashlib.sha256(manifest['text'].encode('utf-8')).hexdigest() != manifest['sha256']:
        raise ValueError("manifest source hash mismatch")
    cases = {x['id']: x for x in manifest['cases']}
    reports = []
    for row in rows:
        if row.get('id') not in cases or any(row.get(k) != cases[row['id']][k] for k in ('text', 'conversation_id')):
            raise ValueError("result does not match prepared request")
        reply = row.get('response', {}).get('reply', {})
        quotes = []
        for ref in reply.get('references', []):
            if isinstance(ref, dict) and ref.get('id') == 'passage' and isinstance(ref.get('text'), str):
                quotes.append({"quote": ref['text'], "locations": quote_locations(manifest['text'], ref['text'])})
        reports.append({"id": row['id'], "oracle_reply": reply, "passage_route": reply.get('path') == 'reading:passage_yesno',
                        "source": manifest['source'], "source_sha256": manifest['sha256'], "quote_occurrences": quotes,
                        "interpretation": "Occurrence only; inspect the whole document for conflicts. No correctness verdict."})
    return reports


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    prep = sub.add_parser('prepare')
    prep.add_argument('--document', type=Path, required=True)
    prep.add_argument('--questions', type=Path, required=True)
    prep.add_argument('--conversation', required=True)
    prep.add_argument('--out', type=Path, required=True)
    check = sub.add_parser('inspect')
    check.add_argument('--manifest', type=Path, required=True)
    check.add_argument('--results', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'prepare':
        cases, manifest = prepare(args.document, json.loads(args.questions.read_text()), args.conversation)
        args.out.mkdir(parents=True, exist_ok=False)
        (args.out / 'cases.json').write_text(json.dumps(cases, indent=2, ensure_ascii=False) + '\n')
        (args.out / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
        print(json.dumps({"cases": str(args.out / 'cases.json'), "warnings": manifest['warnings'], "limits": manifest['limits']}, indent=2))
    else:
        manifest = json.loads(args.manifest.read_text())
        rows = [json.loads(line) for line in args.results.read_text().splitlines()]
        print(json.dumps(inspect(manifest, rows), indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
