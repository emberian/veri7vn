//! Private loopback HTTP/1.0 boundary, mirroring `tools/appliance/serve.py`
//! `Server` and `Handler`: a fixed connection cap (excess connections are
//! closed), one absolute ingress deadline for headers and body, browser
//! origins refused, a loopback Host header, and the tenant routing header.
//!
//! No HTTP crate is used: tiny_http 0.12 starts a thread per connection with
//! no cap and exposes no socket timeouts, and hyper needs an async runtime.
//! This reader handles exactly one request per connection, as the reference
//! server's HTTP/1.0 handler does.

use crate::service::{tenant_key, Discovery, Service};
use crate::wire;
use crate::{failure, operations::valid_operation_id};
use nix::poll::{poll, PollFd, PollFlags};
use serde_json::{json, Value};
use std::io::{ErrorKind, Read, Write};
use std::net::{Shutdown, TcpListener, TcpStream};
use std::os::fd::AsFd;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::{Duration, Instant};

pub const TENANT_HEADER: &str = "x-mini-oracle-tenant";
const MAX_HEADER_BYTES: usize = 65536;
const MAX_HEADERS: usize = 100;

struct Request {
    method: String,
    path: String,
    headers: Vec<(String, String)>,
    leftover: Vec<u8>,
}

impl Request {
    fn all(&self, name: &str) -> Vec<&str> {
        self.headers
            .iter()
            .filter(|(k, _)| k.eq_ignore_ascii_case(name))
            .map(|(_, v)| v.as_str())
            .collect()
    }
    fn first(&self, name: &str) -> Option<&str> {
        self.all(name).first().copied()
    }
}

fn reason(status: u16) -> &'static str {
    match status {
        200 => "OK",
        400 => "Bad Request",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        408 => "Request Timeout",
        409 => "Conflict",
        413 => "Request Entity Too Large",
        415 => "Unsupported Media Type",
        429 => "Too Many Requests",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Timeout",
        507 => "Insufficient Storage",
        _ => "Error",
    }
}

fn respond(stream: &mut TcpStream, reply: &wire::EncodedReply) {
    let status = reply.status();
    let payload = reply.body();
    let head = format!(
        "HTTP/1.0 {status} {}\r\nServer: oracle-host\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nCache-Control: no-store\r\n\r\n",
        reason(status),
        payload.len()
    );
    let _ = stream
        .write_all(head.as_bytes())
        .and_then(|_| stream.write_all(payload));
    let _ = stream.flush();
}

/// Read until the deadline, never past it.
fn read_some(
    stream: &mut TcpStream,
    buffer: &mut [u8],
    deadline: Instant,
) -> std::io::Result<usize> {
    let left = deadline.saturating_duration_since(Instant::now());
    if left.is_zero() {
        return Err(ErrorKind::TimedOut.into());
    }
    stream.set_read_timeout(Some(left))?;
    match stream.read(buffer) {
        Err(e) if matches!(e.kind(), ErrorKind::WouldBlock) => Err(ErrorKind::TimedOut.into()),
        other => other,
    }
}

fn read_head(stream: &mut TcpStream, deadline: Instant) -> Option<Request> {
    let mut data = Vec::new();
    let mut chunk = [0u8; 4096];
    let end = loop {
        if let Some(i) = data.windows(4).position(|w| w == b"\r\n\r\n") {
            break i + 4;
        }
        if let Some(i) = data.windows(2).position(|w| w == b"\n\n") {
            break i + 2;
        }
        if data.len() > MAX_HEADER_BYTES {
            return None;
        }
        match read_some(stream, &mut chunk, deadline) {
            Ok(0) | Err(_) => return None,
            Ok(n) => data.extend_from_slice(&chunk[..n]),
        }
    };
    let text = std::str::from_utf8(&data[..end]).ok()?;
    let mut lines = text.split('\n').map(|l| l.strip_suffix('\r').unwrap_or(l));
    let mut parts = lines.next()?.split(' ');
    let (method, path, version) = (parts.next()?, parts.next()?, parts.next()?);
    if parts.next().is_some() || !version.starts_with("HTTP/") {
        return None;
    }
    let mut headers = Vec::new();
    for line in lines.filter(|l| !l.is_empty()) {
        let (name, value) = line.split_once(':')?;
        if name.is_empty() || name.contains(char::is_whitespace) || headers.len() >= MAX_HEADERS {
            return None;
        }
        headers.push((name.to_owned(), value.trim().to_owned()));
    }
    Some(Request {
        method: method.to_owned(),
        path: path.to_owned(),
        headers,
        leftover: data[end..].to_vec(),
    })
}

