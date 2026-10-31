#!/usr/bin/env python3
"""Untrusted receipt builder for the retained fixed first-wave measurements.
Does not run a workload or modify source snapshots. Raw observations stay in scratch.
Run at the repository root after fetching sol-final-observations.tar.gz.
"""
import copy,hashlib,importlib.util,json,pathlib
ROOT=pathlib.Path('var/sol-wave-20261031/measurement')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(name):return json.loads((ROOT/(name+'.json')).read_text())
def reference(name):
 p=ROOT/(name+'.json');return {'path':str(p),'sha256':sha(p)}
spec=importlib.util.spec_from_file_location('shared',pathlib.Path(__file__).parent.parent/'native_foundation.py');shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
def http(name):
 x=copy.deepcopy(load(name))
 for version,z in x['versions'].items():
  replies=z.pop('correctness');z['correctness']={}
  for case,r in replies.items():
   z['correctness'][case]={'http_status':r[0],'status':r[1].get('status'),'semantic_status':r[1].get('core_metadata',{}).get('semantic_status'),'normalized_sha256':hashlib.sha256(json.dumps(shared.normalize(r),sort_keys=True,separators=(',',':')).encode()).hexdigest()}
 x['raw']=reference(name);return x
names=['foundation-direct-A','sol-direct-A','sol-direct-B','foundation-direct-B','foundation-direct-cpu0','sol-direct-cpu0']
direct={n:load(n) for n in names}
for n,x in direct.items():x['raw']=reference(n)
pairs=[]
for a,b in [('foundation-direct-A','sol-direct-A'),('foundation-direct-B','sol-direct-B'),('foundation-direct-cpu0','sol-direct-cpu0')]:
 for old,new in zip(direct[a]['measurement']['workloads'],direct[b]['measurement']['workloads']):
  equal=shared.normalize([200,old['last_reply']])==shared.normalize([200,new['last_reply']]);assert equal
  pairs.append({'foundation':a,'candidate':b,'workload':old['name'],'semantic_reply_equal':equal,'p50_candidate_over_foundation':new['p50_us']/old['p50_us']})
# Hash full direct replies in the summary; complete graph edges remain in raw files.
for x in direct.values():
 for row in x['measurement']['workloads']:
  r=row.pop('last_reply');row['last_reply_sha256']=hashlib.sha256(json.dumps(r,sort_keys=True,separators=(',',':')).encode()).hexdigest()
readers={}
for name in ['sol-reader-fixed','sol-reader-deadline1s','sol-reader-deadline5s']:
 x=load(name)
 for row in x['measurement']['workloads']:
  for key in ['replies','warmups']:
   source=row.pop(key);row[key+'_summary']=[{'error':r.get('error'),'status':r.get('reply',{}).get('status'),'reason':r.get('reply',{}).get('reason'),'answer':r.get('reply',{}).get('answer'),'sha256':hashlib.sha256(json.dumps(r,sort_keys=True,separators=(',',':')).encode()).hexdigest()} for r in source]
  assert all(p['outer_live_after']==0 for p in row['probes'])
 x['raw']=reference(name);readers[name]=x
consumers={}
for name in ['sol-consumers-results','sol-consumers-order-prepared','sol-consumers-order-fresh']:
 x=load(name)
 for row in x['measurement']['thermal']:
  # Keep independently checked temperatures/power without repeating all diagnostics.
  evidence=row['last_evidence'];evidence['nodes_last']=[{k:r[k] for k in ['id','temperature_k','applied_heat_w','outgoing_link_heat_w','boundary_exchange_w','power_balance_residual_w','power_balance_within_tolerance']} for r in evidence['nodes_last']]
  assert row['analytic_and_fresh_agreement']
 for row in x['measurement']['sequence']:assert row['full_page_and_naive_agreement']
 x['raw']=reference(name);consumers[name]=x
