//! Synthetic ownership and real typed statistics checks; no specialist panel score.
use super::*;

fn fixture(profile: Option<&str>, statistics: bool) -> (tempfile::TempDir, Config, Arc<Service>) {
    let dir = tempfile::tempdir().unwrap();
    let mut value = json!({"schema":"oracle-host-v1","journal":dir.path().join("host.sqlite")});
    if let Some(profile) = profile {
        let source = dir.path().join("source.json");
        let image = dir.path().join("image.sqlite");
        std::fs::write(&source,json!({"concepts":{},"entities":{"Q1":{"name":"Alice","instanceOf":[],"relations":[]}}}).to_string()).unwrap();
        let receipt = core::build_image(&source, &image, 1_000_000, 100_000).unwrap();
        value["conversation_profile"] = json!(profile);
        value["native"] = json!({"image":image,"image_sha256":receipt.image_sha256,"state":dir.path().join("core.sqlite"),"reader_route":true});
    }
    if statistics {
        value["pure"] = json!({"profiles":["statistics"]});
    }
    let config: Config = serde_json::from_value(value).unwrap();
    let service = Service::open(&config).unwrap();
    (dir, config, service)
}
fn raw(id: &str, text: &str) -> Vec<u8> {
    wire::encode(&json!({"request_id":id,"conversation_id":"c","text":text}))
}
fn calibration() -> Value {
    json!({"operation":"statistics.calibration","arguments":{
    "x":[-2,0,2],"response":[-3,1,5],"x_name":"setting","x_unit":"m","response_unit":"N",
    "assumptions":["Prespecified linear conditional mean; independent mean-zero errors."],
    "covariance":"classical_normal_errors","direction":"forward_mean","uncertainty":"point_only","values":[5,7]}})
}
fn text(request: &Value) -> String {
    format!("{}{}", crate::modeling::PREFIX, request)
}
fn query(service: &Service, id: &str, text: &str) -> Value {
    let (status, body) = service.query(&"a".repeat(64), &raw(id, text));
    assert_eq!(status, 200, "{body}");
    body
}

#[test]
fn modeling_prefix_is_owned_without_compiled_or_configured_provider() {
    let (_dir, _config, service) = fixture(None, false);
    let (status, body) = service.query(&"a".repeat(64), &raw("valid", &text(&calibration())));
    assert_eq!(status, 503);
    assert_eq!(body["error"], "modeling_profile_unavailable");
    let bad=query(&service,"bad","Model supplied data: {\"operation\":\"statistics.calibration\",\"arguments\":{\"mean\":[1,2,3]}}");
    assert_eq!(bad["reply"]["path"], "native:modeling");
    assert_eq!(bad["reply"]["reason"], "invalid_input");
    let duplicate = query(
        &service,
        "duplicate",
        "Model supplied data: {\"operation\":1,\"operation\":2,\"arguments\":{}}",
    );
    assert_eq!(duplicate["reply"]["reason"], "invalid_input");
    let outside = query(&service, "outside", "model supplied data: mean 1 2 3");
    assert_ne!(outside["reply"]["path"], "native:modeling");
    service.close();
}

