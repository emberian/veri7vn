//! Read one original-row minimization Problem from stdin and emit its certificate.
use std::io::Read;
fn main() -> Result<(),Box<dyn std::error::Error>> {
 let mut text=String::new();std::io::stdin().take(1_048_577).read_to_string(&mut text)?;
 if text.len()>1_048_576 {return Err("input exceeds example limit".into());}
 let p:oracle_reasoning::exact_lp::Problem=serde_json::from_str(&text)?;
 let out=oracle_reasoning::lp_optimize::optimize(&p,&Default::default())?;
 println!("{}",serde_json::to_string(&out)?);Ok(())
}
