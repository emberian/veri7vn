//! Exploratory scenarios over the frozen provider API; no production admission.
mod support;
use support::{both, emit, Change, Expectation, Program};

fn fact<'a>(id: &'a str, atom: &'a str, source: &'a str) -> Change<'a> {
    Change::Assert { id, atom, source }
}
fn withdraw(id: &str) -> Change<'_> {
    Change::Withdraw { id }
}

fn defaults_and_withdrawal() {
    let mut p = Program::new("demo-birds", "default-flight");
    p.rule(
        "bird-flight-default",
        "local teaching policy",
        Some("flies"),
        &["bird"],
        &["flight-exception"],
    );
    p.rule(
        "penguin-exception",
        "local teaching policy",
        Some("flight-exception"),
        &["penguin"],
        &[],
    );
    p.revise(
        "two independent observations identify a bird",
        &[
            fact("camera/bird", "bird", "camera observation: fixture only"),
            fact("keeper/bird", "bird", "keeper observation: fixture only"),
        ],
    )
    .unwrap();
    emit(&mut p,"default applies",&["bird","flies"],"consistent",
        &[both("bird",true,true),both("flies",true,true)],&[vec!["bird","flies"]],
        "Closed-world status belongs to this complete teaching program, not to a public bird database.");
    p.revise(
        "new observation introduces an exception",
        &[fact(
            "keeper/penguin",
            "penguin",
            "keeper correction: penguin",
        )],
    )
    .unwrap();
    emit(
        &mut p,
        "new exception retracts derived flight",
        &["flies", "flight-exception"],
        "consistent",
        &[
            both("flies", false, false),
            both("flight-exception", true, true),
        ],
        &[vec!["bird", "penguin", "flight-exception"]],
        "Adding evidence can withdraw a default conclusion without deleting the default rule.",
    );
    p.revise(
        "exception observation was misattributed; camera bird report also withdrawn",
        &[withdraw("keeper/penguin"), withdraw("camera/bird")],
    )
    .unwrap();
    emit(
        &mut p,
        "withdrawal restores default; independent support survives",
        &["bird", "flies"],
        "consistent",
        &[both("bird", true, true), both("flies", true, true)],
        &[vec!["bird", "flies"]],
        "Removing one evidence token does not remove a fact still supported by another token.",
    );
    p.revise(
        "last bird observation withdrawn",
        &[withdraw("keeper/bird")],
    )
    .unwrap();
    emit(&mut p,"last support disappears",&["bird","flies"],"consistent",
        &[both("bird",false,false),both("flies",false,false)],&[vec![]],
        "Each revision sends the entire active program; no derived conclusions are cached across snapshots.");
}

fn agent_planning() {
    let mut p = Program::new("agent-local-demo", "one-step-analysis-plan");
    p.rule(
        "local-option",
        "agent plan policy",
        Some("local-run"),
        &["job", "local-ready"],
        &["remote-run"],
    );
    p.rule(
        "remote-option",
        "agent plan policy",
        Some("remote-run"),
        &["job", "remote-ready"],
        &["local-run", "confidential"],
    );
    p.rule(
        "local-completes",
        "action schema",
        Some("planned"),
        &["local-run"],
        &[],
    );
    p.rule(
        "remote-completes",
        "action schema",
        Some("planned"),
        &["remote-run"],
        &[],
    );
    p.rule(
        "escalation",
        "agent fallback policy",
        Some("ask-operator"),
        &["job"],
        &["planned"],
    );
    p.rule(
        "privacy-integrity",
        "agent local privacy constraint",
        None,
        &["remote-run", "confidential"],
        &[],
    );
    p.revise(
        "finite job has two available tools",
        &[
            fact("job/1", "job", "explicit task fixture"),
            fact("tool/local", "local-ready", "tool inventory snapshot"),
            fact("tool/remote", "remote-ready", "tool inventory snapshot"),
        ],
    )
    .unwrap();
    emit(&mut p,"two viable proposed plans",&["local-run","remote-run","planned","ask-operator"],"consistent",
        &[both("local-run",false,true),both("remote-run",false,true),both("planned",true,true),both("ask-operator",false,false)],
        &[vec!["job","local-ready","remote-ready","local-run","planned"],vec!["job","local-ready","remote-ready","remote-run","planned"]],
        "Skeptical planned=true says an option exists in every model, not that a particular action is authorized or chosen. This demo executes no actions.");
    p.revise(
        "user labels supplied task data confidential",
        &[fact(
            "classification/1",
            "confidential",
            "explicit local classification fixture",
        )],
    )
    .unwrap();
    emit(&mut p,"privacy observation removes remote option",&["local-run","remote-run","planned"],"consistent",
        &[both("local-run",true,true),both("remote-run",false,false),both("planned",true,true)],
        &[vec!["job","local-ready","remote-ready","confidential","local-run","planned"]],
        "The negative confidential guard is appropriate only because the complete local classification program is explicitly supplied. Unknown public data is never treated as unclassified.");
    p.revise(
        "local tool withdrawn after inventory change",
        &[withdraw("tool/local")],
    )
    .unwrap();
    emit(&mut p,"no available permissible action: explicit escalation",&["planned","ask-operator"],"consistent",
        &[both("planned",false,false),both("ask-operator",true,true)],
        &[vec!["job","remote-ready","confidential","ask-operator"]],
        "No feasible proposed action is a consistent modeled state; asking for intervention is distinct from logical inconsistency.");
    p.revise(
        "classification withdrawn for a replacement public fixture",
        &[withdraw("classification/1")],
    )
    .unwrap();
    emit(&mut p,"replan after scoped input revision",&["remote-run","ask-operator"],"consistent",
        &[both("remote-run",true,true),both("ask-operator",false,false)],
        &[vec!["job","remote-ready","remote-run","planned"]],
        "Retraction is an explicit local revision, not automatic declassification of a real document.");
}

