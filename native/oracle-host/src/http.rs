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
use serde_json::{json, Value};
use std::io::{ErrorKind, Read, Write};
use std::net::{Shutdown, TcpListener, TcpStream};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::Arc;
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

fn respond(stream: &mut TcpStream, status: u16, body: &Value) {
    let payload = wire::encode(body);
    let head = format!(
        "HTTP/1.0 {status} {}\r\nServer: oracle-host\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nCache-Control: no-store\r\n\r\n",
        reason(status),
        payload.len()
    );
    let _ = stream
        .write_all(head.as_bytes())
        .and_then(|_| stream.write_all(&payload));
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
        "GET" => get(&request, service, port),
        "POST" => post(&mut stream, &request, service, port, deadline),
        _ => (405, failure("unsupported_method_or_route", json!({}))),
    };
    let _ = stream.set_write_timeout(Some(Duration::from_millis(service.limits.ingress_ms)));
    respond(&mut stream, reply.0, &reply.1);
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
) -> (u16, Value) {
    if let Err(reply) = private_request(request, port) {
        return reply;
    }
    let tenant = match tenant(request) {
        Ok(t) => t,
        Err(reply) => return reply,
    };
    if request.path != "/query" && request.path != "/invoke" {
        return (404, failure("not_found", json!({})));
    }
    let lengths = request.all("Content-Length");
    if request.first("Transfer-Encoding").is_some()
        || lengths.len() != 1
        || lengths[0].is_empty()
        || !lengths[0].bytes().all(|b| b.is_ascii_digit())
    {
        return (400, failure("invalid_length", json!({})));
    }
    let media = request
        .first("Content-Type")
        .and_then(|v| v.split(';').next())
        .map(|v| v.trim().to_ascii_lowercase())
        .unwrap_or_else(|| "text/plain".into());
    if media != "application/json" {
        return (415, failure("json_required", json!({})));
    }
    let maximum = service.limits.request_bytes;
    let length: usize = if lengths[0].len() < 20 {
        lengths[0].parse().unwrap_or(usize::MAX)
    } else {
        usize::MAX
    };
    if length > maximum {
        return (413, failure("request_too_large", json!({})));
    }
    let mut body = request.leftover.clone();
    body.truncate(length);
    let mut chunk = vec![0u8; 65536];
    while body.len() < length {
        match read_some(stream, &mut chunk, deadline) {
            Ok(0) => return (400, failure("incomplete_body", json!({}))),
            Ok(n) => body.extend_from_slice(&chunk[..n.min(length - body.len())]),
            Err(_) => return (408, failure("body_timeout", json!({}))),
        }
    }
    if request.path == "/query" {
        service.query(&tenant, &body)
    } else {
        service.invoke(&tenant, &body)
    }
}

/// Accept connections until `stop` is set, then wait for handlers to finish.
pub fn serve(
    listener: TcpListener,
    service: Arc<Service>,
    stop: Arc<AtomicBool>,
) -> std::io::Result<()> {
    let port = listener.local_addr()?.port();
    listener.set_nonblocking(true)?;
    let open = Arc::new(AtomicUsize::new(0));
    while !stop.load(Ordering::Acquire) {
        match listener.accept() {
            Ok((stream, _)) => {
                let _ = stream.set_nonblocking(false);
                if open.fetch_add(1, Ordering::AcqRel) >= service.limits.connections {
                    open.fetch_sub(1, Ordering::AcqRel);
                    drop(stream); // hard cap on open connections; no unbounded threads
                    continue;
                }
                let service = service.clone();
                let open = open.clone();
                std::thread::spawn(move || {
                    handle(stream, &service, port);
                    open.fetch_sub(1, Ordering::AcqRel);
                });
            }
            Err(e) if e.kind() == ErrorKind::WouldBlock => {
                std::thread::sleep(Duration::from_millis(20))
            }
            Err(_) => std::thread::sleep(Duration::from_millis(20)),
        }
    }
    service.stopping.store(true, Ordering::Release);
    drop(listener);
    // In-flight turns keep their own deadlines; let them answer and journal.
    while open.load(Ordering::Acquire) > 0 {
        std::thread::sleep(Duration::from_millis(20));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

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
