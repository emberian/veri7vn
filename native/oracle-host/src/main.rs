//! `oracle-host --config /operator/host.json` serves the loopback appliance.
//! `oracle-host catalogs` prints the compiled pure-provider catalogs (exact text).
//! `oracle-host manifest --image-sha256 HEX [--core-limits JSON]` prints a native
//! release declaration binding this binary, for the operator to review and pin.
#![forbid(unsafe_code)]

use nix::sys::signal::{SigSet, Signal};
use oracle_host::{config, http, native, pure, service::Service, wire};
use serde_json::{json, Value};
use std::net::TcpListener;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

fn fail(message: impl std::fmt::Display) -> ! {
    eprintln!("oracle-host: {message}");
    std::process::exit(2)
}

fn option(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1))
        .cloned()
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("catalogs") => {
            let map: serde_json::Map<String, Value> = pure::catalogs()
                .into_iter()
                .map(|(profile, text)| (profile.to_owned(), json!(text)))
                .collect();
            println!("{}", Value::Object(map));
        }
        Some("manifest") => {
            let image = option(&args, "--image-sha256").unwrap_or_else(|| fail("--image-sha256 required"));
            let limits: oracle_runtime_core::Limits = match option(&args, "--core-limits") {
                Some(text) => serde_json::from_str(&text).unwrap_or_else(|e| fail(format!("--core-limits: {e}"))),
                None => oracle_runtime_core::Limits::default(),
            };
            let host = oracle_host::host_binary_sha256().unwrap_or_else(|e| fail(e));
            let template = native::manifest_template(&image, &limits, &host).unwrap_or_else(|e| fail(e));
            println!("{}", String::from_utf8(wire::encode(&template)).expect("utf-8"));
        }
        Some("--config") => serve(args.get(1).unwrap_or_else(|| fail("--config needs a path"))),
        _ => fail("usage: oracle-host --config PATH | catalogs | manifest --image-sha256 HEX [--core-limits JSON]"),
    }
}

fn serve(path: &str) {
    // Block termination signals before any thread starts, so every thread
    // inherits the mask and only the waiter below receives them.
    let mut signals = SigSet::empty();
    signals.add(Signal::SIGTERM);
    signals.add(Signal::SIGINT);
    signals
        .thread_block()
        .unwrap_or_else(|e| fail(format!("signal mask: {e}")));
    let config = config::read(std::path::Path::new(path)).unwrap_or_else(|e| fail(e));
    let listener = TcpListener::bind(("127.0.0.1", config.port))
        .unwrap_or_else(|e| fail(format!("bind: {e}")));
    let service = Service::open(&config).unwrap_or_else(|e| fail(e));
    if let Some(engine) = &service.engine {
        if let Err(e) = engine.start_all() {
            service.close();
            fail(e);
        }
    }
    let stop = Arc::new(AtomicBool::new(false));
    {
        let stop = stop.clone();
        std::thread::spawn(move || {
            if signals.wait().is_ok() {
                stop.store(true, Ordering::Release);
            }
        });
    }
    let port = listener.local_addr().map(|a| a.port()).unwrap_or(0);
    println!(
        "{}",
        json!({"listening": format!("http://127.0.0.1:{port}"), "backend": "oracle_host",
        "routes": service.routes(), "operations": service.registry.items.len(),
        "host_sha256": service.host_sha256})
    );
    let result = http::serve(listener, service.clone(), stop);
    service.close();
    if let Err(e) = result {
        fail(e);
    }
}
