//! Hosted stable-model transport checks over retained typed request and reply.
use super::*;
use oracle_logic::{Request, Status};
pub(super) fn interpret(
    s: &Structured<'_>,
    q: &Request,
    r: oracle_logic::hosted::HostedReply,
    digest: &str,
) -> CheckedPureReply {
    let body = &r.result;
    let valid = (|| -> Option<()> {
        if r.schema != "oracle-logic-experimental-v1"
            || r.operation_id != s.id
            || body.scope.tenant != q.scope.tenant
            || body.scope.snapshot != q.scope.snapshot
            || body.scope.complete_program != q.scope.complete_program
            || !config::is_hash(&r.program_identity)
            || !config::is_hash(&r.request_identity)
            || body.witness_check != "handwritten_gl_reduct"
            || body.answers.len() != q.queries.len()
        {
            return None;
        }
        for model in &body.models {
            if model.iter().any(|a| *a >= q.atoms.len()) || model.windows(2).any(|w| w[0] >= w[1]) {
                return None;
            }
        }
        if matches!(body.status, Status::Inconsistent) && !body.models.is_empty() {
            return None;
        }
        if s.id == "logic.query" && body.enumeration_complete {
            return None;
        }
        for (a, q) in body.answers.iter().zip(&q.queries) {
            if a.atom != *q {
                return None;
            }
            match body.status {
                Status::Inconsistent => {
                    if a.skeptical.is_some() || a.credulous.is_some() {
                        return None;
                    }
                }
                Status::Consistent => {
                    if a.skeptical.is_none() || a.credulous.is_none() {
                        return None;
                    }
                }
                _ => {}
            }
            for (w, present) in [(a.true_witness, true), (a.false_witness, false)] {
                if let Some(i) = w {
                    if body.models.get(i)?.binary_search(&a.atom).is_ok() != present {
                        return None;
                    }
                }
            }
            if (a.skeptical == Some(true) && a.false_witness.is_some())
                || (a.credulous == Some(false) && a.true_witness.is_some())
            {
                return None;
            }
        }
        Some(())
    })();
    if valid.is_none() {
        return withheld_reply(s.id, "native_reply_invalid", None);
    }
    let status = match body.status {
        Status::Inconclusive => None,
        Status::Inconsistent => Some("inconsistent_solver_trusted_absence_of_stable_models"),
        _ if s.id == "logic.enumerate" => {
            Some("enumerated_checked_models_solver_trusted_completeness")
        }
        _ => Some("checked_witnesses_solver_trusted_absence"),
    };
    let payload = Payload::Logic {
        reply: r,
        admitted_solver_sha256: digest.to_owned(),
    };
    match status {
        None => withheld_reply(s.id, "inconclusive", Some(payload)),
        Some(class) => classification(s.id, s.identity, class, payload),
    }
}
