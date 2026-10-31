#!/usr/bin/env python3
"""Untrusted host consumer for supplied steady passive thermal scenarios.

Transport and independent power checks are ordinary Python, not proved. This
compares supplied scenarios, not a real building forecast or worst-case bound.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
# Support both direct CLI use and path-based importlib loading by panel tools.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from hosted_reasoning import Client as Transport, ContractError, compact, invoke_envelope

OPERATION = 'science.thermal_scenarios'


def validate_reply(arguments, envelope):
    def require(condition, reason):
        if not condition:
            raise ContractError(reason)
    require(isinstance(envelope, dict) and envelope.get('outcome') == 'completed'
            and envelope.get('operation_id') == OPERATION, 'host operation failed')
    reply = envelope.get('reply', {})
    require(reply.get('operation_id') == OPERATION and reply.get('authority') == 'computation_only', 'wrong reply authority')
    if reply.get('status') != 'answered':
        return {'status': 'withheld', 'reason': reply.get('reason', 'host_refusal')}
    result = reply.get('result', {})
    require(result.get('schema') == 'oracle-science-experimental-v1' and result.get('operation') == OPERATION,
            'wrong result schema')
    network = arguments['network']
    order = [n['id'] for n in network['nodes']]
    require(result.get('node_order') == order, 'node order changed')
    require(isinstance(result.get('network_identity'), str) and result['network_identity'].startswith('sha256:'), 'missing content identity')
    require(result.get('factorization_count') == int(any(n.get('fixed_temperature_k') is None for n in network['nodes'])), 'wrong factorization reuse count')
    scenarios = result.get('scenarios')
    require(isinstance(scenarios, list) and [s.get('id') for s in scenarios] == [s['id'] for s in arguments['scenarios']], 'scenario coverage changed')
    index = {node: i for i, node in enumerate(order)}
    summaries = []
    for source, solved in zip(arguments['scenarios'], scenarios):
        data = solved.get('result', {})
        require(data.get('outcome') == 'solved_within_tolerance', 'unaccepted scenario')
        nodes = data.get('nodes', [])
        require([n.get('id') for n in nodes] == order, 'missing power evidence')
        temps = [n.get('temperature_k') for n in nodes]
        require(all(type(t) in (int, float) and math.isfinite(t) and t >= 0 for t in temps), 'invalid accepted temperature')
        outgoing = [[] for _ in nodes]
        for link in network['links']:
            i, j = index[link['from']], index[link['to']]
            q = link['conductance_w_per_k'] * (temps[i] - temps[j])
            outgoing[i].append(q)
            outgoing[j].append(-q)
        for i, node in enumerate(nodes):
            fixed = source['fixed_temperature_k'][i]
            require(fixed is None or temps[i] == fixed, 'boundary changed')
            out = math.fsum(outgoing[i])
            boundary = node.get('boundary_exchange_w') if fixed is not None else 0
            require(type(boundary) in (int, float) and math.isfinite(boundary), 'invalid reservoir exchange')
            residual = out - source['applied_heat_w'][i] - boundary
            tolerance = network.get('power_tolerance_w', 1e-8) + network.get('tolerances', {}).get('consistency_relative', 1e-10) * (math.fsum(abs(x) for x in outgoing[i]) + abs(source['applied_heat_w'][i]))
            require(abs(residual) <= tolerance, 'independent original-node power balance failed')
        summaries.append({'id': source['id'], 'temperature_k': dict(zip(order, temps)),
                          'boundary_exchange_w': {n['id']: n['boundary_exchange_w'] for n in nodes if n.get('fixed_temperature_k') is not None}})
    derivatives = result.get('sensitivities')
    requests = arguments.get('sensitivities', [])
    require(isinstance(derivatives, list) and len(derivatives) == len(requests), 'sensitivity coverage changed')
    for request, derivative in zip(requests, derivatives):
        require(derivative.get('scenario_id') == request['scenario_id'] and derivative.get('parameter') == request['parameter'], 'sensitivity parameter changed')
        values = derivative.get('temperature_derivative')
        require(isinstance(values, list) and len(values) == len(order) and all(type(x) in (int,float) and math.isfinite(x) for x in values), 'invalid derivative')
        source = next(s for s in arguments['scenarios'] if s['id'] == request['scenario_id'])
        temperatures = next(s['temperature_k'] for s in summaries if s['id'] == request['scenario_id'])
        flows = [[] for _ in order]
        parameter = request['parameter']
        for k, link in enumerate(network['links']):
            i, j = index[link['from']], index[link['to']]
            d = link['conductance_w_per_k']*(values[i]-values[j])
            if parameter['kind'] == 'conductance' and parameter['link_index'] == k:
                d += temperatures[link['from']] - temperatures[link['to']]
            flows[i].append(d)
            flows[j].append(-d)
        for i in range(len(order)):
            if source['fixed_temperature_k'][i] is not None:
                require(values[i] == 0, 'boundary derivative changed')
                continue
            load = int(parameter['kind'] == 'load' and parameter['node_id'] == order[i])
            magnitude = max(1, math.fsum(abs(x) for x in flows[i])+load)
            require(abs(math.fsum(flows[i])-load) <= 1e-9*magnitude, 'independent derivative balance failed')
    return {'status': 'answered', 'network_identity': result['network_identity'], 'scenarios': summaries,
            'sensitivities': derivatives, 'factorization_count': result['factorization_count'],
            'scope': 'supplied steady passive linear network; local derivatives; no uncertainty bound'}


class Client(Transport):
    def discover(self):
        descriptor = self.transport('/operations/' + OPERATION)
        if descriptor.get('id') != OPERATION or descriptor.get('availability') != 'live_direct':
            raise ContractError('thermal scenarios unavailable')

    def invoke(self, arguments):
        envelope = self.transport('/invoke', invoke_envelope(OPERATION, arguments, 'thermal-scenarios'))
        return validate_reply(arguments, envelope)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--tenant', default='thermal-demo')
    parser.add_argument('--input', type=Path, default=Path(__file__).resolve().parent / 'specialist/thermal-scenarios/example.json')
    args = parser.parse_args()
    client = Client(args.url, args.tenant)
    client.discover()
    print(json.dumps(client.invoke(json.loads(args.input.read_text())), indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
