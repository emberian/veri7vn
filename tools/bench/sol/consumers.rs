//! Untrusted same-revision reuse observer. No HTTP, theorem or biological claim.
//! Whole batches are timed, including preparation for both alternatives. Analytic
//! chain temperatures/power and naive both-strand matches are checked afterward.
use serde_json::{json,Value};
use std::{sync::atomic::AtomicBool,time::Instant};
use oracle_science::{thermal::{ThermalInput,ThermalResult,thermal_network},thermal_scenarios::{PreparedThermalNetwork,Scenario}};
use oracle_bio::collection::{CollectionInput,SequenceRecord,SearchInput,SearchResult,SequenceCollection,PreparedSearch};
fn stats(mut times:Vec<f64>)->Value {times.sort_by(f64::total_cmp);json!({"repeats":times.len(),"p50_ms":times[times.len()/2],"p95_ms":times[(times.len()*95).div_ceil(100)-1],"samples_ms":times})}
fn close(a:f64,b:f64){assert!((a-b).abs()<=2e-7*a.abs().max(b.abs()).max(1.),"{a} != {b}");}
fn thermal_check(rows:&[ThermalResult],fresh:&[ThermalResult],n:usize){
 for (s,(a,b)) in rows.iter().zip(fresh).enumerate(){
  let q=(s+1) as f64;let boundary=300.+s as f64;
  assert_eq!(a.nodes.len(),n);assert_eq!(a.outcome,b.outcome);
  for (i,(an,bn)) in a.nodes.iter().zip(&b.nodes).enumerate(){
   close(an.temperature_k.unwrap(),boundary+q*i as f64/2.);close(an.temperature_k.unwrap(),bn.temperature_k.unwrap());
   close(an.outgoing_link_heat_w,if i==0{-q}else if i==n-1{q}else{0.});
   close(an.outgoing_link_heat_w,bn.outgoing_link_heat_w);close(an.applied_heat_w,bn.applied_heat_w);
   close(an.power_balance_residual_w,0.);assert!(an.power_balance_within_tolerance);
   if i==0 {close(an.boundary_exchange_w.unwrap(),-q);close(an.boundary_exchange_w.unwrap(),bn.boundary_exchange_w.unwrap());}
  }
  close(a.conservation.net_external_heat_w,0.);close(a.conservation.total_node_power_residual_w,0.);
  for (x,y) in a.links.iter().zip(&b.links){close(x.candidate_heat_from_to_w,y.candidate_heat_from_to_w);close(x.candidate_heat_from_to_w,-q);}
 }
}
fn thermal()->Value {
 let control=AtomicBool::new(false);let limits=oracle_science::Limits::default();let mut reports=Vec::new();
 for (n,count) in [(16,8),(64,32),(128,8)] {
  let network:ThermalInput=serde_json::from_value(json!({"description":"Supplied analytic equal-conductance chain","assumptions":["steady passive constant conductance; ideal fixed boundary"],"reference_temperature_k":300,"nodes":(0..n).map(|i|if i==0{json!({"id":format!("n{i}"),"applied_heat_w":0,"fixed_temperature_k":300})}else{json!({"id":format!("n{i}"),"applied_heat_w":0})}).collect::<Vec<_>>(),"links":(1..n).map(|i|json!({"from":format!("n{}",i-1),"to":format!("n{i}"),"conductance_w_per_k":2})).collect::<Vec<_>>()})).unwrap();
  let scenarios:Vec<Scenario>=(0..count).map(|s|{let mut loads=vec![0.;n];loads[n-1]=(s+1) as f64;let mut fixed=vec![None;n];fixed[0]=Some(300.+s as f64);Scenario{id:format!("s{s}"),applied_heat_w:loads,fixed_temperature_k:fixed}}).collect();
  let mut prepared_times=Vec::new();let mut solve_times=Vec::new();let mut fresh_times=Vec::new();let mut last=Value::Null;
  for _ in 0..10 {
   let t=Instant::now();let prepared=PreparedThermalNetwork::prepare(&network,&limits,&control,None).unwrap();let prep_ms=t.elapsed().as_secs_f64()*1000.;
   let t=Instant::now();let reused:Vec<_>=scenarios.iter().map(|s|prepared.solve(s,&limits,&control).unwrap()).collect();let solve_ms=t.elapsed().as_secs_f64()*1000.;prepared_times.push(prep_ms+solve_ms);solve_times.push(solve_ms);
   let t=Instant::now();let fresh:Vec<_>=scenarios.iter().map(|s|{let mut input=network.clone();for (i,node) in input.nodes.iter_mut().enumerate(){node.applied_heat_w=s.applied_heat_w[i];node.fixed_temperature_k=s.fixed_temperature_k[i];}thermal_network(&input,&limits,&control).unwrap()}).collect();fresh_times.push(t.elapsed().as_secs_f64()*1000.);
   thermal_check(&reused,&fresh,n);last=json!({"network_identity":prepared.identity(),"nodes_last":reused.last().unwrap().nodes,"conservation_last":reused.last().unwrap().conservation});
  }
  reports.push(json!({"nodes":n,"scenarios":count,"prepared_including_prepare":stats(prepared_times),"prepared_solve_only":stats(solve_times),"fresh_each_scenario":stats(fresh_times),"analytic_and_fresh_agreement":true,"last_evidence":last}));
 }
 json!(reports)
}
fn rc(s:&str)->String{s.bytes().rev().map(|b|match b{b'A'=>'T',b'C'=>'G',b'G'=>'C',b'T'=>'A',_=>panic!("ACGT only")}).collect()}
fn naive(collection:&CollectionInput,patterns:&[SequenceRecord])->Vec<Value>{
 let mut hits=Vec::new();
 for (ri,r) in collection.records.iter().enumerate(){let seq=r.sequence.to_ascii_uppercase();for start in 0..seq.len(){for (pi,p) in patterns.iter().enumerate(){let pseq=p.sequence.to_ascii_uppercase();let reverse=rc(&pseq);let same=reverse==pseq;for (pat,strand) in if same{vec![(&pseq,"both")]}else{vec![(&pseq,"forward"),(&reverse,"reverse")]}{if seq[start..].starts_with(pat.as_str()){hits.push(json!({"record_index":ri,"record_label":r.label,"pattern_index":pi,"pattern_label":p.label,"strand":strand,"start":start,"end":start+pat.len(),"matched_sequence":&seq[start..start+pat.len()]}));}}}}}
 hits
}
fn sequence()->Value{
 let control=AtomicBool::new(false);let mut reports=Vec::new();
 for (records,len,page_size) in [(2,256,32),(8,1024,128)] {
  let collection=CollectionInput{schema:oracle_bio::collection::COLLECTION_SCHEMA.into(),records:(0..records).map(|i|SequenceRecord{label:format!("record{i}"),sequence:if i%2==0{"ACGT".repeat(len/4)}else{"AAATATGC".repeat(len/8)}}).collect()};
  let patterns:Vec<_>=["ACG","CGT","AAA","ATAT"].iter().enumerate().map(|(i,p)|SequenceRecord{label:format!("pattern{i}"),sequence:p.to_string()}).collect();let expected=naive(&collection,&patterns);
  let mut reused_times=Vec::new();let mut fresh_times=Vec::new();let mut last=Value::Null;
  for _ in 0..10 {
   let prepared_run=||{
    let t=Instant::now();let prepared_collection=SequenceCollection::prepare(&collection,&control).unwrap();let prepared=PreparedSearch::prepare(&prepared_collection,&patterns,&control).unwrap();let mut cursor=None;let mut reused:Vec<SearchResult>=Vec::new();
    loop {let page=prepared.page(page_size,cursor.as_ref(),&control).unwrap();cursor=page.next_cursor.clone();let complete=page.complete;reused.push(page);if complete{break;}assert!(reused.len()<10000);}
    (reused,t.elapsed().as_secs_f64()*1000.)
   };
   let fresh_run=||{
    let t=Instant::now();let mut request=SearchInput{collection:collection.clone(),patterns:patterns.clone(),page_size,cursor:None};let mut fresh=Vec::new();
    loop {let page=oracle_bio::collection::search_collection(&request,&control).unwrap();request.cursor=page.next_cursor.clone();let complete=page.complete;fresh.push(page);if complete{break;}assert!(fresh.len()<10000);}
    (fresh,t.elapsed().as_secs_f64()*1000.)
   };
   let (reused,fresh,reused_ms,fresh_ms)=if std::env::var_os("SOL_FRESH_FIRST").is_some(){let(fresh,ft)=fresh_run();let(reused,rt)=prepared_run();(reused,fresh,rt,ft)}else{let(reused,rt)=prepared_run();let(fresh,ft)=fresh_run();(reused,fresh,rt,ft)};
   reused_times.push(reused_ms);fresh_times.push(fresh_ms);
   let ra=serde_json::to_value(&reused).unwrap();let rb=serde_json::to_value(&fresh).unwrap();assert_eq!(ra,rb,"Complete pages, identities, cursors, work and hits must agree");
   let flattened:Vec<Value>=reused.iter().flat_map(|page|page.hits.iter().map(|hit|serde_json::to_value(hit).unwrap())).collect();assert_eq!(flattened,expected,"Independent naive original-coordinate both-strand search");
   last=json!({"pages":reused.len(),"hits":expected.len(),"collection_sha256":reused[0].collection_sha256,"request_sha256":reused[0].request_sha256,"complete":reused.last().unwrap().complete});
  }
  reports.push(json!({"records":records,"record_bases":len,"patterns":patterns.len(),"page_size":page_size,"prepared_including_prepare_and_all_pages":stats(reused_times),"repeated_stateless_all_pages":stats(fresh_times),"order":if std::env::var_os("SOL_FRESH_FIRST").is_some(){"fresh_first"}else{"prepared_first"},"full_page_and_naive_agreement":true,"evidence":last}));
 }
 json!(reports)
}
fn main(){println!("{}",json!({"schema":"sol-consumer-reuse-v1","scope":"same candidate source, no HTTP; whole-batch timing; validation outside timed interval","thermal":thermal(),"sequence":sequence()}));}
