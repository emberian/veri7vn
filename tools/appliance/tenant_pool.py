"""Untrusted host-internal tenant execution pool, not authentication or Mini authority.

Each resident tenant owns a separate Service and spawned EngineProcess. Only
immutable code/data are shared. Callers MUST supply authenticated host-assigned
keys; no request field establishes identity. Journals survive eviction; Oracle
in-memory conversation state does not. Hosts must expose that lifecycle limit.
"""
from __future__ import annotations

from dataclasses import dataclass, replace
from contextlib import closing
import fcntl
import json
import os
from pathlib import Path
import re
import sqlite3
import threading
import tempfile
import time

from serve import Config, Service, IDENTIFIER, OPERATION_ID, encode, failure, validate_paths


@dataclass
class _Resident:
    busy: bool = True
    service: object = None
    last_used: float = 0.0
    generation: int = 0
    poisoned: bool = False


class TenantPool:
    """Synchronous bounded execution; no queued calls or per-tenant background jobs.

    ``config.workspace`` is an operator-owned pool directory. Runtime/data paths
    are immutable shared inputs. The service_factory hook is for narrow tests;
    production uses Service, which spawns one isolated EngineProcess per tenant.
    One bounded background thread expires idle processes. Admission also reuses
    the least recently idle slot. No thread is allocated per tenant.
    """

    def __init__(self, config: Config, *, max_resident=2, max_tenants=128, idle_seconds=300.0,
                 service_factory=Service, clock=time.monotonic):
        if type(max_resident) is not int or not 1 <= max_resident <= 64:
            raise ValueError('max_resident must be between 1 and 64')
        if type(max_tenants) is not int or not max_resident <= max_tenants <= 10000:
            raise ValueError('max_tenants must cover residents and be at most 10000')
        if type(idle_seconds) not in (int, float) or not 0 < idle_seconds < float('inf'):
            raise ValueError('idle_seconds must be finite and positive')
        validate_paths(config)
        self.config = replace(config, workspace=config.workspace.resolve())
        if os.path.lexists(self.config.workspace / 'requests.sqlite3'):
            # A standalone journal has no authenticated tenant assignment.
            # Ignoring it would permit old request IDs to execute again under
            # a new tenant directory; guessing an owner would leak old state.
            raise ValueError('legacy standalone workspace requires explicit migration; use a fresh tenant pool root')
        self.max_resident, self.idle_seconds = max_resident, idle_seconds
        self.max_tenants = max_tenants
        self.factory, self.clock = service_factory, clock
        self.condition = threading.Condition()
        self.residents = {}
        self.closing = False
        self.stop_requested = False
        self.closed = False
        self.registry_failed = False
        self.reaper_stop = threading.Event()
        self.config.workspace.mkdir(mode=0o700, parents=True, exist_ok=True)
        lock_path = self.config.workspace / 'tenant-pool.lock'
        fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        self.lock_file = os.fdopen(fd, 'a')
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BaseException:
            self.lock_file.close()
            raise RuntimeError('pool root already owned') from None
        try:
            registry = self.config.workspace / 'tenant-registry.sqlite3'
            if registry.is_symlink():
                raise ValueError('tenant registry must not be a symlink')
            self.registry = sqlite3.connect(registry, check_same_thread=False)
            self.registry.execute('PRAGMA synchronous=FULL')
            self.registry.execute('CREATE TABLE IF NOT EXISTS tenants (id TEXT PRIMARY KEY)')
            self.registry.execute('CREATE TABLE IF NOT EXISTS conversations (tenant TEXT, id TEXT, generation INTEGER NOT NULL, poisoned INTEGER NOT NULL, PRIMARY KEY(tenant,id))')
            self.registry.commit()
        except BaseException:
            self.lock_file.close()
            raise
        self.reaper = threading.Thread(target=self._reaper_loop, name='oracle-tenant-reaper', daemon=True)
        self.reaper.start()

    @property
    def stopping(self):
        return self.stop_requested or self.closing or self.registry_failed

    @stopping.setter
    def stopping(self, value):
        if value:
            with self.condition:
                self.stop_requested = True
                self.reaper_stop.set()
                self.condition.notify_all()

    def _reaper_loop(self):
        interval = max(0.05, min(30.0, self.idle_seconds / 2))
        while not self.reaper_stop.wait(interval):
            self.reap_idle()

    @staticmethod
    def _identity(key):
        if not isinstance(key, str) or not re.fullmatch(r'[0-9a-f]{64}', key):
            raise ValueError('invalid host tenant key')
        return key  # host already domain-separates and hashes the trusted identity

    def _workspace(self, identity):
        # The host owns this directory. Reject tenant-path symlinks rather than
        # resolving them into another tenant, runtime, or a caller-chosen path.
        path = self.config.workspace / ('tenant-' + identity)
        path.mkdir(mode=0o700, exist_ok=True)
        if path.is_symlink() or path.resolve() != path:
            raise ValueError('tenant workspace must be a real owned directory')
        return path

    def _next_generation(self, workspace):
        path = workspace / 'pool-generation'
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        except FileNotFoundError:
            value = 0
        else:
            with os.fdopen(fd, 'rb') as stream:
                raw = stream.read(33)
            if len(raw) > 32 or not raw.strip().isdigit():
                raise ValueError('invalid pool generation')
            value = int(raw)
        value += 1
        fd, name = tempfile.mkstemp(prefix='pool-generation-', dir=workspace)
        temporary = Path(name)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(str(value).encode('ascii'))
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
            directory = os.open(workspace, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
        return value

    def _acquire(self, key):
        identity = self._identity(key)
        victim = None
        factory_started = False
        with self.condition:
            if self.stopping:
                return None, (503, failure('pool_stopping', retryable=False))
            resident = self.residents.get(identity)
            if resident is not None:
                if resident.poisoned:
                    return None, (503, failure('tenant_close_uncertain', retryable=False))
                if resident.busy:
                    return None, (429, failure('tenant_busy', retryable=True))
                resident.busy = True
                return (identity, resident), None
            if len(self.residents) >= self.max_resident:
                idle = [(entry.last_used, name, entry) for name, entry in self.residents.items()
                        if not entry.busy and not entry.poisoned]
                if not idle:
                    return None, (429, failure('pool_busy', retryable=True))
                _, name, victim = min(idle)
            try:
                known = self.registry.execute('SELECT 1 FROM tenants WHERE id=?', (identity,)).fetchone()
                if not known:
                    if self.registry.execute('SELECT COUNT(*) FROM tenants').fetchone()[0] >= self.max_tenants:
                        return None, (507, failure('tenant_capacity', retryable=False))
                    self.registry.execute('INSERT INTO tenants(id) VALUES(?)', (identity,))
                    self.registry.commit()
            except sqlite3.Error:
                self.registry_failed = True
                return None, (507, failure('tenant_registry_error', retryable=False))
            if victim is not None:
                del self.residents[name]
            resident = _Resident()
            self.residents[identity] = resident  # reservation counts toward cap
        try:
            if victim is not None:
                try:
                    victim.service.close()  # close before creating replacement
                except BaseException:
                    # A failed close does not prove its process stopped. Retain a
                    # poisoned reservation so this pool never exceeds its cap.
                    resident.service, resident.poisoned = victim.service, True
                    raise
            workspace = self._workspace(identity)
            resident.generation = self._next_generation(workspace)
            factory_started = True
            resident.service = self.factory(replace(self.config, workspace=workspace))
            return (identity, resident), None
        except Exception as error:
            with self.condition:
                if factory_started:
                    resident.poisoned = True  # constructor cleanup cannot be independently established
                if resident.poisoned:
                    resident.busy = False
                else:
                    del self.residents[identity]
                self.condition.notify_all()
            return None, (503, failure('tenant_start_failed', error_type=type(error).__name__, retryable=False))
        except BaseException:
            with self.condition:
                if factory_started:
                    resident.poisoned = True
                if resident.poisoned:
                    resident.busy = False
                else:
                    del self.residents[identity]
                self.condition.notify_all()
            raise

    def _execute(self, key, operation):
        try:
            lease, error = self._acquire(key)
        except (ValueError, UnicodeError):
            return 400, failure('invalid_tenant_key')
        if error:
            return error
        identity, resident = lease
        try:
            return operation(resident)
        finally:
            with self.condition:
                resident.last_used = self.clock()
                resident.busy = False
                self.condition.notify_all()

    def _retained(self, identity, raw, request_id, path, method):
        """Read exact durable replies without allocating an Engine or resetting context."""
        workspace = self.config.workspace / ('tenant-' + identity)
        database = workspace / 'requests.sqlite3'
        if workspace.is_symlink() or database.is_symlink():
            return 503, failure('tenant_workspace_invalid', retryable=False)
        if not database.exists():
            return None
        try:
            with closing(sqlite3.connect(database.as_uri()+'?mode=ro', uri=True, timeout=0)) as db:
                columns = {row[1] for row in db.execute('PRAGMA table_info(requests)')}
                # Service's legacy migration defines all pre-route rows as
                # POST /query. The cold replay path must apply that identical
                # interpretation without requiring an Engine just to migrate.
                method_column = 'method' if 'method' in columns else "'POST'"
                path_column = 'path' if 'path' in columns else "'/query'"
                row = db.execute('SELECT body,result,'+method_column+','+path_column+' FROM requests WHERE id=?', (request_id,)).fetchone()
        except sqlite3.Error:
            return 503, failure('tenant_journal_unavailable', retryable=True)
        if row is None:
            return None
        if row[0] != raw or row[2:] != (method, path):
            return 409, failure('request_id_conflict')
        if row[1] is None:
            resident = self.residents.get(identity)
            if resident is not None and resident.busy:
                return 429, failure('tenant_busy', retryable=True)
        if row[1] is not None and len(row[1]) > self.config.max_reply_bytes:
            return 502, failure('reply_too_large', execution_completed=True, retained_in_journal=True, state_may_have_changed=True)
        try:
            result = json.loads(row[1]) if row[1] is not None else failure('interrupted', state_may_have_changed=True)
            return Service.status(result), result
        except (ValueError, TypeError, KeyError):
            return 503, failure('tenant_journal_invalid', retryable=False)

    def request(self, key, raw, path='/query', method='POST'):
        if not isinstance(raw, bytes):
            return 400, failure('invalid_request')
        if len(raw) > self.config.max_request_bytes:
            return 413, failure('request_too_large')
        if path not in ('/query', '/invoke') or method != 'POST':
            return 405, failure('unsupported_method_or_route')
        try:
            identity = self._identity(key)
            def pairs(items):
                result = {}
                for name, value in items:
                    if name in result:
                        raise ValueError('duplicate key')
                    result[name] = value
                return result
            request = json.loads(raw.decode('utf-8'), object_pairs_hook=pairs,
                                 parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
            fields = {'request_id','conversation_id','text'} if path == '/query' else {'request_id','conversation_id','operation_id','arguments'}
            if not isinstance(request,dict) or set(request) != fields:
                raise ValueError()
            for name in ('request_id','conversation_id'):
                if not isinstance(request[name],str) or not IDENTIFIER.fullmatch(request[name]):
                    raise ValueError()
            if path == '/query':
                if not isinstance(request['text'],str) or not request['text'].strip():
                    raise ValueError()
            elif not isinstance(request['operation_id'],str) or not OPERATION_ID.fullmatch(request['operation_id']) or not isinstance(request['arguments'],dict):
                raise ValueError()
            encode(request)
        except (ValueError, UnicodeError, RecursionError):
            return 400, failure('invalid_request')
        with self.condition:
            if self.stopping:
                return 503, failure('pool_stopping', retryable=False)
            retained = self._retained(identity,raw,request['request_id'],path,method)
            if retained is not None:
                return retained  # exact journal identity wins over conversation reset
            resident = self.residents.get(identity)
            # A busy resident may be starting or executing a pending poisoned
            # turn. Let the existing admission gate return429 in those cases;
            # transient pending state is not a permanent reset decision.
            if resident is None or not resident.busy:
                try:
                    previous = self.registry.execute('SELECT generation,poisoned FROM conversations WHERE tenant=? AND id=?', (identity,request['conversation_id'])).fetchone()
                except sqlite3.Error:
                    self.registry_failed = True
                    return 507, failure('tenant_registry_error', executed=False)
                if previous and (resident is None or resident.poisoned or previous[0] != resident.generation or previous[1]):
                    return 409, failure('conversation_reset_required', executed=False, fresh_conversation_required=True,
                                        generation=resident.generation if resident is not None else None, retryable=False)

        def execute(resident):
            # Recheck under the tenant lease: a racing first caller may have
            # completed while this caller was waiting for the metadata mutex.
            retained = self._retained(identity,raw,request['request_id'],path,method)
            if retained is not None:
                return retained
            with self.condition:
                try:
                    previous = self.registry.execute('SELECT generation,poisoned FROM conversations WHERE tenant=? AND id=?', (identity,request['conversation_id'])).fetchone()
                    if previous and (previous[0] != resident.generation or previous[1]):
                        return 409, failure('conversation_reset_required', executed=False, fresh_conversation_required=True,
                                            generation=resident.generation, retryable=False)
                    if not previous and self.registry.execute('SELECT COUNT(*) FROM conversations WHERE tenant=?',(identity,)).fetchone()[0] >= self.config.max_requests:
                        return 507, failure('conversation_registry_full', executed=False)
                    # Pending is pessimistically poisoned before execution; a
                    # host crash cannot make an uncertain turn look untouched.
                    self.registry.execute('INSERT OR REPLACE INTO conversations(tenant,id,generation,poisoned) VALUES(?,?,?,1)', (identity,request['conversation_id'],resident.generation))
                    self.registry.commit()
                except sqlite3.Error:
                    self.registry_failed = True
                    return 507, failure('tenant_registry_error', executed=False)
            result = resident.service.request(raw,path,method)
            if not result[1].get('state_may_have_changed',False):
                with self.condition:
                    try:
                        self.registry.execute('UPDATE conversations SET poisoned=0 WHERE tenant=? AND id=?',(identity,request['conversation_id']))
                        self.registry.commit()
                    except sqlite3.Error:
                        self.registry_failed = True
                        # The exact service result is already durable; retain it
                        # and block subsequent admission rather than changing it.
            return result
        return self._execute(key,execute)

    def discover(self, key, parameters):
        # Host routing owns HTTP query parsing; retain bounded fixed fields here.
        if not isinstance(parameters, dict) or set(parameters) - {'offset', 'limit', 'q', 'availability', 'operation_id'}:
            return 400, failure('invalid_discovery')
        try:
            if len(encode(parameters)) > 2048:
                return 400, failure('invalid_discovery')
        except (ValueError, TypeError, UnicodeError):
            return 400, failure('invalid_discovery')
        return self._execute(key, lambda r: r.service.discover(parameters))

    def capabilities(self, key):
        def result(resident):
            caps = dict(resident.service.capabilities())
            caps['tenant_execution'] = {
                'generation': resident.generation,
                'max_resident_engines': self.max_resident,
                'max_tenants': self.max_tenants,
                'query_queue': 0,
                'journal_survives_eviction': True,
                'in_memory_conversations_survive_eviction': False,
                'conversation_reset_policy': 'Exact durable retries survive eviction. New requests using an old or uncertain conversation receive409 conversation_reset_required; use a fresh conversation_id and supply needed context.',
                'scope': 'Isolated process and persistent workspace for host-assigned tenant; not authentication.',
            }
            return 200, caps
        return self._execute(key, result)

    def health(self):
        """Pool-only health; does not create tenant state or warm an Engine."""
        with self.condition:
            return {'ready': not self.stopping, 'resident_or_reserved': len(self.residents),
                    'busy': sum(r.busy for r in self.residents.values()),
                    'poisoned': sum(r.poisoned for r in self.residents.values()),
                    'max_resident_engines': self.max_resident, 'query_queue': 0}

    def reap_idle(self):
        with self.condition:
            if self.stopping:
                return 0
            now = self.clock()
            victims = [(key, r) for key, r in self.residents.items()
                       if not r.busy and not r.poisoned and now-r.last_used >= self.idle_seconds]
            for _, resident in victims:
                resident.busy = True  # shutdown still consumes its slot
        removed = 0
        for key, resident in victims:
            try:
                resident.service.close()
            except Exception:
                with self.condition:
                    resident.poisoned = True
                    resident.busy = False
                    self.condition.notify_all()
            else:
                with self.condition:
                    del self.residents[key]
                    removed += 1
                    self.condition.notify_all()
        return removed

    def close(self):
        """Stop admission, drain active bounded calls/startups, then close residents."""
        with self.condition:
            if self.closed:
                return
            if self.closing:
                self.condition.wait_for(lambda: self.closed)
                return
            self.closing = True
            self.stop_requested = True
            self.reaper_stop.set()
            self.condition.wait_for(lambda: not any(r.busy for r in self.residents.values()))
            residents = list(self.residents.values())
        self.reaper.join()
        errors = []
        for resident in residents:
            try:
                if resident.service is None:
                    raise RuntimeError('failed constructor has no cleanup-confirmed service handle')
                resident.service.close()
            except Exception as error:
                errors.append(error)
        with self.condition:
            if not errors:
                self.residents.clear()
                self.registry.close()
                self.lock_file.close()
            # Failed shutdown retains ownership and reservations; another pool
            # cannot start additional processes against this same root.
            self.closed = True
            self.condition.notify_all()
        if errors:
            raise RuntimeError('tenant shutdown uncertain; pool ownership retained') from errors[0]
