#!/usr/bin/env python3
"""Create an explicitly experimental adapter copy with startup-only telemetry.

Does not edit the runtime or log tenant requests. No proof/admission authority.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

HELPER = '''
# EXPERIMENTAL STARTUP TELEMETRY: scratch adapter only, never a deployment receipt.
import builtins as _profile_builtins
import resource as _profile_resource
import time as _profile_time
_PROFILE_STARTED = _profile_time.monotonic()
_PROFILE_COMPILE = {"calls": 0, "source_bytes": 0, "seconds": 0.0}
def _profile_mark(phase):
    usage = _profile_resource.getrusage(_profile_resource.RUSAGE_SELF)
    memory = {}
    try:
        for line in Path('/proc/self/smaps_rollup').read_text().splitlines():
            key, _, value = line.partition(':')
            if key in ('Rss','Pss','Private_Clean','Private_Dirty','Shared_Clean','Shared_Dirty'):
                memory[key+'_KiB'] = int(value.strip().split()[0])
    except OSError:
        pass
    io = {}
    try:
        io = {k:int(v) for k,v in (line.split(':',1) for line in Path('/proc/self/io').read_text().splitlines())}
    except OSError:
        pass
    print(json.dumps({'startup_profile': {'phase':phase, 'pid':os.getpid(),
        'monotonic':_profile_time.monotonic(), 'since_import_seconds':_profile_time.monotonic()-_PROFILE_STARTED,
        'user_seconds':usage.ru_utime,'system_seconds':usage.ru_stime,
        'minor_faults':usage.ru_minflt,'major_faults':usage.ru_majflt,
        'max_rss_KiB':usage.ru_maxrss,'memory':memory,'io':io,
        'compile':dict(_PROFILE_COMPILE)}}), flush=True)

def _profile_compile(*args, **kwargs):
    started = _profile_time.monotonic()
    try:
        return _PROFILE_ORIGINAL_COMPILE(*args, **kwargs)
    finally:
        _PROFILE_COMPILE['calls'] += 1
        _PROFILE_COMPILE['seconds'] += _profile_time.monotonic()-started
        if args and isinstance(args[0], (str,bytes,bytearray)):
            _PROFILE_COMPILE['source_bytes'] += len(args[0])

_PROFILE_ORIGINAL_COMPILE = _profile_builtins.compile
'''


DETAIL = '''
_PROFILE_DETAILS = {}
def _profile_timed(name, original):
    def wrapped(*args, **kwargs):
        started = _profile_time.monotonic()
        cpu = _profile_time.thread_time()
        try:
            return original(*args, **kwargs)
        finally:
            record = _PROFILE_DETAILS.setdefault(name, {'calls':0,'wall_seconds':0.0,'thread_cpu_seconds':0.0})
            record['calls'] += 1
            record['wall_seconds'] += _profile_time.monotonic()-started
            record['thread_cpu_seconds'] += _profile_time.thread_time()-cpu
    return wrapped

def _profile_operations():
    import operations as module
    for name in ('_registered','_specialists','_numeric','_core','_extensions','_declarations'):
        setattr(Operations,name,_profile_timed('operations.'+name,getattr(Operations,name)))
    module.read_json = _profile_timed('metadata.read_json',module.read_json)
    original_load = module.load_module
    def load(path, name):
        result = _profile_timed('module.'+Path(path).name,original_load)(path,name)
        if name == 'appliance_direct_combo':
            original_init = result._Organ.__init__
            def initialize(self, manifest_path, *args, **kwargs):
                return _profile_timed('organ.'+Path(manifest_path).parent.name,original_init)(self,manifest_path,*args,**kwargs)
            result._Organ.__init__ = initialize
        for class_name in ('WorkbenchOperations','ExamInspection','DecisionOperations','VisualOperations','BuilderOperations'):
            cls = getattr(result,class_name,None)
            if cls is not None:
                cls.__init__ = _profile_timed('provider.'+class_name+'.init',cls.__init__)
                cls.catalog = _profile_timed('provider.'+class_name+'.catalog',cls.catalog)
        return result
    module.load_module = load

def _profile_details_emit():
    print(json.dumps({'startup_details':_PROFILE_DETAILS}),flush=True)
'''


def instrument(source, output, detailed=False, lazy=False):
    if output.exists():
        raise ValueError('output must be a new scratch adapter directory')
    shutil.copytree(source, output)
    output.chmod(0o700)
    target = output/'serve.py'
    target.chmod(target.stat().st_mode | 0o200)
    text = target.read_text()
    changes = {
        '\ndef _worker(connection, config):': HELPER+'\ndef _worker(connection, config):',
        '    engine = None\n    try:\n        preflight(config)\n        engine = import_launcher(config).Engine()\n        operations = engine._ex.submit(Operations, engine, config).result()':
        '''    engine = None
    _profile_builtins.compile = _profile_compile
    _profile_mark('worker_enter')
    try:
        preflight(config)
        _profile_mark('preflight_done')
        launcher = import_launcher(config)
        _profile_mark('launcher_import_done')
        engine = launcher.Engine()
        _profile_mark('engine_done')
        operations = engine._ex.submit(Operations, engine, config).result()
        _profile_mark('operations_done')
        _profile_builtins.compile = _PROFILE_ORIGINAL_COMPILE''',
        '        self.process.start()\n        child.close()':
        "        _profile_mark('parent_spawn_begin')\n        self.process.start()\n        _profile_mark('parent_spawn_returned')\n        child.close()",
        '            self.available = True\n        except BaseException:':
        "            self.available = True\n            _profile_mark('parent_ready')\n        except BaseException:",
    }
    for before, after in changes.items():
        if text.count(before) != 1:
            raise ValueError('adapter instrumentation anchor changed')
        text = text.replace(before,after,1)
    if detailed:
        text=text.replace('\ndef _worker(connection, config):',DETAIL+'\ndef _worker(connection, config):',1)
        text=text.replace('        operations = engine._ex.submit(Operations, engine, config).result()',
                          '        _profile_operations()\n        operations = engine._ex.submit(Operations, engine, config).result()\n        _profile_details_emit()',1)
    if lazy:
        if not detailed:
            raise ValueError('lazy prototype requires detailed instrumentation')
        old="""        _profile_operations()
        operations = engine._ex.submit(Operations, engine, config).result()
        _profile_details_emit()
        _profile_mark('operations_done')
        _profile_builtins.compile = _PROFILE_ORIGINAL_COMPILE
        summary = {state: sum(item["availability"] == state for item in operations.items.values())
                   for state in ("live_direct", "text_only", "unavailable")}"""
        new="""        operations = None
        _profile_mark('operations_deferred')
        _profile_builtins.compile = _PROFILE_ORIGINAL_COMPILE
        summary = None"""
        if text.count(old)!=1:raise ValueError('lazy initialization anchor changed')
        text=text.replace(old,new,1)
        anchor='                action = request.get("_action", "query")'
        replacement=anchor+'''
                if action in ('invoke','discover') and operations is None:
                    _profile_builtins.compile = _profile_compile
                    _profile_mark('lazy_operations_begin')
                    _profile_operations()
                    operations = engine._ex.submit(Operations, engine, config).result()
                    _profile_details_emit()
                    _profile_mark('lazy_operations_done')
                    _profile_builtins.compile = _PROFILE_ORIGINAL_COMPILE'''
        if text.count(anchor)!=1:raise ValueError('lazy dispatch anchor changed')
        text=text.replace(anchor,replacement,1)
        anchor='"invoke": "/invoke", "counts": getattr(self.backend, "operations", {})}'
        if text.count(anchor)!=1:raise ValueError('lazy capabilities anchor changed')
        text=text.replace(anchor,'"invoke": "/invoke", "counts": None, "initialization": "deferred_until_direct_request", "prototype_note": "Scratch lazy catalog; counts are not reported by this prototype, including after initialization."}',1)
    compile(text,str(target),'exec')
    target.write_text(text)
    record={'schema':'oracle-startup-instrumentation-v1','production':False,
            'source_adapter_sha256':hashlib.sha256((source/'serve.py').read_bytes()).hexdigest(),
            'instrumented_adapter_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
            'detailed_operations':detailed,
            'lazy_operations_prototype':lazy,
            'semantics':('Scratch prototype defers Operations until first discovery or invoke; capabilities explicitly reports unknown counts. Query methods and reply serialization are unchanged.' if lazy else 'Startup phase markers and compile-duration counter only; query methods and reply serialization are unchanged.'),
            'tenant_text_logged_by_profile':False}
    (output/'STARTUP-PROFILE.json').write_text(json.dumps(record,indent=2)+'\n')
    return record


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-adapter',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--detailed',action='store_true')
    parser.add_argument('--lazy-operations',action='store_true')
    args=parser.parse_args()
    print(json.dumps(instrument(args.source_adapter,args.output,args.detailed,args.lazy_operations)))
