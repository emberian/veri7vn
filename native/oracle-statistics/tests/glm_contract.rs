//! Independent identities and exact witnesses for the supplied GLM consumer.
use oracle_statistics::glm::{self, Family, FiniteMleCertificate, GlmInput, SeparationCertificate, Status};
use oracle_statistics::{Error, Limits};
use serde_json::json;
use std::sync::atomic::AtomicBool;

fn binomial() -> GlmInput {
    serde_json::from_value(json!({"family":"grouped_binomial_logit","method":"maximum_likelihood",
        "features":[[-1.0],[1.0]],"intercept":true,"successes":[2,8],"trials":[10,10],
        "uncertainty":"model_based_wald","model":{"description":"Independent manufactured groups",
        "predictor_names":["stress"],"predictor_units":["1"],"independent_unit":"individual independent trial",
        "grouping":"ten independent trials sharing each supplied design row",
        "assumptions":["Prespecified correct logistic probabilities; independent binomial rows"]},
        "predictions":[{"features":[0.0],"trials":20}]})).unwrap()
}
fn poisson() -> GlmInput {
    serde_json::from_value(json!({"family":"poisson_log","method":"maximum_likelihood",
        "features":[[],[]],"intercept":true,"counts":[1,3],"exposures":[1.0,3.0],"exposure_unit":"device-hour",
        "uncertainty":"model_based_wald","model":{"description":"Independent manufactured event counts",
        "predictor_names":[],"predictor_units":[],"independent_unit":"independent device interval",
        "grouping":"one fixed interval per independent device",
        "assumptions":["Independent Poisson counts; correct log-linear rate with fixed exposure"]},
        "predictions":[{"features":[],"exposure":2.0}]})).unwrap()
}
fn run(i:&GlmInput)->glm::GlmResult {glm::fit(i,&Limits::default(),&AtomicBool::new(false)).unwrap()}
fn close(a:f64,b:f64) {assert!((a-b).abs()<=2e-7*b.abs().max(1.0),"{a} != {b}");}
#[test]
fn analytic_grouped_binomial_and_model_information() {
    let i=binomial();let r=run(&i);
    assert_eq!(r.status,Status::FiniteMleConverged);
    close(r.coefficient_candidate[0],0.0);close(r.coefficient_candidate[1],4f64.ln());
    close(r.observations[0].fitted_probability.unwrap(),0.2);close(r.observations[1].fitted_probability.unwrap(),0.8);
    close(r.predictions[0].probability.unwrap(),0.5);close(r.predictions[0].expected_count.unwrap(),10.0);
    // Weights 10*.2*.8=1.6 at x=-1,+1, so X'WX=diag(3.2,3.2).
    let inf=r.inference.as_ref().unwrap();close(inf.coefficient_covariance[0][0],0.3125);close(inf.coefficient_covariance[1][1],0.3125);
    close(inf.coefficient_covariance[0][1],0.0);
    assert!(glm::verify_finiteness_certificate(&i,r.finite_mle_certificate.as_ref().unwrap(),&Limits::default(),&AtomicBool::new(false)).unwrap());
}
#[test]
fn grouping_independent_repeated_bernoulli_trials_preserves_estimate_and_information() {
    let grouped=binomial();let g=run(&grouped);let mut expanded=grouped.clone();
    expanded.features=vec![];let mut successes=vec![];
    for (x,n_success) in [(-1.0,2usize),(1.0,8usize)] {for k in 0..10 {expanded.features.push(vec![x]);successes.push(u64::from(k<n_success));}}
    expanded.successes=Some(successes);expanded.trials=Some(vec![1;20]);
    let e=run(&expanded);assert_eq!(e.status,Status::FiniteMleConverged);
    for j in 0..2 {close(e.coefficient_candidate[j],g.coefficient_candidate[j]);
        for k in 0..2 {close(e.inference.as_ref().unwrap().coefficient_covariance[j][k],g.inference.as_ref().unwrap().coefficient_covariance[j][k]);}}
}
#[test]
fn analytic_poisson_exposure_rate_and_scale_transform() {
    let i=poisson();let r=run(&i);assert_eq!(r.status,Status::FiniteMleConverged);
    close(r.coefficient_candidate[0],0.0);close(r.predictions[0].rate_per_exposure_unit.unwrap(),1.0);
    close(r.predictions[0].expected_count.unwrap(),2.0);close(r.inference.as_ref().unwrap().coefficient_covariance[0][0],0.25);
    let mut scaled=i.clone();scaled.exposures=Some(vec![1000.0,3000.0]);scaled.predictions[0].exposure=Some(2000.0);
    scaled.exposure_unit=Some("milli-device-hour".into());let s=run(&scaled);
    assert_eq!(s.status,Status::FiniteMleConverged);close(s.coefficient_candidate[0],-1000f64.ln());
    close(s.predictions[0].expected_count.unwrap(),2.0);close(s.predictions[0].rate_per_exposure_unit.unwrap(),0.001);
}
#[test]
fn general_poisson_overlap_works_without_full_rank_positive_count_subset() {
    let mut i=poisson();i.features=vec![vec![-1.0],vec![0.0],vec![1.0]];
    i.counts=Some(vec![0,1,0]);i.exposures=Some(vec![1.0;3]);i.model.predictor_names=vec!["x".into()];i.model.predictor_units=vec!["1".into()];
    i.predictions[0].features=vec![0.0];
    let r=run(&i);assert_eq!(r.status,Status::FiniteMleConverged);
    close(r.coefficient_candidate[0],-3f64.ln());close(r.coefficient_candidate[1],0.0);
    let cert=FiniteMleCertificate{family:Family::PoissonLog,weights:vec!["1".into(),"-2".into(),"1".into()],basis_rows:vec![0,1]};
    assert!(glm::verify_finiteness_certificate(&i,&cert,&Limits::default(),&AtomicBool::new(false)).unwrap());
}
#[test]
fn complete_and_quasi_separation_are_exactly_certified_never_successful_wald_fits() {
    for quasi in [false,true] {
        let mut i=binomial();
        if quasi {i.features=vec![vec![-1.0],vec![0.0],vec![1.0]];i.successes=Some(vec![0,1,2]);i.trials=Some(vec![2,2,2]);}
        else{i.successes=Some(vec![0,2]);i.trials=Some(vec![2,2]);}
        let r=run(&i);assert_eq!(r.status,Status::SeparationCertified);
        assert!(r.inference.is_none());assert!(r.predictions[0].probability.is_none());assert!(r.finite_mle_certificate.is_none());
        assert!(glm::verify_separation_certificate(&i,r.separation_certificate.as_ref().unwrap(),&Limits::default(),&AtomicBool::new(false)).unwrap());
        let cert=SeparationCertificate{family:Family::GroupedBinomialLogit,direction:vec!["0".into(),"1".into()]};
        assert!(glm::verify_separation_certificate(&i,&cert,&Limits::default(),&AtomicBool::new(false)).unwrap());
    }
}
#[test]
fn zero_poisson_counts_with_and_without_intercept_have_different_geometry() {
    let mut i=poisson();i.counts=Some(vec![0,0]);let r=run(&i);
    assert_eq!(r.status,Status::SeparationCertified);assert!(r.inference.is_none());
    i.intercept=false;i.features=vec![vec![-1.0],vec![1.0]];i.exposures=Some(vec![1.0,1.0]);
    i.model.predictor_names=vec!["x".into()];i.model.predictor_units=vec!["1".into()];i.predictions[0].features=vec![0.0];
    let r=run(&i);assert_eq!(r.status,Status::FiniteMleConverged);close(r.coefficient_candidate[0],0.0);
}
#[test]
fn witness_replay_rejects_zero_weights_unbalanced_rows_and_false_recession() {
    let i=binomial();
    // Signed rows: [1,-1],[-1,1],[1,1],[-1,-1]. Equal weights balance.
    let good=FiniteMleCertificate{family:i.family,weights:vec!["1".into();4],basis_rows:vec![0,2]};
    assert!(glm::verify_finiteness_certificate(&i,&good,&Limits::default(),&AtomicBool::new(false)).unwrap());
    for weights in [vec!["0","1","1","1"],vec!["2","1","1","1"]] {
        let bad=FiniteMleCertificate{weights:weights.into_iter().map(str::to_string).collect(),..good.clone()};
        assert!(!glm::verify_finiteness_certificate(&i,&bad,&Limits::default(),&AtomicBool::new(false)).unwrap());
    }
    let bad=FiniteMleCertificate{basis_rows:vec![0,1],..good};
    assert!(!glm::verify_finiteness_certificate(&i,&bad,&Limits::default(),&AtomicBool::new(false)).unwrap());
    let false_direction=SeparationCertificate{family:i.family,direction:vec!["0".into(),"1".into()]};
    assert!(!glm::verify_separation_certificate(&i,&false_direction,&Limits::default(),&AtomicBool::new(false)).unwrap());
}
#[test]
fn finite_nonconvergence_rank_alias_and_resource_refusal_do_not_predict() {
    let mut i=binomial();i.successes=Some(vec![1,6]);i.solver.max_iterations=1;
    let r=run(&i);assert_ne!(r.status,Status::FiniteMleConverged);assert!(r.inference.is_none());assert!(r.predictions[0].probability.is_none());
    i=binomial();i.features=vec![vec![1.0],vec![1.0]];
    let r=run(&i);assert_eq!(r.status,Status::RankDeficient);assert!(r.inference.is_none());
    let mut limits=Limits::default();limits.work=1;
    assert!(matches!(glm::fit(&binomial(),&limits,&AtomicBool::new(false)),Err(Error::Limit(_))));
    assert!(matches!(glm::fit(&binomial(),&Limits::default(),&AtomicBool::new(true)),Err(Error::Cancelled)));
}
#[test]
fn invalid_family_support_and_hidden_weights_are_rejected() {
    let mut i=binomial();i.successes=Some(vec![11,8]);assert!(glm::fit(&i,&Limits::default(),&AtomicBool::new(false)).is_err());
    i=binomial();i.exposures=Some(vec![1.0,1.0]);assert!(glm::fit(&i,&Limits::default(),&AtomicBool::new(false)).is_err());
    let mut p=poisson();p.exposures=Some(vec![0.0,1.0]);assert!(glm::fit(&p,&Limits::default(),&AtomicBool::new(false)).is_err());
    let mut value=serde_json::to_value(binomial()).unwrap();value["precision_weights"]=json!([1.0,1.0]);
    assert!(serde_json::from_value::<GlmInput>(value).is_err());
}

