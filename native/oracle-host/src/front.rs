//! The front door's arbitration rule, written down in `native/docs/HOST.md`.
//!
//! Routes are grouped by depth. Group 0 is the native learned reader and every
//! admitted organ; group 1 is the contained Engine. A group is decided by
//! `oracle_runtime_core::admission::arbitrate`: all answers must agree (exact
//! text, or within 0.5 percent when both carry the same explicit unit), any
//! accepted refusal ends the turn, and a failed route blocks an answer. Only a
//! group in which no route took the question lets the next group try. No
//! route is ranked above another; disagreement is a refusal, never a pick.

use oracle_runtime_core::admission::{
    arbitrate, AdmissionLimits, AdmissionOutcome, AdmissionPolicy, AgreementKey, AgreementMode,
    AnswerCandidate, Participation, RefusalKind, RelativeAgreement, RouteOutcome, RouteReport,
    RouteSpec, SemanticRefusal, Unavailability,
};
use oracle_runtime_core::value::{ExactNumber, ValueLimits};
use oracle_runtime_core::{Budget, Cancellation, Limits};
use serde_json::{json, Map, Value};

pub const TOLERANCE: &str = "0.005";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Offer {
    Answer,
    Refusal,
    NoReading,
    Unavailable,
}

impl Offer {
    fn label(self) -> &'static str {
        match self {
            Self::Answer => "answer",
            Self::Refusal => "refusal",
            Self::NoReading => "no_reading",
            Self::Unavailable => "unavailable",
        }
    }
}

/// One route's report on one question, kept whole for provenance.
#[derive(Clone, Debug)]
pub struct Candidate {
    pub route: String,
    pub group: usize,
    pub offer: Offer,
    pub status: String,
    pub response: String,
    pub path: String,
    /// Agreement key text: the reader's answer, or an organ's `value`.
    pub key: Option<String>,
    pub unit: Option<String>,
    pub number: Option<String>,
    /// The producer's complete reply (Engine and organs), or reader result.
    pub reply: Value,
    pub detail: Value,
    pub ms: f64,
}

impl Candidate {
    pub fn unavailable(route: String, group: usize, detail: &str, ms: f64) -> Self {
        Self {
            route,
            group,
            offer: Offer::Unavailable,
            status: "unavailable".into(),
            response: String::new(),
            path: String::new(),
            key: None,
            unit: None,
            number: None,
            reply: Value::Null,
            detail: json!({"error": detail.chars().take(512).collect::<String>()}),
            ms,
        }
    }

    /// From an answerer-contract reply (`status`, `response`, `path`, `value`, `unit`).
    pub fn from_reply(route: String, group: usize, offer: Offer, reply: &Value, ms: f64) -> Self {
        let text = |k: &str| {
            reply
                .get(k)
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_owned()
        };
        let value = reply.get("value");
        let number = value.filter(|v| v.is_number()).map(Value::to_string);
        let unit = reply
            .get("unit")
            .and_then(Value::as_str)
            .filter(|u| !u.is_empty())
            .map(str::to_owned);
        let key = match value {
            Some(Value::String(s)) if !s.trim().is_empty() => Some(s.clone()),
            Some(v @ (Value::Number(_) | Value::Bool(_))) => Some(v.to_string()),
            _ => None,
        }
        .or_else(|| Some(text("response")).filter(|r| !r.trim().is_empty()));
        Self {
            route,
            group,
            offer,
            status: text("status"),
            response: text("response"),
            path: text("path"),
            key,
            unit,
            number,
            reply: reply.clone(),
            detail: Value::Null,
            ms,
        }
    }

    fn report(&self, limits: &ValueLimits) -> RouteReport {
        let outcome = match self.offer {
            Offer::NoReading => RouteOutcome::NoReading,
            Offer::Unavailable => RouteOutcome::Unavailable(Unavailability::Failed(
                self.detail["error"]
                    .as_str()
                    .unwrap_or("unavailable")
                    .to_owned(),
            )),
            Offer::Refusal => RouteOutcome::Refusal(SemanticRefusal {
                kind: RefusalKind::Deliberate,
                response: self.response.clone(),
                path: self.path.clone(),
            }),
            Offer::Answer => {
                let numeric = match (&self.number, &self.unit) {
                    (Some(n), Some(u)) => {
                        ExactNumber::parse(n, limits)
                            .ok()
                            .map(|value| AgreementKey::Number {
                                value,
                                unit: u.clone(),
                            })
                    }
                    _ => None,
                };
                match numeric.or_else(|| self.key.clone().map(AgreementKey::Text)) {
                    Some(key) => RouteOutcome::Answer(AnswerCandidate {
                        key,
                        response: self.response.clone(),
                        path: self.path.clone(),
                        dimension: None,
                        evidence: vec![],
                    }),
                    // An answer with nothing to compare cannot join agreement.
                    None => RouteOutcome::Unavailable(Unavailability::Failed(
                        "answer carries no comparable value or text".into(),
                    )),
                }
            }
        };
        RouteReport {
            route: self.route.clone(),
            outcome,
        }
    }

