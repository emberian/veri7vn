//! Untrusted direct reader observer; same supplied image/questions for both
//! versions. Candidate counters are explicit reservation units, never RSS.
use oracle_runtime_core::{Budget,Cancellation,Image,Limits};
use serde_json::{json,Value};
use std::{path::Path,time::Instant};
fn main(){
 let args:Vec<String>=std::env::args().collect();let image=&args[1];let digest=&args[2];
 let fixtures:Value=serde_json::from_str(&std::fs::read_to_string(&args[3]).unwrap()).unwrap();
 let timeout_ms=args.get(4).map(|x|x.parse::<u64>().unwrap()).unwrap_or(1000);let repeats=args.get(5).map(|x|x.parse::<usize>().unwrap()).unwrap_or(10);assert!(repeats>0);
 let mut limits=Limits::default();limits.timeout_ms=timeout_ms;
 let resource=Image::open(Path::new(image),digest,limits.clone()).unwrap();
 let mut results=Vec::new();
 for f in fixtures.as_array().unwrap().iter().filter(|f|f["profile"]=="reader") {
  let q=f["arguments"]["question"].as_str().unwrap();
  let mut warmups=Vec::new();for _ in 0..3 {warmups.push(match resource.read_whole("bench",q,Cancellation::default()){Ok(text)=>json!({"reply":serde_json::from_str::<Value>(&text).unwrap()}),Err(e)=>json!({"error":e.to_string()})});}
  let mut samples=Vec::new();let mut replies=Vec::new();let mut probes:Vec<Value>=Vec::new();
  for _ in 0..repeats {
   let budget=Budget::new(&limits,Cancellation::default()).unwrap();
   #[cfg(feature="candidate")] oracle_runtime_core::reader::probe::enable();
   let t=Instant::now();let result=resource.read_whole_with_budget("bench",q,&budget);samples.push(t.elapsed().as_nanos());
   replies.push(match result {Ok(text)=>json!({"reply":serde_json::from_str::<Value>(&text).unwrap()}),Err(e)=>json!({"error":e.to_string()})});
   #[cfg(feature="candidate")] {
    let records=oracle_runtime_core::reader::probe::take();oracle_runtime_core::reader::probe::disable();let m=budget.memory().snapshot();
    probes.push(json!({"outer_live_after":m.live,"outer_peak":m.peak,"outer_limit":m.limit,"records":records.iter().map(|r|json!({"matched":r.matched,"compiled_plans":r.compiled_plans,"execution_cache_hits":r.execution_cache_hits,"projection_hydrations":r.projection_hydrations,"unique_outcomes":r.unique_outcomes,"wire_bytes":r.wire_bytes,"retained_live":r.retained_live,"retained_peak":r.retained_peak})).collect::<Vec<_>>()}));
   }
  }
  samples.sort_unstable();results.push(json!({"name":f["name"],"count":repeats,"timeout_ms":timeout_ms,"p50_ms":samples[repeats/2] as f64/1e6,"p95_ms":samples[(repeats*95).div_ceil(100)-1] as f64/1e6,"replies":replies,"warmups":warmups,"probes":probes}));
 }
 println!("{}",json!({"schema":"sol-direct-reader-v1","image_sha256":digest,"workloads":results}));
}
