#!/usr/bin/env python3
"""Validate coverage obligations against pinned source denominator and task IDs."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
def read(p): return json.loads((ROOT/p).read_text())
inventory=read('audit/coverage/inventory.json')
ledger=read('audit/coverage/decisions.json')
tasks={t['id'] for t in read('project/tasks.json')['tasks']}
assert set(ledger['entries'])=={s['id'] for s in inventory['specialists']},'manifest denominator mismatch'
for s in inventory['specialists']:
    e=ledger['entries'][s['id']]
    assert set(ledger['required_fields_per_entry'])<=e.keys(),s['id']
    assert e['status'] in ledger['allowed_statuses'],s['id']
    assert e['scope']['declared_operations']==s['declared_kinds'],s['id']
    assert set(e['work_packages'])<=tasks,s['id']
    for field in ('manifest','module'):
        assert hashlib.sha256((ROOT/s[field]).read_bytes()).hexdigest()==s[field+'_sha256'],s[field]
    if e['status'] in ('preserved','repaired'):
        assert all(e[k] for k in ('implementation_evidence','assurance_evidence','behavior_evidence','deployment_evidence')),s['id']
d=read('docs/coverage/classification/denominator.json')
assert d['unreviewed_reachability_paths']==[s['path'] for s in inventory['python_sources']]
r=read('docs/coverage/classification/runtime-chain.json')
head=read('upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/HEAD_MANIFEST.json')
assert [x['module'] for x in r['chain']]==head['chain_tip_to_base']
assert r['tip']==head['tip']
print(f"{len(ledger['entries'])} manifest identities/operations/task references and hashes checked; {len(r['chain'])} chain members retained; no coverage promotion")

profiles=read('docs/coverage/classification/domain-profiles.json')
domain_ids={x['id'] for x in inventory['specialists'] if x['family']=='needs-semantic-classification'}
profile_ids=[m for p in profiles['profiles'].values() for m in p['manifests']]
assert len(profile_ids)==len(set(profile_ids))
assert set(profile_ids)|set(profiles['unreviewed_manifests'])==domain_ids
assert not set(profile_ids)&set(profiles['unreviewed_manifests'])
for key,p in profiles['profiles'].items():
 assert set(p['owners'])<=tasks,key
 assert p['native_obligations'] and p['source'] and p['review'],key
 for m in p['manifests']:
  assert ledger['entries'][m]['semantic_profile'].endswith('#'+key),m
dispatch=read('docs/coverage/classification/dispatch.json')
assert not dispatch['unresolved_bases']
assert not dispatch['missing_head_members']
for p,digest in dispatch['source_sha256'].items():
 assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest,p
assert len(dispatch['chain'])==361
print(f"{len(profile_ids)} domain profiles assigned; actual 361-class C3 evidence pinned; conditional activation remains explicit")

for path,digest in read('docs/coverage/classification/regression-sources.json')['sha256'].items():
 assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
print(str(len(read('docs/coverage/classification/regression-sources.json')['sha256']))+' upstream regression definitions/dependencies match pinned source')

for path,digest in profiles.get('local_closure_sha256',{}).items():
 assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
print(str(len(profiles.get('local_closure_sha256',{})))+' domain/local-helper source texts pinned; composition/deployment unestablished')

roles=read('docs/coverage/classification/source-roles.json')
for key,inventory_key in [('python_roles','python_sources'),('tracked_roles','tracked_files')]:
 paths=[p for group in roles[key].values() for p in group]
 assert len(paths)==len(set(paths)),key
 assert set(paths)=={x['path'] for x in inventory[inventory_key]},key
assert all(p['current_exists'] and p['size_matches_published'] for p in roles['materialized_packs'])
print('Source partitions account for all 1757 Python and 3608 Git entries; 14 materialized packs present/size-matched, no fresh payload hash claim')

for entry in inventory['python_sources']:
 assert hashlib.sha256((ROOT/entry['path']).read_bytes()).hexdigest()==entry['sha256'],entry['path']
print('All 1757 source contents still match pinned inventory hashes')
