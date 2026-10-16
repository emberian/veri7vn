#!/usr/bin/env python3
"""Static manifest dispositions. Never imports upstream or infers dead code."""
import ast
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]

def inspect(path):
    tree = ast.parse(path.read_text())
    classes = []
    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            methods = []
            for f in node.body:
                if isinstance(f, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    calls = sorted({ast.unparse(n.func) for n in ast.walk(f) if isinstance(n, ast.Call)})
                    methods.append({'name': f.name, 'line': f.lineno, 'calls': calls,
                        'self_writes': sorted({ast.unparse(n) for n in ast.walk(f) if isinstance(n, ast.Attribute) and isinstance(n.ctx, ast.Store) and isinstance(n.value, ast.Name) and n.value.id == 'self'})})
            classes.append({'name': node.name, 'bases': [ast.unparse(x) for x in node.bases], 'methods': methods})
    return classes

def main():
    inventory = json.loads((ROOT/'audit/coverage/inventory.json').read_text())
    decisions = json.loads((ROOT/'audit/coverage/decisions.json').read_text())
    profiles=json.loads((ROOT/'docs/coverage/classification/domain-profiles.json').read_text())['profiles']
    by_manifest={m:(key,p) for key,p in profiles.items() for m in p['manifests']}
    entries = {}
    for s in inventory['specialists']:
        classes = inspect(ROOT/s['module'])
        manifest=json.loads((ROOT/s['manifest']).read_text())
        observation = s['id'] == 'sql'
        scopes = ['owned_algorithm_model']
        if observation: scopes = ['engine_observation', 'owned_observer_algorithm']
        if s['family'] in ('relation-readers', 'ordered-fact-rules'): scopes = ['source_observation', 'owned_reader_algorithm']
        if s['family'] == 'stateful-site': scopes = ['source_observation', 'candidate_workflow', 'owned_state_algorithm']
        profile=by_manifest.get(s['id'])
        if profile:scopes=profile[1]['roles']
        operation_roles={}
        for kind in s['declared_kinds']:
            roles=scopes[:]
            if profile:
                # Mixed families need operation-specific scope; owned numeric
                # algorithms never disappear into an observation label.
                if s['id']=='algorithms':
                    roles=['source_table_observation','owned_reader_algorithm'] if kind=='complexity' else ['owned_algorithm_model']
                elif s['id']=='logic-v3':
                    roles=['source_table_observation','owned_reader_algorithm'] if kind=='form' else ['owned_algorithm_model']
                elif s['id']=='dataformats':
                    roles=['engine_observation','owned_observer_algorithm'] if kind.startswith('json_') else ['owned_algorithm_model']
                elif s['id'].startswith('astronomy'):
                    roles=['owned_algorithm_model','retained_source_premises'] if kind in ('light_time','weight','ratio','year_years','distance_from_earth') else ['source_table_observation','owned_reader_algorithm']
                elif s['id'].startswith('chemistry'):
                    roles=['owned_algorithm_model','retained_source_premises'] if kind in ('molar_mass','g2mol','mol2g','percent') else ['source_table_observation','owned_reader_algorithm']
                elif s['id']=='library':
                    roles=['source_table_observation','owned_reader_algorithm'] if kind.startswith('lcc') else ['owned_algorithm_model']
                elif s['id']=='geography':
                    roles=['source_table_observation','owned_reader_algorithm'] if kind.startswith('capital') else ['owned_algorithm_model']
                elif s['id']=='crafts':
                    roles=['source_table_observation','owned_reader_algorithm'] if kind.startswith('mix_') or kind=='complement' else ['owned_algorithm_model']
                elif 'owned_algorithm_model' in roles and 'source_table_observation' in roles:
                    roles=['owned_algorithm_model','retained_source_premises']
            operation_roles[kind]=roles
        entries[s['id']] = dict(status='not_lifted', scope={'declared_operations': s['declared_kinds'], 'operation_roles':operation_roles, 'behavior_roles': scopes, 'declared_class': s['class'], 'acceptance_policy':manifest.get('accept',{}), 'family_hint': s['family'], 'declared_resource_claim':manifest.get('store'), 'domain_missing_from_registry_at_inventory':s['domain_missing_from_registry'], 'operation_review': 'Source-based migration profile; inherited closure limits explicit' if profile else 'AST extracted; semantic profile review remains required'},
          source_revision=inventory['upstream_revision'], source_paths=[s['manifest'], s['module']], capability_packages=[], implementation_evidence=[], assurance_evidence=[], behavior_evidence=[], deployment_evidence=[], limitations=['Declared kind is not an activation witness.', 'No native migration or refinement established.', 'Imported helpers, dispatch and model premises require family review.'], semantic_profile=('docs/coverage/classification/domain-profiles.json#'+profile[0]) if profile else None,
          work_packages=profile[1]['owners'] if profile else ['domain-families'] if s['family']=='needs-semantic-classification' else {'relation-readers':['relation-family'], 'ordered-fact-rules':['facts-document-family'], 'quantity-computation':['domain-families'], 'stateful-site':['state-effects','stateful-connectors']}.get(s['family'], ['coverage-disposition']))
    for source in inventory['specialists']:
        entry=entries[source['id']]
        if source['domain_missing_from_registry']:
            entry['limitations'].append('Manifest domain absent from central registry at pinned audit; store availability and route-specific reachability require review.')
        if source['family']=='stateful-site':
            entry['limitations'].append('Warehouse confirmation appends an in-memory requested-order artifact; no external order dispatch or durable warehouse mutation is implemented by SiteOrgan.')
        if source['family']=='relation-readers':
            entry['limitations'].append('Release relation/name snapshot dependencies are missing (audit/results/availability.json); alternate handwritten readers do not establish complete mined-source parity.')
    for name,entry in entries.items():
        previous=decisions.get('entries',{}).get(name,{})
        # Refinement/implementation evidence is hand-reviewed authority: a source
        # index refresh must never demote or erase another integration's work.
        for field in ('status','capability_packages','implementation_evidence','assurance_evidence','behavior_evidence','deployment_evidence'):
            if field in previous:entry[field]=previous[field]
        for limitation in previous.get('limitations',[]):
            if limitation not in entry['limitations']:entry['limitations'].append(limitation)
    decisions['entries'] = entries
    decisions['classification_note'] = 'All manifests retained with exact declared operations and source paths; 119 domain entries have source-reviewed migration profiles. Roles describe migration obligations, not completed lifts. Source-only algorithms remain owned even when their data is observed.'
    # Generated obligations use one object per line; human semantic rationale lives
    # in the shared profiles instead of thousands of repeated AST pseudo-records.
    meta={k:v for k,v in decisions.items() if k!='entries'}
    header=json.dumps(meta,indent=2,sort_keys=True).rstrip()[:-1].rstrip()
    lines=[header+',', '  "entries": {']
    items=sorted(entries.items())
    for index,(name,entry) in enumerate(items):
        lines.append('    '+json.dumps(name)+': '+json.dumps(entry,sort_keys=True,separators=(',',':'))+(',' if index<len(items)-1 else ''))
    lines+=['  }','}']
    (ROOT/'audit/coverage/decisions.json').write_text('\n'.join(lines)+'\n')
    out={'source_revision':inventory['upstream_revision'], 'python_source_count':len(inventory['python_sources']), 'tracked_file_count':len(inventory['tracked_files']), 'manifest_count':len(entries), 'unreviewed_reachability_paths':[x['path'] for x in inventory['python_sources']], 'exclusions':[], 'materialized_data_evidence':'audit/results/availability.json', 'note':'All non-manifest source remains explicit pending reachability review; no bulk dead-code exclusion.'}
    (ROOT/'docs/coverage/classification/denominator.json').write_text(json.dumps(out,indent=2)+'\n')
    print(f'{len(entries)} manifest dispositions; {len(out["unreviewed_reachability_paths"])} source paths retained; no exclusions')
if __name__ == '__main__': main()
