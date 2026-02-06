use serde::{Serialize, Deserialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TipInfo {
    pub slot: u64,
    pub block_hash: String,
    pub block_number: u64,
    pub epoch: u64,
    pub is_syncing: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub enum SyncStatus {
    NotStarted,
    Bootstrapping,
    DownloadingSnapshots,
    ImportingSnapshots,
    Syncing,
    #[allow(dead_code)]
    CaughtUp,
}
