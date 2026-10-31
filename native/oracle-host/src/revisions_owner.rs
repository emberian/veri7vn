//! Typed evidence owner over the existing core session journal. Solver config
//! and execution stay in native host dispatch, never in stored tenant commands.
use oracle_logic::{revisions::*, revisions_owner as domain};
use oracle_runtime_core::{
    self as core,
    session::{NativeSessionOwner, SessionBinding},
};
use serde::{Deserialize, Serialize};

/// Replay is intentionally bounded while retained history is revalidated.
pub const MAX_RECORDS: usize = 128;
pub const OPERATION: &str = domain::OPERATION;
pub struct EvidenceOwner;
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MutationCommand {
    pub revision: Revision,
}
fn scope(binding: &SessionBinding) -> ScopeKey {
    ScopeKey {
        tenant: binding.tenant.clone(),
        workspace: binding.session.clone(),
    }
}
fn error(error: oracle_logic::Error) -> core::Error {
    match error {
        oracle_logic::Error::Limit(message) => core::Error::Limit(message),
        oracle_logic::Error::Cancelled => core::Error::Cancelled,
        oracle_logic::Error::Invalid("stale workspace revision") => {
            core::Error::Conflict("evidence revision changed")
        }
        oracle_logic::Error::Invalid("stale evidence solve revision") => {
            core::Error::Conflict("evidence solve revision changed")
        }
        oracle_logic::Error::Invalid("revision token reused with different content") => {
            core::Error::Conflict("evidence token reused with different content")
        }
        other => core::Error::Invalid(other.to_string()),
    }
}
impl NativeSessionOwner for EvidenceOwner {
    const OWNER: &'static str = oracle_logic::revisions::OWNER;
    const VERSION: u32 = oracle_logic::revisions::VERSION;
    const OPERATION: &'static str = OPERATION;
    type State = StoredWorkspace;
    type Command = MutationCommand;
    type Reply = domain::MutationReply;
    fn validate(state: &Self::State, binding: &SessionBinding, _revision: i64) -> core::Result<()> {
        Workspace::import(state.clone(), &scope(binding), MAX_RECORDS)
            .map(|_| ())
            .map_err(error)
    }
    fn transition(
        binding: &SessionBinding,
        _revision: i64,
        _request: &str,
        state: Option<Self::State>,
        command: Self::Command,
        budget: &core::Budget,
    ) -> core::Result<(Self::State, Self::Reply)> {
        budget.check()?;
        budget.spend(state.as_ref().map_or(1, |s| s.history.len() as u64 + 1))?;
        let result = domain::revise(
            &binding.tenant,
            state,
            domain::Mutation {
                workspace: binding.session.clone(),
                revision: command.revision,
            },
            MAX_RECORDS,
        )
        .map_err(error)?;
        budget.check()?;
        Ok(result)
    }
}
/// The caller must obtain this state via the core's authenticated validated
/// owner read, not from the HTTP body. The caller's evidence revision is checked
/// independently from the session version; the receipt binds the exact snapshot.
pub fn prepare_solve(
    binding: &SessionBinding,
    state: StoredWorkspace,
    expected_revision: u64,
    queries: Vec<String>,
    limits: &oracle_logic::Limits,
) -> core::Result<Prepared> {
    domain::prepare_solve(
        &binding.tenant,
        state,
        binding.session.clone(),
        expected_revision,
        queries,
        MAX_RECORDS,
        limits,
    )
    .map_err(error)
}
