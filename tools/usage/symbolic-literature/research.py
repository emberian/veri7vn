#!/usr/bin/env python3
"""Bounded literature retrieval helper; untrusted research plumbing, not a proof checker."""
from pathlib import Path
import importlib.util, json, re, ssl, urllib.request
OUT=Path.home()/'paperbin/oracle7-20261027/symbolic'
OUT.mkdir(parents=True,exist_ok=True)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError('Kagi redirects disabled to protect credentials')

def kagi(query,name):
    key=None
    for line in (Path.home()/'dev/allgame/.env').read_text().splitlines():
        m=re.fullmatch(r'\s*KAGI_API_KEY\s*=\s*(.*?)\s*',line)
        if m:
            key=m.group(1).strip('"\''); break
    if not key: raise RuntimeError('Kagi key absent')
    body=json.dumps({'query':query}).encode()
    req=urllib.request.Request('https://kagi.com/api/v1/search',data=body,headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
    ctx=ssl.create_default_context(cafile='/opt/homebrew/etc/openssl@3/cert.pem')
    opener=urllib.request.build_opener(NoRedirect(),urllib.request.HTTPSHandler(context=ctx))
    try:
        with opener.open(req,timeout=40) as r: result=json.loads(r.read(3000000))
    except Exception as e: raise RuntimeError(str(e).replace(key,'[REDACTED]')) from None
    (OUT/(name+'.json')).write_text(json.dumps(result,indent=2))
    data=result.get('data',{})
    rows=data.get('search',[]) if isinstance(data,dict) else data
    print(name,[(r.get('title'),r.get('url')) for r in rows[:8]])

if __name__=='__main__':
    import sys
    kagi(sys.argv[1],sys.argv[2])
