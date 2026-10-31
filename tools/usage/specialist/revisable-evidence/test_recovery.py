"""Independent transport fault cases; central runner owns execution."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from hosted_reasoning import normalize_tenant, ContractError
from revisable_evidence import EvidenceCursor, resumable, strict_json


class Server:
    def __init__(self):
        self.runtime='a'*64
        self.rows={}
        self.journal={}
        self.mutations=0

    def call(self,tenant,body):
        operation=body['operation_id']; conversation=body['conversation_id']
        key=(tenant,conversation)
        row=self.rows.setdefault(key,{'version':0,'revision':0,'records':{},'active':set()})
        scope={'tenant':tenant,'workspace':hashlib.sha256(('oracle-native-runtime-host-v1\0session\0'+conversation).encode()).hexdigest()}
        identity=lambda:hashlib.sha256(json.dumps([row['revision'],sorted(row['active'])]).encode()).hexdigest()
        args=body['arguments'];command=args['command']
        journal_key=(tenant,body['request_id'])
        if operation=='logic.workspace' and journal_key in self.journal:
            prior,result=self.journal[journal_key]
            if prior!=body:raise ContractError('409 changed retry')
            return copy.deepcopy(result)
        if args['expected_version']!=row['version']:raise ContractError('409 stale session')
        if operation=='logic.workspace.checkpoint':
            if command['expected_revision']!=row['revision'] or command.get('expected_snapshot_identity') not in (None,identity()):
                raise ContractError('409 stale checkpoint')
            core={'schema':'oracle-evidence-checkpoint-v1','runtime_identity':self.runtime,
                  'session_version':row['version'],'checkpoint':{'scope':scope,'revision':row['revision'],
                  'snapshot_identity':identity(),'active_record_ids':sorted(row['active']),
                  'coverage_ids':sorted(k for k in row['active'] if row['records'][k]['kind']=='coverage')}}
        elif operation=='logic.workspace':
            revision=command['revision']
            if revision['expected_revision']!=row['revision']:raise ContractError('409 stale evidence')
            for record in revision['insert']:
                if record['id'] in row['records']:raise ContractError('duplicate record')
                row['records'][record['id']]=copy.deepcopy(record);row['active'].add(record['id'])
            for identifier in revision['withdraw']:row['active'].remove(identifier)
            row['revision']+=1;row['version']+=1;self.mutations+=1
            core={'version':row['version'],'result':{'scope':scope,'commit':{
                'revision':row['revision'],'snapshot_identity':identity()}}}
        else:
            if command['expected_revision']!=row['revision']:raise ContractError('409 stale solve')
            active=[row['records'][k] for k in row['active']]
            atoms={r['atom'] for r in active if r['kind']=='observation'}
            safe=('ready' in atoms and 'risk' not in atoms and 'risk-coverage' in row['active'])
            core={'receipt':{'scope':scope,'revision':row['revision'],'snapshot_identity':identity()},
                  'result':{'answers':[{'skeptical':safe}]}}
        result={'outcome':'completed','operation_id':operation,'reply':{'operation_id':operation,
            'authority':'supplied_evidence','runtime_identity':self.runtime,'core_reply_json':json.dumps(core,separators=(',',':'))}}
        if operation=='logic.workspace':self.journal[journal_key]=(copy.deepcopy(body),copy.deepcopy(result))
        return result


class Transport:
    def __init__(self,server,tenant='incident-demo'):
        self.server=server;self.tenant=normalize_tenant(tenant)
        self.drop=False;self.fail_solve=False;self.bad_ack=False
    def transport(self,path,body=None):
        if body is None:return {'id':'logic.workspace.checkpoint','availability':'live_direct',
                               'implementation':{'runtime_identity':self.server.runtime}}
        if self.fail_solve and body['operation_id']=='logic.workspace.solve':raise TimeoutError('injected solve timeout')
        result=self.server.call(self.tenant,body)
        if body['operation_id']=='logic.workspace':
            if self.drop:
                self.drop=False;raise ConnectionError('lost response after commit')
            if self.bad_ack:result['reply']['runtime_identity']='f'*64
        return result


class Recovery(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory();self.addCleanup(self.temporary.cleanup)
        self.path=Path(self.temporary.name)/'resume.json'
        self.scenario=strict_json(Path(__file__).with_name('incident-history.json').read_text())
        self.server=Server();self.client=Transport(self.server)
    def cursor(self,client=None):return EvidenceCursor(client or self.client,self.path,'supplied-incident','plan')

    def test_lost_ack_restart_recovers_exact_request_before_new_checkpoint(self):
        self.client.drop=True
        with self.assertRaises(ConnectionError):
            with self.cursor() as cursor:cursor.revise(self.scenario['history'][0])
        pending=strict_json(self.path.read_text())['pending']
        self.assertIsNotNone(pending)
        self.assertEqual(self.server.mutations,1)
        # New client process object; same durable server/journal after restart.
        with self.cursor(Transport(self.server)) as cursor:
            self.assertEqual(cursor.record['next_index'],1)
            self.assertIsNone(cursor.record['pending'])
            self.assertEqual(cursor.record['last_ack_json'],self.server.journal[
                (self.client.tenant,pending['request']['request_id'])][1]['reply']['core_reply_json'])
        self.assertEqual(self.server.mutations,1)

    def test_pending_replay_then_concurrent_advance_refuses_without_rebase(self):
        self.client.drop=True
        with self.assertRaises(ConnectionError):
            with self.cursor() as cursor:cursor.revise(self.scenario['history'][0])
        self.server.rows[(self.client.tenant,'supplied-incident')]['version']+=1
        with self.assertRaisesRegex(ContractError,'stale session'):
            with self.cursor():pass
        record=strict_json(self.path.read_text())
        self.assertIsNone(record['pending']) # Exact ACK was recovered first.
        self.assertEqual(record['position']['session_version'],1)
        self.assertEqual(self.server.mutations,1)

    def test_tenant_deployment_and_plan_mismatch_preserve_pending(self):
        self.client.drop=True
        with self.assertRaises(ConnectionError):
            with self.cursor() as cursor:cursor.revise(self.scenario['history'][0])
        before=self.path.read_bytes()
        with self.assertRaises(ContractError):
            with self.cursor(Transport(self.server,'other')):pass
        self.server.runtime='b'*64
        with self.assertRaises(ContractError):
            with self.cursor():pass
        self.server.runtime='a'*64
        with self.assertRaises(ContractError):
            with EvidenceCursor(self.client,self.path,'supplied-incident','other-plan'):pass
        self.assertEqual(self.path.read_bytes(),before)
        self.assertEqual(self.server.mutations,1)

    def test_invalid_ack_and_changed_pending_do_not_retire_request(self):
        self.client.bad_ack=True
        with self.assertRaises(ContractError):
            with self.cursor() as cursor:cursor.revise(self.scenario['history'][0])
        record=strict_json(self.path.read_text());self.assertIsNotNone(record['pending'])
        record['pending']['request']['arguments']['command']['revision']['token']='tampered'
        self.path.write_text(json.dumps(record))
        with self.assertRaises(ContractError):
            with self.cursor():pass
        self.assertEqual(self.server.mutations,1)

    def test_failed_solve_retains_committed_cursor_and_support_withdrawals_resume(self):
        self.client.fail_solve=True
        with self.assertRaises(TimeoutError):resumable(self.client,self.scenario,self.path,1)
        record=strict_json(self.path.read_text())
        self.assertEqual(record['next_index'],1);self.assertIsNone(record['pending'])
        self.client.fail_solve=False
        rows=resumable(self.client,self.scenario,self.path)
        self.assertEqual([row['solve']['result']['answers'][0]['skeptical'] for row in rows],
                         [True,True,False,True,False,False])
        self.assertEqual(self.server.mutations,6)

    def test_concurrent_cursor_writer_cannot_acquire_lock(self):
        with self.cursor():
            with self.assertRaises(BlockingIOError):
                with self.cursor():pass

    def test_torn_or_invalid_cursor_is_not_overwritten_or_sent(self):
        for text in ('{"schema":', '{}', '{"schema":"oracle-evidence-client-resume-v1","schema":"other"}'):
            self.path.write_text(text)
            with self.assertRaises((ValueError,ContractError)):
                with self.cursor():pass
            self.assertEqual(self.path.read_text(),text)
            self.assertEqual(self.server.mutations,0)

    def test_oversized_pending_plus_prior_receipt_cannot_send_unresumable_intent(self):
        with self.cursor() as cursor:
            cursor.record['last_ack_json']='x'*600000
            cursor._save()
            prior=self.path.read_bytes()
            revision=copy.deepcopy(self.scenario['history'][0])
            revision['insert'][0]['domain']='y'*600000
            with self.assertRaisesRegex(ContractError,'storage limit'):
                cursor.revise(revision)
            self.assertIsNone(cursor.record['pending'])
            cursor.recover_pending() # Catching the error cannot send the intent.
            self.assertEqual(self.server.mutations,0)
            self.assertEqual(self.path.read_bytes(),prior)
        with self.cursor() as restored:
            self.assertEqual(restored.record['next_index'],0)


if __name__=='__main__':unittest.main()
