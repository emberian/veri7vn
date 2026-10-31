use oracle_statistics::{Limits, sequential::*};
use std::sync::atomic::AtomicBool;
fn input(xs: Vec<f64>, alpha:f64)->SequentialInput {
    SequentialInput { config:SequentialConfig { method:METHOD.into(),bounds:[0.,1.],alpha,
        metric:"inspection pass".into(),unit:"fraction".into(),
        sampling_assumptions:vec!["Prespecified stream; common conditional pass probability".into()],
        multiplicity:"Single monitored metric; full alpha allocated here".into(),hypothesis:Some(0.5) }, observations:xs }
}
#[test]
fn step_replay_identity_and_atomic_rejection() {
    let cancel=AtomicBool::new(false); let limits=Limits::default();
    let initial=replay(&input(vec![1.,0.,1.],0.05),&limits,&cancel).unwrap();
    let snapshot=initial.state.clone();
    assert!(step(&initial.state,2,0.,&limits,&cancel).is_err());
    assert!(step(&initial.state,3,2.,&limits,&cancel).is_err());
    assert_eq!(initial.state,snapshot);
    let next=step(&initial.state,3,0.25,&limits,&cancel).unwrap();
    let direct=replay(&input(vec![1.,0.,1.,0.25],0.05),&limits,&cancel).unwrap();
    assert_eq!(next,direct);
    let encoded=serde_json::to_string(&next.state).unwrap();
    let decoded:SequentialState=serde_json::from_str(&encoded).unwrap();
    assert_eq!(decoded,next.state);
}
#[test]
fn finite_path_optional_stopping_against_independent_integer_capital() {
    // Every Bernoulli path, not just fixed-time marginal coverage. Integer
    // arithmetic oracle: lambda numerator/64 and penalty numerator/32768.
    let n:usize=12; let alpha=0.8; let cancel=AtomicBool::new(false);
    for quarters in [1i64,2,3] {
        let mu=quarters as f64/4.; let mut ever_mass=0.;
        for bits in 0..(1u64<<n) {
            let xs:Vec<f64>=(0..n).map(|j|((bits>>j)&1) as f64).collect();
            let result=replay(&input(xs.clone(),alpha),&Limits::default(),&cancel).unwrap();
            let mut sum=0i64; let mut penalty=0i64; let mut exact_ever=false;
            let mut actual_ever=false;
            for t in 1..=n {
                let exponent=(usize::BITS-1-t.leading_zeros())/2;
                let l=64i64>>exponent;
                sum+=l*(4*xs[t-1] as i64-quarters);
                penalty+=l*l; // sum lambda^2/8 = penalty/32768
                // centered sum = sum/256; threshold=2+penalty/32768
                exact_ever |= sum.abs()*128>2*32768+penalty;
                let point=&result.history[t-1];
                actual_ever |= point.interval.map_or(true, |[a,b]|mu<a || mu>b);
                assert_eq!(actual_ever,exact_ever,"t={t}, bits={bits}, mu={mu}");
            }
            if actual_ever {
                let ones=bits.count_ones() as i32;
                ever_mass+=mu.powi(ones)*(1.-mu).powi(n as i32-ones);
            }
        }
        assert!(ever_mass<=alpha+1e-12,"ever exclusion mass {ever_mass}");
    }
}
#[test]
fn analytic_constant_stream_and_bounds_affine_equivariance() {
    let cancel=AtomicBool::new(false);
    let r=replay(&input(vec![1.;128],0.05),&Limits::default(),&cancel).unwrap();
    assert!(r.interval.unwrap()[0]>0.5);
    assert_eq!(r.interval.unwrap()[1],1.);
    assert!(r.history.last().unwrap().log_capital_lower.unwrap()[0]>r.log_rejection_boundary_upper);
    let mut transformed=input(vec![12.;128],0.05);
    transformed.config.bounds=[10.,12.]; transformed.config.hypothesis=Some(11.);
    let s=replay(&transformed,&Limits::default(),&cancel).unwrap();
    assert!((s.interval.unwrap()[0]-(10.+2.*r.interval.unwrap()[0])).abs()<1e-10);
    let empty=replay(&input(vec![],0.05),&Limits::default(),&cancel).unwrap();
    assert_eq!(empty.interval,Some([0.,1.]));
}
#[test]
fn explicit_contract_and_resource_rejections() {
    let cancel=AtomicBool::new(false);
    for bad in [f64::NAN,-0.1,1.1] {
        assert!(replay(&input(vec![bad],0.05),&Limits::default(),&cancel).is_err());
    }
    for alpha in [0.,1.,1e-20,f64::NAN] {
        assert!(replay(&input(vec![],alpha),&Limits::default(),&cancel).is_err());
    }
    let mut drift=input(vec![0.5],0.05); drift.config.method="fixed-time-repeated".into();
    assert!(replay(&drift,&Limits::default(),&cancel).is_err());
    let mut limits=Limits::default(); limits.rows=1;
    assert!(replay(&input(vec![0.;2],0.05),&limits,&cancel).is_err());
    assert!(replay(&input(vec![0.],0.05),&Limits::default(),&AtomicBool::new(true)).is_err());
}

