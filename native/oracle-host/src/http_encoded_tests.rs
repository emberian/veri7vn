use super::*;
use serde::Serialize;
use std::sync::atomic::AtomicUsize;

#[test]
fn http_writes_one_preencoded_body_without_serializing_it_again() {
    struct Counted<'a>(&'a AtomicUsize);
    impl Serialize for Counted<'_> {
        fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
            self.0.fetch_add(1, Ordering::SeqCst);
            "quote \"; snowman ☃".serialize(serializer)
        }
    }
    let serializations = AtomicUsize::new(0);
    let reply = wire::EncodedReply::encode(200, &Counted(&serializations), 1024).unwrap();
    let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
    let mut client = TcpStream::connect(listener.local_addr().unwrap()).unwrap();
    client
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let (mut server, _) = listener.accept().unwrap();
    respond(&mut server, &reply);
    server.shutdown(Shutdown::Both).unwrap();
    let mut received = Vec::new();
    client.read_to_end(&mut received).unwrap();
    let split = received.windows(4).position(|s| s == b"\r\n\r\n").unwrap();
    let headers = std::str::from_utf8(&received[..split]).unwrap();
    assert!(headers.contains(&format!("Content-Length: {}", reply.body().len())));
    assert_eq!(&received[split + 4..], reply.body());
    assert_eq!(serializations.load(Ordering::SeqCst), 1);
}

#[test]
fn oversized_http_route_emits_only_bounded_refusal_not_a_response_prefix() {
    let directory = tempfile::tempdir().unwrap();
    let config = serde_json::from_value(json!({
        "schema":"oracle-host-v1","journal":directory.path().join("journal.sqlite3"),
        "limits":{"reply_bytes":1024}
    }))
    .unwrap();
    let service = Service::open(&config).unwrap();
    assert!(wire::encode(&service.capabilities()).len() > 1024);
    let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
    let address = listener.local_addr().unwrap();
    let mut client = TcpStream::connect(address).unwrap();
    client
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let (server, _) = listener.accept().unwrap();
    let serving = service.clone();
    let handler = std::thread::spawn(move || handle(server, &serving, address.port()));
    write!(
        client,
        "GET /capabilities HTTP/1.0\r\nHost: 127.0.0.1:{}\r\n{}: {}\r\n\r\n",
        address.port(),
        TENANT_HEADER,
        "a".repeat(64)
    )
    .unwrap();
    let mut received = Vec::new();
    client.read_to_end(&mut received).unwrap();
    handler.join().unwrap();
    let split = received.windows(4).position(|s| s == b"\r\n\r\n").unwrap();
    let headers = std::str::from_utf8(&received[..split]).unwrap();
    let body = &received[split + 4..];
    assert!(headers.starts_with("HTTP/1.0 502 "));
    assert!(headers.contains(&format!("Content-Length: {}", body.len())));
    assert!(body.len() <= 1024);
    let value = wire::parse(body).unwrap();
    assert_eq!(value["error"], "reply_too_large");
    assert!(value.get("providers").is_none());
    service.close();
}
