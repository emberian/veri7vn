use oracle_reasoning::{exact_lp::{self, Certificate, Problem, Row}, lp_optimize::{self, Limits}};
use num_rational::BigRational as Q;
use num_traits::{Zero, One};
fn texts(xs: &[&str]) -> Vec<String> { xs.iter().map(|s|s.to_string()).collect() }
fn problem(c:&[&str], rows:&[(&[&str],&str)]) -> Problem {
 Problem {variables:(0..c.len()).map(|i|format!("x{i}")).collect(), objective:Some(texts(c)),
 rows:rows.iter().enumerate().map(|(i,(a,b))|Row {id:i.to_string(),coefficients:texts(a),bound:b.to_string()}).collect()}
}
fn objective(p:&Problem,c:&Certificate)->Q {
 let Certificate::Optimal {point,..}=c else {panic!("not optimal")};
 p.objective.as_ref().unwrap().iter().zip(point).map(|(a,x)|a.parse::<Q>().unwrap()*x.parse::<Q>().unwrap()).sum()
}
fn solve(p:&Problem,expected:&str)->Certificate {
 let out=lp_optimize::optimize(p,&Limits::default()).unwrap();
 assert_eq!(out.status,expected,"{p:?}: {:?}",out.reason);
 let cert=out.certificate.unwrap();
 assert_eq!(exact_lp::check_certificate(p,&cert,&exact_lp::Limits::default()).unwrap(),expected);
 cert
}
#[test]
fn analytic_optimum_and_original_row_mutations() {
 let p=problem(&["2","1"],&[(&["-1","-1"],"-3"),(&["-1","0"],"0"),(&["0","-1"],"0"),(&["0","1"],"2")]);
 let cert=solve(&p,"optimal");assert_eq!(objective(&p,&cert),Q::from_integer(4.into()));
 let mut changed=p.clone();changed.rows[0].bound="-4".into();assert!(exact_lp::check_certificate(&changed,&cert,&exact_lp::Limits::default()).is_err());
 let mut changed=p.clone();changed.objective=Some(texts(&["3","1"]));assert!(exact_lp::check_certificate(&changed,&cert,&exact_lp::Limits::default()).is_err());
 if let Certificate::Optimal {point,multipliers}=cert {
  let mut bad=point.clone();bad[0]="-1/2".into();assert!(exact_lp::check_certificate(&p,&Certificate::Optimal {point:bad,multipliers:multipliers.clone()},&exact_lp::Limits::default()).is_err());
  let mut bad=multipliers;for v in &mut bad {*v="0".into();}assert!(exact_lp::check_certificate(&p,&Certificate::Optimal {point,multipliers:bad},&exact_lp::Limits::default()).is_err());
 }
}
#[test]
fn empty_rows_free_lineality_zero_rows_and_infeasibility() {
 solve(&problem(&["1"],&[]),"unbounded");
 solve(&problem(&["0","0"],&[]),"optimal");
 let p=problem(&["1","0"],&[(&["-1","0"],"-1")]);assert_eq!(objective(&p,&solve(&p,"optimal")),Q::one());
 solve(&problem(&["0"],&[(&["0"],"-1")]),"infeasible");
 solve(&problem(&["1"],&[(&["1"],"0"),(&["-1"],"-1")]),"infeasible");
 let p=problem(&["1"],&[(&["-1"],"-1/3"),(&["-2"],"-2/3"),(&["1"],"1/3"),(&["0"],"0")]);
 assert_eq!(objective(&p,&solve(&p,"optimal")),Q::new(1.into(),3.into()));
 let invalid=Problem {variables:vec![],rows:vec![],objective:Some(vec![])};
 assert!(lp_optimize::optimize(&invalid,&Limits::default()).is_err());
}
#[test]
fn unbounded_ray_requires_original_feasible_base() {
 let p=problem(&["-1","-1"],&[(&["-1","0"],"-2"),(&["0","-1"],"0")]);
 let cert=solve(&p,"unbounded");
 if let Certificate::Unbounded {point,direction}=cert {
  let bad=Certificate::Unbounded {point:texts(&["0","0"]),direction:direction.clone()};assert!(exact_lp::check_certificate(&p,&bad,&exact_lp::Limits::default()).is_err());
  let bad=Certificate::Unbounded {point,direction:direction.iter().map(|s|(-s.parse::<Q>().unwrap()).to_string()).collect()};assert!(exact_lp::check_certificate(&p,&bad,&exact_lp::Limits::default()).is_err());
 }
}
#[test]
fn bland_rule_handles_classic_degenerate_cycling_instance() {
 let p=problem(&["-10","57","9","24"],&[
  (&["1/2","-11/2","-5/2","9"],"0"),(&["1/2","-3/2","-1/2","1"],"0"),(&["1","0","0","0"],"1"),
  (&["-1","0","0","0"],"0"),(&["0","-1","0","0"],"0"),(&["0","0","-1","0"],"0"),(&["0","0","0","-1"],"0")]);
 let cert=solve(&p,"optimal");assert_eq!(objective(&p,&cert),-Q::one());
 let tiny=Limits {pivots:1,..Limits::default()};let out=lp_optimize::optimize(&p,&tiny).unwrap();assert_eq!(out.status,"unknown");assert!(out.certificate.is_none());
}
// Independent two-dimensional boundary intersection enumeration. This oracle
// uses no tableau, basis update or dual construction from the implementation.
fn enumerate(p:&Problem)->Q {
 let a:Vec<Vec<Q>>=p.rows.iter().map(|r|r.coefficients.iter().map(|s|s.parse().unwrap()).collect()).collect();
 let b:Vec<Q>=p.rows.iter().map(|r|r.bound.parse().unwrap()).collect();
 let c:Vec<Q>=p.objective.as_ref().unwrap().iter().map(|s|s.parse().unwrap()).collect();
 let mut best:Option<Q>=None;
 for i in 0..a.len(){for j in i+1..a.len(){
  let det=&a[i][0]*&a[j][1]-&a[i][1]*&a[j][0];if det.is_zero(){continue;}
  let x=(&b[i]*&a[j][1]-&a[i][1]*&b[j])/&det;
  let y=(&a[i][0]*&b[j]-&b[i]*&a[j][0])/&det;
  if a.iter().zip(&b).all(|(a,b)|&a[0]*&x+&a[1]*&y<=*b) {
   let value=&c[0]*&x+&c[1]*&y;best=Some(best.map_or(value.clone(),|old|old.min(value)));
  }
 }}best.unwrap()
}
#[test]
fn enumerated_small_resource_polygons() {
 for u in 1..=3 {for v in 1..=3 {for cap in 1..=4 {for a in 1..=2 {for b in 1..=2 {
  let p=problem(&["-2","-3"],&[(&["-1","0"],"0"),(&["0","-1"],"0"),(&["1","0"],&u.to_string()),(&["0","1"],&v.to_string()),(&[&a.to_string(),&b.to_string()],&cap.to_string())]);
  let cert=solve(&p,"optimal");assert_eq!(objective(&p,&cert),enumerate(&p));
 }}}}}
}
#[test]
fn arithmetic_and_storage_exhaustion_never_claim_an_optimum() {
 let p=problem(&["1"],&[(&["-1"],"-1/101")]);
 for limits in [Limits {bits:4,..Limits::default()},Limits {tableau_cells:0,..Limits::default()},Limits {work:0,..Limits::default()}] {
  let out=lp_optimize::optimize(&p,&limits).unwrap();assert_eq!(out.status,"unknown");assert!(out.certificate.is_none());
 }
}
