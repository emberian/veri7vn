//! Consistency check of the `reasoning_lab` demo layer. NOT a solver result.
//!
//! This runs the `reasoning_lab` example in its default mode (no `--solver`,
//! so no stable-model search happens) and reads the JSON it prints. It then
//! checks the thirteen handwritten readouts described in `DEMOS.md` against
//! each other:
//!
//! * there are exactly thirteen readouts, in the order of the DEMOS.md table;
//! * each `handwritten_expected_models_with_conditional_traces` entry has the
//!   models listed in that table, and every one of them is closed under the
//!   builder's own rules (nothing unsupported, nothing extra derivable, no
//!   violated constraint), which is the stable-model condition for a normal
//!   program checked by the demo scaffolding itself;
//! * the handwritten skeptical/credulous answers equal what those handwritten
//!   models imply, and the two "inconsistent" readouts list no models and have
//!   null answers.
//!
//! It cannot show that the handwritten models are ALL the stable models of the
//! program (a missing model would go unnoticed) and says nothing about the
//! frozen provider or clingo.
use serde_json::Value;
use std::collections::BTreeSet;
use std::process::Command;

fn lab_output() -> Vec<Value> {
    let exe = std::env::current_exe().unwrap();
    let lab = exe
        .parent()
        .and_then(|deps| deps.parent())
        .unwrap()
        .join("examples")
        .join(format!("reasoning_lab{}", std::env::consts::EXE_SUFFIX));
    if !lab.exists() {
        // `cargo test` builds examples; `cargo test --test <name>` does not.
        let cargo = std::env::var("CARGO").unwrap_or_else(|_| "cargo".into());
        let built = Command::new(cargo)
            .args(["build", "--example", "reasoning_lab"])
            .current_dir(env!("CARGO_MANIFEST_DIR"))
            .status()
            .unwrap();
        assert!(built.success());
    }
    assert!(lab.exists(), "example not built: {}", lab.display());
    let out = Command::new(&lab).output().unwrap();
    assert!(
        out.status.success(),
        "reasoning_lab failed: {:?}",
        out.status
    );
    serde_json::Deserializer::from_slice(&out.stdout)
        .into_iter::<Value>()
        .collect::<Result<_, _>>()
        .unwrap()
}

type Models = Vec<Vec<&'static str>>;
/// (scenario title, expected status, hand-derived models from DEMOS.md)
fn table() -> Vec<(&'static str, &'static str, Models)> {
    vec![
        ("default applies", "consistent", vec![vec!["bird", "flies"]]),
        (
            "new exception retracts derived flight",
            "consistent",
            vec![vec!["bird", "penguin", "flight-exception"]],
        ),
        (
            "withdrawal restores default; independent support survives",
            "consistent",
            vec![vec!["bird", "flies"]],
        ),
        ("last support disappears", "consistent", vec![vec![]]),
        (
            "two viable proposed plans",
            "consistent",
            vec![
                vec!["job", "local-ready", "remote-ready", "local-run", "planned"],
                vec![
                    "job",
                    "local-ready",
                    "remote-ready",
                    "remote-run",
                    "planned",
                ],
            ],
        ),
        (
            "privacy observation removes remote option",
            "consistent",
            vec![vec![
                "job",
                "local-ready",
                "remote-ready",
                "confidential",
                "local-run",
                "planned",
            ]],
        ),
        (
            "no available permissible action: explicit escalation",
            "consistent",
            vec![vec!["job", "remote-ready", "confidential", "ask-operator"]],
        ),
        (
            "replan after scoped input revision",
            "consistent",
            vec![vec!["job", "remote-ready", "remote-run", "planned"]],
        ),
        (
            "ambiguous explanation suggests a discriminating measurement",
            "consistent",
            vec![
                vec!["alert", "sensor-fault", "explained", "request-selftest"],
                vec!["alert", "real-event", "explained", "request-selftest"],
            ],
        ),
        (
            "measurement filters explanations",
            "consistent",
            vec![vec![
                "alert",
                "selftest-failed",
                "sensor-fault",
                "explained",
            ]],
        ),
        (
            "incompatible observations require reconciliation",
            "inconsistent",
            vec![],
        ),
        (
            "explicit evidence repair restores a different diagnosis",
            "consistent",
            vec![vec!["alert", "selftest-passed", "real-event", "explained"]],
        ),
        (
            "inconsistent obligations do not authorize either action",
            "inconsistent",
            vec![],
        ),
    ]
}

fn names(v: &Value) -> BTreeSet<String> {
    v.as_array()
        .unwrap()
        .iter()
        .map(|x| x.as_str().unwrap().to_string())
        .collect()
}

#[test]
fn thirteen_readouts_match_the_demos_table() {
    let out = lab_output();
    let table = table();
    assert_eq!(out.len(), 13);
    assert_eq!(table.len(), 13);
    for (readout, (title, status, models)) in out.iter().zip(&table) {
        assert_eq!(readout["scenario"], *title);
        assert_eq!(readout["handwritten_expected_status"], *status);
        let traces = readout["handwritten_expected_models_with_conditional_traces"]
            .as_array()
            .unwrap();
        let got: Vec<BTreeSet<String>> =
            traces.iter().map(|t| names(&t["interpretation"])).collect();
        let want: Vec<BTreeSet<String>> = models
            .iter()
            .map(|m| m.iter().map(|s| s.to_string()).collect())
            .collect();
        assert_eq!(got, want, "models differ in: {title}");
    }
}

#[test]
fn each_handwritten_model_is_closed_under_the_demo_rules() {
    for readout in lab_output() {
        let title = readout["scenario"].as_str().unwrap().to_string();
        for trace in readout["handwritten_expected_models_with_conditional_traces"]
            .as_array()
            .unwrap()
        {
            assert!(
                trace["unsupported_candidate_atoms"]
                    .as_array()
                    .unwrap()
                    .is_empty(),
                "unsupported atoms in: {title}"
            );
            assert!(
                trace["closure_atoms_outside_candidate"]
                    .as_array()
                    .unwrap()
                    .is_empty(),
                "derivable atoms missing from model in: {title}"
            );
            assert!(
                trace["conditional_derivation"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .all(|s| s.get("violated_constraint").is_none()),
                "violated constraint in: {title}"
            );
        }
    }
}

#[test]
fn handwritten_answers_follow_from_handwritten_models() {
    for readout in lab_output() {
        let title = readout["scenario"].as_str().unwrap().to_string();
        let models: Vec<BTreeSet<String>> = readout
            ["handwritten_expected_models_with_conditional_traces"]
            .as_array()
            .unwrap()
            .iter()
            .map(|t| names(&t["interpretation"]))
            .collect();
        let inconsistent = readout["handwritten_expected_status"] == "inconsistent";
        assert_eq!(models.is_empty(), inconsistent, "{title}");
        for answer in readout["handwritten_expected_answers"].as_array().unwrap() {
            let atom = answer["atom"].as_str().unwrap();
            if inconsistent {
                assert!(
                    answer["skeptical"].is_null() && answer["credulous"].is_null(),
                    "{title}: {atom}"
                );
                continue;
            }
            let skeptical = models.iter().all(|m| m.contains(atom));
            let credulous = models.iter().any(|m| m.contains(atom));
            assert_eq!(answer["skeptical"], skeptical, "{title}: skeptical {atom}");
            assert_eq!(answer["credulous"], credulous, "{title}: credulous {atom}");
        }
    }
}
