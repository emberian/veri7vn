#!/usr/bin/env python3
"""Untrusted client: translate explicit supplied coding intervals with source maps.

Each returned codon is independently checked against original supplied DNA and a
separately tabulated standard code. No genes, ORFs or protein function inferred.
"""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
from hosted_reasoning import normalize_tenant, invoke_envelope

OPERATION='bio.translate_coding_intervals'
CODE_ID='ncbi-standard-1-2024-09-23'
SOURCE_SCHEMA='oracle-translation-source-v1'
SCHEMA='oracle-coding-translation-v1'
CODE_SOURCE='https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#SG1'
# Independently grouped synonymous codons; not the native TCAG-indexed row.
GROUPS={'F':'TTT TTC','L':'TTA TTG CTT CTC CTA CTG','S':'TCT TCC TCA TCG AGT AGC',
        'Y':'TAT TAC','*':'TAA TAG TGA','C':'TGT TGC','W':'TGG','P':'CCT CCC CCA CCG',
        'H':'CAT CAC','Q':'CAA CAG','R':'CGT CGC CGA CGG AGA AGG','I':'ATT ATC ATA','M':'ATG',
        'T':'ACT ACC ACA ACG','N':'AAT AAC','K':'AAA AAG','V':'GTT GTC GTA GTG',
        'A':'GCT GCC GCA GCG','D':'GAT GAC','E':'GAA GAG','G':'GGT GGC GGA GGG'}
CODE={codon:aa for aa,codons in GROUPS.items() for codon in codons.split()}
COMPLEMENT=str.maketrans('ACGTRYSWKMBDHVN','TGCAYRSWMKVHDBN')


def compact(value):
    return json.dumps(value,ensure_ascii=False,separators=(',',':'))


def identities(arguments):
    def field(h,text):
        raw=text.encode();h.update(len(raw).to_bytes(8,'little'));h.update(raw)
    source=arguments['source'];h=hashlib.sha256();field(h,source['schema'])
    h.update(len(source['records']).to_bytes(8,'little'))
    for record in source['records']:
        field(h,record['label']);field(h,record['sequence'])
    source_id=h.hexdigest();h=hashlib.sha256();field(h,SCHEMA);field(h,source_id);field(h,arguments['genetic_code'])
    field(h,compact([arguments[k] for k in ('initiation','remainder','stops','ambiguity')]))
    h.update(len(arguments['features']).to_bytes(8,'little'))
    for feature in arguments['features']:
        field(h,compact({k:feature[k] for k in ('label','record_index','start','end','strand','frame')}))
    return source_id,h.hexdigest()


def validate_arguments(args):
    if not isinstance(args,dict) or set(args)!={'source','features','genetic_code','initiation','remainder','stops','ambiguity'}:
        raise ValueError('supply source, explicit features, genetic_code and all translation policies')
    if args['genetic_code']!=CODE_ID or args['initiation']!='literal_codon':
        raise ValueError('only explicitly named standard code with literal codon initiation is supported')
    if args['remainder'] not in ('reject','drop') or args['stops'] not in ('include','terminate','reject') or args['ambiguity'] not in ('reject','unknown'):
        raise ValueError('translation policy')
    source=args['source']
    if not isinstance(source,dict) or set(source)!={'schema','records'} or source['schema']!=SOURCE_SCHEMA:
        raise ValueError('translation source schema')
    records=source['records'];features=args['features']
    if not isinstance(records,list) or len(records)>256 or not isinstance(features,list) or not 1<=len(features)<=256:
        raise ValueError('source record or feature count')
    total=0
    for record in records:
        if (not isinstance(record,dict) or set(record)!={'label','sequence'} or not isinstance(record['label'],str)
                or len(record['label'].encode())>256 or not isinstance(record['sequence'],str)):
            raise ValueError('source record')
        total+=len(record['sequence'])
        alphabet='ACGTacgt' if args['ambiguity']=='reject' else 'ACGTRYSWKMBDHVNacgtryswkmbdhvn'
        if total>131072 or any(b not in alphabet for b in record['sequence']):
            raise ValueError('source DNA alphabet or base cap')
    potential=0
    for feature in features:
        if (not isinstance(feature,dict) or set(feature)!={'label','record_index','start','end','strand','frame'}
                or not isinstance(feature['label'],str) or len(feature['label'].encode())>256
                or any(type(feature[k]) is not int for k in ('record_index','start','end','frame'))
                or not 0<=feature['record_index']<len(records) or feature['strand'] not in ('forward','reverse')):
            raise ValueError('feature identity or strand')
        start,end,frame=feature['start'],feature['end'],feature['frame']
        if not 0<=start<end<=len(records[feature['record_index']]['sequence']) or not 0<=frame<=min(2,end-start):
            raise ValueError('feature interval or frame')
        length=end-start-frame
        if args['remainder']=='reject' and length%3:
            raise ValueError('incomplete trailing codon')
        potential+=length//3
        if potential>16384:
            raise ValueError('potential codon cap')


