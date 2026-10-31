//! Real host HTTP/state journey over a manufactured immutable image. No panel score.
use oracle_host::{
    config::{Config, HostLimits, NativeConfig},
    service::Service,
};
use serde_json::{json, Value};
use std::{
    io::{Read, Write},
    net::{TcpListener, TcpStream},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    thread,
};

struct Http {
    address: std::net::SocketAddr,
    stop: Arc<AtomicBool>,
    worker: Option<thread::JoinHandle<()>>,
}
impl Http {
    fn new(service: Arc<Service>) -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let stop = Arc::new(AtomicBool::new(false));
        let stopper = stop.clone();
        let worker =
            thread::spawn(move || oracle_host::http::serve(listener, service, stopper).unwrap());
        Self {
            address,
            stop,
            worker: Some(worker),
        }
    }
}
impl Drop for Http {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Release);
        self.worker.take().unwrap().join().unwrap();
    }
}
fn call(service: &Http, tenant: &str, operation: &str, request: &str, args: Value) -> (u16, Value) {
    let address = service.address;
    let body=json!({"request_id":request,"conversation_id":"conversation","operation_id":operation,"arguments":args}).to_string();
    let mut stream = TcpStream::connect(address).unwrap();
    write!(stream,"POST /invoke HTTP/1.1\r\nHost: 127.0.0.1:{}\r\nX-Mini-Oracle-Tenant: {tenant}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",address.port(),body.len()).unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();
    let (headers, body) = response.split_once("\r\n\r\n").unwrap();
    (
        headers.split_whitespace().nth(1).unwrap().parse().unwrap(),
        serde_json::from_str(body).unwrap(),
    )
}

#[test]
fn context_http_retry_tenant_restart_and_pure_image_calls() {
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("source.json");
    let image = dir.path().join("image.sqlite");
    std::fs::write(
        &source,
        json!({"concepts":{},"entities":{"Q1":{"name":"Alice","instanceOf":[],"relations":[]}}})
            .to_string(),
    )
    .unwrap();
    let receipt = oracle_runtime_core::build_image(&source, &image, 1_000_000, 100_000).unwrap();
    let mut config = Config {
        schema: "oracle-host-v1".into(),
        port: 0,
        limits: HostLimits::default(),
        journal: dir.path().join("journal.sqlite"),
        native: Some(NativeConfig {
            image,
            image_sha256: receipt.image_sha256,
            state: dir.path().join("state.sqlite"),
            core_limits: Value::Null,
            release: None,
            reader_route: false,
        }),
        kernels: None,
        engine: None,
        pure: None,
    };
    let tenant = "a".repeat(64);
    let other = "b".repeat(64);
    let service = Http::new(Service::open(&config).unwrap());
    let args = json!({"command":{"op":"observe","value":{"number":"12.5","origin":"exact_decimal"}},"expected_version":0});
    let first = call(&service, &tenant, "context.execute", "first", args.clone());
    assert_eq!(first.0, 200, "{:?}", first);
    let retry = call(&service, &tenant, "context.execute", "first", args.clone());
    assert_eq!(retry.0, 200);
    assert_eq!(
        first.1["reply"]["core_reply_json"],
        retry.1["reply"]["core_reply_json"]
    );
    let changed = call(
        &service,
        &tenant,
        "context.execute",
        "first",
        json!({"command":{"op":"clear"},"expected_version":0}),
    );
    assert_eq!(changed.0, 409);
    let isolated = call(
        &service,
        &other,
        "context.execute",
        "inspect",
        json!({"command":{"op":"inspect"},"expected_version":0}),
    );
    assert_eq!(isolated.0, 200);
    let isolated_raw: Value =
        serde_json::from_str(isolated.1["reply"]["core_reply_json"].as_str().unwrap()).unwrap();
    assert!(isolated_raw["result"]["scalar"].is_null());
    let coverage = call(
        &service,
        &tenant,
        "graph.coverage",
        "coverage",
        json!({"coverage":{"subjects":["Q1"],"predicate":"knows","direction":"forward","traversal_limit":10}}),
    );
    assert_eq!(coverage.0, 200, "{:?}", coverage);
    let raw: Value =
        serde_json::from_str(coverage.1["reply"]["core_reply_json"].as_str().unwrap()).unwrap();
    assert_eq!(raw["answers"]["absent_in_snapshot"], true);
    let plan =
        json!({"nodes":[{"op":"find","name":"Alice"}],"output":0,"projection":{"kind":"count"}});
    let batch = call(
        &service,
        &tenant,
        "graph.batch",
        "batch",
        json!({"batch":{"items":[{"dialect":"graph","input":plan,"demand":"full"}]}}),
    );
    assert_eq!(batch.0, 200, "{:?}", batch);
    assert_eq!(batch.1["durable_replay"], false);
    let journal = rusqlite::Connection::open(&config.journal).unwrap();
    let journaled: i64 = journal
        .query_row("SELECT count(*) FROM requests", [], |r| r.get(0))
        .unwrap();
    assert_eq!(journaled, 0, "native turns must use one core journal only");
    drop(journal);
    drop(service);
    let service = Http::new(Service::open(&config).unwrap());
    let restarted = call(&service, &tenant, "context.execute", "first", args);
    assert_eq!(restarted.0, 200);
    assert_eq!(
        first.1["reply"]["core_reply_json"],
        restarted.1["reply"]["core_reply_json"]
    );
    let scaled = call(
        &service,
        &tenant,
        "context.execute",
        "scale",
        json!({"command":{"op":"scale","factor":"2"},"expected_version":1}),
    );
    assert_eq!(scaled.0, 200, "{:?}", scaled);
    let raw: Value =
        serde_json::from_str(scaled.1["reply"]["core_reply_json"].as_str().unwrap()).unwrap();
    assert_eq!(raw["result"]["scalar"]["value"]["number"], "25/1");
    drop(service);
    let mut limits = oracle_runtime_core::Limits::default();
    limits.result_bytes = 32;
    config.native.as_mut().unwrap().core_limits = serde_json::to_value(limits).unwrap();
    config.native.as_mut().unwrap().state = dir.path().join("tiny-state.sqlite");
    config.journal = dir.path().join("tiny-journal.sqlite");
    let service = Http::new(Service::open(&config).unwrap());
    let limited = call(
        &service,
        &tenant,
        "graph.coverage",
        "limited",
        json!({"coverage":{"subjects":["Q1"],"predicate":"knows","direction":"forward","traversal_limit":10}}),
    );
    assert_eq!(limited.0, 503, "{:?}", limited);
    assert_eq!(limited.1["error"], "runtime_budget");
}
