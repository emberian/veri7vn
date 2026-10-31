#!/usr/bin/env python3
"""Untrusted transport for native revisable-evidence exports.

Consumes JSON exported by revisions_lab; ledger/revision semantics belong to
Rust, never this client. Supplied incident fixtures do not authorize deployment
or establish completeness of the external world. Existing host trust applies.
"""
import argparse
import json
from pathlib import Path
from hosted_reasoning import Client, ContractError, compact, digest, program_text


def run(client, exported):
    rows = []
    for revision in exported:
        arguments = dict(revision['request'])
        arguments.pop('operation')
        receipt = revision['receipt']
        if (arguments['scope']['tenant'] != client.tenant
                or receipt['scope']['tenant'] != client.tenant
                or receipt['snapshot_identity'] != arguments['scope']['snapshot']
                or receipt['program_identity'] != digest(program_text(arguments))
                or receipt['request_identity'] != digest(compact(revision['request']))):
            raise ContractError('native export receipt mismatch')
        result = client.invoke('logic.query', arguments)
        if (len(result['answers']) != 1
                or result['answers'][0]['skeptical'] is not revision['gold_safe']):
            raise ContractError('fresh host result differs from incident gold or is inconclusive')
        # Native receipt binds program and query identities; existing Client
        # checks the actual host reply against both complete request identities.
        rows.append({'receipt': revision['receipt'], 'result': result})
    return rows


def persisted(client, scenario):
    """Commit evidence first, then solve its exact immutable native revision."""
    if (len(scenario['history']) != len(scenario['gold_safe'])
            or scenario['queries'] != ['safe']):
        raise ContractError('incomplete incident gold/query fixture')
    session_version = 0
    rows = []
    conversation = scenario['scope']['workspace']
    def invoke(operation, command, request_id):
        body = {'operation_id': operation,
                'arguments': {'command': command, 'expected_version': session_version},
                'request_id': request_id, 'conversation_id': conversation}
        envelope = client.transport('/invoke', body)
        if envelope.get('outcome') != 'completed' or envelope.get('operation_id') != operation:
            raise ContractError('workspace operation did not complete')
        reply = envelope.get('reply', {})
        if reply.get('operation_id') != operation or reply.get('authority') != 'supplied_evidence':
            raise ContractError('workspace reply authority/operation mismatch')
        raw = reply.get('core_reply_json')
        if not isinstance(raw, str):
            raise ContractError('missing exact native reply')
        return json.loads(raw)
    for revision, gold in zip(scenario['history'], scenario['gold_safe']):
        mutation = {'command': 'revise', 'revision': revision}
        request_id = 'evidence-' + digest(compact(mutation))[:32]
        committed = invoke('logic.workspace', mutation, request_id)
        # An exact request replay must return the identical journal result even
        # with the original now-stale expected session version.
        if invoke('logic.workspace', mutation, request_id) != committed:
            raise ContractError('mutation exact replay changed acknowledgement')
        if committed.get('version') != session_version + 1:
            raise ContractError('session version did not advance atomically')
        session_version = committed['version']
        ack = committed['result']
        if ack['scope']['tenant'] != client.tenant:
            raise ContractError('mutation tenant mismatch')
        evidence_revision = ack['commit']['revision']
        solved = invoke('logic.workspace.solve',
                        {'command': 'solve', 'expected_revision': evidence_revision,
                         'queries': scenario['queries']}, request_id + '-solve')
        receipt = solved['receipt']
        if (receipt['scope'] != ack['scope'] or receipt['revision'] != evidence_revision
                or receipt['snapshot_identity'] != ack['commit']['snapshot_identity']):
            raise ContractError('answer is not bound to committed evidence')
        answers = solved['result']['answers']
        if len(answers) != 1 or answers[0]['skeptical'] is not gold:
            raise ContractError('persisted workspace differs from incident gold')
        rows.append({'commit': ack, 'solve': solved})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export', type=Path)
    parser.add_argument('--tenant', required=True)
    parser.add_argument('--persisted-history', action='store_true',
                        help='input is incident-history.json; use durable native owner')
    parser.add_argument('--url', default='http://127.0.0.1:8765')
    args = parser.parse_args()
    # Client construction follows the host's existing transport contract.
    client = Client(args.url, args.tenant)
    data = json.loads(args.export.read_text())
    rows = persisted(client, data) if args.persisted_history else run(client, data)
    print(json.dumps(rows, indent=2))


if __name__ == '__main__':
    main()