#[cfg(feature = "statistics")]
#[test]
fn modeling_real_math_declines_and_strict_declarations() {
    let (_dir, _config, service) = fixture(None, true);
    let result = query(&service, "fit", &text(&calibration()));
    assert_eq!(result["reply"]["status"], "answered");
    assert!(
        (result["reply"]["result"]["estimates"][0]["value"]
            .as_f64()
            .unwrap()
            - 11.0)
            .abs()
            < 1e-10
    );
    assert!(
        (result["reply"]["result"]["estimates"][1]["value"]
            .as_f64()
            .unwrap()
            - 15.0)
            .abs()
            < 1e-10
    );
    assert_eq!(result["reply"]["authority"], "computation_only");
    assert_eq!(result["reply"]["result"]["output_unit"], "N");
    assert!(result["reply"].get("checked_reply").is_none());
    assert_eq!(result["reply"]["modeling_reason"], "model_result");
    assert!(
        result["reply"].get("reason").is_none(),
        "the route must not invent or overwrite a provider reason"
    );
    let response = result["reply"]["response"].as_str().unwrap();
    assert!(response.len() < 180);
    assert!(
        !response.contains('{'),
        "structured results must not be embedded in response text"
    );
    assert_eq!(result["reply"]["supplied"], calibration());
    let mut inverse = calibration();
    inverse["arguments"]["direction"] = json!("inverse_point");
    inverse["arguments"]["values"] = json!([11]);
    let result = query(&service, "inverse", &text(&inverse));
    assert!(
        (result["reply"]["result"]["estimates"][0]["value"]
            .as_f64()
            .unwrap()
            - 5.0)
            .abs()
            < 1e-10
    );
    assert_eq!(result["reply"]["result"]["output_unit"], "m");
    for (i, key) in ["assumptions", "x_unit", "uncertainty", "response_unit"]
        .iter()
        .enumerate()
    {
        let mut missing = calibration();
        missing["arguments"].as_object_mut().unwrap().remove(*key);
        let result = query(&service, &format!("missing{i}"), &text(&missing));
        assert_eq!(result["reply"]["reason"], "invalid_input");
    }
    let mut rank = calibration();
    rank["arguments"]["x"] = json!([1, 1, 1]);
    let result = query(&service, "rank", &text(&rank));
    assert_eq!(result["reply"]["status"], "withheld");
    assert_eq!(result["reply"]["modeling_reason"], "model_refused");
    assert_eq!(result["reply"]["reason"], "calibration_unavailable");
    let oversized = format!("{}{}", crate::modeling::PREFIX, " ".repeat(65536));
    assert_eq!(
        query(&service, "bytes", &oversized)["reply"]["reason"],
        "invalid_input"
    );
    service.close();
}

#[cfg(feature = "statistics")]
fn poisson() -> Value {
    json!({"operation":"statistics.events_exposure","arguments":{
    "family":"poisson_log","method":"maximum_likelihood","features":[[],[]],"intercept":true,"uncertainty":"none",
    "model":{"description":"Supplied rate model","predictor_names":[],"predictor_units":[],"independent_unit":"device interval","grouping":"One independent interval per row","assumptions":["Independent rows and prespecified constant rate"]},
    "predictions":[{"features":[],"exposure":3}],"counts":[2,6],"exposures":[1,3],"exposure_unit":"device-hour"}})
}

#[cfg(feature = "statistics")]
#[test]
fn modeling_actual_glm_certificate_and_owned_refusals() {
    let (_dir, _config, service) = fixture(None, true);
    let result = query(&service, "poisson", &text(&poisson()));
    assert_eq!(result["reply"]["status"], "answered", "{result}");
    assert_eq!(result["reply"]["result"]["status"], "finite_mle_converged");
    assert!(result["reply"]["result"]["finite_mle_certificate"].is_object());
    let mut zeros = poisson();
    zeros["arguments"]["counts"] = json!([0, 0]);
    let result = query(&service, "zeros", &text(&zeros));
    assert_eq!(result["reply"]["status"], "withheld");
    assert_eq!(result["reply"]["result"]["status"], "separation_certified");
    assert!(result["reply"]["result"]["separation_certificate"].is_object());
    for (id, mut request) in [
        ("empty", poisson()),
        ("grouping", poisson()),
        ("exposure", poisson()),
        ("unknown", poisson()),
    ] {
        match id {
            "empty" => request["arguments"]["predictions"] = json!([]),
            "grouping" => {
                request["arguments"]["model"]
                    .as_object_mut()
                    .unwrap()
                    .remove("grouping");
            }
            "exposure" => request["arguments"]["predictions"] = json!([{"features":[]}]),
            _ => request["arguments"]["mean"] = json!([1, 2, 3]),
        }
        let result = query(&service, id, &text(&request));
        assert_eq!(result["reply"]["reason"], "invalid_input");
    }
    service.close();
}

