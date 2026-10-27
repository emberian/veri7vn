#!/usr/bin/env python3
"""Untrusted bounded Wikidata date-metadata importer; source evidence, not proof.

Joins JSON statements to same-revision RDF time nodes, then matches the exact RDF
literal to a read-only legacy store. No precision or calendar is inferred from a
placeholder day. Full selected claims, including deprecated claims and qualifiers,
are retained. Nothing updates a SQLite store or an existing output file.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import urllib.request
import time
import threading
import urllib.error
import xml.etree.ElementTree as ET

RDF = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
WB = 'http://wikiba.se/ontology#'
VALUE = 'http://www.wikidata.org/prop/statement/value/'
ENTITY = 'http://www.wikidata.org/entity/'
MAX_BYTES = 8 * 1024 * 1024
_REQUEST_LOCK = threading.Lock()
_NEXT_REQUEST = 0.0


def fetch(url):
    global _NEXT_REQUEST
    req = urllib.request.Request(url, headers={'User-Agent': 'Veri7vn/1.0 bounded public date-precision research'})
    for attempt in range(3):
        # Four workers may overlap parsing and latency, but source requests have
        # a global rate limit. Never bypass an upstream 429 with another host.
        with _REQUEST_LOCK:
            delay = max(0.0, _NEXT_REQUEST - time.monotonic())
            if delay:
                time.sleep(delay)
            _NEXT_REQUEST = time.monotonic() + 1.2
        try:
            with urllib.request.urlopen(req, timeout=40) as response:
                data = response.read(MAX_BYTES + 1)
            if len(data) > MAX_BYTES:
                raise ValueError('source exceeds 8 MiB bound')
            return data
        except urllib.error.HTTPError as error:
            if error.code not in (408, 429, 500, 502, 503, 504) or attempt == 2:
                raise
            retry = error.headers.get('Retry-After', '')
            pause = float(retry) if retry.replace('.', '', 1).isdigit() else 10*(attempt+1)
            with _REQUEST_LOCK:
                _NEXT_REQUEST = max(_NEXT_REQUEST, time.monotonic()+pause)
        except (OSError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(2**attempt)


def rdf_times(data, qid, properties, revision):
    if b'<!DOCTYPE' in data.upper() or b'<!ENTITY' in data.upper():
        raise ValueError('DTD/entity declarations are not accepted')
    root = ET.fromstring(data)
    about, resource = '{'+RDF+'}about', '{'+RDF+'}resource'
    index = {node.get(about): node for node in root if node.get(about)}
    versions = {child.text for node in root for child in node if child.tag == '{http://schema.org/}version'}
    if versions != {str(revision)}:
        raise ValueError('JSON/RDF revisions differ or version missing')
    result = {}
    prefix = ENTITY+'statement/'+qid+'-'
    for subject, node in index.items():
        if not subject.lower().startswith(prefix.lower()):
            continue
        statement = qid+'$'+subject[len(prefix):]
        for child in node:
            if child.tag not in {'{'+VALUE+'}'+p for p in properties}:
                continue
            target = index.get(child.get(resource))
            if target is None:
                raise ValueError('missing RDF time value node')
            fields = {element.tag.removeprefix('{'+WB+'}'): element.text or element.get(resource)
                      for element in target if element.tag.startswith('{'+WB+'}')}
            required = {'timeValue', 'timePrecision', 'timeTimezone', 'timeCalendarModel'}
            if not required <= fields.keys():
                raise ValueError('incomplete RDF time node')
            result[(statement.lower(), child.tag.split('}')[-1])] = fields
    return result


def compile_record(entity, property_id, rdf, legacy_literals, source):
    qid = entity['id']
    claims = entity.get('claims', {}).get(property_id, [])
    if len(claims) > 100:
        raise ValueError('more than 100 claims for selected property')
    statements, bindings = [], []
    for claim in claims:
        snak = claim.get('mainsnak', {})
        snapshot = dict(claim)
        if snak.get('snaktype') == 'value' and snak.get('datatype') == 'time':
            value = snak['datavalue']['value']
            r = rdf.get((claim['id'].lower(), property_id))
            if r is None:
                raise ValueError('JSON time statement missing in same-revision RDF')
            if (int(r['timePrecision']) != value['precision'] or
                int(r['timeTimezone']) != value['timezone'] or
                r['timeCalendarModel'] != value['calendarmodel']):
                raise ValueError('JSON/RDF time metadata disagree')
            snapshot['rdf_time'] = r
            # Exact lexical equality, not a guessed conversion or day-one rule.
            if r['timeValue'] in legacy_literals:
                bindings.append({'legacy_literal': r['timeValue'], 'statement_id': claim['id']})
        statements.append(snapshot)
    return {'subject': qid, 'property': property_id, 'label': entity.get('labels', {}).get('en', {}).get('value'),
            'source': source, 'legacy_literals_observed': sorted(legacy_literals),
            'statements': statements, 'bindings': bindings}


def source_snapshot(item, cache, allow_fetch):
    qid, props = item['qid'], item['properties']
    json_path = cache/(qid+'.json')
    json_url = 'https://www.wikidata.org/wiki/Special:EntityData/'+qid+'.json'
    if not json_path.exists():
        if not allow_fetch:
            raise FileNotFoundError(json_path)
        json_path.write_bytes(fetch(json_url))
    json_bytes = json_path.read_bytes()
    if len(json_bytes) > MAX_BYTES:
        raise ValueError('cached source exceeds size bound')
    entity = json.loads(json_bytes)['entities'][qid]
    rev = entity['lastrevid']
    rdf_path = cache/(qid+'.rdf')
    rdf_url = 'https://www.wikidata.org/wiki/Special:EntityData/'+qid+'.rdf?revision='+str(rev)
    if not rdf_path.exists():
        if not allow_fetch:
            raise FileNotFoundError(rdf_path)
        rdf_path.write_bytes(fetch(rdf_url))
    rdf_bytes = rdf_path.read_bytes()
    if len(rdf_bytes) > MAX_BYTES:
        raise ValueError('cached source exceeds size bound')
    times = rdf_times(rdf_bytes, qid, props, rev)
    source = {'kind': 'wikidata-entity-json-and-rdf', 'revision': rev,
              'json_url': json_url+'?revision='+str(rev), 'rdf_url': rdf_url,
              'json_sha256': hashlib.sha256(json_bytes).hexdigest(),
              'rdf_sha256': hashlib.sha256(rdf_bytes).hexdigest(),
              'snapshot_observed_at': datetime.fromtimestamp(json_path.stat().st_mtime, timezone.utc).isoformat()}
    return entity, times, source


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtime', type=Path, required=True)
    p.add_argument('--selection', type=Path, required=True)
    p.add_argument('--cache', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--fetch', action='store_true', help='Fetch missing bounded entity snapshots; otherwise use only cache')
    p.add_argument('--workers', type=int, choices=range(1,5), default=4)
    args = p.parse_args()
    if args.out.exists():
        p.error('output already exists; use a new output path')
    selected = json.loads(args.selection.read_text())
    if not 1 <= len(selected) <= 256 or sum(len(i['properties']) for i in selected) > 2048:
        p.error('select 1..256 entities and at most 2048 entity/property pairs')
    seen = set()
    for item in selected:
        qid, props = item['qid'], item['properties']
        if qid in seen or not re.fullmatch(r'Q[1-9][0-9]*', qid) or not 1 <= len(props) <= 8 or any(not re.fullmatch(r'P[1-9][0-9]*', x) for x in props):
            p.error('invalid or duplicate entity/property selection')
        seen.add(qid)
    args.cache.mkdir(parents=True, exist_ok=True)
    store = args.runtime.resolve()/'root/relstore/relations_v2.sqlite3'
    db = sqlite3.connect(store.as_uri()+'?mode=ro&immutable=1', uri=True)
    db.execute('PRAGMA query_only=ON')
    records, failures = [], []
    try:
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(source_snapshot, item, args.cache, args.fetch): item for item in selected}
            for number, future in enumerate(as_completed(futures),1):
                item = futures[future]
                qid, props = item['qid'], item['properties']
                try:
                    entity, times, source = future.result()
                    entity_records = []
                    for prop in props:
                        rows = db.execute('SELECT lit FROM fact INDEXED BY fact_sp WHERE s=? AND p=? LIMIT 101', (int(qid[1:]), int(prop[1:]))).fetchall()
                        if len(rows) > 100:
                            raise ValueError('more than 100 legacy values')
                        literals = {r[0] for r in rows if r[0] is not None}
                        entity_records.append(compile_record(entity, prop, times, literals, source))
                    records.extend(entity_records)
                    print(number,'/',len(selected),qid,'revision',source['revision'],'pairs',len(entity_records),flush=True)
                except Exception as exc:
                    failures.append({'qid':qid,'properties':props,'error':str(exc)})
                    print(number,'/',len(selected),qid,'FAILED',str(exc),flush=True)
    finally:
        db.close()
    manifest = json.loads((args.runtime/'APPLIANCE.json').read_text())
    store_meta = next(s for s in manifest['stores'] if s['path']=='root/relstore/relations_v2.sqlite3')
    output = {'schema': 'oracle7-date-precision-v1', 'version': 1,
              'assurance': 'Untrusted source metadata. Exact statement/RDF/legacy-value binding, not a proof of historical truth.',
              'legacy_store': {'path': store_meta['path'], 'sha256_declared': store_meta['sha256']},
              'records': sorted(records,key=lambda r:(int(r['subject'][1:]),int(r['property'][1:]))),
              'import_failures': failures}
    payload = json.dumps(output, ensure_ascii=False, indent=2)+'\n'
    if len(payload.encode()) > 16*1024*1024:
        raise ValueError('sidecar exceeds 16 MiB')
    with args.out.open('x') as stream:
        stream.write(payload)
    print('wrote',len(records),'entity/property records',len(payload.encode()),'bytes;',len(failures),'failed entities')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