def reference(args):
    """Bounded direct reference retaining every omitted and translated interval."""
    validate_arguments(args)
    output=[]
    for fi,feature in enumerate(args['features']):
        record=args['source']['records'][feature['record_index']]
        text=record['sequence'][feature['start']:feature['end']].upper()
        if feature['strand']=='reverse':
            text=text.translate(COMPLEMENT)[::-1]
        def interval(lo,hi):
            if lo==hi:
                return None
            if feature['strand']=='forward':
                start,end=feature['start']+lo,feature['start']+hi
            else:
                start,end=feature['end']-hi,feature['end']-lo
            return {'start':start,'end':end,'strand':feature['strand']}
        frame=feature['frame'];full=(len(text)-frame)//3
        protein='';codons=[];termination=None;after=None
        for ci in range(full):
            lo=frame+ci*3;codon=text[lo:lo+3];aa=CODE.get(codon,'X')
            mapping={'amino_acid_index':ci,'amino_acid':aa,'codon':codon,'source':interval(lo,lo+3)}
            if aa=='*' and args['stops']=='reject':
                raise ValueError('stop codon rejected by policy')
            if aa=='*' and args['stops']=='terminate':
                termination=mapping;after=interval(lo+3,len(text));break
            protein+=aa;codons.append(mapping)
        output.append({'feature_index':fi,'feature':feature,'record_label':record['label'],'protein':protein,'codons':codons,
                       'frame_skipped':interval(0,frame),'trailing_bases':interval(frame+full*3,len(text)),
                       'termination_stop':termination,'untranslated_after_stop':after})
    return output


def translate(invoke,args):
    validate_arguments(args)
    expected=reference(args)
    source_id,request_id=identities(args)
    result=invoke(args)
    if (not isinstance(result,dict) or result.get('schema')!=SCHEMA or result.get('source_sha256')!=source_id
            or result.get('request_sha256')!=request_id or result.get('genetic_code')!=CODE_ID
            or result.get('genetic_code_source')!=CODE_SOURCE or result.get('complete') is not True
            or any(result.get(k)!=args[k] for k in ('initiation','remainder','stops','ambiguity'))
            or result.get('translations')!=expected):
        raise ValueError('native translation fails source-bound independent codon/coordinate replay')
    for feature in result['translations']:
        if type(feature['feature_index']) is not int or any(type(feature['feature'][k]) is not int for k in ('record_index','start','end','frame')):
            raise ValueError('translation ordinal type')
        mappings=feature['codons']+([feature['termination_stop']] if feature['termination_stop'] is not None else [])
        for mapping in mappings:
            if type(mapping['amino_acid_index']) is not int or any(type(mapping['source'][k]) is not int for k in ('start','end')):
                raise ValueError('codon coordinate type')
        for interval in (feature['frame_skipped'],feature['trailing_bases'],feature['untranslated_after_stop']):
            if interval is not None and any(type(interval[k]) is not int for k in ('start','end')):
                raise ValueError('omitted interval type')
    examined=sum(len(t['codons'])+int(t['termination_stop'] is not None) for t in expected)
    if type(result.get('codons_examined')) is not int or result['codons_examined']!=examined:
        raise ValueError('codon coverage mismatch')
    return {'schema':'sequence-translation-consumer-v1','status':'answered','result':result,
            'assurance':'native table translation independently replayed against supplied source and tabulated standard codons; no gene or ORF claim'}


class Client:
    def __init__(self,url='http://127.0.0.1:8765',tenant='sequence-translation'):
        self.url,self.tenant=url.rstrip('/'),normalize_tenant(tenant)
    def invoke(self,args):
        body=invoke_envelope(OPERATION,args,'supplied-coding-translation')
        request=urllib.request.Request(self.url+'/invoke',data=compact(body).encode(),
            headers={'Content-Type':'application/json','x-mini-oracle-tenant':self.tenant})
        with urllib.request.urlopen(request,timeout=30) as response:
            raw=response.read(8*1024*1024+1)
        if len(raw)>8*1024*1024:
            raise ValueError('client reply byte cap')
        envelope=json.loads(raw);reply=envelope.get('reply',{})
        if (envelope.get('outcome')!='completed' or envelope.get('operation_id')!=OPERATION
                or reply.get('status')!='answered' or reply.get('operation_id')!=OPERATION
                or reply.get('authority')!='computation_only'):
            raise ValueError('host refused translation; no complete result')
        return reply['result']


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input',type=Path)
    parser.add_argument('--url',default='http://127.0.0.1:8765')
    parser.add_argument('--tenant',default='sequence-translation')
    args=parser.parse_args()
    if args.input.stat().st_size>262144:
        parser.error('input byte cap')
    try:
        result=translate(Client(args.url,args.tenant).invoke,json.loads(args.input.read_text()))
    except (ValueError,KeyError,TypeError,OSError) as error:
        result={'status':'withheld','complete':False,'reason':str(error)}
    print(json.dumps(result,indent=2))
    return int(result['status']!='answered')

if __name__=='__main__':
    raise SystemExit(main())
