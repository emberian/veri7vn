use oracle_runtime_core::release::{
    runtime_profile_sha256, Availability, OperationRegistration, ReleaseBindings, ReleaseManifest,
    ResourceBinding, SchemaVersion, MAX_MANIFEST_BYTES, MAX_OPERATIONS,
};
use oracle_runtime_core::{Error, Limits};
use serde_json::{json, Value};

fn declaration() -> Value {
    json!({
        "schema":"oracle-native-release-v1",
        "runtime_artifact_sha256":"1".repeat(64),
        "data_image_sha256":"2".repeat(64),
        "resource_profile_sha256":"3".repeat(64),
        "appliance_receipt_sha256":null,
        "schemas":[{"id":"image","version":2},{"id":"state","version":1}],
        "resources":[{"id":"lexicon","sha256":"4".repeat(64),"schema_id":"image"}],
        "operations":[
            {"id":"native.query","version":1,"summary":"Query the admitted image",
             "availability":"implemented","input_schema":{"type":"object","additionalProperties":false},
             "output_schema":{"type":"object"},"resources":["lexicon"],"limitations":["No proof claim"]},
            {"id":"legacy.query","version":1,"summary":"Contained legacy interpreter",
             "availability":"legacy_contained","input_schema":{"type":"object"},
             "output_schema":{"type":"object"},"resources":[],"limitations":["Requires host containment"]},
            {"id":"offline.build","version":1,"summary":"Build an image offline",
             "availability":"offline_only","input_schema":{"type":"object"},
             "output_schema":{"type":"object"},"resources":[],"limitations":[]},
            {"id":"host.network","version":1,"summary":"Host network authority",
             "availability":"unavailable","input_schema":{"type":"object"},
             "output_schema":{"type":"object"},"resources":[],"limitations":[]}
        ]
    })
}

fn parse(value: Value) -> ReleaseManifest {
    ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).unwrap()
}

fn bindings() -> ReleaseBindings {
    ReleaseBindings {
        runtime_artifact_sha256: "1".repeat(64),
        data_image_sha256: "2".repeat(64),
        resource_profile_sha256: "3".repeat(64),
        resources: vec![ResourceBinding {
            id: "lexicon".into(),
            sha256: "4".repeat(64),
        }],
    }
}

fn registry() -> Vec<OperationRegistration> {
    vec![
        OperationRegistration {
            id: "native.query".into(),
            availability: Availability::Implemented,
        },
        OperationRegistration {
            id: "legacy.query".into(),
            availability: Availability::LegacyContained,
        },
    ]
}

#[test]
fn unknown_fields_and_duplicate_typed_keys_fail_closed() {
    for field in ["root", "operation", "resource", "schema"] {
        let mut value = declaration();
        match field {
            "root" => {
                value["executable"] = json!("/client/chosen");
            }
            "operation" => {
                value["operations"][0]["verified"] = json!(true);
            }
            "resource" => {
                value["resources"][0]["path"] = json!("/client/chosen");
            }
            "schema" => {
                value["schemas"][0]["source"] = json!("client");
            }
            _ => unreachable!(),
        }
        assert!(
            ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).is_err(),
            "{field}"
        );
    }
    let duplicate = serde_json::to_string(&declaration()).unwrap().replacen(
        "\"schema\":\"oracle-native-release-v1\"",
        "\"schema\":\"oracle-native-release-v1\",\"schema\":\"oracle-native-release-v1\"",
        1,
    );
    assert!(ReleaseManifest::from_json(duplicate.as_bytes()).is_err());
}

#[test]
fn duplicate_ids_and_missing_dependencies_are_rejected() {
    for collection in ["operations", "resources", "schemas"] {
        let mut value = declaration();
        let repeated = value[collection][0].clone();
        value[collection].as_array_mut().unwrap().push(repeated);
        assert!(
            ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).is_err(),
            "{collection}"
        );
    }
    let mut value = declaration();
    value["operations"][0]["resources"] = json!(["absent"]);
    assert!(ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).is_err());
    value = declaration();
    value["resources"][0]["schema_id"] = json!("absent");
    assert!(ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).is_err());
    value = declaration();
    value["operations"][0]["resources"] = json!(["lexicon", "lexicon"]);
    assert!(ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).is_err());
}