    pub fn provenance(&self) -> Value {
        let mut row = json!({"route": self.route, "group": self.group, "outcome": self.offer.label(),
            "status": self.status, "path": self.path, "ms": (self.ms * 1000.0).round() / 1000.0});
        if self.offer == Offer::Answer || self.offer == Offer::Refusal {
            row["response"] = json!(self.response);
        }
        if let Some(key) = &self.key {
            if self.offer == Offer::Answer {
                row["agreement_key"] = json!(key);
            }
        }
        if !self.detail.is_null() {
            row["detail"] = self.detail.clone();
        }
        if let Some(provenance) = self.reply.get("provenance") {
            row["producer_provenance"] = provenance.clone();
        }
        row
    }
}

pub fn value_limits() -> ValueLimits {
    ValueLimits::default()
}

pub fn policy(routes: &[&Candidate]) -> AdmissionPolicy {
    let limits = value_limits();
    AdmissionPolicy {
        routes: routes
            .iter()
            .map(|c| RouteSpec {
                id: c.route.clone(),
                participation: Participation::Required,
            })
            .collect(),
        agreement: AgreementMode::Relative(Box::new(RelativeAgreement {
            tolerance: ExactNumber::parse(TOLERANCE, &limits).expect("constant"),
            floor: ExactNumber::parse("0", &limits).expect("constant"),
            value_limits: limits,
        })),
        limits: AdmissionLimits::default(),
    }
}

#[derive(Debug)]
pub enum Decision {
    /// Group answered: the index into the group's candidates of the reply shown.
    Answered {
        selected: usize,
        agreeing: Vec<usize>,
    },
    Refused {
        routes: Vec<usize>,
    },
    Disagreement {
        routes: Vec<usize>,
    },
    Unavailable {
        routes: Vec<usize>,
    },
    NoReading,
}

impl Decision {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Answered { .. } => "answered",
            Self::Refused { .. } => "refused",
            Self::Disagreement { .. } => "disagreement",
            Self::Unavailable { .. } => "unavailable",
            Self::NoReading => "no_reading",
        }
    }
}

/// Arbitrate one group with the core admission rule.
pub fn decide(group: &[&Candidate]) -> Result<Decision, String> {
    if group.is_empty() {
        return Ok(Decision::NoReading);
    }
    let limits = value_limits();
    let budget = Budget::new(
        &Limits {
            timeout_ms: 5000,
            fuel: 10_000_000,
            ..Limits::default()
        },
        Cancellation::default(),
    )
    .map_err(|e| e.to_string())?;
    let decision = arbitrate(
        &policy(group),
        group.iter().map(|c| c.report(&limits)),
        &budget,
    )
    .map_err(|e| e.to_string())?;
    Ok(match decision.outcome().clone() {
        AdmissionOutcome::Answered { selected, agreeing } => {
            Decision::Answered { selected, agreeing }
        }
        AdmissionOutcome::Refused { routes } => Decision::Refused { routes },
        AdmissionOutcome::Disagreement { routes } => Decision::Disagreement { routes },
        AdmissionOutcome::Unavailable { routes } => Decision::Unavailable { routes },
        AdmissionOutcome::NoReading => Decision::NoReading,
        AdmissionOutcome::GuardVeto { .. } | AdmissionOutcome::GuardUnavailable { .. } => {
            return Err("no guards are configured".into())
        }
    })
}