fn private_request(request: &Request, port: u16) -> Result<(), (u16, Value)> {
    if request.first("Origin").is_some_and(|v| !v.is_empty())
        || request
            .first("Sec-Fetch-Site")
            .is_some_and(|v| !v.is_empty())
    {
        return Err((403, failure("browser_request_rejected", json!({}))));
    }
    let host = request.first("Host").unwrap_or("");
    let allowed = [
        "127.0.0.1".to_owned(),
        format!("127.0.0.1:{port}"),
        "localhost".to_owned(),
        format!("localhost:{port}"),
    ];
    if !allowed.iter().any(|a| a == host) {
        return Err((400, failure("invalid_host", json!({}))));
    }
    Ok(())
}

fn tenant(request: &Request) -> Result<String, (u16, Value)> {
    let values = request.all(TENANT_HEADER);
    if values.len() != 1 || !tenant_key(values[0]) {
        return Err((400, failure("host_tenant_required", json!({}))));
    }
    Ok(values[0].to_owned())
}

fn percent_decode(text: &str) -> Option<String> {
    let bytes = text.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'+' => out.push(b' '),
            b'%' => match text
                .get(i + 1..i + 3)
                .and_then(|h| u8::from_str_radix(h, 16).ok())
            {
                Some(b) if text.as_bytes()[i + 1].is_ascii_hexdigit() => {
                    out.push(b);
                    i += 2;
                }
                _ => out.push(b'%'),
            },
            b => out.push(b),
        }
        i += 1;
    }
    String::from_utf8(out).ok()
}

/// `serve.py`'s `/operations` parameter rules.
pub fn discovery(path: &str) -> Option<Discovery> {
    let (base, query) = match path.split_once('?') {
        Some((b, q)) => (b, Some(q)),
        None => (path, None),
    };
    if let Some(id) = base.strip_prefix("/operations/") {
        if query.is_some() || !valid_operation_id(id) {
            return None;
        }
        return Some(Discovery::Detail(id.to_owned()));
    }
    if base != "/operations" {
        return None;
    }
    let mut fields: Vec<(String, String)> = Vec::new();
    if let Some(query) = query.filter(|q| !q.is_empty()) {
        for pair in query.split('&') {
            let (k, v) = pair.split_once('=')?;
            fields.push((percent_decode(k)?, percent_decode(v)?));
        }
    }
    if fields.len() > 4 {
        return None;
    }
    let mut seen = std::collections::BTreeMap::new();
    for (k, v) in fields {
        if !["offset", "limit", "q", "availability"].contains(&k.as_str())
            || seen.insert(k, v).is_some()
        {
            return None;
        }
    }
    let offset = seen.get("offset").map_or("0", String::as_str);
    let limit = seen.get("limit").map_or("10", String::as_str);
    let digits = |s: &str, max: usize| {
        !s.is_empty() && s.len() <= max && s.bytes().all(|b| b.is_ascii_digit())
    };
    if !digits(offset, 9) || !digits(limit, 2) {
        return None;
    }
    let limit: usize = limit.parse().ok()?;
    let q = seen.get("q").cloned().unwrap_or_default();
    let availability = seen.get("availability").cloned();
    if !(1..=50).contains(&limit)
        || q.len() > 256
        || availability
            .as_deref()
            .is_some_and(|a| !["live_direct", "text_only", "unavailable"].contains(&a))
    {
        return None;
    }
    Some(Discovery::List {
        offset: offset.parse().ok()?,
        limit,
        q,
        availability,
    })
}