receipt={'schema':'native-sol-firstwave-performance-v1','date':'2026-10-31','scope':'Immutable checked first-wave code versus f0dfad7 foundation, excluding all phase2 overlays. No specialist panel completion metric or theorem from this lane.','panel_numbers':None,'theorem_statements':[],
'source':{'foundation':'f0dfad77669dfb3f97f6680cd452b406bcfae271','candidate_archive':'/tank/lanes/o7-sol-validation-20261031/checked-source.tar','candidate_archive_sha256':'1cc9257be31ca0279350d4b8f73e36db923797311fb149323ebbfdcabf55674e','candidate_manifest':'/tank/lanes/o7-sol-validation-20261031/checked-source.json','candidate_manifest_sha256':'6935098ca7b9615f07026e34aa441e396edb37ef5db3535bb8ef0e4594a3d69b','extracted':'/tank/lanes/o7-sol-measurement-20261031/sol-sealed','content_check':load('sol-source-check'),'mtime_policy':'Extracted source/manifests touched before warm-target build, content hashes unchanged.'},
'build':{'profile':'release,thin LTO,codegen-units1','jobs':2,'target':'/tank/lanes/o7-native-20261028/target','mode':'serial,offline,pinned snapshot Cargo.lock','thread_environment':shared.THREAD_ENV,'artifacts':(ROOT/'sol-binary-hashes.txt').read_text(),'logs':{p.name:{'path':str(p),'sha256':sha(p)} for p in ROOT.glob('*-build.log') if p.name.startswith(('sol-','foundation-direct'))}},
'http':{n:http('sol-http-'+n) for n in ['AB','BA']},'direct':direct,'direct_comparisons':pairs,'reader':readers,'consumers':consumers,
'cpu_diagnostic':{'model':'Intel Core i9-12900','logical_cpus':24,'physical_cores':16,'topology':'CPU0–15:8SMTcores,5.0–5.1GHzmaximum;CPU16–23:8single-threadcores,3.8GHzmaximum.','scope':'One bounded existing-binary pair taskset -c0, no production affinity change. Exit0 from taskset; observer affinity field describes observer parent, not target. Underlying binaries are the corresponding retained direct artifacts, although binary_sha256 in these two wrapper records hashes /usr/bin/taskset.','interpretation':'Large unpinned graph slowdown1.85–2.04x fell to1.33x on CPU0. Hybrid placement contributes but does not remove regression; no algorithm cause isolated.'},
'findings':['All28 HTTP semantic fixture pairs agree; three direct pairs×two workload last replies agree. Identity and volatile provider timing exclusions match foundation receipt.','Polling removal resolves old20msHTTP floor. Small science medians20.12/20.24ms→0.484/0.642ms. No claim that all this gain is kernel speed.','Small direct invocation improves144/194us→63.5/61.3us, while largegraph regresses4.08/4.00ms→7.54/8.15ms; CPU0 residual slowdown retained.','Thermal prepared+preparation batches are faster for all declared chains in observed trials, with analytic temperatures/power and fresh agreement. No HTTP or physical applicability claim.','Sequence prepared-first timings look worse; fresh-first timings reverse the ranking. The second alternative is much faster in both orders. These observations do not resolve a stable prepared-vs-stateless speed claim. Both exact pages/identity/cursors/work and naive scan agree.','Reader probes show concrete cache hits and retained-byte reservations, but also many intermediate plan compilations. Outer retained reservations returned to0 after every measured read.','Selected release reader deadline diagnostic had0errors in15one-second measured calls and5five-second measured calls on original fixed image. This does not replace full retained100+16cells or establish stable1s behavior of debug/deployed variants.'],
'limitations':['Shared machine load/CPU frequency, hybrid core placement, OS cache, allocator layout and monitoring are not isolated. Raw load before/after retained.','RSS stat counters are approximate; PSS/private smaps read at different instants, so separate sampled maxima need not order consistently. Child-walk nominal2ms wait can still miss peaks.','Consumer microbenchmarks use cancellation-only AtomicBool WorkControl, not production ExecutionContext fuel/deadline charging. No host throughput inference.','Original sequence pass kept first output alive during second timing and did large JSON/naive checks between paired trials. Counterbalanced same-binary followup exposes a strong order/cache/allocator confound; no cherry-picked replacement or causal API ratio.','Thermal numerical fields are compared with stated relative2e-7 tolerance; prepared results intentionally omit fresh factorization diagnostics. Analytic original-node balances independently checked.','Reader retained-byte units are conservative explicit reservations, not allocator live bytes or RSS. Returned wire strings and foreign/SQLite/mmap storage are outside this accounting.','The five deadline-sensitive cases were selected from prior failures and are diagnostic, not representative coverage. Earlier central validator DEV1s errors remain valid evidence; release observations do not erase them.','No new full reader four-cell/cohort or shipped specialist panels rerun by this measurement lane.'],
'handoff':{'runner':'Released to root/sol_expansion_validation after existing bounded followups; all owned processes reaped, no measurement builds/services remain.','phase2':'Keep original artifacts. Structural work-vs-memory separation is a later overlay and may use narrow same-CPU diagnostic for causal evidence; not incorporated here.'},
'checks':{'http_pairs_equal':28,'direct_last_reply_pairs_equal':6,'consumer_thermal_cases_analytic_and_fresh':3,'consumer_sequence_cases_full_pages_and_naive':2,'reader_outer_live_after_zero':True},'raw_root':str(ROOT),'remote_root':'/tank/lanes/o7-sol-measurement-20261031'}
receipt['harness_provenance']=json.loads((pathlib.Path(__file__).parent/'recorded/source-chain.json').read_text())
assert all(v['reply_equal'] for x in receipt['http'].values() for v in x['comparisons'].values())
pathlib.Path('native/evidence/2026-10-31-sol-performance.json').write_text(json.dumps(receipt,indent=2)+'\n')
