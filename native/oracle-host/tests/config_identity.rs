use oracle_host::config::{self, Config, EngineConfig};
use serde_json::{json, Value};
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

fn settings(root: &Path) -> EngineConfig {
    serde_json::from_value(json!({"python":{"path":"/python","sha256":"a".repeat(64)},
        "answerer":{"path":"/worker","sha256":"b".repeat(64)},
        "checkout":root,"revision":"source-revision","state":"/private/state"}))
    .unwrap()
}

fn receipt(root: &Path, engine: &mut EngineConfig) {
    let path = root.join("oracle7.py");
    fs::write(&path, "# fixture code\n").unwrap();
    let record = json!({"sha256":config::sha256_file(&path).unwrap(),
        "size":fs::metadata(&path).unwrap().len(),
        "executable":fs::metadata(&path).unwrap().permissions().mode() & 0o111 != 0});
    let path = root.join("APPLIANCE.json");
    fs::write(
        &path,
        serde_json::to_vec(&json!({"schema":1,"source_revision":"source-revision",
        "stores":[],"files":{"oracle7.py":record}}))
        .unwrap(),
    )
    .unwrap();
    engine.materialization = Some(config::Artifact {
        sha256: config::sha256_file(&path).unwrap(),
        path,
    });
}

#[test]
fn materialization_admits_actual_patched_files_without_git() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = settings(dir.path());
    receipt(dir.path(), &mut engine);
    assert_eq!(
        config::admit_engine_checkout(&engine).unwrap()["mode"],
        "materialized"
    );
    fs::write(dir.path().join("oracle7.py"), "# modified code\n").unwrap();
    assert!(config::admit_engine_checkout(&engine).is_err());
}

#[test]
fn inventory_rejects_shadow_modules_missing_files_and_changed_receipt() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = settings(dir.path());
    receipt(dir.path(), &mut engine);
    let extra = dir.path().join("json.py");
    fs::write(&extra, "# import shadow\n").unwrap();
    assert!(config::admit_engine_checkout(&engine).is_err());
    fs::remove_file(extra).unwrap();
    fs::remove_file(dir.path().join("oracle7.py")).unwrap();
    assert!(config::admit_engine_checkout(&engine).is_err());
    receipt(dir.path(), &mut engine);
    fs::write(dir.path().join("APPLIANCE.json"), "{}").unwrap();
    assert!(config::admit_engine_checkout(&engine).is_err());
}

#[test]
fn journal_identity_tracks_semantics_and_survives_relocation() {
    let value = json!({"schema":"oracle-host-v1","journal":"/state/journal","port":0,
        "engine":{"python":{"path":"/a/python","sha256":"a".repeat(64)},
        "answerer":{"path":"/a/worker","sha256":"b".repeat(64)},
        "checkout":"/a/tree","revision":"rev","state":"/state/engine"}});
    let identity = |v: Value| {
        config::deployment_identity(
            &serde_json::from_value::<Config>(v).unwrap(),
            &"c".repeat(64),
        )
        .unwrap()
    };
    let first = identity(value.clone());
    let mut moved = value.clone();
    moved["port"] = json!(1234);
    moved["journal"] = json!("/other/journal");
    moved["engine"]["state"] = json!("/other/engine");
    moved["engine"]["checkout"] = json!("/b/tree");
    moved["engine"]["python"]["path"] = json!("/b/python");
    moved["engine"]["answerer"]["path"] = json!("/b/worker");
    assert_eq!(first, identity(moved));
    for (field, changed) in [
        ("revision", json!("new")),
        ("tip", json!("other")),
        ("workers", json!(2)),
        ("turn_ms", json!(123)),
    ] {
        let mut next = value.clone();
        next["engine"][field] = changed;
        assert_ne!(first, identity(next), "{field}");
    }
}

#[test]
fn prepared_identity_binds_trust_and_policy_but_not_locator() {
    let mut value = json!({"schema":"oracle-host-v1","journal":"/journal",
        "engine":{"python":{"path":"/python","sha256":"a".repeat(64)},
        "answerer":{"path":"/worker","sha256":"b".repeat(64)},
        "checkout":"/source","revision":"rev","state":"/private",
        "prepared":{"artifact":{"path":"/public/MANIFEST.json","sha256":"d".repeat(64)}}}});
    let identity = |v: Value| config::deployment_identity(
        &serde_json::from_value::<Config>(v).unwrap(), &"c".repeat(64)).unwrap();
    let first = identity(value.clone());
    value["engine"]["prepared"]["artifact"]["path"] = json!("/relocated/MANIFEST.json");
    assert_eq!(first, identity(value.clone()));
    value["engine"]["prepared"]["replacement_attempts"] = json!(3);
    assert_ne!(first, identity(value.clone()));
    value["engine"]["prepared"]["replacement_attempts"] = json!(2);
    value["engine"]["prepared"]["artifact"]["sha256"] = json!("e".repeat(64));
    assert_ne!(first, identity(value));
}