fn handle(mut stream: TcpStream, service: &Arc<Service>, port: u16) {
    let deadline = Instant::now() + Duration::from_millis(service.limits.ingress_ms);
    let Some(request) = read_head(&mut stream, deadline) else {
        let _ = stream.shutdown(Shutdown::Both);
        return;
    };
    let reply = match request.method.as_str() {
        "GET" => {
            let (status, body) = get(&request, service, port);
            service.encode_response(status, &body)
        }
        "POST" => post(&mut stream, &request, service, port, deadline),
        _ => service.encode_response(405, &failure("unsupported_method_or_route", json!({}))),
    };
    let _ = stream.set_write_timeout(Some(Duration::from_millis(service.limits.ingress_ms)));
    respond(&mut stream, &reply);
    let _ = stream.shutdown(Shutdown::Both);
}

fn get(request: &Request, service: &Arc<Service>, port: u16) -> (u16, Value) {
    if let Err(reply) = private_request(request, port) {
        return reply;
    }
    if request.path == "/health" {
        return service.health();
    }
    if let Err(reply) = tenant(request) {
        return reply;
    }
    if request.path == "/capabilities" {
        return (200, service.capabilities());
    }
    if request.path == "/operations"
        || request.path.starts_with("/operations?")
        || request.path.starts_with("/operations/")
    {
        return match discovery(&request.path) {
            Some(parameters) => service.discover(&parameters),
            None => (400, failure("invalid_discovery_request", json!({}))),
        };
    }
    (404, failure("not_found", json!({})))
}

fn post(
    stream: &mut TcpStream,
    request: &Request,
    service: &Arc<Service>,
    port: u16,
    deadline: Instant,
) -> wire::EncodedReply {
    match read_post(stream, request, service, port, deadline) {
        Ok((tenant, body)) if request.path == "/query" => service.query_encoded(&tenant, &body),
        Ok((tenant, body)) => service.invoke_encoded(&tenant, &body),
        Err((status, body)) => service.encode_response(status, &body),
    }
}

fn read_post(
    stream: &mut TcpStream,
    request: &Request,
    service: &Arc<Service>,
    port: u16,
    deadline: Instant,
) -> Result<(String, Vec<u8>), (u16, Value)> {
    if let Err(reply) = private_request(request, port) {
        return Err(reply);
    }
    let tenant = match tenant(request) {
        Ok(t) => t,
        Err(reply) => return Err(reply),
    };
    if request.path != "/query" && request.path != "/invoke" {
        return Err((404, failure("not_found", json!({}))));
    }
    let lengths = request.all("Content-Length");
    if request.first("Transfer-Encoding").is_some()
        || lengths.len() != 1
        || lengths[0].is_empty()
        || !lengths[0].bytes().all(|b| b.is_ascii_digit())
    {
        return Err((400, failure("invalid_length", json!({}))));
    }
    let media = request
        .first("Content-Type")
        .and_then(|v| v.split(';').next())
        .map(|v| v.trim().to_ascii_lowercase())
        .unwrap_or_else(|| "text/plain".into());
    if media != "application/json" {
        return Err((415, failure("json_required", json!({}))));
    }
    let maximum = service.limits.request_bytes;
    let length: usize = if lengths[0].len() < 20 {
        lengths[0].parse().unwrap_or(usize::MAX)
    } else {
        usize::MAX
    };
    if length > maximum {
        return Err((413, failure("request_too_large", json!({}))));
    }
    let mut body = request.leftover.clone();
    body.truncate(length);
    let mut chunk = vec![0u8; 65536];
    while body.len() < length {
        match read_some(stream, &mut chunk, deadline) {
            Ok(0) => return Err((400, failure("incomplete_body", json!({})))),
            Ok(n) => body.extend_from_slice(&chunk[..n.min(length - body.len())]),
            Err(_) => return Err((408, failure("body_timeout", json!({})))),
        }
    }
    Ok((tenant, body))
}

/// Accept connections until `stop` is set, then wait for handlers to finish.
// Readiness wakes immediately on an arriving connection. This timeout only
// bounds observation of the signal waiter's stop flag while the listener is idle.
const STOP_OBSERVATION_MS: u16 = 100;

