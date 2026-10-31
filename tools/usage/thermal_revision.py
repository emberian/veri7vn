#!/usr/bin/env python3
"""Untrusted supplied-measurement adapter, not a physical forecast or HOL proof.

Atoms select explicit typed records; they never encode or parse numerical values.
The host retains evidence, while this caller supplies the numerical model/package.
"""
import argparse
import copy
import json
import math
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from hosted_reasoning import Client, ContractError, compact, digest, program_text, invoke_envelope
from revisable_evidence import EvidenceCursor, strict_json
from thermal_scenarios import Client as ScenarioClient, validate_reply as validate_thermal_reply, OPERATION

SCHEMA = 'supplied-thermal-measurements-v1'


class ThermalClient(ScenarioClient):
    def invoke(self, arguments):
        envelope = self.transport('/invoke', invoke_envelope(OPERATION, arguments, 'thermal-revision'))
        summary = validate_thermal_reply(arguments, envelope)
        if summary['status'] == 'answered':
            # Keep the bound numerical outcome and original-node residuals as
            # reviewable evidence, in addition to the independent Python check.
            summary['outcome_and_balance'] = envelope['reply']['result']['scenarios'][0]['result']
        return summary


def require(value, message):
    if not value:
        raise ContractError(message)


def queries(package):
    return [package['coverage_atom']] + [r['support_atom'] for r in package['measurements']]


def checked_answers(package, solved):
    """Reconstruct native compiler indexing from its complete support templates.

    The authenticated host supplies these templates. Check request/program hashes
    and exact answer IDs, including inactive query-only atoms, before selection.
    This is a consistency check, not independent evidence authentication.
    """
    receipt = solved.get('receipt', {})
    templates = solved.get('support_templates')
    require(type(templates) is list, 'missing support templates')
    labels = set(queries(package))
    for row in templates:
        labels.update(row['conjunction'] + row['absent'])
        if row['head'] is not None:
            labels.add(row['head'])
    atoms = sorted(labels)
    index = {label: i for i, label in enumerate(atoms)}
    scope = {'tenant': receipt['scope']['tenant'], 'snapshot': receipt['snapshot_identity'], 'complete_program': True}
    request = {'operation': 'query', 'scope': scope, 'atoms': atoms,
        'rules': [{'head': None if row['head'] is None else index[row['head']],
                   'positive': [index[a] for a in row['conjunction']],
                   'negative': [index[a] for a in row['absent']]} for row in templates],
        'queries': [index[a] for a in queries(package)]}
    require(receipt.get('compiler') == 'oracle.logic.revisions/1'
        and receipt.get('request_identity') == digest(compact(request))
        and receipt.get('program_identity') == digest(program_text(request)), 'compiled evidence identity mismatch')
    result = solved.get('result', {})
    answers = result.get('answers', [])
    require(result.get('scope') == scope and [a.get('atom') for a in answers] == request['queries'], 'evidence query identity mismatch')
    require(result.get('status') == 'consistent'
        and result.get('completeness_trust', '').startswith('solver_trusted_'), 'incomplete evidence solve')
    return answers


