use log::info;
use std::path::PathBuf;
use amaru::stages::{Config, StoreType};
use amaru_kernel::network::NetworkName;
use amaru_stores::rocksdb::RocksDbConfig;

pub async fn setup_amaru_config(network: NetworkName, data_dir: PathBuf) -> Option<Config> {
    info!("Setting up Amaru config for network: {:?}", network);
    
    let ledger_dir = data_dir.join("ledger.db");
    let chain_dir = data_dir.join("chain.db");
    
    // Create directories only if they don't exist
    if let Err(e) = std::fs::create_dir_all(&ledger_dir) {
        log::error!("Failed to create ledger dir: {}", e);
        return None;
    }
    if let Err(e) = std::fs::create_dir_all(&chain_dir) {
        log::error!("Failed to create chain dir: {}", e);
        return None;
    }
    
    let ledger_config = RocksDbConfig::new(ledger_dir).with_shared_env();
    let chain_config = RocksDbConfig::new(chain_dir).with_shared_env();
    
    Some(Config {
        upstream_peers: get_peers_for_network(network),
        ledger_store: StoreType::RocksDb(ledger_config),
        chain_store: StoreType::RocksDb(chain_config),
        migrate_chain_db: true,
        ..Config::default()
    })
}

pub fn get_peers_for_network(network: NetworkName) -> Vec<String> {
    match network {
        NetworkName::Mainnet => vec!["relays.cardano-mainnet.iohk.io:3001".into()],
        NetworkName::Preprod => vec!["preprod-node.play.dev.cardano.org:3001".into()],
        NetworkName::Preview => vec![
            "preview-node.play.dev.cardano.org:3001".into(),
            "relays.cardano-preview.iohkdev.io:3001".into(),
        ],
        _ => vec![],
    }
}