#[test]
fn live_append_is_constant_work_and_import_replays_untrusted_rows() {
    use oracle_execution::{ExecutionError, WorkControl};
    use std::sync::atomic::{AtomicU64,Ordering};
    struct Count(AtomicU64);
    impl WorkControl for Count {
        fn checkpoint(&self, work:u64) -> std::result::Result<(),ExecutionError> {
            self.0.fetch_add(work,Ordering::SeqCst); Ok(())
        }
    }
    let control=Count(AtomicU64::new(0));
    let limits=Limits::default();
    let mut live=SequentialMonitor::new(input(vec![],0.05).config,&limits,&control).unwrap();
    for index in 0..128 {
        let before=control.0.load(Ordering::SeqCst);
        live.append(index,if index%3==0 {0.} else {1.},&limits,&control).unwrap();
        assert_eq!(control.0.load(Ordering::SeqCst)-before,64);
    }
    let snapshot=live.export_state();
    let direct=replay(&SequentialInput {config:snapshot.config.clone(),
        observations:snapshot.observations.clone()},&limits,&control).unwrap();
    assert_eq!(live.history(),direct.history.as_slice());
    let imported=SequentialMonitor::import(&snapshot,&limits,&control).unwrap();
    assert_eq!(imported.export_state(),snapshot);
    assert_eq!(imported.history(),live.history());
    assert!(live.append(127,1.,&limits,&control).is_err());
    assert!(live.append(128,2.,&limits,&control).is_err());
    assert_eq!(live.export_state(),snapshot);
    let mut corrupt=snapshot.clone(); corrupt.position+=1;
    assert!(SequentialMonitor::import(&corrupt,&limits,&control).is_err());
    corrupt=snapshot.clone(); corrupt.observations[0]=2.;
    assert!(SequentialMonitor::import(&corrupt,&limits,&control).is_err());
    // Unknown fields cannot smuggle a cached accumulator through raw-state import.
    let mut json=serde_json::to_value(&snapshot).unwrap();
    json.as_object_mut().unwrap().insert("weighted".into(),serde_json::json!(999));
    assert!(serde_json::from_value::<SequentialState>(json).is_err());
}

