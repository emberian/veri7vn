//! Untrusted next-cycle comparison; no production counters or theorem claims.
//! Baseline Value+final encode and post EncodedReply are explicitly different
//! implementations of the SAME encoded service boundary. JSON inspection,
//! independent checks, probe collection and output drop are outside timed calls.
use oracle_host::{config::Config,service::Service,wire};
use oracle_runtime_core::{Image,Limits,Budget,Cancellation,ReaderBuildOptions,build_image_with_reader};
use oracle_runtime_core::grammar::{ReaderExport,ReaderPolicy,TemplateRow,READER_FORMAT,READER_VERSION};
use serde_json::{json,Value};
use std::{collections::BTreeMap,path::{Path,PathBuf},sync::Arc,time::Instant};
const CALLS:usize=50;const WARM:usize=5;const READS:usize=10;
const TENANT:&str="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
enum Produced {
 #[cfg(feature="encoded")] Encoded(wire::EncodedReply),
 #[cfg(not(feature="encoded"))] ValueThenEncoded(u16,Vec<u8>),
}
impl Produced {
 fn status(&self)->u16{match self{#[cfg(feature="encoded")] Self::Encoded(r)=>r.status(),#[cfg(not(feature="encoded"))] Self::ValueThenEncoded(s,_)=>*s}}
 fn body(&self)->&[u8]{match self{#[cfg(feature="encoded")] Self::Encoded(r)=>r.body(),#[cfg(not(feature="encoded"))] Self::ValueThenEncoded(_,b)=>b}}
}
fn produce(service:&Arc<Service>,raw:&[u8])->Produced{
 #[cfg(feature="encoded")] {Produced::Encoded(service.invoke_encoded(TENANT,raw))}
 #[cfg(not(feature="encoded"))] {let(status,value)=service.invoke(TENANT,raw);Produced::ValueThenEncoded(status,wire::encode(&value))}
}
fn stats(mut samples:Vec<f64>)->Value{samples.sort_by(f64::total_cmp);json!({"count":samples.len(),"min_us":samples[0],"p50_us":samples[samples.len()/2],"p95_us":samples[(samples.len()*95).div_ceil(100)-1],"samples_us":samples})}
fn args_cases()->Vec<(String,String,Value)>{
 let mut cases=vec![
  ("lp_interval".into(),"reasoning.exact_linear_feasibility".into(),json!({"variables":["x"],"rows":[{"id":"low","coefficients":["-1"],"bound":"-1/3"},{"id":"high","coefficients":["1"],"bound":"1/2"}],"objective":null})),
  ("glm_binomial".into(),"statistics.events_exposure".into(),json!({"family":"grouped_binomial_logit","method":"maximum_likelihood","features":[[-1],[1]],"intercept":true,"successes":[2,8],"trials":[10,10],"uncertainty":"model_based_wald","model":{"description":"Manufactured stress versus failure example","predictor_names":["stress"],"predictor_units":["1"],"independent_unit":"individual independent trial","grouping":"ten independent trials with identical supplied stress per row","assumptions":["Independent binomial groups; prespecified correct logit-linear probability; fixed design; usual asymptotic regularity"]},"predictions":[{"features":[0],"trials":20}]})),
  ("graph_small".into(),"graph.minimum_spanning_forest".into(),json!({"vertices":3,"edges":[[0,1,4],[1,2,-2],[0,2,9]]})),
  ("graph_retained_chain".into(),"graph.minimum_spanning_forest".into(),json!({"vertices":1000,"edges":(0..999).map(|i|json!([i,i+1,1])).collect::<Vec<_>>()})),
 ];
 let mut edges=Vec::new();for block in 0..128{let a=4*block;for(u,v,w)in[(0,1,-7),(0,1,-3),(1,2,1),(0,2,6),(2,3,2),(0,3,8),(0,0,-100),(3,1,6),(1,2,1)]{edges.push(json!([a+u,a+v,w]));}}
 cases.push(("graph_multigraph".into(),"graph.minimum_spanning_forest".into(),json!({"vertices":512,"edges":edges})));cases
}
fn verify(name:&str,body:&Value){
 assert_eq!(body["reply"]["status"],"answered","{name}: {body}");let r=&body["reply"]["result"];
 match name{
  "graph_small"=>{assert_eq!(r["total_weight"],"2");assert_eq!(r["components"],1);assert_eq!(r["edge_ids"],json!([0,1]));},
  "graph_retained_chain"=>{assert_eq!(r["total_weight"],"999");assert_eq!(r["components"],1);assert_eq!(r["edge_ids"],json!((0..999).collect::<Vec<_>>()));},
  "graph_multigraph"=>{assert_eq!(r["total_weight"],"-512");assert_eq!(r["components"],128);assert_eq!(r["edge_ids"],json!((0..128).flat_map(|i|[9*i,9*i+2,9*i+4]).collect::<Vec<_>>()));},
  "lp_interval"=>{assert_eq!(r["status"],"feasible");let p=r["certificate"]["point"][0].as_str().unwrap();let(n,d)=p.split_once('/').unwrap_or((p,"1"));let(n,d)=(n.parse::<i128>().unwrap(),d.parse::<i128>().unwrap());assert!(d>0&&3*n>=d&&2*n<=d);},
  "glm_binomial"=>{assert_eq!(r["status"],"finite_mle_converged");let b=r["coefficient_candidate"].as_array().unwrap();assert!(b[0].as_f64().unwrap().abs()<1e-7);assert!((b[1].as_f64().unwrap()-4f64.ln()).abs()<1e-7);assert!(!r["finite_mle_certificate"].is_null());},
  _=>panic!("undeclared fixture"),
 }
}
fn st(function:&str,dependencies:&[usize],inputs:Value)->Value{json!({"function":function,"dependencies":dependencies,"inputs":inputs})}
fn row(family:&str,template:&str,skeleton:Value)->TemplateRow{TemplateRow{family:family.into(),level:0,template:template.into(),skeleton,support:3}}
fn fixture(root:&Path)->Value{
 std::fs::create_dir(root).expect("new owned fixture directory");let source=root.join("kb.json");let image=root.join("tiny.sqlite");
 let kb=json!({"concepts":{"P":{"name":"person","instanceOf":[]},"O":{"name":"organisation","instanceOf":[]}},"entities":{
 "L":{"name":"Library","instanceOf":["O"],"attributes":[],"relations":[]},"Y":{"name":"York","instanceOf":[],"attributes":[],"relations":[]},
 "A":{"name":"Alice","instanceOf":["P"],"attributes":[],"relations":[{"predicate":"employer","object":"L","direction":"forward","qualifiers":{}},{"predicate":"resident of","object":"Y","direction":"forward","qualifiers":{"start":[{"type":"year","value":2001}]}}]},
 "B":{"name":"Bob","instanceOf":["P"],"attributes":[],"relations":[{"predicate":"employer","object":"L","direction":"forward","qualifiers":{}},{"predicate":"resident of","object":"Y","direction":"forward","qualifiers":{"start":[{"type":"year","value":1999}]}}]}}});
 std::fs::write(&source,kb.to_string()).unwrap();let kb_sha=oracle_host::config::sha256_file(&source).unwrap();
 let templates=vec![
 row("segment","C1",json!({"role":"filter","steps":[st("FilterConcept",&[],json!([["@","C",1,""]]))]})),
 row("segment","in E1",json!({"role":"source","steps":[st("Find",&[],json!([["@","E",1,""]])),st("Relate",&[],json!(["resident of","backward"]))]})),
 row("outer","how many X1",json!([st("@X",&[],json!([1])),st("Count",&[0],json!([]))])),
 row("fragment","C1 employing X1",json!([st("@X",&[],json!([1])),st("Relate",&[0],json!(["employer","forward"])),st("FilterConcept",&[1],json!([["@","C",1,""]]))]))];
 let reader=ReaderExport{format:READER_FORMAT.into(),version:READER_VERSION,metadata:BTreeMap::from([("normalization".into(),json!("reader7_possessive")),("kb_sha256".into(),json!(kb_sha))]),policy:ReaderPolicy::default(),templates,forms:vec![],shapes:vec![],aliases:vec![],words:vec![]};
 let receipt=build_image_with_reader(&source,&image,1_000_000,100_000,ReaderBuildOptions{reader:Some(&reader),..Default::default()}).unwrap();
 json!({"path":image,"image_sha256":receipt.image_sha256,"source_sha256":kb_sha,"question":"How many organisations employing persons in York?","independent_answer":"1","truth":"Alice and Bob reside in York and both work for Library; exactly one supplied organisation."})
}
fn reader_case(name:&str,path:&Path,sha:&str,question:&str,expected:Option<&str>)->Value{
 let mut limits=Limits::default();limits.timeout_ms=1000;let image=Image::open(path,sha,limits.clone()).unwrap();
 let mut warmup_errors=Vec::new();for _ in 0..WARM{match image.read_whole("bench",question,Cancellation::default()){Ok(r)=>{std::hint::black_box(r);},Err(e)=>warmup_errors.push(e.to_string())}}
 let mut samples=Vec::new();let mut errors=Vec::new();let mut last=None;
 for _ in 0..READS{let budget=Budget::new(&limits,Cancellation::default()).unwrap();let t=Instant::now();let result=image.read_whole_with_budget("bench",question,&budget);let elapsed=t.elapsed().as_secs_f64()*1e6;samples.push(elapsed);match result{Ok(text)=>{last=Some(text);},Err(e)=>errors.push(e.to_string())}}
 let parsed:Option<Value>=last.map(|s|serde_json::from_str(&s).unwrap());if let Some(answer)=expected{assert!(errors.is_empty()&&warmup_errors.is_empty());assert_eq!(parsed.as_ref().unwrap()["status"],"answered");assert_eq!(parsed.as_ref().unwrap()["answer"],answer);
  let readings=parsed.as_ref().unwrap()["readings"].as_array().unwrap();assert!(!readings.is_empty());
  for reading in readings{assert_eq!(reading["result"]["entities"],json!(["L"]),"A count of one must refer to Library, not York");let program=reading["program"].as_array().unwrap();assert_eq!(program.len(),6);assert_eq!(program[3]["function"],"Relate");assert_eq!(program[3]["dependencies"],json!([2]));assert_eq!(program[4]["function"],"FilterConcept");assert_eq!(program[4]["dependencies"],json!([3]));assert_eq!(program[5]["function"],"Count");assert_eq!(program[5]["dependencies"],json!([4]));}
 }
 // Structural diagnostics are collected by ONE separate untimed real read.
 oracle_runtime_core::reader::probe::enable();let diagnostic=image.read_whole("bench",question,Cancellation::default());let records=oracle_runtime_core::reader::probe::take();oracle_runtime_core::reader::probe::disable();
 assert!(diagnostic.is_ok(),"untimed structural read failed");assert!(!records.is_empty(),"missing actual-reader diagnostic record");
 let snapshots:Vec<Value>=records.iter().map(|r|{
  #[allow(unused_mut)] let mut value=json!({"matched":r.matched,"compiled_plans":r.compiled_plans,"execution_cache_hits":r.execution_cache_hits,"projection_hydrations":r.projection_hydrations,"unique_outcomes":r.unique_outcomes,"wire_bytes":r.wire_bytes,"retained_live":r.retained_live,"retained_peak":r.retained_peak});
  #[cfg(feature="packed_probe")] {
   assert_eq!(r.fragment_materializations,0,"fragment viability restored flat syntax");
   let fields=json!({"fragment_checks":r.fragment_checks,"whole_checks":r.whole_checks,"composed_checks":r.composed_checks,"complete_checks":r.complete_checks,"unique_operations":r.unique_operations,"syntax_specs":r.syntax_specs,"validation_failures":r.validation_failures,"root_cache_hits":r.root_cache_hits,"rejected_cache_hits":r.rejected_cache_hits,"resident_roots":r.resident_roots,"diagnostic_materializations":r.diagnostic_materializations,"fragment_materializations":r.fragment_materializations});
   value.as_object_mut().unwrap().extend(fields.as_object().unwrap().clone());
  }
  value
 }).collect();
 json!({"name":name,"image_sha256":sha,"timing":stats(samples),"errors":errors,"warmup_errors":warmup_errors,"last_reply":parsed,"untimed_diagnostic_error":diagnostic.err().map(|e|e.to_string()),"structural_probe":snapshots,"compiled_plans_meaning":if cfg!(feature="packed_probe"){"successful checked roots"}else{"legacy full Program compile aggregate"}})
}
fn measure(args:&[String])->Value{
 assert_eq!(args.len(),7,"measure RUN_DIR TINY_IMAGE TINY_SHA LARGE_IMAGE LARGE_SHA");let root=PathBuf::from(&args[2]);std::fs::create_dir(&root).expect("new owned run directory");let root=root.canonicalize().unwrap();
 let cfg:Config=serde_json::from_value(json!({"schema":"oracle-host-v1","port":0,"journal":root.join("journal.sqlite3"),"limits":{"capacity":4,"invoke_ms":30000},"pure":{"profiles":["reasoning","statistics"]}})).unwrap();let service=Service::open(&cfg).unwrap();let mut rows=Vec::new();
 for(name,operation,arguments)in args_cases(){let raw=serde_json::to_vec(&json!({"request_id":"bench","conversation_id":"bench","operation_id":operation,"arguments":arguments})).unwrap();let first=produce(&service,&raw);assert_eq!(first.status(),200);verify(&name,&serde_json::from_slice(first.body()).unwrap());drop(first);
  for _ in 0..WARM{drop(produce(&service,&raw));}let mut samples=Vec::new();let mut lengths=Vec::new();let mut statuses=Vec::new();let mut last=Vec::new();
  for i in 0..CALLS{let t=Instant::now();let result=produce(&service,&raw);let us=t.elapsed().as_secs_f64()*1e6;samples.push(us);statuses.push(result.status());lengths.push(result.body().len());std::hint::black_box(result.body());if i+1==CALLS{last=result.body().to_vec();}drop(result);}
  let last_json:Value=serde_json::from_slice(&last).unwrap();assert!(statuses.iter().all(|s|*s==200),"nonaccepted work must not become a speed result");verify(&name,&last_json);rows.push(json!({"name":name,"operation":operation,"request_bytes":raw.len(),"request_sha256":oracle_host::config::sha256_bytes(&raw),"reply_encoded_bytes":lengths,"statuses":statuses,"timing":stats(samples),"last_reply":last_json}));}
 service.close();let readers=vec![reader_case("tiny_composed",Path::new(&args[3]),&args[4],"How many organisations employing persons in York?",Some("1")),reader_case("retained_composed",Path::new(&args[5]),&args[6],"Which city whose official website is http://www.saskatoon.ca/ whose population is 222189?",None)];
 json!({"schema":"sol-next-cycle-v1","boundary":if cfg!(feature="encoded"){"invoke_encoded owned encoded reply; no compatibility decode"}else{"invoke Value then wire::encode, matching baseline HTTP boundary"},"calls_per_case":CALLS,"warmups_per_case":WARM,"reader_calls_per_case":READS,"service":rows,"reader":readers,"probe_scope":"Release Debug snapshot is descriptive; origin-aware assertions come from separate cfg(test) structural artifact, outside timing."})
}
fn main(){let args:Vec<String>=std::env::args().collect();let out=match args.get(1).map(String::as_str){Some("fixture")=>{assert_eq!(args.len(),3);fixture(Path::new(&args[2]))},Some("measure")=>measure(&args),_=>panic!("fixture NEW_DIR | measure NEW_RUN_DIR TINY_IMAGE TINY_SHA LARGE_IMAGE LARGE_SHA")};println!("{}",out);}
