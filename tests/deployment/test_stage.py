import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('stage', Path(__file__).resolve().parents[2]/'tools/deploy/stage.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

class Staging(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.root=Path(self.tmp.name)
        source=self.root/'artifact';source.write_bytes(b'actual bytes')
        self.plan={'schema':'veri7vn-local-deployment/1','target':'macOS-ARM64','session':'Veri7vn_Native_Service','launch':['{package}/runtime/isabelle','java','ServiceMain'],'artifacts':[
            {'source':str(source),'path':role+'/artifact','role':role,'component':'test','origin':'test snapshot','license':'unresolved D19','sha256':stage.digest(source)} for role in ('runtime','heap','host','source','license')]}
        self.install=self.root/'install'
    def tearDown(self):self.tmp.cleanup()
    def test_deterministic_and_failed_update_preserves_current(self):
        first=stage.stage(self.plan,self.install)
        self.assertEqual(first,stage.stage(self.plan,self.install))
        before=(self.install/'current').readlink()
        self.plan['artifacts'][-1]['sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'digest mismatch'):stage.stage(self.plan,self.install)
        self.assertEqual(before,(self.install/'current').readlink())
        stage.verify(first)
    def test_interrupted_stage_not_selected_or_deleted(self):
        first=stage.stage(self.plan,self.install)
        interrupted=self.install/'generations/.incomplete-unrelated'
        interrupted.mkdir();(interrupted/'partial').write_bytes(b'partial')
        self.assertEqual(first,stage.stage(self.plan,self.install))
        self.assertTrue((interrupted/'partial').exists())
    def test_interrupted_copy_preserves_selected_generation(self):
        first=stage.stage(self.plan,self.install)
        with patch.object(stage.shutil,'copyfile',side_effect=OSError('interrupted copy')):
            with self.assertRaisesRegex(OSError,'interrupted copy'):
                stage.stage(self.plan,self.install)
        self.assertEqual(first.resolve(),(self.install/'current').resolve())
        stage.verify(first)
    def test_candidate_does_not_replace_working_selection(self):
        selected=stage.stage(self.plan,self.install)
        candidate_spec=dict(self.plan,qualification_notes=['new incompatible native checkpoint interpretation'])
        candidate=stage.stage(candidate_spec,self.install,select=False)
        self.assertNotEqual(selected,candidate)
        self.assertEqual(selected.resolve(),(self.install/'current').resolve())
        stage.verify(candidate);stage.verify(selected)
        self.assertEqual(candidate,stage.stage(candidate_spec,self.install,select=False))
        self.assertEqual(selected.resolve(),(self.install/'current').resolve())

    def test_manifest_change_is_detected(self):
        first=stage.stage(self.plan,self.install)
        (first/'manifest.json').write_text('{}')
        with self.assertRaisesRegex(ValueError,'manifest identity'):
            stage.verify(first)
        with self.assertRaisesRegex(ValueError,'manifest identity'):
            stage.verify(self.install/'current')
    def test_empty_override_cannot_launch_missing_runtime(self):
        self.plan['artifacts']=[e for e in self.plan['artifacts'] if e['role']!='heap']
        self.plan['missing']=['heap closure absent']
        self.plan['launch_blockers']=[]
        stage.stage(self.plan,self.install)
        with patch.object(stage.os,'execve') as execute:
            with self.assertRaisesRegex(ValueError,'heap closure absent'):
                stage.launch(self.install,self.root/'state',[])
            execute.assert_not_called()
    def test_complete_spec_cannot_omit_heap(self):
        self.plan['artifacts']=[e for e in self.plan['artifacts'] if e['role']!='heap']
        self.plan['launch_blockers']=[]
        with self.assertRaisesRegex(ValueError,'closure'):
            stage.stage(self.plan,self.install)
    def test_nested_directories_persist_before_selection(self):
        self.plan['artifacts'][0]['path']='runtime/deep/inside/artifact'
        self.plan['artifacts'].append(dict(path='runtime/deep/link',link='inside/artifact',role='runtime',component='test',origin='snapshot',license='local',sha256=stage.hashlib.sha256(b'inside/artifact').hexdigest()))
        events=[]
        force=stage.force_directory
        replace=stage.os.replace
        rename=stage.os.rename
        def record_force(path):
            events.append(('directory',Path(path)))
            force(path)
        def record_replace(source,target):
            events.append(('replace',Path(target)))
            return replace(source,target)
        def record_rename(source,target):
            events.append(('rename',Path(target)))
            return rename(source,target)
        with patch.object(stage,'force_directory',side_effect=record_force),patch.object(stage.os,'replace',side_effect=record_replace),patch.object(stage.os,'rename',side_effect=record_rename):
            stage.stage(self.plan,self.install)
        child=next(i for i,e in enumerate(events) if str(e[1]).endswith('/runtime/deep/inside'))
        parent=next(i for i,e in enumerate(events) if str(e[1]).endswith('/runtime/deep'))
        renamed=next(i for i,e in enumerate(events) if e[0]=='rename')
        generations=next(i for i,e in enumerate(events) if e==('directory',self.install/'generations'))
        selected=next(i for i,e in enumerate(events) if e==('replace',self.install/'current'))
        self.assertLess(child,parent)
        self.assertLess(parent,renamed)
        self.assertLess(renamed,generations)
        self.assertLess(generations,selected)
        self.assertEqual(('directory',self.install),events[-1])
    def test_launch_pins_generation_across_pointer_switch(self):
        self.plan['launch']=['{package}/runtime/artifact']
        self.plan['artifacts'][0]['executable']=True
        first=stage.stage(self.plan,self.install).resolve()
        incomplete=dict(self.plan,missing=['required heap unavailable'])
        second=stage.stage(incomplete,self.install,select=False)
        planner=stage._launch_plan
        def switch_current(root,manifest,state,extra):
            # Simulate an independently selected generation after pinning. This
            # bypasses staging only to exercise the launch TOCTOU boundary.
            (self.install/'current').unlink()
            (self.install/'current').symlink_to(second)
            return planner(root,manifest,state,extra)
        with patch.object(stage,'_launch_plan',side_effect=switch_current),patch.object(stage.os,'execve') as execute,patch.object(stage.platform,'system',return_value='Darwin'),patch.object(stage.platform,'machine',return_value='arm64'):
            stage.launch(self.install,self.root/'state',[])
        self.assertNotEqual(first,(self.install/'current').resolve())
        self.assertEqual(str(first/'runtime/artifact'),execute.call_args.args[0])
    def test_unqualified_update_cannot_select_existing_installation(self):
        first=stage.stage(self.plan,self.install)
        new=dict(self.plan,qualification_notes=['D44 rejects old40ac checkpoint'])
        with self.assertRaisesRegex(ValueError,'guarded state compatibility'):
            stage.stage(new,self.install)
        self.assertEqual(first.resolve(),(self.install/'current').resolve())
        stage.verify(first)
        candidate=stage.stage(new,self.install,select=False)
        self.assertNotEqual(first,candidate)
        stage.verify(candidate)
    def test_workbench_surface_is_explicit_and_generation_pinned(self):
        self.plan['launch']=['{package}/runtime/artifact']
        self.plan['artifacts'][0]['executable']=True
        self.plan['surfaces']={'workbench':{'arguments':['--workbench']},'source':{'launch':['{package}/runtime/artifact','java','Workbench','{state}/workspace'],'environment':{'CLASSPATH':'{package}/host/artifact'}}}
        generation=stage.stage(self.plan,self.install)
        with patch.object(stage.platform,'system',return_value='Darwin'),patch.object(stage.platform,'machine',return_value='arm64'):
            plan=stage.launch_plan(self.install,self.root/'state',['run','the sum of -2 and 3'],'workbench')
            self.assertEqual([str(generation.resolve()/'runtime/artifact'),'--workbench','run','the sum of -2 and 3'],plan['command'])
            source=stage.launch_plan(self.install,self.root/'state',['list'],'source')
            self.assertEqual(['java','Workbench',str((self.root/'state').resolve()/'workspace'),'list'],source['command'][1:])
            self.assertNotIn('--workbench',source['command'])
            self.assertEqual(str(generation.resolve()/'host/artifact'),source['environment']['CLASSPATH'])
            with self.assertRaisesRegex(ValueError,'surface unavailable'):
                stage.launch_plan(self.install,self.root/'state',surface='missing')

    def test_fresh_bootstrap_home_is_private_and_cleaned(self):
        from types import SimpleNamespace
        self.plan['launch']=['{package}/runtime/artifact']
        self.plan['artifacts'][0]['executable']=True
        self.plan['environment']={'USER_HOME':'{bootstrap_home}'}
        self.plan['associations']={'bootstrap_user_home':'fresh-owned-temporary/1'}
        stage.stage(self.plan,self.install)
        observed=[]
        def child(command,env):
            home=Path(env['USER_HOME']);observed.append(home)
            self.assertTrue(home.is_dir())
            self.assertEqual(env['HOME'],str(home))
            self.assertNotIn('LD_PRELOAD',env)
            self.assertNotIn('_JAVA_OPTIONS',env)
            self.assertNotIn('BASH_ENV',env)
            self.assertEqual(env['VERI7VN_BOOTSTRAP_HOME'],str(home))
            self.assertNotEqual(home,(self.root/'state/user-home').resolve())
            (home/'owned-test').write_text('private temporary setup')
            return SimpleNamespace(returncode=0)
        with patch.dict(stage.os.environ,{'LD_PRELOAD':'untrusted','_JAVA_OPTIONS':'untrusted','BASH_ENV':'untrusted'}),patch.object(stage.subprocess,'run',side_effect=child),patch.object(stage.platform,'system',return_value='Darwin'),patch.object(stage.platform,'machine',return_value='arm64'):
            with self.assertRaises(SystemExit) as exit_result:stage.launch(self.install,self.root/'state',[])
        self.assertEqual(0,exit_result.exception.code)
        self.assertEqual(1,len(observed));self.assertFalse(observed[0].exists())

    def test_no_implicit_directories_or_links(self):
        source=self.root/'link';source.symlink_to(self.root/'artifact')
        self.plan['artifacts'][0]['source']=str(source)
        with self.assertRaisesRegex(ValueError,'regular file'):stage.stage(self.plan,self.install)
    def test_explicit_internal_symlink(self):
        self.plan['artifacts'].append(dict(path='runtime/link',link='artifact',role='runtime',component='test',origin='snapshot',license='local',sha256=stage.hashlib.sha256(b'artifact').hexdigest()))
        first=stage.stage(self.plan,self.install)
        stage.verify(first)
        self.assertEqual('artifact',str((first/'runtime/link').readlink()))
    def test_escaping_symlink(self):
        self.plan['artifacts'].append(dict(path='runtime/link',link='../../escape',role='runtime',component='test',origin='snapshot',license='local',sha256='0'*64))
        with self.assertRaisesRegex(ValueError,'escaping'):
            stage.stage(self.plan,self.install)
    def test_traversal(self):
        self.plan['artifacts'][0]['path']='../escape'
        with self.assertRaises(ValueError):stage.stage(self.plan,self.install)
    def test_modified_artifact_rejected(self):
        root=stage.stage(self.plan,self.install)
        artifact=root/'heap/artifact';artifact.chmod(0o644);artifact.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'changed artifact'):stage.verify(root)

if __name__=='__main__':unittest.main()
