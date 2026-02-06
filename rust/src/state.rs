use std::sync::Mutex;
use crate::models::{TipInfo, SyncStatus};

pub static LATEST_TIP: Mutex<Option<TipInfo>> = Mutex::new(None);
pub static SYNC_STATUS: Mutex<SyncStatus> = Mutex::new(SyncStatus::NotStarted);

#[allow(dead_code)]
pub fn get_latest_tip() -> Option<TipInfo> {
    LATEST_TIP.lock().ok().and_then(|t| t.clone())
}

pub fn get_sync_status() -> SyncStatus {
    SYNC_STATUS.lock().ok().map(|s| s.clone()).unwrap_or(SyncStatus::NotStarted)
}

pub fn set_sync_status(status: SyncStatus) {
    let _ = SYNC_STATUS.lock().map(|mut s| *s = status);
}
