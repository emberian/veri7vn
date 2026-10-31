#!/usr/bin/env python3
"""Untrusted transport for native revisable-evidence exports.

Consumes JSON exported by revisions_lab; ledger/revision semantics belong to
Rust, never this client. Supplied incident fixtures do not authorize deployment
or establish completeness of the external world. Existing host trust applies.
"""
import argparse
import json
import os
from pathlib import Path
import tempfile
from hosted_reasoning import Client, ContractError, compact, digest, program_text, unique_object, invalid_constant

MAX_CURSOR_BYTES = 1024 * 1024


def strict_json(text):
    return json.loads(text, object_pairs_hook=unique_object, parse_constant=invalid_constant)


def atomic_cursor(path, value):
    """Replace only this explicit client cursor; server owns all evidence."""
    encoded = json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False)
    if len(encoded.encode('utf-8')) > MAX_CURSOR_BYTES:
        raise ContractError('client cursor exceeds resumable storage limit')
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                         prefix=path.name + '.', delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        temporary = None
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if temporary is not None:
            temporary.unlink()


class EvidenceCursor:
    """Explicit retry cursor; its receipts grant no server import authority.

    Hold the local exclusive lock through transport. A pending exact mutation is
    saved before sending and retired only after validating its acknowledgement.
    Resume recovers pending first, then checks the server's pinned current state.
    """
    SCHEMA = 'oracle-evidence-client-resume-v1'

    def __init__(self, client, path, conversation, plan_identity):
        self.client, self.path = client, Path(path)
        self.conversation, self.plan_identity = conversation, plan_identity
        self.scope = {'tenant': client.tenant, 'workspace': digest(
            'oracle-native-runtime-host-v1\0session\0' + conversation)}
        self.record = None
        self.lock = None

    def __enter__(self):
        import fcntl  # Cursor mode targets the existing macOS/Linux appliance.
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock = os.open(str(self.path) + '.owner', os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            descriptor = self.client.transport('/operations/logic.workspace.checkpoint')
            self.runtime = descriptor.get('implementation', {}).get('runtime_identity')
            if (descriptor.get('id') != 'logic.workspace.checkpoint'
                    or descriptor.get('availability') != 'live_direct'
                    or type(self.runtime) is not str or len(self.runtime) != 64):
                raise ContractError('checkpoint operation unavailable or unidentified')
            if self.path.exists():
                if self.path.stat().st_size > MAX_CURSOR_BYTES:
                    raise ContractError('client cursor too large')
                self.record = strict_json(self.path.read_text())
                self._validate_record()
            else:
                self.record = {'schema': self.SCHEMA, 'tenant': self.client.tenant,
                    'conversation': self.conversation, 'runtime_identity': self.runtime,
                    'plan_identity': self.plan_identity, 'position': {'session_version': 0,
                    'revision': 0, 'snapshot_identity': None}, 'next_index': 0,
                    'pending': None, 'last_checkpoint': None, 'last_ack_json': None}
            self.recover_pending()
            self.verify()
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *_):
        if self.lock is not None:
            os.close(self.lock)
            self.lock = None

    def _save(self):
        atomic_cursor(self.path, self.record)

    def _validate_record(self):
        record = self.record
        if (type(record) is not dict or record.get('schema') != self.SCHEMA
                or record.get('tenant') != self.client.tenant
                or record.get('conversation') != self.conversation
                or record.get('runtime_identity') != self.runtime
                or record.get('plan_identity') != self.plan_identity):
            raise ContractError('cursor tenant/conversation/deployment/plan mismatch')
        position = record.get('position')
        if (type(position) is not dict or type(position.get('session_version')) is not int
                or not 0 <= position['session_version'] < 2**63
                or type(position.get('revision')) is not int or not 0 <= position['revision'] < 2**64
                or type(position.get('snapshot_identity')) is not str
                or len(position['snapshot_identity']) != 64
                or type(record.get('next_index')) is not int or record['next_index'] < 0):
            raise ContractError('invalid cursor position')
        pending = record.get('pending')
        if pending is not None:
            if type(pending) is not dict or type(pending.get('request')) is not dict:
                raise ContractError('invalid pending request')
            request = pending['request']
            command = request.get('arguments', {}).get('command', {})
            revision = command.get('revision', {})
            expected = self._mutation_request(revision)
            if (request != expected or pending.get('request_identity') != digest(compact(request))
                    or pending.get('next_index') != record['next_index'] + 1):
                raise ContractError('pending request changed or is not based on cursor')

    def _invoke(self, body):
        operation = body['operation_id']
        envelope = self.client.transport('/invoke', body)
        if envelope.get('outcome') != 'completed' or envelope.get('operation_id') != operation:
            raise ContractError('workspace operation did not complete')
        reply = envelope.get('reply', {})
        if (reply.get('operation_id') != operation or reply.get('authority') != 'supplied_evidence'
                or reply.get('runtime_identity') != self.runtime
                or type(reply.get('core_reply_json')) is not str):
            raise ContractError('workspace reply authority/deployment mismatch')
        raw = reply['core_reply_json']
        core = strict_json(raw)
        if type(core) is not dict:
            raise ContractError('invalid workspace core reply')
        return core, raw

    def _request(self, operation, command, version):
        body = {'operation_id': operation, 'arguments': {'command': command,
                'expected_version': version}, 'conversation_id': self.conversation}
        body['request_id'] = 'evidence-' + digest(compact(body))[:40]
        return body

    def _mutation_request(self, revision):
        if (type(revision) is not dict
                or type(revision.get('expected_revision')) is not int
                or revision.get('expected_revision') != self.record['position']['revision']):
            raise ContractError('mutation does not extend cursor evidence revision')
        return self._request('logic.workspace', {'command': 'revise', 'revision': revision},
                             self.record['position']['session_version'])

    def recover_pending(self):
        pending = self.record['pending']
        if pending is None:
            return
        self._validate_record()
        body = pending['request']
        core, raw = self._invoke(body)
        ack = core.get('result', {})
        commit = ack.get('commit', {})
        if (core.get('version') != body['arguments']['expected_version'] + 1
                or ack.get('scope') != self.scope
                or commit.get('revision') != self.record['position']['revision'] + 1
                or type(commit.get('snapshot_identity')) is not str
                or len(commit['snapshot_identity']) != 64):
            raise ContractError('acknowledgement does not match pending mutation')
        self.record['position'] = {'session_version': core['version'],
            'revision': commit['revision'], 'snapshot_identity': commit['snapshot_identity']}
        self.record['next_index'] = pending['next_index']
        self.record['last_ack_json'] = raw
        self.record['pending'] = None
        self._save()

    def verify(self):
        if self.record['pending'] is not None:
            raise ContractError('recover the pending exact request before checking current state')
        position = self.record['position']
        command = {'command': 'checkpoint', 'expected_revision': position['revision'],
                   'expected_snapshot_identity': position['snapshot_identity']}
        body = self._request('logic.workspace.checkpoint', command, position['session_version'])
        core, _ = self._invoke(body)
        checkpoint = core.get('checkpoint', {})
        if (core.get('schema') != 'oracle-evidence-checkpoint-v1'
                or core.get('runtime_identity') != self.runtime
                or core.get('session_version') != position['session_version']
                or checkpoint.get('scope') != self.scope
                or checkpoint.get('revision') != position['revision']
                or type(checkpoint.get('snapshot_identity')) is not str
                or len(checkpoint['snapshot_identity']) != 64
                or position['snapshot_identity'] is not None
                   and checkpoint['snapshot_identity'] != position['snapshot_identity']):
            raise ContractError('server checkpoint differs from cursor')
        position['snapshot_identity'] = checkpoint['snapshot_identity']
        self.record['last_checkpoint'] = core
        self._save()
        return core

    def revise(self, revision):
        self.recover_pending()
        self.verify()
        body = self._mutation_request(revision)
        self.record['pending'] = {'request': body, 'request_identity': digest(compact(body)),
                                 'next_index': self.record['next_index'] + 1}
        try:
            self._save()  # Required before network I/O, including the first attempt.
        except BaseException:
            # A caller may catch this while retaining the same object. Never
            # let recover_pending send an intent that was not durably written.
            self.record['pending'] = None
            raise
        self.recover_pending()
        return self.verify()

    def solve(self, queries):
        self.recover_pending()
        position = self.record['position']
        command = {'command': 'solve', 'expected_revision': position['revision'], 'queries': queries}
        core, _ = self._invoke(self._request('logic.workspace.solve', command, position['session_version']))
        receipt = core.get('receipt', {})
        if (receipt.get('scope') != self.scope or receipt.get('revision') != position['revision']
                or receipt.get('snapshot_identity') != position['snapshot_identity']):
            raise ContractError('solve receipt differs from committed cursor')
        return core