fn listener_ready(listener: &TcpListener, timeout_ms: u16) -> std::io::Result<bool> {
    let mut descriptors = [PollFd::new(listener.as_fd(), PollFlags::POLLIN)];
    poll(&mut descriptors, timeout_ms).map_err(std::io::Error::from)?;
    let events = descriptors[0].revents().unwrap_or_else(PollFlags::empty);
    if events.intersects(PollFlags::POLLERR | PollFlags::POLLHUP | PollFlags::POLLNVAL) {
        return Err(std::io::Error::other("listener readiness failed"));
    }
    Ok(events.contains(PollFlags::POLLIN))
}

struct Connections {
    capacity: usize,
    active: Mutex<usize>,
    drained: Condvar,
}

// The closure owns the guard before spawn, so both a failed spawn and a handler
// unwind release the connection count. It never owns the Service or its joins.
struct ConnectionGuard(Arc<Connections>);

impl Connections {
    fn new(capacity: usize) -> Arc<Self> {
        Arc::new(Self {
            capacity,
            active: Mutex::new(0),
            drained: Condvar::new(),
        })
    }

    fn acquire(self: &Arc<Self>) -> Option<ConnectionGuard> {
        let mut active = self.active.lock().unwrap_or_else(|p| p.into_inner());
        if *active >= self.capacity {
            return None;
        }
        *active += 1;
        Some(ConnectionGuard(self.clone()))
    }

    fn drain(&self) {
        let mut active = self.active.lock().unwrap_or_else(|p| p.into_inner());
        while *active > 0 {
            active = self.drained.wait(active).unwrap_or_else(|p| p.into_inner());
        }
    }
}

impl Drop for ConnectionGuard {
    fn drop(&mut self) {
        let mut active = self.0.active.lock().unwrap_or_else(|p| p.into_inner());
        *active -= 1;
        if *active == 0 {
            self.0.drained.notify_all();
        }
    }
}