#[cfg(feature = "statistics")]
#[test]
fn modeling_native_cursor_atomic_replay_restart_and_refusal_preservation() {
    let (_dir, config, service) = fixture(Some("native-v1"), true);
    let tenant = "a".repeat(64);
    let observe = wire::encode(
        &json!({"request_id":"observe","conversation_id":"c","operation_id":"context.native","arguments":{"expected_version":0,
        "command":{"op":"observe","quantity":{"number":"42","unit":"J","origin":"exact_decimal"}}}}),
    );
    assert_eq!(service.invoke_encoded(&tenant, &observe).status(), 200);
    let mut rank = calibration();
    rank["arguments"]["x"] = json!([1, 1, 1]);
    let refused = query(&service, "rank", &text(&rank));
    assert_eq!(refused["conversation_version"], 2);
    assert_eq!(
        refused["reply"]["native_context_transition"],
        "preserved_refusal"
    );
    let inspect = query(&service, "inspect", "What was that?");
    assert_eq!(
        inspect["reply"]["provenance"]["native_context"]["anchor"]["value"]["number"],
        "42"
    );
    let request = raw("fit", &text(&calibration()));
    let first = service.query_encoded(&tenant, &request);
    assert_eq!(first.status(), 200);
    let body = wire::parse(first.body()).unwrap();
    assert_eq!(body["conversation_version"], 4);
    assert_eq!(
        body["reply"]["native_context_transition"],
        "cleared_unrepresentable_answer"
    );
    assert_eq!(
        service.query_encoded(&tenant, &request).body(),
        first.body()
    );
    assert_eq!(
        service
            .query_encoded(&tenant, &raw("fit", "changed"))
            .status(),
        409
    );
    let inspect = query(&service, "empty", "What was that?");
    assert_eq!(
        inspect["reply"]["provenance"]["native_context"]["anchor"]["kind"],
        "empty"
    );
    service.close();
    drop(service);
    let restarted = Service::open(&config).unwrap();
    assert_eq!(
        restarted.query_encoded(&tenant, &request).body(),
        first.body()
    );
    let inspect = query(&restarted, "after-restart", "What was that?");
    assert_eq!(
        inspect["reply"]["provenance"]["native_context"]["anchor"]["kind"],
        "empty"
    );
    restarted.close();
}

#[cfg(feature = "statistics")]
#[test]
fn modeling_readonly_declines_without_engine_projection() {
    let (_dir, config, service) = fixture(Some("readonly-v1"), true);
    let request = raw("fit", &text(&calibration()));
    let tenant = "a".repeat(64);
    let first = service.query_encoded(&tenant, &request);
    let body = wire::parse(first.body()).unwrap();
    assert_eq!(first.status(), 200);
    assert_eq!(
        body["reply"]["reason"],
        "conversation_transition_unsupported"
    );
    assert!(service.engine.is_none());
    assert_eq!(
        service.query_encoded(&tenant, &request).body(),
        first.body()
    );
    service.close();
    drop(service);
    let restarted = Service::open(&config).unwrap();
    assert_eq!(
        restarted.query_encoded(&tenant, &request).body(),
        first.body()
    );
    restarted.close();
}

