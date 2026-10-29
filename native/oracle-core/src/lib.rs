//! Native execution foundation. No proof claims or ambient tenant authority.
//! Image paths and tenant identities must come from an authenticated host.
#![forbid(unsafe_code)]

mod budget;
mod image;
mod query;
mod runtime;

pub use budget::{Budget, Cancellation, Limits};
pub use image::{build_image, BuildReceipt, Image};
pub use query::{Node, Plan, Projection, QueryResult};
pub use runtime::{Execution, Runtime};

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("invalid input: {0}")]
    Invalid(String),
    #[error("capacity busy")]
    Busy,
    #[error("cancelled")]
    Cancelled,
    #[error("deadline exceeded")]
    Deadline,
    #[error("resource limit: {0}")]
    Limit(&'static str),
    #[error("conflict: {0}")]
    Conflict(&'static str),
    #[error("incompatible format: {0}")]
    Format(String),
    #[error("internal lock poisoned")]
    Poisoned,
    #[error(transparent)]
    Sql(rusqlite::Error),
    #[error(transparent)]
    Io(#[from] std::io::Error),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
}

impl From<rusqlite::Error> for Error {
    fn from(error: rusqlite::Error) -> Self {
        match error.sqlite_error_code() {
            Some(rusqlite::ErrorCode::DatabaseBusy | rusqlite::ErrorCode::DatabaseLocked) => {
                Self::Busy
            }
            _ => Self::Sql(error),
        }
    }
}

pub(crate) fn digest(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    format!("{:x}", Sha256::digest(bytes))
}

pub(crate) fn lock<T>(mutex: &std::sync::Mutex<T>) -> Result<std::sync::MutexGuard<'_, T>> {
    mutex.try_lock().map_err(|e| match e {
        std::sync::TryLockError::WouldBlock => Error::Busy,
        std::sync::TryLockError::Poisoned(_) => Error::Poisoned,
    })
}
