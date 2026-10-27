import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
import linux_memory as m

ROLLUP = '''header\nRss: 100 kB\nPss: 60 kB\nPrivate_Clean: 10 kB\nPrivate_Dirty: 20 kB\nShared_Clean: 40 kB\nShared_Dirty: 30 kB\nSwap: 2 kB\n'''
class MemoryTests(unittest.TestCase):
    def test_adapter_selection_rejects_wrapper_and_python_command_payloads(self):
        script=b'/opt/oracle/adapter/serve.py'
        def identity(*argv):return (123,b'\0'.join(argv)+b'\0')
        self.assertTrue(m.is_adapter_identity(identity(b'/usr/bin/python3.12',b'-B',script,b'--port',b'0')))
        self.assertTrue(m.is_adapter_identity(identity(b'python',script)))
        for argv in ((b'bwrap',b'--',b'/usr/bin/python3.12',b'-B',script),
                     (b'/usr/bin/python3.12',b'-c',b'child code',script),
                     (b'/usr/bin/python3.12',b'-m',b'child_module',script),
                     (b'/usr/bin/not-python',script),
                     (b'/usr/bin/python3.12',b'/other.py',script)):
            with self.subTest(argv=argv):self.assertFalse(m.is_adapter_identity(identity(*argv)))
    def test_spawn_worker_with_interpreter_flags_and_wrapper_refusal(self):
        def identity(*args): return (7,b'\0'.join(args)+b'\0')
        code=b'from multiprocessing.spawn import spawn_main; spawn_main(tracker_fd=4, pipe_handle=6)'
        for flags in ((),(b'-B',),(b'-I',b'-B')):
            self.assertTrue(m.is_engine_worker_identity(identity(b'/usr/bin/python3.12',*flags,b'-c',code)))
        self.assertFalse(m.is_engine_worker_identity(identity(b'bwrap',b'--',b'python3',b'-c',code)))
        self.assertFalse(m.is_engine_worker_identity(identity(b'python3',b'-m',b'multiprocessing.spawn')))
        self.assertFalse(m.is_engine_worker_identity(identity(b'python3',b'-c',b'print(1)')))
    def test_pss_private_shared_and_vanished(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'10').mkdir(); (root/'10'/'smaps_rollup').write_text(ROLLUP)
            result=m.sample([10,11],root)
            self.assertEqual(result['totals_kib']['Rss_kib'],100)
            self.assertEqual(result['totals_kib']['Pss_kib'],60)
            self.assertEqual(result['totals_kib']['private_kib'],30)
            self.assertEqual(result['totals_kib']['shared_kib'],70)
            self.assertEqual(result['vanished'],[11])
    def test_process_tree_collects_all_threads(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for pid, tid, children in [(1,1,'2'),(1,3,'4'),(2,2,''),(4,4,'')]:
                p=root/str(pid)/'task'/str(tid);p.mkdir(parents=True,exist_ok=True);(p/'children').write_text(children)
            self.assertEqual(m.descendants(1,root),[1,2,4])
    def test_disappearing_process_is_not_a_failure(self):
        with patch.object(Path, 'iterdir', side_effect=ProcessLookupError):
            self.assertEqual(m.descendants(7), [7])
        with patch.object(Path, 'read_text', side_effect=ProcessLookupError):
            self.assertIsNone(m.cgroup(7))
    def test_permission_error_is_not_misreported_as_gone(self):
        with patch.object(Path, 'iterdir', side_effect=PermissionError):
            with self.assertRaises(PermissionError): m.descendants(7)
        with patch.object(Path, 'read_text', side_effect=PermissionError):
            with self.assertRaises(PermissionError): m.cgroup(7)
    def test_signal_only_same_start_and_argv(self):
        signals=[]
        with patch.object(m, 'process_identity', return_value=(11,b'python\0service\0')):
            self.assertTrue(m.signal_if_same(7,(11,b'python\0service\0'),15,killer=lambda *x:signals.append(x)))
            self.assertFalse(m.signal_if_same(7,(10,b'python\0service\0'),15,killer=lambda *x:signals.append(x)))
        with patch.object(m, 'process_identity', side_effect=ProcessLookupError):
            self.assertFalse(m.signal_if_same(7,(11,b'x'),15,killer=lambda *x:signals.append(x)))
        self.assertEqual(signals,[(7,15)])
    def test_live_identity_handles_exit_zombie_and_reuse(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); p=root/'7'; p.mkdir()
            def stat(state,ticks):
                fields=[state]+['0']*18+[str(ticks)]
                (p/'stat').write_text('7 (name with spaces) '+' '.join(fields))
            stat('S',42); self.assertTrue(m.identity_still_running(7,(42,b'x'),root))
            self.assertFalse(m.identity_still_running(7,(41,b'x'),root))
            stat('Z',42); self.assertFalse(m.identity_still_running(7,(42,b'x'),root))
            (p/'stat').unlink(); self.assertFalse(m.identity_still_running(7,(42,b'x'),root))
    def test_rejects_incomplete(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'2';p.mkdir();(p/'smaps_rollup').write_text('Rss: 7 kB\n')
            with self.assertRaises(ValueError): m.read_rollup(2,Path(tmp))
if __name__=='__main__': unittest.main()