#[test]
fn identities_ignore_declaration_order_and_json_whitespace() {
    let value = declaration();
    let original = parse(value.clone()).identity().unwrap();
    let pretty = serde_json::to_vec_pretty(&value).unwrap();
    assert_eq!(
        original,
        ReleaseManifest::from_json(&pretty)
            .unwrap()
            .identity()
            .unwrap()
    );
    let mut reversed = value;
    for collection in ["operations", "resources", "schemas"] {
        reversed[collection].as_array_mut().unwrap().reverse();
    }
    assert_eq!(original, parse(reversed).identity().unwrap());
    assert_eq!(original.len(), 64);
}

#[test]
fn every_execution_constituent_changes_the_identity() {
    let original = parse(declaration()).identity().unwrap();
    let substitutions = [
        ("/runtime_artifact_sha256", json!("a".repeat(64))),
        ("/data_image_sha256", json!("a".repeat(64))),
        ("/resource_profile_sha256", json!("a".repeat(64))),
        ("/appliance_receipt_sha256", json!("a".repeat(64))),
        ("/schemas/0/version", json!(3)),
        ("/schemas/1/version", json!(2)),
        ("/resources/0/sha256", json!("a".repeat(64))),
        ("/resources/0/schema_id", json!("state")),
        ("/operations/0/id", json!("native.query.v2")),
        ("/operations/0/version", json!(2)),
        ("/operations/0/summary", json!("Different declaration")),
        ("/operations/0/availability", json!("unavailable")),
        ("/operations/0/input_schema/type", json!("array")),
        ("/operations/0/output_schema/type", json!("array")),
        ("/operations/0/resources", json!([])),
        ("/operations/0/limitations", json!(["Different limitation"])),
    ];
    for (pointer, replacement) in substitutions {
        let mut changed = declaration();
        *changed.pointer_mut(pointer).unwrap() = replacement;
        assert_ne!(original, parse(changed).identity().unwrap(), "{pointer}");
    }
}

#[test]
fn malformed_hashes_versions_paths_and_bounds_are_rejected() {
    for hash in ["", "abc", &"A".repeat(64), &"g".repeat(64), &"1".repeat(65)] {
        let mut value = declaration();
        value["runtime_artifact_sha256"] = json!(hash);
        assert!(ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).is_err());
    }
    for pointer in ["/schemas/0/version", "/operations/0/version"] {
        let mut value = declaration();
        *value.pointer_mut(pointer).unwrap() = json!(0);
        assert!(ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).is_err());
    }
    for id in [
        "/bin/python",
        "../shell",
        "https://example.org",
        "import os",
        "",
    ] {
        let mut value = declaration();
        value["operations"][0]["id"] = json!(id);
        assert!(ReleaseManifest::from_json(&serde_json::to_vec(&value).unwrap()).is_err());
    }
    let large = vec![b' '; MAX_MANIFEST_BYTES + 1];
    assert!(matches!(
        ReleaseManifest::from_json(&large),
        Err(Error::Limit(_))
    ));
    let mut manifest = parse(declaration());
    manifest
        .operations
        .resize(MAX_OPERATIONS + 1, manifest.operations[0].clone());
    assert!(matches!(manifest.validate(), Err(Error::Limit(_))));
    let mut manifest = parse(declaration());
    manifest.operations[0].summary = "x".repeat(513);
    assert!(manifest.identity().is_err());
    let mut manifest = parse(declaration());
    let mut deep = json!({});
    for _ in 0..40 {
        deep = json!({"nested":deep});
    }
    manifest.operations[0].input_schema = deep;
    assert!(matches!(manifest.identity(), Err(Error::Limit(_))));
}

#[test]
fn admission_requires_trusted_identity_and_all_measured_artifacts() {
    let manifest = parse(declaration());
    let identity = manifest.identity().unwrap();
    assert!(manifest
        .clone()
        .admit(&"0".repeat(64), &bindings(), &registry())
        .is_err());
    for part in [
        "runtime",
        "image",
        "profile",
        "resource",
        "missing",
        "extra",
        "duplicate",
    ] {
        let mut observed = bindings();
        match part {
            "runtime" => observed.runtime_artifact_sha256 = "f".repeat(64),
            "image" => observed.data_image_sha256 = "f".repeat(64),
            "profile" => observed.resource_profile_sha256 = "f".repeat(64),
            "resource" => observed.resources[0].sha256 = "f".repeat(64),
            "missing" => observed.resources.clear(),
            "extra" => observed.resources.push(ResourceBinding {
                id: "extra".into(),
                sha256: "f".repeat(64),
            }),
            "duplicate" => observed.resources.push(observed.resources[0].clone()),
            _ => unreachable!(),
        }
        assert!(
            manifest
                .clone()
                .admit(&identity, &observed, &registry())
                .is_err(),
            "{part}"
        );
    }
    let admitted = manifest.admit(&identity, &bindings(), &registry()).unwrap();
    assert_eq!(admitted.identity(), identity);
    admitted.check_identity(&identity).unwrap();
    assert!(admitted.check_identity(&"0".repeat(64)).is_err());
}