#[test]
fn outward_arithmetic_encloses_exact_rational_edges_at_every_prefix() {
    use num_rational::BigRational as Q;
    fn q(x:f64)->Q { Q::from_float(x).unwrap() }
    let sub=f64::from_bits(1);
    let one_up=f64::from_bits(1f64.to_bits()+1);
    let large:f64=1e300;
    let large_up=f64::from_bits(large.to_bits()+512);
    let cases:Vec<([f64;2],Vec<f64>)>=vec![
        ([0.1,0.9],vec![0.1,0.2,0.3,0.8,0.9].repeat(32)),
        ([-0.3,0.7],vec![-0.3,0.7].repeat(128)),
        ([-17.2,-3.1],vec![-3.1;128]),
        ([large,large_up],vec![large_up;128]),
        ([0.,8.*sub],vec![8.*sub;128]),
        ([1.,one_up],vec![one_up;128]),
        ([-1e-300,-0.5e-300],vec![-0.5e-300;128]),
        ([1e308,1.1e308],vec![1.1e308;128]),
    ];
    for (bounds,xs) in cases {
        let mut supplied=input(xs,0.05);
        supplied.config.bounds=bounds;
        supplied.config.hypothesis=Some(bounds[0]);
        let actual=replay(&supplied,&Limits::default(),&AtomicBool::new(false)).unwrap();
        let [a,b]=bounds.map(q);
        let width=&b-&a;
        let mut weights=q(0.); let mut weighted=q(0.); let mut penalty=q(0.);
        let mut hull=Some((q(0.),q(1.)));
        // alpha .05 => ceil(log2(2/alpha))=6, independently exact.
        for (i,&x) in supplied.observations.iter().enumerate() {
            let t=i+1;
            let exponent=(usize::BITS-1-t.leading_zeros())/2;
            let lambda=Q::new(1.into(),(1u64<<exponent).into());
            weights+=&lambda;
            weighted+=((q(x)-&a)/&width)*&lambda;
            penalty+=(&lambda*&lambda)/q(8.);
            let lo=(&weighted-q(6.)-&penalty)/&weights;
            let hi=(&weighted+q(6.)+&penalty)/&weights;
            hull=hull.and_then(|(old_lo,old_hi)| {
                let next_lo=old_lo.max(lo); let next_hi=old_hi.min(hi);
                if next_lo<=next_hi {Some((next_lo,next_hi))} else {None}
            });
            let out=&actual.history[i];
            match &hull {
                Some((lo,hi))=> {
                    let interval=out.interval.expect("nonempty exact set must not be discarded");
                    assert!(interval[0].is_finite() && interval[1].is_finite());
                    assert!(bounds[0]<=interval[0] && interval[1]<=bounds[1]);
                    assert!(q(interval[0])<=&a+lo*&width,"inward lower endpoint at {bounds:?}, prefix {t}");
                    assert!(q(interval[1])>=&a+hi*&width,"inward upper endpoint at {bounds:?}, prefix {t}");
                },
                None=>assert!(out.interval.is_none()),
            }
            // Hypothesis equals a => exact normalized m=0. Capital lower
            // bounds must never overstate either mathematical log capital.
            let logs=out.log_capital_lower.unwrap();
            assert!(q(logs[0])<=&weighted-&penalty);
            assert!(q(logs[1])<=-&weighted-&penalty);
        }
    }
}

#[test]
fn too_narrow_subnormal_range_refused_and_cancel_checked_before_raw_cloning() {
    use oracle_statistics::Error;
    let mut supplied=input(vec![],0.05);
    supplied.config.bounds=[f64::from_bits(1),f64::from_bits(2)];
    supplied.config.hypothesis=None;
    assert!(replay(&supplied,&Limits::default(),&AtomicBool::new(false)).is_err());
    let mut state=SequentialState {config:input(vec![],0.05).config,position:0,observations:vec![]};
    state.config.metric="x".repeat(1_048_576);
    let cancel=AtomicBool::new(true);
    assert!(matches!(SequentialMonitor::import(&state,&Limits::default(),&cancel),Err(Error::Cancelled)));
    assert!(matches!(step(&state,0,0.5,&Limits::default(),&cancel),Err(Error::Cancelled)));
    assert!(SequentialMonitor::import(&state,&Limits::default(),&AtomicBool::new(false)).is_err());
}
