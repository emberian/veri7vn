"""Safe source lifecycle fixtures: no acquisition, commands or services invoked."""
import ast
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
ROOT=Path(__file__).resolve().parents[2]

def selected(path,names,env):
    p=ROOT/path;tree=ast.parse(p.read_text())
    nodes=[n for n in tree.body if isinstance(n,(ast.FunctionDef,ast.ClassDef)) and n.name in names]
    assert {n.name for n in nodes}==set(names)
    exec(compile(ast.Module(body=nodes,type_ignores=[]),str(p),'exec'),env)
    return env

class LifecycleCases(unittest.TestCase):
    def test_removed_sensor_can_receive_late_history(self):
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp);config=folder/'fixture.json';history=folder/'fixture.jsonl'
            c={'id':'fixture','fields':[{'path':'temperature','quantity':'temperature','unit':'C'}]}
            config.write_text(json.dumps(c));history.write_text('')
            targets=[]
            class Thread:
                def __init__(self,target,daemon):targets.append(target)
                def start(self):pass
            def read_source(cfg):
                # Removal interleaves after loop acquired config but before read
                # completes. Only this temporary fixture's files are removed.
                config.unlink();history.unlink()
                return {'temperature':20},'local mock old acquisition'
            env=selected('upstream/workbench/sensors.py',{'configs','poll_once','start_poller'},
                {'DIR':folder,'json':json,'time':SimpleNamespace(time=lambda:100,sleep=lambda seconds:None),
                 'threading':SimpleNamespace(Thread=Thread),'_POLLERS':{},'STATUS':{},
                 'read_source':read_source,'check':lambda f,v:(True,''),'QUANTITIES':{},'KEEP_S':86400})
            env['start_poller']('fixture');targets[0]()
            self.assertFalse(config.exists())
            self.assertTrue(history.exists())
            self.assertEqual(json.loads(history.read_text())['v'],20)
            self.assertTrue(env['STATUS']['fixture']['ok'])
            self.assertNotIn('fixture',env['_POLLERS'])
            # Replacement validates binding epoch before publication; retirement
            # must not be represented only by deleting config/history files.

    def test_disk_persistence_off_still_learns_in_memory(self):
        directory=str(ROOT/'upstream/root/wander-train');sys.path.insert(0,directory)
        try:
            p=ROOT/'upstream/root/wander-train/organ_code_chat_v2.py'
            spec=importlib.util.spec_from_file_location('audit_code_chat',p)
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        finally:sys.path.remove(directory)
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'library.json';chat=module.CodeChat(str(path));chat.persist=False
            before=len(chat.org.prims)
            result=chat.answer('write a function add that adds two numbers: add(2, 3) == 5, add(-1, 1) == 0')
            self.assertIsNotNone(result)
            self.assertTrue(result['confident'])
            self.assertFalse(path.exists())
            self.assertGreater(len(chat.org.prims),before)
            self.assertIn('add',chat.org.library_src)
            # Source w486's loop-* switch controls disk only; native evaluation
            # must also isolate in-memory learned kernels/exposure for independence.

if __name__=='__main__':unittest.main()
