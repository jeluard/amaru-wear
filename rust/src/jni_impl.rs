use jni::sys::jstring;
use jni::JNIEnv;
use log::info;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::runtime::Runtime;
use std::sync::Mutex;
use amaru_kernel::network::NetworkName;
use amaru_tracing_json::{JsonTraceCollector, JsonLayer};
use amaru::bootstrap::bootstrap;
use amaru::stages::build_and_run_network;
use tracing::Dispatch;
use tracing_subscriber::layer::SubscriberExt;
use std::mem;

use crate::amaru::setup_amaru_config;
use crate::state::{get_sync_status, set_sync_status, LATEST_TIP};
use crate::models::{SyncStatus, TipInfo};

pub static RUNTIME: Mutex<Option<Arc<Runtime>>> = Mutex::new(None);

pub fn init_logger() {
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Info)
            .with_tag("AmaruWear"),
    );
    info!("✅ Android logger initialized");
}

pub fn start_node(network: &str, data_dir: &str) -> i64 {
    info!("🚀 JNI: startNode called with network={}, data_dir={}", network, data_dir);

    let network_name = match network.to_lowercase().as_str() {
        "mainnet" => NetworkName::Mainnet,
        "preprod" => NetworkName::Preprod,
        "preview" => NetworkName::Preview,
        _ => {
            log::error!("Invalid network name: {}", network);
            return -3;
        }
    };

    let app_dir = PathBuf::from(data_dir);

    // Atomically check-and-set runtime: create and store in one lock hold to prevent TOCTOU races
    let rt_clone = {
        let mut r = match RUNTIME.lock() {
            Ok(g) => g,
            Err(e) => {
                log::error!("Failed to lock runtime: {}", e);
                return -5;
            }
        };
        if r.is_some() {
            log::error!("❌ startNode called while node is already running — this is a bug");
            return -6;
        }
        let runtime = match Runtime::new() {
            Ok(rt) => Arc::new(rt),
            Err(e) => {
                log::error!("Failed to create tokio runtime: {}", e);
                return -4;
            }
        };
        let clone = runtime.clone();
        *r = Some(runtime);
        clone
    };

    // Set up tracing with JsonTraceCollector
    let collector = JsonTraceCollector::default();
    let layer = JsonLayer::new(collector.clone());
    let subscriber = tracing_subscriber::registry().with(layer);
    let dispatch = Dispatch::new(subscriber);
    let guard = tracing::dispatcher::set_global_default(dispatch);
    mem::forget(guard);

    // Start Amaru in background thread with its own runtime for network
    std::thread::Builder::new()
        .name("amaru-network".into())
        .stack_size(8 * 1024 * 1024)
        .spawn(move || {
            rt_clone.block_on(async {
                info!("🚀 Starting Amaru on network {:?} in: {:?}", network_name, app_dir);
                set_sync_status(SyncStatus::Bootstrapping);
                
                let ledger_dir = app_dir.join("ledger.db");
                let chain_dir = app_dir.join("chain.db");
                
                // Create directories
                if let Err(e) = std::fs::create_dir_all(&ledger_dir) {
                    log::error!("Failed to create ledger dir: {}", e);
                }
                if let Err(e) = std::fs::create_dir_all(&chain_dir) {
                    log::error!("Failed to create chain dir: {}", e);
                }
                
                // Bootstrap if needed
                if !ledger_dir.join("CURRENT").exists() {
                    // IMPORTANT: Change to app_dir FIRST so bootstrap can create snapshots/ there
                    info!("📂 Attempting to change working dir to: {:?}", app_dir);
                    match std::env::set_current_dir(&app_dir) {
                        Ok(_) => {
                            if let Ok(cwd) = std::env::current_dir() {
                                info!("✓ Working dir is now: {:?}", cwd);
                            }
                        }
                        Err(e) => {
                            log::error!("❌ Failed to chdir: {}", e);
                        }
                    }
                    
                    info!("📥 Bootstrapping ledger from snapshots...");
                    match bootstrap(network_name, ledger_dir.clone(), chain_dir.clone()).await {
                        Ok(_) => info!("✅ Bootstrap complete"),
                        Err(e) => log::error!("❌ Bootstrap failed: {}", e),
                    }
                } else {
                    info!("📂 Ledger already exists, skipping bootstrap");
                }
                
                // Run network
                if let Some(config) = setup_amaru_config(network_name, app_dir).await {
                    let listen_address = config.listen_address.clone();
                    info!("🔄 Starting network sync (listening on {})...", listen_address);
                    set_sync_status(SyncStatus::Syncing);
                    
                    match build_and_run_network(config, None).await {
                        Ok(running) => {
                            info!("✅ Network running");
                            running.join().await;
                        }
                        Err(e) => log::error!("❌ Network error on {}: {}", listen_address, e),
                    }
                }
            });
        })
        .unwrap();
    
    // Start polling loop in a separate thread (not blocked by network runtime)
    let collector_for_poll = collector.clone();
    std::thread::Builder::new()
        .name("trace-poller".into())
        .spawn(move || {
            loop {
                std::thread::sleep(std::time::Duration::from_millis(500));
                for line in collector_for_poll.flush() {
                    process_trace_event(&line);
                }
            }
        })
        .unwrap();
    
    0
}

