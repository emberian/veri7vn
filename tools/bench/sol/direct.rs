//! Untrusted direct Service observer. Excludes TCP/HTTP accept/ingress/response
//! encoding, but includes request envelope parsing, admission, typed provider,
//! invocation scheduling, interpretation and response Value construction.
use oracle_host::{config::Config, service::Service};
use serde_json::{json,Value};
use std::{path::PathBuf,time::Instant};
fn main(){
 let root=PathBuf::from(std::env::args().nth(1).expect("owned run directory"));
 std::fs::create_dir_all(&root).unwrap();let root=root.canonicalize().unwrap();
 let cfg:Config=serde_json::from_value(json!({"schema":"oracle-host-v1","port":0,"journal":root.join("journal.sqlite3"),"limits":{"capacity":4,"invoke_ms":30000},"pure":{"profiles":["reasoning"]}})).unwrap();
 let started=Instant::now();let service=Service::open(&cfg).unwrap();let open_us=started.elapsed().as_micros();
 let mut rows=Vec::new();
 for (name,vertices) in [("small",3usize),("large",1000)] {
  let edges:Vec<Value>=(0..vertices-1).map(|i|json!([i,i+1,1])).collect();
  let bytes=serde_json::to_vec(&json!({"request_id":"bench","conversation_id":"bench","operation_id":"graph.minimum_spanning_forest","arguments":{"vertices":vertices,"edges":edges}})).unwrap();
  for _ in 0..20 {let (status,r)=service.invoke(&"a".repeat(64),&bytes);assert_eq!(status,200,"{r}");assert_eq!(r["reply"]["status"],"answered");}
  let tenant="a".repeat(64);let mut samples=Vec::new();let mut output=Value::Null;let start=Instant::now();
  for _ in 0..1000 {let t=Instant::now();let (status,r)=service.invoke(&tenant,&bytes);samples.push(t.elapsed().as_nanos());assert_eq!(status,200,"{r}");assert_eq!(r["reply"]["status"],"answered");output=r;}
  let elapsed=start.elapsed().as_secs_f64();samples.sort_unstable();
  rows.push(json!({"name":name,"count":samples.len(),"p50_us":samples[500] as f64/1000.,"p95_us":samples[949] as f64/1000.,"elapsed_s":elapsed,"answered_per_s":1000./elapsed,"last_reply":output}));
 }
 service.close();println!("{}",json!({"schema":"sol-direct-service-v1","open_us":open_us,"workloads":rows,"health_after_close":service.health()}));
}