def validate_package(package):
    require(set(package) == {'schema', 'coverage_atom', 'measurements', 'network', 'decision'}, 'unknown or missing package fields')
    require(package.get('schema') == SCHEMA, 'measurement schema mismatch')
    records = package['measurements']
    require(records and len({r['id'] for r in records}) == len(records), 'measurement IDs missing or repeated')
    require(type(package['coverage_atom']) is str and package['coverage_atom'], 'invalid coverage atom')
    require(len(set(queries(package))) == len(queries(package)), 'coverage and support atoms must be distinct')
    require(set(package['decision']) == {'node_id', 'maximum_temperature_k'}, 'invalid decision schema')
    network = package['network']
    require({'description', 'assumptions', 'reference_temperature_k', 'nodes', 'links'} <= set(network)
        <= {'description', 'assumptions', 'reference_temperature_k', 'nodes', 'links', 'power_tolerance_w', 'tolerances'}, 'invalid network schema')
    require(type(network['description']) is str and type(network['assumptions']) is list
        and all(type(a) is str for a in network['assumptions']), 'invalid model declarations')
    reference = network['reference_temperature_k']
    require(type(reference) in (int, float) and math.isfinite(reference) and reference >= 0, 'invalid reference temperature')
    if 'power_tolerance_w' in network:
        tolerance = network['power_tolerance_w']
        require(type(tolerance) in (int, float) and math.isfinite(tolerance) and tolerance >= 0, 'invalid power tolerance')
    if 'tolerances' in network:
        tolerances = network['tolerances']
        require(set(tolerances) == {'rank_relative', 'consistency_relative'}, 'invalid tolerance schema')
        require(all(type(v) in (int, float) and math.isfinite(v) and 0 < v < 1 for v in tolerances.values()), 'invalid numerical tolerance')
    nodes = network['nodes']
    require(0 < len(nodes) <= 128 and len(network['links']) <= 1024, 'network exceeds adapter limit')
    for node in nodes:
        require({'id', 'applied_heat_w'} <= set(node) <= {'id', 'applied_heat_w', 'fixed_temperature_k'}, 'invalid node schema')
        require(type(node['id']) is str and node['id'], 'invalid node ID')
        require(type(node['applied_heat_w']) in (int, float) and math.isfinite(node['applied_heat_w']), 'invalid base load')
        fixed = node.get('fixed_temperature_k')
        require(fixed is None or type(fixed) in (int, float) and math.isfinite(fixed) and fixed >= 0, 'invalid fixed boundary')
    for link in network['links']:
        require(set(link) == {'from', 'to', 'conductance_w_per_k'}, 'invalid link schema')
        require(link['from'] in {n['id'] for n in nodes} and link['to'] in {n['id'] for n in nodes}, 'unknown link node')
        g = link['conductance_w_per_k']
        require(type(g) in (int, float) and math.isfinite(g) and g > 0, 'invalid base conductance')
    require(len({n['id'] for n in nodes}) == len(nodes), 'duplicate nodes')
    require(package['decision']['node_id'] in {n['id'] for n in nodes}, 'unknown decision node')
    limit = package['decision']['maximum_temperature_k']
    require(type(limit) in (int, float) and math.isfinite(limit) and limit >= 0, 'invalid decision limit')
    for record in records:
        require(set(record) == {'id', 'value', 'unit', 'target', 'source', 'source_revision', 'support_atom'}, 'invalid measurement schema')
        require(all(type(record[k]) is str and record[k] for k in ('id', 'source', 'source_revision', 'support_atom')), 'missing measurement label')
        target = record['target']
        kind = target.get('kind')
        require(kind in ('load', 'conductance'), 'unknown measurement target')
        require(set(target) == ({'kind', 'node_id'} if kind == 'load' else {'kind', 'link_index'}), 'invalid target schema')
        require(record['unit'] == ('W' if kind == 'load' else 'W/K'), 'measurement unit mismatch')
        value = record['value']
        require(type(value) in (int, float) and math.isfinite(value) and (kind != 'conductance' or value > 0), 'invalid measurement value')
        if kind == 'load':
            matches = [n for n in nodes if n['id'] == target['node_id']]
            require(len(matches) == 1 and matches[0].get('fixed_temperature_k') is None, 'load target must be a free node')
        else:
            index = target['link_index']
            require(type(index) is int and 0 <= index < len(package['network']['links']), 'invalid conductance link')