#[test]
fn prepared_requires_materialization_and_bounded_policy() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = settings(dir.path());
    assert!(config::admit_engine_prepared(&engine).unwrap().is_none());
    engine.prepared = Some(config::PreparedEngineConfig {
        artifact: config::Artifact {path: dir.path().join("MANIFEST.json"), sha256: "a".repeat(64)},
        replacement_attempts: 2, replacement_backoff_ms: 1000,
    });
    assert!(config::admit_engine_prepared(&engine).unwrap_err().0.contains("materialization"));
    engine.prepared.as_mut().unwrap().replacement_attempts = 9;
    assert!(config::admit_engine_prepared(&engine).unwrap_err().0.contains("policy"));
}

#[test]
fn prepared_admits_exact_pair_and_rejects_tamper_extra_and_symlink() {
    use std::os::unix::fs::symlink;
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("source"); fs::create_dir(&source).unwrap();
    let public = dir.path().join("public"); fs::create_dir(&public).unwrap();
    let mut engine = settings(&source);
    engine.revision = "c473d28914e480425adb29b4f7f42485b8cfb4e3".into();
    engine.state = dir.path().join("private");
    let mut files = serde_json::Map::new();
    for name in ["oracle7.py", "workbench/swarm/runtime_preparation.py", "root/organs10/kqa/train.json", "root/organs10/kqa/kb.json"] {
        let path = source.join(name); fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(&path, b"fixture").unwrap();
        files.insert(name.into(), json!({"size":7,"executable":false,"sha256":config::sha256_file(&path).unwrap()}));
    }
    let receipt = json!({"schema":1,"source_revision":engine.revision,"stores":[],"files":files,
        "prepared_source":{"mode":"isolated_prepared_u8_w574","baseline_appliance_sha256":"97286fb824bb102a24ac9e7458fc8d8426212ad0bff2b585bd00d6e0462d00a5"},
        "patches":[{"sha256":"c3f4de2ea8d1a6ff039786668cba8c730943a5649db784364b1745d03d0ef2d8"}]});
    fs::write(source.join("APPLIANCE.json"), serde_json::to_vec(&receipt).unwrap()).unwrap();
    engine.materialization = Some(config::Artifact {path:source.join("APPLIANCE.json"),sha256:config::sha256_file(&source.join("APPLIANCE.json")).unwrap()});
    let reader = format!("reader90_{}.pickle", "a".repeat(24));
    let clause = format!("clause101_{}.pickle", "b".repeat(20));
    let mut payloads = serde_json::Map::new();
    for name in [&reader, &clause] {
        fs::write(public.join(name), b"tables").unwrap();
        payloads.insert(name.clone(), json!({"bytes":6,"sha256":config::sha256_bytes(b"tables")}));
    }
    let manifest = json!({"schema":"oracle-public-reader-preparation-v1","assurance":"fixture",
        "identity":{"materialization_sha256":engine.materialization.as_ref().unwrap().sha256,
        "hash_seed":"0","source_sha256":{"workbench/swarm/runtime_preparation.py":files["workbench/swarm/runtime_preparation.py"]["sha256"]},
        "data_sha256":{"train.json":files["root/organs10/kqa/train.json"]["sha256"],"kb.json":files["root/organs10/kqa/kb.json"]["sha256"]}},"files":payloads});
    let path = public.join("MANIFEST.json"); fs::write(&path,serde_json::to_vec(&manifest).unwrap()).unwrap();
    engine.prepared = Some(config::PreparedEngineConfig {artifact:config::Artifact {sha256:config::sha256_file(&path).unwrap(),path}, replacement_attempts:2,replacement_backoff_ms:1000});
    config::admit_engine_checkout(&engine).unwrap();
    assert!(config::admit_engine_prepared(&engine).unwrap().is_some());
    fs::write(public.join("private-state"), b"forbidden").unwrap();
    assert!(config::admit_engine_prepared(&engine).is_err());
    fs::remove_file(public.join("private-state")).unwrap();
    fs::write(public.join(&reader), b"tamper").unwrap();
    assert!(config::admit_engine_prepared(&engine).is_err());
    fs::remove_file(public.join(&reader)).unwrap();
    symlink(public.join(&clause), public.join(&reader)).unwrap();
    assert!(config::admit_engine_prepared(&engine).is_err());
    engine.state = dir.path().join("state-alias/child");
    symlink(&public, dir.path().join("state-alias")).unwrap();
    assert!(config::admit_engine_prepared(&engine).unwrap_err().0.contains("disjoint"));
}
