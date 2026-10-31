#!/usr/bin/env python3
"""Untrusted exact-fragment client for immutable caller-supplied DNA.

Consumes every bounded host page before claiming collection-wide absence. Native
completeness trusts handwritten traversal; --reference additionally compares a
bounded independent naive scan. No alignment score or biological interpretation.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import urllib.request
from hosted_reasoning import normalize_tenant, invoke_envelope

OPERATION = 'bio.search_collection'


def identities(arguments):
    def field(h, text):
        raw = text.encode('utf-8')
        h.update(len(raw).to_bytes(8, 'little')); h.update(raw)
    c = arguments['collection']; h = hashlib.sha256(); field(h, c['schema'])
    h.update(len(c['records']).to_bytes(8, 'little'))
    for row in c['records']:
        field(h, row['label']); field(h, row['sequence'])
    collection = h.hexdigest(); h = hashlib.sha256()
    field(h, 'oracle-sequence-search-v1'); field(h, collection)
    h.update(len(arguments['patterns']).to_bytes(8, 'little'))
    for row in arguments['patterns']:
        field(h, row['label']); field(h, row['sequence'])
    return collection, h.hexdigest()


def reverse_complement(sequence):
    return sequence.translate(str.maketrans('ACGT', 'TGCA'))[::-1]


def naive(arguments):
    """Independent complete reference only for small bounded truth cases."""
    records, patterns = arguments['collection']['records'], arguments['patterns']
    if sum(len(r['sequence']) for r in records) * sum(len(p['sequence']) for p in patterns) > 2_000_000:
        raise ValueError('reference work cap')
    hits = []
    for ri, record in enumerate(records):
        text = record['sequence'].upper()
        for start in range(len(text)):
            for pi, pattern in enumerate(patterns):
                p = pattern['sequence'].upper(); rc = reverse_complement(p)
                orientations = [('both', p)] if p == rc else [('forward', p), ('reverse', rc)]
                for strand, needle in orientations:
                    if text.startswith(needle, start):
                        hits.append({'record_index': ri, 'record_label': record['label'], 'pattern_index': pi,
                                     'pattern_label': pattern['label'], 'strand': strand, 'start': start,
                                     'end': start+len(needle), 'matched_sequence': needle})
    return hits


def validate_arguments(arguments):
    if not isinstance(arguments, dict) or set(arguments) != {'collection', 'patterns', 'page_size'}:
        raise ValueError('supply collection, patterns and page_size; consumer starts from first page')
    c = arguments['collection']
    if not isinstance(c, dict) or set(c) != {'schema', 'records'} or c['schema'] != 'oracle-sequence-collection-v1':
        raise ValueError('collection schema')
    records, patterns = c['records'], arguments['patterns']
    if not isinstance(records, list) or len(records) > 256 or not isinstance(patterns, list) or not 1 <= len(patterns) <= 128:
        raise ValueError('record or pattern count')
    for rows, empty in ((records, True), (patterns, False)):
        for row in rows:
            if (not isinstance(row, dict) or set(row) != {'label', 'sequence'}
                    or not isinstance(row['label'], str) or len(row['label'].encode()) > 256
                    or not isinstance(row['sequence'], str) or (not empty and not row['sequence'])
                    or any(b not in 'ACGTacgt' for b in row['sequence'])):
                raise ValueError('DNA must be supplied ACGT; labels are provenance, never unique keys')
    if sum(len(r['sequence']) for r in records) > 131072 or sum(len(p['sequence']) for p in patterns) > 4096:
        raise ValueError('base count')
    if type(arguments['page_size']) is not int or not 1 <= arguments['page_size'] <= 1024:
        raise ValueError('page size')


def search_all(invoke, arguments, max_pages=256, max_hits=16384, reference=False):
    """No partial success: client cap/refusal leaves completeness unknown."""
    validate_arguments(arguments)
    request = copy.deepcopy(arguments)
    collection_id, batch_id = identities(request)
    hits = []; previous = None; seen_cursors = set()
    for page_index in range(max_pages):
        result = invoke(request)
        if (not isinstance(result, dict) or result.get('schema') != 'oracle-sequence-search-v1'
                or result.get('collection_sha256') != collection_id or result.get('request_sha256') != batch_id
                or type(result.get('complete')) is not bool or not isinstance(result.get('hits'), list)
                or result.get('coverage_start') != request.get('cursor') or len(result['hits']) > request['page_size']):
            raise ValueError('invalid source-bound page')
        for hit in result['hits']:
            ri, pi, start, end = (hit[k] for k in ('record_index', 'pattern_index', 'start', 'end'))
            if any(type(x) is not int for x in (ri, pi, start, end)) or not 0 <= ri < len(request['collection']['records']) or not 0 <= pi < len(request['patterns']):
                raise ValueError('invalid hit ordinal')
            r, p = request['collection']['records'][ri], request['patterns'][pi]
            forward = p['sequence'].upper(); reverse = reverse_complement(forward)
            strand = hit['strand']; orientation = {'forward':0, 'reverse':1, 'both':2}[strand]
            needle = reverse if strand == 'reverse' else forward
            if ((strand == 'both') != (forward == reverse) or hit['record_label'] != r['label']
                    or hit['pattern_label'] != p['label'] or not 0 <= start < end <= len(r['sequence'])
                    or end-start != len(needle) or r['sequence'][start:end].upper() != needle
                    or hit['matched_sequence'] != needle):
                raise ValueError('hit fails independent original-coordinate replay')
            order = (ri,start,pi,orientation)
            if previous is not None and previous >= order:
                raise ValueError('page order repeated or reversed')
            previous = order
            if len(hits) >= max_hits:
                raise ValueError('client hit cap; collection-wide completion unknown')
            hits.append(hit)
        cursor = result.get('next_cursor')
        if result['complete']:
            if cursor is not None:
                raise ValueError('complete page has continuation')
            if reference and hits != naive(arguments):
                raise ValueError('native output differs from independent exhaustive reference')
            return {'schema':'sequence-collection-consumer-v1', 'status':'answered',
                    'collection_sha256':collection_id, 'request_sha256':batch_id, 'hits':hits,
                    'complete':True, 'pages':page_index+1,
                    'absent_pattern_indices':[i for i in range(len(request['patterns'])) if not any(h['pattern_index']==i for h in hits)],
                    'assurance':'positive hits replayed; full traversal trusted handwritten native code' + ('; independent naive reference agrees' if reference else '')}
        if not result['hits'] or not isinstance(cursor, dict) or cursor.get('request_sha256') != batch_id:
            raise ValueError('invalid incomplete page')
        encoded = json.dumps(cursor,sort_keys=True)
        if encoded in seen_cursors:
            raise ValueError('repeated continuation')
        seen_cursors.add(encoded); request['cursor'] = cursor
    raise ValueError('client page cap; collection-wide completion unknown')


class Client:
    def __init__(self, url='http://127.0.0.1:8765', tenant='sequence-collection'):
        self.url, self.tenant = url.rstrip('/'), normalize_tenant(tenant)

    def invoke(self, arguments):
        body = invoke_envelope(OPERATION, arguments, 'supplied-sequence-search')
        request = urllib.request.Request(self.url+'/invoke', data=json.dumps(body).encode(),
            headers={'Content-Type':'application/json','x-mini-oracle-tenant':self.tenant})
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read(8*1024*1024+1)
        if len(raw) > 8*1024*1024:
            raise ValueError('client response byte cap')
        envelope = json.loads(raw)
        reply = envelope.get('reply',{})
        if (envelope.get('outcome') != 'completed' or envelope.get('operation_id') != OPERATION
                or reply.get('operation_id') != OPERATION or reply.get('status') != 'answered'
                or reply.get('authority') != 'computation_only'):
            raise ValueError('host refused or did not complete exact search; no absence established')
        return reply['result']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='JSON supplied collection, patterns and page_size')
    parser.add_argument('--url', default='http://127.0.0.1:8765')
    parser.add_argument('--tenant', default='sequence-collection')
    parser.add_argument('--reference', action='store_true')
    args = parser.parse_args()
    if args.input.stat().st_size > 262144:
        parser.error('input byte cap')
    arguments = json.loads(args.input.read_text())
    try:
        result = search_all(Client(args.url,args.tenant).invoke,arguments,reference=args.reference)
    except (ValueError, KeyError, TypeError) as error:
        result = {'status':'withheld','reason':str(error),'complete':False}
    print(json.dumps(result,indent=2))
    return 0 if result['status']=='answered' else 1

if __name__ == '__main__':
    raise SystemExit(main())