#[test]
fn exact_witness_uses_original_noninteger_dyadics_and_rejects_one_ulp_change() {
    let mut i=binomial();i.features=vec![vec![-0.1],vec![-0.1],vec![0.1],vec![0.1]];
    i.successes=Some(vec![1,0,1,0]);i.trials=Some(vec![1;4]);
    let cert=FiniteMleCertificate{family:i.family,weights:vec!["1".into();4],basis_rows:vec![0,2]};
    assert!(glm::verify_finiteness_certificate(&i,&cert,&Limits::default(),&AtomicBool::new(false)).unwrap());
    let false_separator=SeparationCertificate{family:i.family,direction:vec!["0".into(),"1".into()]};
    assert!(!glm::verify_separation_certificate(&i,&false_separator,&Limits::default(),&AtomicBool::new(false)).unwrap());
    i.features[0][0]=f64::from_bits((-0.1f64).to_bits()+1);
    assert!(!glm::verify_finiteness_certificate(&i,&cert,&Limits::default(),&AtomicBool::new(false)).unwrap());
}

#[test]
fn predictor_unit_rescaling_restores_coefficients_covariance_and_predictions() {
    let original=binomial();let baseline=run(&original);let mut scaled=original.clone();
    for row in &mut scaled.features{row[0]*=1000.0;}
    scaled.model.predictor_units[0]="milli-unit".into();
    let result=run(&scaled);assert_eq!(result.status,Status::FiniteMleConverged);
    close(result.coefficient_candidate[1],baseline.coefficient_candidate[1]/1000.0);
    close(result.inference.as_ref().unwrap().coefficient_covariance[1][1],baseline.inference.as_ref().unwrap().coefficient_covariance[1][1]/1e6);
    close(result.predictions[0].probability.unwrap(),baseline.predictions[0].probability.unwrap());
}

#[test]
fn final_publication_observes_shared_work_budget_and_reports_all_charges() {
    use std::sync::atomic::{AtomicU64,Ordering};
    struct Counter{used:AtomicU64,allowed:u64}
    impl oracle_execution::WorkControl for Counter {
        fn checkpoint(&self,work:u64)->oracle_execution::Result<()> {
            let used=self.used.fetch_add(work,Ordering::SeqCst)+work;
            if used>self.allowed{Err(oracle_execution::ExecutionError::FuelExhausted)}else{Ok(())}
        }
    }
    let control=Counter{used:AtomicU64::new(0),allowed:u64::MAX};
    let result=glm::fit(&binomial(),&Limits::default(),&control).unwrap();
    let total=control.used.load(Ordering::SeqCst);
    assert_eq!(total,result.diagnostics.work_units as u64);
    // Exhaust only the final post-assembly checkpoint. No accepted result may
    // escape after the shared control rejects publication.
    let control=Counter{used:AtomicU64::new(0),allowed:total-1};
    assert!(matches!(glm::fit(&binomial(),&Limits::default(),&control),Err(Error::Limit(_))));
}
