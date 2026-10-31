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
