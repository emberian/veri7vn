"""Actual Dispatcher with explicit test-only staged native/capability inputs."""
import hashlib,json,subprocess,sys,tempfile
from pathlib import Path
family,locator,outfile=sys.argv[1:];spec=json.loads(Path(locator).read_text());base=Path.cwd();binary=(base/spec['binary']).resolve();cap=(base/spec['capabilities']).resolve()
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(binary)==spec['binary_sha256']
if 'capabilities_sha256' in spec:assert sha(cap)==spec['capabilities_sha256']
with tempfile.TemporaryDirectory(prefix='staged-consumer-') as tmp:
 root=Path(tmp);d=root/'var'/family/'bin';d.mkdir(parents=True);(d/family).symlink_to(binary);(root/'var/fusion').symlink_to(base/'var/fusion',target_is_directory=True)
 c=root/'cap/src/extract'/family;c.mkdir(parents=True);(c/'capabilities.json').write_bytes(cap.read_bytes())
 script="""import sys,runpy
from pathlib import Path
sys.path.insert(0,str(Path('tools').resolve()))
import runtime_contract as r
original=r._family_capabilities
caproot=sys.argv.pop(1);family=sys.argv.pop(1)
r._family_capabilities=lambda repo,entry: original(caproot if entry['family']==family else repo,entry)
sys.argv[0]='tools/dispatch/dispatch.py'
runpy.run_path('tools/dispatch/dispatch.py',run_name='__main__')
"""
 cmd=['python3','-B','-c',script,str(root/'cap'),family,'--order','front','--var-root',str(root/'var'),'--organs',family,'--no-reader','--no-document','--no-routes','--no-dialogue','--no-code']
 items=spec['items'];p=subprocess.run(cmd,input=''.join(json.dumps({'id':str(i),'q':x['q']})+'\n' for i,x in enumerate(items)),capture_output=True,text=True,timeout=30,check=True)
 replies=list(map(json.loads,p.stdout.splitlines()));assert len(replies)==len(items)
 rows=[]
 for i,(x,r) in enumerate(zip(items,replies)):
  ok=r['id']==str(i) and r['status']==x['status'] and r.get('kind')==x['kind']
  if x['status']=='answered':
   ok=ok and (r.get('value')==x['expected'] if isinstance(x['expected'],(str,list,dict,bool)) else abs(float(r['value'])-x['expected']) <= (abs(x['expected'])/1000 if x.get('relative') else .00005))
  else:ok=ok and r['provenance']['dispatch'].get('decisive') is True
  ok=ok and all(t in r.get('response','') for t in x.get('response_contains',[]))
  ok=ok and all(t not in r.get('response','') for t in x.get('response_not_contains',[]))
  rows.append({'case':x,'passed':bool(ok),'reply':r});print(i,ok,r.get('kind'),r.get('value'))
 record={'scope':'actual Dispatcher; test-only staged capability file injection through unchanged shared loader, no production/selection mutation','binary_sha256':sha(binary),'capabilities_sha256':sha(cap),'dispatcher_sha256':sha('tools/dispatch/dispatch.py'),'shared_loader_sha256':sha('tools/runtime_contract.py'),'rows':rows,'stderr':p.stderr}
 Path(outfile).write_text(json.dumps(record,indent=2)+'\n');assert all(r['passed'] for r in rows)