#[cfg(feature = "statistics")]
#[test]
fn modeling_owns_before_hostile_organs_and_reader_in_both_journals() {
    use std::os::unix::fs::PermissionsExt;
    for profile in [None, Some("native-v1")] {
        let (directory, mut config, service) = fixture(profile, true);
        service.close();
        drop(service);
        let executable = directory.path().join("hostile-organ");
        let log = directory.path().join("asked");
        std::fs::write(&executable, format!(r#"#!/bin/sh
while IFS= read -r line; do
  printf 'asked\n' >> '{}'
  id=$(printf '%s' "$line" | /usr/bin/sed -E 's/.*"id":([0-9]+).*/\1/')
  printf '{{"id":%s,"status":"answered","kind":"mean","response":"999","path":"hostile:incidental_mean","value":999}}\n' "$id"
done
"#, log.display())).unwrap();
        std::fs::set_permissions(&executable, std::fs::Permissions::from_mode(0o700)).unwrap();
        config.kernels = Some(serde_json::from_value(json!({"organs":[{"id":"hostile-mean","executable":executable,
            "sha256":config::sha256_file(&executable).unwrap(),"family":"acoustics","accept":{"kinds":["mean"],"context_regex":null}}]})).unwrap());
        let service = Service::open(&config).unwrap();
        for (id, question) in [("valid",text(&calibration())),("invalid","Model supplied data: {\"operation\":\"statistics.events_exposure\",\"arguments\":{}}".into())] {
            let body=query(&service,id,&question); assert_eq!(body["reply"]["path"],"native:modeling");
        }
        assert!(
            !log.exists(),
            "owned requests reached a hostile incidental-mean candidate"
        );
        let body = query(&service, "outside", "What is the mean of 1, 2, 3?");
        assert_eq!(body["reply"]["status"], "answered");
        assert!(log.exists());
        service.close();
    }
}

#[cfg(feature = "statistics")]
#[test]
fn modeling_opaque_binding_refuses_before_computation_and_unavailable_preserves_cursor() {
    let (_directory, _config, service) = fixture(None, true);
    let tenant = "a".repeat(64);
    // bind updates an existing dispatched conversation; it does not insert one.
    // Reproduce the ordinary Engine journal lifecycle before testing the guard.
    let prior = raw("prior-engine", "a prior opaque Engine question");
    assert!(matches!(
        service
            .journal
            .begin_encoded(&tenant, "prior-engine", &prior, service.limits.reply_bytes)
            .unwrap(),
        EncodedLookup::Fresh
    ));
    service
        .journal
        .dispatch(&tenant, "prior-engine", "c")
        .unwrap();
    service
        .journal
        .bind(&tenant, "c", 0, "opaque-unrecoverable")
        .unwrap();
    service.journal.finish_bytes(&tenant, "prior-engine", "c",
        &wire::encode(&json!({"outcome":"completed","reply":{"status":"answered","response":"prior Engine answer"}})), true).unwrap();
    assert_eq!(
        service.journal.conversation(&tenant, "c").unwrap(),
        Some((0, "opaque-unrecoverable".into()))
    );
    let result = query(&service, "bound", &text(&calibration()));
    assert_eq!(
        result["reply"]["reason"],
        "conversation_transition_unsupported"
    );
    service.close();
    let (_directory, _config, service) = fixture(Some("native-v1"), false);
    let (status, result) = service.query(&tenant, &raw("unavailable", &text(&calibration())));
    assert_eq!(status, 503);
    assert_eq!(result["error"], "modeling_profile_unavailable");
    let body = query(&service, "next", "What was that?");
    assert_eq!(
        body["conversation_version"], 1,
        "execution failure must not commit a semantic refusal"
    );
    service.close();
}

#[cfg(feature = "statistics")]
#[test]
fn modeling_encoding_failure_does_not_publish_context_or_advance_revision() {
    let (_directory, mut config, service) = fixture(Some("native-v1"), true);
    service.close();
    drop(service);
    config.limits.reply_bytes = 1024;
    let service = Service::open(&config).unwrap();
    let tenant = "a".repeat(64);
    let body = query(&service, "before", "What was that?");
    assert_eq!(body["conversation_version"], 1);
    let (status, body) = service.query(&tenant, &raw("large", &text(&calibration())));
    assert_eq!(status, 502);
    assert_eq!(body["error"], "reply_too_large");
    let body = query(&service, "after", "What was that?");
    assert_eq!(body["conversation_version"], 2);
    assert_eq!(
        body["reply"]["provenance"]["native_context"]["anchor"]["kind"],
        "empty"
    );
    service.close();
}

#[cfg(feature = "statistics")]
#[test]
fn modeling_invalid_optional_fields_are_semantic_refusals_not_execution_failures() {
    let (_directory, _config, service) = fixture(None, true);
    for (id, mut request) in [
        ("bad-solver", poisson()),
        ("blank", calibration()),
        ("many", calibration()),
        ("unsupported", calibration()),
    ] {
        match id {
            "bad-solver" => request["arguments"]["solver"] = json!({"max_iterations":-1}),
            "blank" => request["arguments"]["assumptions"] = json!(["  \t"]),
            "many" => request["arguments"]["values"] = json!(vec![1; 33]),
            _ => request["operation"] = json!("statistics.linear_regression"),
        }
        let result = query(&service, id, &text(&request));
        assert_eq!(result["reply"]["status"], "withheld");
        assert_eq!(result["reply"]["reason"], "invalid_input");
    }
    service.close();
}
