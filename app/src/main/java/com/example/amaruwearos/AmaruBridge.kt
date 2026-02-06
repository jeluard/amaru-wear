package com.amaruwear

object AmaruBridge {
    init {
        System.loadLibrary("amaru_wear")
    }

    /**
     * Initialize the Android logger for Rust
     */
    external fun initLogger()

    /**
     * Start the Amaru node
     * @param network The network name ("mainnet", "preprod", "preview")
     * @param dataDir The data directory path for storing blockchain data
     * @return 0 on success, negative error code on failure
     */
    external fun startNode(network: String, dataDir: String): Long

    /**
     * Get the latest tip information as JSON
     * @return JSON string with slot, blockHash, blockNumber, epoch, isSyncing, status
     */
    external fun getLatestTip(): String

    /**
     * Stop the Amaru node
     */
    external fun stopNode()
}
