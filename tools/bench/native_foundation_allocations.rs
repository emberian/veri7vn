//! Untrusted allocation microbenchmark, NOT HTTP or the full host pipeline.
//! Counts Rust global allocator calls/allocated bytes (including realloc new sizes),
//! not live bytes, retained bytes, C malloc, OS mappings, or whole-process RSS.
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use serde_json::Value;
struct Count;
static CALLS: AtomicU64 = AtomicU64::new(0);
static BYTES: AtomicU64 = AtomicU64::new(0);
unsafe impl GlobalAlloc for Count {
    unsafe fn alloc(&self,l:Layout)->*mut u8 { CALLS.fetch_add(1,Ordering::Relaxed);BYTES.fetch_add(l.size() as u64,Ordering::Relaxed);System.alloc(l) }
    unsafe fn alloc_zeroed(&self,l:Layout)->*mut u8 { CALLS.fetch_add(1,Ordering::Relaxed);BYTES.fetch_add(l.size() as u64,Ordering::Relaxed);System.alloc_zeroed(l) }
    unsafe fn realloc(&self,p:*mut u8,l:Layout,n:usize)->*mut u8 { CALLS.fetch_add(1,Ordering::Relaxed);BYTES.fetch_add(n as u64,Ordering::Relaxed);System.realloc(p,l,n) }
    unsafe fn dealloc(&self,p:*mut u8,l:Layout){System.dealloc(p,l)}
}
#[global_allocator] static ALLOC:Count=Count;
fn run(args:&Value,typed:bool)->Value {
    let cancel=AtomicBool::new(false);let limits=oracle_science::Limits::default();
    if typed {
        let input=serde_json::from_value(args.clone()).unwrap();
        let output=oracle_science::linear(&input,oracle_science::Operation::SolveLinear,&limits,&cancel).unwrap();
        serde_json::to_value(output).unwrap()
    } else {
        let envelope=serde_json::json!({"operation":"science.solve_linear","arguments":args});
        let text=serde_json::to_string(&envelope).unwrap();
        let reply=oracle_science::call(&text,&limits,&cancel).unwrap();
        serde_json::from_str(&reply).unwrap()
    }
}
fn main(){
    let fixtures:Value=serde_json::from_str(&std::fs::read_to_string(std::env::args().nth(1).unwrap()).unwrap()).unwrap();
    let mut results=Vec::new();
    for fixture in fixtures.as_array().unwrap().iter().filter(|f|f["profile"]=="science" && f["name"]!="science-refusal") {
        let args=&fixture["arguments"];
        let expected=run(args,false);assert_eq!(expected,run(args,true));
        for typed in [false,true] {
            for _ in 0..5 {std::hint::black_box(run(args,typed));}
            CALLS.store(0,Ordering::Relaxed);BYTES.store(0,Ordering::Relaxed);
            let start=std::time::Instant::now();
            for _ in 0..100 {std::hint::black_box(run(args,typed));}
            let elapsed=start.elapsed().as_secs_f64();
            let calls=CALLS.load(Ordering::Relaxed);let bytes=BYTES.load(Ordering::Relaxed);
            results.push(serde_json::json!({"name":fixture["name"],"typed":typed,"repeats":100,"alloc_calls_per_call":calls as f64/100.0,"allocated_bytes_per_call":bytes as f64/100.0,"elapsed_seconds":elapsed,"reply_equal":true}));
        }
    }
    println!("{}",serde_json::to_string_pretty(&results).unwrap());
}
