//! Typed bridge for an existing host session owner, not a journal or registry.
//! Mutation and solving are separate commands: only mutation changes evidence.
//! The host authenticates tenant/session and uses its existing CAS transaction.
use crate::{revisions::*, Error, Limits, Reply};
use serde::{Deserialize, Serialize};

pub const OPERATION: &str = "logic.workspace";
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub enum Command {
    Revise {
        revision: Revision,
    },
    Solve {
        expected_revision: u64,
        queries: Vec<String>,
    },
    Checkpoint {
        expected_revision: u64,
        #[serde(default)]
        expected_snapshot_identity: Option<String>,
    },
}

pub fn checkpoint_checked(
    workspace: &Workspace,
    expected_revision: u64,
    expected_snapshot_identity: Option<&str>,
) -> Result<Checkpoint, Error> {
    let checkpoint = workspace.checkpoint();
    if checkpoint.revision != expected_revision {
        return Err(Error::Invalid("stale evidence checkpoint revision"));
    }
    if expected_snapshot_identity.is_some_and(|expected| expected != checkpoint.snapshot_identity) {
        return Err(Error::Invalid("stale evidence checkpoint identity"));
    }
    Ok(checkpoint)
}

pub fn checkpoint(
    tenant: &str,
    state: Option<StoredWorkspace>,
    workspace: String,
    expected_revision: u64,
    expected_snapshot_identity: Option<&str>,
    max_records: usize,
    control: &dyn oracle_execution::WorkControl,
) -> Result<Checkpoint, Error> {
    crate::revisions::restore_checkpoint(control, 0)?;
    let scope = ScopeKey {
        tenant: tenant.into(),
        workspace,
    };
    let workspace = match state {
        Some(state) => Workspace::import_with_control(state, &scope, max_records, control)?,
        None => Workspace::new(scope)?,
    };
    let checkpoint = checkpoint_checked(&workspace, expected_revision, expected_snapshot_identity)?;
    crate::revisions::restore_checkpoint(control, 0)?;
    Ok(checkpoint)
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Mutation {
    pub workspace: String,
    pub revision: Revision,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MutationReply {
    pub scope: ScopeKey,
    pub commit: Commit,
}
#[derive(Serialize)]
pub struct SolveReply {
    pub receipt: Receipt,
    pub result: Reply,
    /// Rule templates distinguish conjunction, alternative rules, absence and
    /// coverage guards. Applicability is model-relative, not a causal claim.
    pub support_templates: Vec<Justification>,
}
/// Host calls this after deserialization at its storage boundary. This checks
/// every revision and never treats absent Python state as an empty Oracle state.
pub fn validate_state(
    state: &StoredWorkspace,
    tenant: &str,
    max_records: usize,
) -> Result<(), Error> {
    let scope = ScopeKey {
        tenant: tenant.into(),
        workspace: state.scope.workspace.clone(),
    };
    Workspace::import(state.clone(), &scope, max_records).map(|_| ())
}
/// Run inside the host's typed owner transition, then atomically persist the
/// returned history and this acknowledgement through the existing journal.
pub fn revise(
    tenant: &str,
    previous: Option<StoredWorkspace>,
    command: Mutation,
    max_records: usize,
) -> Result<(StoredWorkspace, MutationReply), Error> {
    let scope = ScopeKey {
        tenant: tenant.into(),
        workspace: command.workspace,
    };
    let mut workspace = match previous {
        Some(state) => Workspace::import(state, &scope, max_records)?,
        None => Workspace::new(scope.clone())?,
    };
    let commit = workspace.apply(command.revision, max_records)?;
    Ok((workspace.export(), MutationReply { scope, commit }))
}
/// Host obtains state using its authenticated checked owner read API. A concurrent
/// later revision cannot change this prepared request. The receipt names the
/// exact older snapshot; no claim is made that it is still the latest on return.
pub fn prepare_solve(
    tenant: &str,
    state: StoredWorkspace,
    workspace: String,
    expected_revision: u64,
    queries: Vec<String>,
    max_records: usize,
    limits: &Limits,
) -> Result<Prepared, Error> {
    let scope = ScopeKey {
        tenant: tenant.into(),
        workspace,
    };
    let workspace = Workspace::import(state, &scope, max_records)?;
    let snapshot = workspace.snapshot();
    if snapshot.revision() != expected_revision {
        return Err(Error::Invalid("stale evidence solve revision"));
    }
    snapshot.prepare(queries, limits)
}
/// Operator solver config stays outside the core session store and outside
/// tenant command JSON. Failure leaves all previously committed evidence intact.
pub fn solve(
    prepared: &Prepared,
    solver: &std::path::Path,
    limits: &Limits,
    control: &dyn oracle_execution::WorkControl,
) -> Result<SolveReply, Error> {
    let evaluated = prepared.evaluate(solver, limits, control)?;
    Ok(SolveReply {
        receipt: evaluated.receipt,
        result: evaluated.reply,
        support_templates: prepared.supports().to_vec(),
    })
}