fn process_trace_event(line: &serde_json::Value) {
    let name = line.get("name").and_then(|v| v.as_str()).unwrap_or_default();
    
    // Only log important events (skip verbose network/http traces)
    let should_log = !name.is_empty() 
        && !name.contains("checkout") 
        && !name.contains("pooling") 
        && !name.contains("idle")
        && !name.contains("forward_chain")  // Too verbose
        && !name.contains("chain_sync")
        && !name.contains("diffusion")
        && !name.contains("consensus.store");
    
    if should_log {
        info!("📊 Trace: {}", name);
    }
    
    // Update status based on bootstrap events
    match name {
        "Downloading snapshot" => {
            set_sync_status(SyncStatus::DownloadingSnapshots);
        }
        "Importing snapshots" | "Importing snapshot" => {
            set_sync_status(SyncStatus::ImportingSnapshots);
        }
        "Imported snapshots" => {
            set_sync_status(SyncStatus::Syncing);
        }
        _ => {}
    }
    
    // Handle tip updates
    match name {
        "starting" => {
            if let Some(tip_obj) = line.get("tip").and_then(|v| v.as_object()) {
                if let Some(slot) = tip_obj.get("slot").and_then(|v| v.as_u64()) {
                    if let Some(hash) = tip_obj.get("hash").and_then(|v| v.as_str()) {
                        let tip = TipInfo {
                            slot,
                            block_hash: hash.to_string(),
                            block_number: slot / 20,
                            epoch: slot / 432000,
                            is_syncing: true,
                        };
                        let _ = LATEST_TIP.lock().map(|mut t| *t = Some(tip));
                        info!("📍 Starting: slot={}", slot);
                    }
                }
            }
        }
        "track_peers.caught_up.new_tip" => {
            if let Some(point) = extract_point_slot(line) {
                let tip = TipInfo {
                    slot: point,
                    block_hash: extract_point_hash(line),
                    block_number: point / 20,
                    epoch: point / 432000,
                    is_syncing: false,
                };
                let _ = LATEST_TIP.lock().map(|mut t| *t = Some(tip));
                set_sync_status(SyncStatus::CaughtUp);
                info!("✅ Caught up! slot={}", point);
            }
        }
        "track_peers.syncing.new_tip" => {
            if let Some(point) = extract_point_slot(line) {
                let tip = TipInfo {
                    slot: point,
                    block_hash: extract_point_hash(line),
                    block_number: point / 20,
                    epoch: point / 432000,
                    is_syncing: true,
                };
                let _ = LATEST_TIP.lock().map(|mut t| *t = Some(tip));
                info!("🔄 Syncing: slot={}", point);
            }
        }
        // Handle diffusion forward_chain events - slot/hash is in the name itself
        name if name.contains("forward_chain") && name.contains("Forward(BlockHeader") => {
            if let Some(slot_idx) = name.find("slot: ") {
                let slot_str = &name[slot_idx + 6..];
                if let Some(end_idx) = slot_str.find(|c: char| !c.is_numeric()) {
                    if let Ok(slot) = slot_str[..end_idx].parse::<u64>() {
                        let hash = extract_hash_from_name(name);
                        let tip = TipInfo {
                            slot,
                            block_hash: hash.clone(),
                            block_number: slot / 20,
                            epoch: slot / 432000,
                            is_syncing: true,
                        };
                        let _ = LATEST_TIP.lock().map(|mut t| *t = Some(tip));
                        // Only log occasionally to reduce spam
                        if slot % 1000 == 0 {
                            info!("🔄 Syncing: slot={} hash={}", slot, &hash[..8.min(hash.len())]);
                        }
                    }
                }
            }
        }
        _ => {}
    }
}

fn extract_point_slot(line: &serde_json::Value) -> Option<u64> {
    line.get("point").and_then(|v| v.as_str()).and_then(|s| s.split('.').next()).and_then(|s| s.parse().ok())
}

fn extract_point_hash(line: &serde_json::Value) -> String {
    line.get("point").and_then(|v| v.as_str()).and_then(|s| s.split('.').nth(1)).unwrap_or("").to_string()
}

fn extract_hash_from_name(name: &str) -> String {
    // Parse: ... BlockHeader { hash: "fedc1ee50b4251f573225e7ab1be688c02d5fa7e4b747f49e997e69ac284847f", ...
    if let Some(hash_idx) = name.find("hash: \"") {
        let hash_start = hash_idx + 7;
        if let Some(hash_end) = name[hash_start..].find('"') {
            return name[hash_start..hash_start + hash_end].to_string();
        }
    }
    String::new()
}

pub fn stop_node() -> i64 {
    info!("🛑 JNI: stopNode called");
    if let Ok(mut r) = RUNTIME.lock() {
        if r.take().is_some() { return 0; }
    }
    -1
}

pub fn get_latest_tip_json(env: JNIEnv) -> jstring {
    let status = get_sync_status();
    
    let response = if let Ok(tip_lock) = LATEST_TIP.lock() {
        if let Some(tip) = tip_lock.as_ref() {
            serde_json::json!({
                "status": format!("{:?}", status),
                "slot": tip.slot,
                "epoch": tip.epoch,
                "blockHash": tip.block_hash,
                "blockNumber": tip.block_number,
                "isSyncing": tip.is_syncing,
            })
        } else {
            serde_json::json!({
                "status": format!("{:?}", status),
                "slot": 0, "epoch": 0, "blockHash": "pending", "blockNumber": 0, "isSyncing": true,
            })
        }
    } else {
        serde_json::json!({
            "status": "Error", "slot": 0, "epoch": 0, "blockHash": "error", "blockNumber": 0, "isSyncing": true,
        })
    };
    
    env.new_string(response.to_string()).expect("Couldn't create java string!").into_raw()
}