def adapt(package, solved):
    """Pin selection to a completed exact solve; agreeing alternatives survive.

    No majority voting, newest-source preference, missing-value defaults, or
    fallback to base values for any declared measured target is allowed.
    """
    validate_package(package)
    records = package['measurements']
    receipt = solved.get('receipt', {})
    answers = checked_answers(package, solved)
    require(type(receipt.get('revision')) is int and type(receipt.get('snapshot_identity')) is str, 'missing evidence receipt')
    binding = {'evidence_receipt': copy.deepcopy(receipt), 'measurement_package_identity': digest(compact(package)),
               'base_supplied_model_identity': digest(compact(package['network']))}
    if answers[0].get('skeptical') is not True:
        return None, {**binding, 'status': 'withheld', 'reason': 'measurement coverage unavailable'}
    network = copy.deepcopy(package['network'])
    targets = {}
    for record, answer in zip(records, answers[1:]):
        target = record['target']
        kind = target['kind']
        key = compact({'kind': kind, **({'node_id': target['node_id']} if kind == 'load' else {'link_index': target['link_index']})})
        targets.setdefault(key, [])
        if answer.get('skeptical') is True:
            targets[key].append(record)
    selected = []
    for key, active in targets.items():
        if not active or len({r['value'] for r in active}) != 1:
            return None, {**binding, 'status': 'withheld', 'reason': 'missing or conflicting measurement support', 'target': json.loads(key)}
        record = active[0]
        target = record['target']
        if target['kind'] == 'load':
            nodes = [n for n in network['nodes'] if n['id'] == target['node_id']]
            require(len(nodes) == 1, 'unknown load node')
            nodes[0]['applied_heat_w'] = record['value']
        else:
            index = target['link_index']
            require(type(index) is int and 0 <= index < len(network['links']), 'invalid conductance link')
            network['links'][index]['conductance_w_per_k'] = record['value']
        selected.append({'target': target, 'value': record['value'], 'unit': record['unit'], 'supporting_measurements': [r['id'] for r in active]})
    binding.update(selected_measurements=selected, supplied_model_identity=digest(compact(network)))
    return network, binding


def decide(package, solved, thermal):
    network, binding = adapt(package, solved)
    if network is None:
        return binding
    arguments = {'network': network, 'scenarios': [{'id': 'revision',
        'applied_heat_w': [n.get('applied_heat_w', 0) for n in network['nodes']],
        'fixed_temperature_k': [n.get('fixed_temperature_k') for n in network['nodes']]}], 'sensitivities': []}
    numerical = thermal.invoke(arguments)
    if numerical['status'] != 'answered':
        return {**binding, 'status': 'withheld', 'reason': 'thermal calculation withheld', 'numerical': numerical}
    decision = package['decision']
    limit = decision['maximum_temperature_k']
    require(type(limit) in (int, float) and math.isfinite(limit) and limit >= 0, 'invalid decision limit')
    temperature = numerical['scenarios'][0]['temperature_k'][decision['node_id']]
    return {**binding, 'status': 'answered', 'decision': 'accept' if temperature <= limit else 'reject',
        'temperature_k': temperature, 'maximum_temperature_k': limit, 'numerical': numerical,
        'preparation_policy': 'fresh complete network preparation on every call; no retained cross-request factors',
        'scope': 'decision for this supplied model and evidence snapshot; not necessarily latest at return; not a physical forecast'}


def run(client, thermal, plan, cursor_path):
    package = plan['package']
    validate_package(package)
    rows = []
    with EvidenceCursor(client, cursor_path, plan['conversation'], digest(compact(plan))) as cursor:
        start = cursor.record['next_index']
        if start:
            rows.append(decide(package, cursor.solve(queries(package)), thermal))
        for step in plan['steps'][start:]:
            cursor.revise(step['revision'])
            rows.append(decide(package, cursor.solve(queries(package)), thermal))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--tenant', default='thermal-revision-demo')
    parser.add_argument('--input', type=Path, default=Path(__file__).resolve().parent / 'specialist/thermal-revision/example.json')
    parser.add_argument('--cursor', required=True, type=Path)
    args = parser.parse_args()
    plan = strict_json(args.input.read_text())
    validate_package(plan['package'])
    thermal = ThermalClient(args.url, args.tenant)
    thermal.discover()
    print(json.dumps(run(Client(args.url, args.tenant), thermal, plan, args.cursor), indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