/// The `/query` reply body (`reply` member) for a decided group.
pub fn reply(
    decision: &Decision,
    group: &[&Candidate],
    all: &[Candidate],
    decided_group: Option<usize>,
) -> Value {
    let mut body = match decision {
        Decision::Answered { selected, .. } => producer_fields(group[*selected], "answered"),
        Decision::Refused { routes } => {
            let first = group[routes[0]];
            let status = if first.status.is_empty() || first.status == "answered" {
                "withheld"
            } else {
                first.status.as_str()
            };
            producer_fields(first, status)
        }
        Decision::Disagreement { .. } => json!({"status": "withheld",
            "response": "The routes that read this question gave different answers, so no answer is given.",
            "path": "host:disagreement"}),
        Decision::Unavailable { .. } => json!({"status": "withheld",
            "response": "A route that must take part could not answer, so no answer is given.",
            "path": "host:unavailable"}),
        Decision::NoReading => json!({"status": "withheld",
            "response": "No configured route reads this question.", "path": "host:no_reading"}),
    };
    let mut provenance = match body.get("provenance") {
        Some(Value::Object(map)) => map.clone(),
        _ => Map::new(),
    };
    let decided: Vec<&str> = match decision {
        Decision::Answered { agreeing, .. } => {
            agreeing.iter().map(|&i| group[i].route.as_str()).collect()
        }
        Decision::Refused { routes }
        | Decision::Disagreement { routes }
        | Decision::Unavailable { routes } => {
            routes.iter().map(|&i| group[i].route.as_str()).collect()
        }
        Decision::NoReading => vec![],
    };
    provenance.insert(
        "host".into(),
        json!({
        "rule": "depth groups; agreement or refusal within the first group that takes the question",
        "decision": decision.label(), "group": decided_group, "routes": decided,
        "candidates": all.iter().map(Candidate::provenance).collect::<Vec<_>>()}),
    );
    body["provenance"] = Value::Object(provenance);
    body
}

fn producer_fields(candidate: &Candidate, status: &str) -> Value {
    let mut body =
        json!({"status": status, "response": candidate.response, "path": candidate.path});
    if let Value::Object(reply) = &candidate.reply {
        for key in ["value", "kind", "references", "provenance", "unit"] {
            if let Some(v) = reply.get(key) {
                body[key] = v.clone();
            }
        }
    }
    body
}

#[cfg(test)]
mod tests {
    use super::*;

    fn answer(route: &str, key: &str, unit: Option<&str>) -> Candidate {
        let mut reply = json!({"status": "answered", "response": format!("It is {key}."), "path": route, "value": key});
        if let Some(unit) = unit {
            reply["value"] = serde_json::from_str(key).unwrap();
            reply["unit"] = json!(unit);
        }
        Candidate::from_reply(route.into(), 0, Offer::Answer, &reply, 0.0)
    }

    #[test]
    fn agreeing_answers_answer_and_the_first_is_shown() {
        let (a, b) = (
            answer("reader", "Paris", None),
            answer("organ:x", " paris ", None),
        );
        let decision = decide(&[&a, &b]).unwrap();
        assert!(
            matches!(decision, Decision::Answered { selected: 0, ref agreeing } if agreeing == &[0, 1])
        );
    }

    #[test]
    fn different_answers_are_refused_not_picked() {
        let (a, b) = (
            answer("reader", "Paris", None),
            answer("organ:x", "Lyon", None),
        );
        assert!(matches!(
            decide(&[&a, &b]).unwrap(),
            Decision::Disagreement { .. }
        ));
        let body = reply(
            &decide(&[&a, &b]).unwrap(),
            &[&a, &b],
            &[a.clone(), b.clone()],
            Some(0),
        );
        assert_eq!(body["status"], "withheld");
        assert_eq!(
            body["provenance"]["host"]["candidates"]
                .as_array()
                .unwrap()
                .len(),
            2
        );
    }

    #[test]
    fn numbers_agree_within_half_a_percent_only_with_one_unit() {
        let (a, b) = (
            answer("a", "343.2", Some("m/s")),
            answer("b", "343.9", Some("m/s")),
        );
        assert!(matches!(
            decide(&[&a, &b]).unwrap(),
            Decision::Answered { .. }
        ));
        let c = answer("c", "346", Some("m/s"));
        assert!(matches!(
            decide(&[&a, &c]).unwrap(),
            Decision::Disagreement { .. }
        ));
        let d = answer("d", "343.2", Some("km/h"));
        assert!(matches!(
            decide(&[&a, &d]).unwrap(),
            Decision::Disagreement { .. }
        ));
    }

    #[test]
    fn a_refusal_ends_the_turn_and_silence_falls_through() {
        let a = answer("a", "Paris", None);
        let refusal = Candidate::from_reply(
            "b".into(),
            0,
            Offer::Refusal,
            &json!({"status": "clarification", "response": "Which one?", "path": "b>ask"}),
            0.0,
        );
        let decision = decide(&[&a, &refusal]).unwrap();
        assert!(matches!(decision, Decision::Refused { .. }));
        assert_eq!(
            reply(&decision, &[&a, &refusal], &[], Some(0))["status"],
            "clarification"
        );
        let silent = Candidate::from_reply("c".into(), 0, Offer::NoReading, &json!({}), 0.0);
        assert!(matches!(decide(&[&silent]).unwrap(), Decision::NoReading));
        let failed = Candidate::unavailable("d".into(), 0, "deadline", 0.0);
        assert!(matches!(
            decide(&[&a, &failed]).unwrap(),
            Decision::Unavailable { .. }
        ));
    }
}