#[test]
fn availability_claims_require_exact_actual_registrations() {
    let manifest = parse(declaration());
    let identity = manifest.identity().unwrap();
    for case in ["missing", "wrong_kind", "unknown", "offline", "duplicate"] {
        let mut registrations = registry();
        match case {
            "missing" => {
                registrations.pop();
            }
            "wrong_kind" => registrations[1].availability = Availability::Implemented,
            "unknown" => registrations.push(OperationRegistration {
                id: "unknown".into(),
                availability: Availability::Implemented,
            }),
            "offline" => registrations.push(OperationRegistration {
                id: "offline.build".into(),
                availability: Availability::OfflineOnly,
            }),
            "duplicate" => registrations.push(registrations[0].clone()),
            _ => unreachable!(),
        }
        assert!(
            manifest
                .clone()
                .admit(&identity, &bindings(), &registrations)
                .is_err(),
            "{case}"
        );
    }
    let admitted = manifest.admit(&identity, &bindings(), &registry()).unwrap();
    let counts = admitted.counts();
    assert_eq!(counts.implemented, 1);
    assert_eq!(counts.legacy_contained, 1);
    assert_eq!(counts.offline_only, 1);
    assert_eq!(counts.unavailable, 1);
    admitted.require_implemented("native.query").unwrap();
    for id in ["legacy.query", "offline.build", "host.network", "unknown"] {
        assert!(admitted.require_implemented(id).is_err(), "{id}");
    }
}

#[test]
fn opened_runtime_checks_actual_image_limits_and_supported_schemas() {
    let limits = Limits::default();
    let profile = runtime_profile_sha256(&limits).unwrap();
    // Every operator Limits field participates, not a selected subset of bounds.
    let value = serde_json::to_value(&limits).unwrap();
    for (field, original) in value.as_object().unwrap() {
        let mut altered = value.clone();
        altered[field] = json!(original.as_u64().unwrap() + 1);
        let changed: Limits = serde_json::from_value(altered).unwrap();
        assert_ne!(
            profile,
            runtime_profile_sha256(&changed).unwrap(),
            "{field}"
        );
    }
    let mut manifest = parse(declaration());
    manifest.resource_profile_sha256 = profile.clone();
    let identity = manifest.identity().unwrap();
    let mut measured = bindings();
    measured.resource_profile_sha256 = profile;
    let admitted = manifest.admit(&identity, &measured, &registry()).unwrap();
    let schemas = vec![
        SchemaVersion {
            id: "image".into(),
            version: 2,
        },
        SchemaVersion {
            id: "state".into(),
            version: 1,
        },
    ];
    admitted
        .check_runtime(&measured.data_image_sha256, &limits, &schemas)
        .unwrap();
    assert!(admitted
        .check_runtime(&"f".repeat(64), &limits, &schemas)
        .is_err());
    let changed_limits = Limits {
        fuel: limits.fuel + 1,
        ..limits.clone()
    };
    assert!(admitted
        .check_runtime(&measured.data_image_sha256, &changed_limits, &schemas)
        .is_err());
    let mut incompatible = schemas.clone();
    incompatible[1].version = 2;
    assert!(admitted
        .check_runtime(&measured.data_image_sha256, &limits, &incompatible)
        .is_err());
    incompatible[1].id = "unlisted_schema".into();
    assert!(admitted
        .check_runtime(&measured.data_image_sha256, &limits, &incompatible)
        .is_err());
    assert!(admitted
        .check_runtime(&measured.data_image_sha256, &limits, &[])
        .is_err());
    incompatible = schemas.clone();
    incompatible.push(schemas[0].clone());
    assert!(admitted
        .check_runtime(&measured.data_image_sha256, &limits, &incompatible)
        .is_err());
}