def resumable(client, scenario, cursor_path, stop_after=None):
    """Continue a supplied finite plan; pure solving may safely repeat."""
    if len(scenario['history']) != len(scenario['gold_safe']) or scenario['queries'] != ['safe']:
        raise ContractError('incomplete supplied plan')
    rows = []
    with EvidenceCursor(client, cursor_path, scenario['scope']['workspace'], digest(compact(scenario))) as cursor:
        index = cursor.record['next_index']
        if index > len(scenario['history']):
            raise ContractError('cursor exceeds supplied plan')
        # A prior mutation may have committed while its subsequent solve failed.
        # Re-solve that exact committed revision before submitting new evidence.
        if index:
            solved = cursor.solve(scenario['queries'])
            if solved['result']['answers'][0]['skeptical'] is not scenario['gold_safe'][index - 1]:
                raise ContractError('resumed solve differs from supplied gold')
            rows.append({'checkpoint': cursor.record['last_checkpoint'], 'solve': solved})
        end = len(scenario['history']) if stop_after is None else min(len(scenario['history']), index + stop_after)
        for revision, gold in zip(scenario['history'][index:end], scenario['gold_safe'][index:end]):
            checkpoint = cursor.revise(revision)
            solved = cursor.solve(scenario['queries'])
            if len(solved['result']['answers']) != 1 or solved['result']['answers'][0]['skeptical'] is not gold:
                raise ContractError('resumed workspace differs from supplied gold')
            rows.append({'checkpoint': checkpoint, 'solve': solved})
    return rows


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
    parser.add_argument('--cursor', type=Path,
                        help='explicit atomic client retry cursor; resume it after host/client restart')
    parser.add_argument('--stop-after', type=int,
                        help='with --cursor, apply at most this many additional supplied revisions')
    parser.add_argument('--url', default='http://127.0.0.1:8765')
    args = parser.parse_args()
    if args.cursor and not args.persisted_history:
        parser.error('--cursor requires --persisted-history')
    if args.stop_after is not None and (not args.cursor or args.stop_after < 0):
        parser.error('--stop-after requires --cursor and a nonnegative count')
    # Client construction follows the host's existing transport contract.
    client = Client(args.url, args.tenant)
    data = json.loads(args.export.read_text())
    rows = (resumable(client, data, args.cursor, args.stop_after) if args.cursor
            else persisted(client, data) if args.persisted_history else run(client, data))
    print(json.dumps(rows, indent=2))


if __name__ == '__main__':
    main()