fn diagnosis_and_information() {
    let mut p = Program::new("diagnostic-demo", "alert-diagnosis");
    p.rule(
        "fault-hypothesis",
        "exclusive two-cause model",
        Some("sensor-fault"),
        &["alert"],
        &["real-event"],
    );
    p.rule(
        "event-hypothesis",
        "exclusive two-cause model",
        Some("real-event"),
        &["alert"],
        &["sensor-fault"],
    );
    p.rule(
        "fault-explains",
        "diagnostic model",
        Some("explained"),
        &["sensor-fault"],
        &[],
    );
    p.rule(
        "event-explains",
        "diagnostic model",
        Some("explained"),
        &["real-event"],
        &[],
    );
    p.rule(
        "failed-selftest-excludes-event",
        "teaching assumption: exclusive causes",
        None,
        &["selftest-failed", "real-event"],
        &[],
    );
    p.rule(
        "passed-selftest-excludes-fault",
        "teaching assumption: perfect self-test",
        None,
        &["selftest-passed", "sensor-fault"],
        &[],
    );
    p.rule(
        "mutually-exclusive-observations",
        "diagnostic consistency policy",
        None,
        &["selftest-failed", "selftest-passed"],
        &[],
    );
    // Instrumentation recommendation is about supplied observations, not about
    // inspecting all stable models with an unsupported modal rule.
    p.rule(
        "request-selftest",
        "diagnostic information-gathering policy",
        Some("request-selftest"),
        &["alert"],
        &["selftest-failed", "selftest-passed"],
    );
    p.revise(
        "one alarm, no discrimination measurement",
        &[fact("alarm/001", "alert", "synthetic alarm observation")],
    )
    .unwrap();
    emit(&mut p,"ambiguous explanation suggests a discriminating measurement",&["sensor-fault","real-event","explained","request-selftest"],"consistent",
        &[both("sensor-fault",false,true),both("real-event",false,true),both("explained",true,true),both("request-selftest",true,true)],
        &[vec!["alert","sensor-fault","explained","request-selftest"],vec!["alert","real-event","explained","request-selftest"]],
        "Stable-model alternatives are possible explanations, not probabilities, causal discovery, or minimal abductive diagnoses. Self-test action is proposed, not executed.");
    p.revise(
        "test fixture reports a failed self-test",
        &[fact(
            "selftest/001",
            "selftest-failed",
            "synthetic perfect-test observation",
        )],
    )
    .unwrap();
    emit(&mut p,"measurement filters explanations",&["sensor-fault","real-event","request-selftest"],"consistent",
        &[both("sensor-fault",true,true),both("real-event",false,false),both("request-selftest",false,false)],
        &[vec!["alert","selftest-failed","sensor-fault","explained"]],
        "An explicit integrity constraint eliminates the incompatible hypothesis. Exclusivity and perfect tests are strong demo assumptions, not empirical facts.");
    p.revise(
        "conflicting test report arrives",
        &[fact(
            "selftest/002",
            "selftest-passed",
            "second synthetic observation, incompatible with first",
        )],
    )
    .unwrap();
    let unknown = [
        Expectation {
            atom: "sensor-fault",
            skeptical: None,
            credulous: None,
        },
        Expectation {
            atom: "real-event",
            skeptical: None,
            credulous: None,
        },
    ];
    emit(&mut p,"incompatible observations require reconciliation",&["sensor-fault","real-event"],"inconsistent",
        &unknown,&[],"No stable model: do not infer everything. Both observation sources stay visible in the ledger; no hidden automatic repair or arbitrary source preference.");
    p.revise(
        "operator withdraws the misattributed first test token",
        &[withdraw("selftest/001")],
    )
    .unwrap();
    emit(&mut p,"explicit evidence repair restores a different diagnosis",&["sensor-fault","real-event"],"consistent",
        &[both("sensor-fault",false,false),both("real-event",true,true)],
        &[vec!["alert","selftest-passed","real-event","explained"]],
        "Repair is a proposed evidence-level operation with provenance, not a solver silently relaxing constraints.");
}

fn incompatible_obligations() {
    let mut p = Program::new("policy-demo", "conflicting-obligations");
    p.rule(
        "must-release",
        "policy A",
        Some("release"),
        &["request"],
        &[],
    );
    p.rule("must-hold", "policy B", Some("hold"), &["request"], &[]);
    p.rule(
        "exclusive-actions",
        "action model",
        None,
        &["release", "hold"],
        &[],
    );
    p.revise(
        "request activates incompatible policies",
        &[fact("request/1", "request", "synthetic request")],
    )
    .unwrap();
    let unknown = [
        Expectation {
            atom: "release",
            skeptical: None,
            credulous: None,
        },
        Expectation {
            atom: "hold",
            skeptical: None,
            credulous: None,
        },
    ];
    emit(&mut p,"inconsistent obligations do not authorize either action",&["release","hold"],"inconsistent",&unknown,&[],
        "This is ordinary normal-program stable-model semantics. It neither invents policy priorities nor supplies a paraconsistent repair. Distinct from a timeout, model cap, or no available plan.");
}

fn main() {
    defaults_and_withdrawal();
    agent_planning();
    diagnosis_and_information();
    incompatible_obligations();
}