pub fn serve(
    listener: TcpListener,
    service: Arc<Service>,
    stop: Arc<AtomicBool>,
) -> std::io::Result<()> {
    let port = listener.local_addr()?.port();
    listener.set_nonblocking(true)?;
    let open = Connections::new(service.limits.connections);
    let result = loop {
        if stop.load(Ordering::Acquire) {
            break Ok(());
        }
        match listener_ready(&listener, STOP_OBSERVATION_MS) {
            Ok(false) => continue,
            Ok(true) => {}
            Err(e) if e.kind() == ErrorKind::Interrupted => continue,
            Err(e) => break Err(e),
        }
        // A signal may arrive during readiness waiting. Stop before accepting.
        if stop.load(Ordering::Acquire) {
            break Ok(());
        }
        match listener.accept() {
            Ok((stream, _)) => {
                if let Err(e) = stream.set_nonblocking(false) {
                    break Err(e);
                }
                let Some(connection) = open.acquire() else {
                    drop(stream); // hard cap; no accepted connection queue
                    continue;
                };
                let service = service.clone();
                // Spawn failure drops this closure, stream and guard together.
                // Refuse that connection and keep serving within the same cap.
                let _ = std::thread::Builder::new()
                    .name("oracle-http".into())
                    .spawn(move || {
                        let _connection = connection;
                        handle(stream, &service, port);
                    });
            }
            Err(e)
                if matches!(
                    e.kind(),
                    ErrorKind::WouldBlock | ErrorKind::Interrupted | ErrorKind::ConnectionAborted
                ) => {}
            Err(e) => break Err(e),
        }
    };
    service.stopping.store(true, Ordering::Release);
    drop(listener);
    // In-flight turns retain deadlines and journal ownership. A guard signals
    // their completion even on unwind; no sleep loop delays shutdown drain.
    open.drain();
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn listener_readiness_wakes_before_idle_timeout() {
        let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
        listener.set_nonblocking(true).unwrap();
        let address = listener.local_addr().unwrap();
        let (entered, waiting) = std::sync::mpsc::channel();
        let (reply, ready) = std::sync::mpsc::channel();
        let waiter = std::thread::spawn(move || {
            entered.send(()).unwrap();
            reply.send(listener_ready(&listener, 5000)).unwrap();
        });
        waiting.recv_timeout(Duration::from_secs(2)).unwrap();
        let _connection = TcpStream::connect(address).unwrap();
        // Readiness, rather than the five-second timeout, must finish the wait.
        assert!(ready.recv_timeout(Duration::from_secs(2)).unwrap().unwrap());
        waiter.join().unwrap();
    }

    #[test]
    fn connection_guards_bound_work_and_release_on_unwind_or_unstarted_closure() {
        let connections = Connections::new(1);
        let guard = connections.acquire().unwrap();
        assert!(connections.acquire().is_none());
        // A failed Builder::spawn drops its owned closure without running it.
        let unstarted = move || {
            let _guard = guard;
        };
        drop(unstarted);
        let guard = connections.acquire().unwrap();
        let handler = std::thread::spawn(move || {
            let _guard = guard;
            panic!("handler panic");
        });
        assert!(handler.join().is_err());
        assert_eq!(*connections.active.lock().unwrap(), 0);
        assert!(connections.acquire().is_some());
    }

    #[test]
    fn connection_drain_waits_for_live_handler_guard() {
        let connections = Connections::new(1);
        let guard = connections.acquire().unwrap();
        let draining = connections.clone();
        let (entered, waiting) = std::sync::mpsc::channel();
        let (reply, done) = std::sync::mpsc::channel();
        let supervisor = std::thread::spawn(move || {
            entered.send(()).unwrap();
            draining.drain();
            reply.send(()).unwrap();
        });
        waiting.recv_timeout(Duration::from_secs(2)).unwrap();
        assert!(matches!(
            done.try_recv(),
            Err(std::sync::mpsc::TryRecvError::Empty)
        ));
        drop(guard);
        done.recv_timeout(Duration::from_secs(2)).unwrap();
        supervisor.join().unwrap();
        connections.drain();
    }

    #[test]
    fn idle_http_server_observes_shutdown_without_a_connection() {
        let directory = tempfile::tempdir().unwrap();
        let config = serde_json::from_value(json!({
            "schema": "oracle-host-v1", "journal": directory.path().join("journal.sqlite3")
        }))
        .unwrap();
        let service = Service::open(&config).unwrap();
        let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
        let stop = Arc::new(AtomicBool::new(false));
        let serving = service.clone();
        let stopping = stop.clone();
        let (entered, waiting) = std::sync::mpsc::channel();
        let (reply, stopped) = std::sync::mpsc::channel();
        let server = std::thread::spawn(move || {
            entered.send(()).unwrap();
            reply.send(serve(listener, serving, stopping)).unwrap();
        });
        waiting.recv_timeout(Duration::from_secs(2)).unwrap();
        stop.store(true, Ordering::Release);
        stopped
            .recv_timeout(Duration::from_secs(2))
            .unwrap()
            .unwrap();
        server.join().unwrap();
        assert!(service.stopping.load(Ordering::Acquire));
        service.close();
    }

    #[test]
    fn discovery_parameters_follow_the_reference_rules() {
        assert!(matches!(
            discovery("/operations"),
            Some(Discovery::List {
                offset: 0,
                limit: 10,
                ..
            })
        ));
        assert!(matches!(discovery("/operations?limit=50&q=graph%20query"),
                         Some(Discovery::List { limit: 50, ref q, .. }) if q == "graph query"));
        assert!(discovery("/operations?limit=51").is_none());
        assert!(discovery("/operations?limit=0").is_none());
        assert!(discovery("/operations?offset=1&offset=2").is_none());
        assert!(discovery("/operations?other=1").is_none());
        assert!(discovery("/operations?availability=maybe").is_none());
        assert!(
            matches!(discovery("/operations/graph.query"), Some(Discovery::Detail(ref id)) if id == "graph.query")
        );
        assert!(discovery("/operations/graph.query?x=1").is_none());
        assert!(discovery("/operations/.bad").is_none());
    }
}

#[cfg(test)]
#[path = "http_encoded_tests.rs"]
mod encoded_reply_tests;
