package com.amaruwear

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject

data class TipInfo(
    val slot: Long,
    val blockHash: String,
    val blockNumber: Long,
    val epoch: Long,
    val isSyncing: Boolean,
    val status: String
)

sealed class TipState {
    object Loading : TipState()
    data class Bootstrapping(val message: String) : TipState()
    data class Success(val tip: TipInfo) : TipState()
    data class Error(val message: String) : TipState()
}

class AmaruViewModel(private val context: Context) : ViewModel() {
    private val _tipState = MutableStateFlow<TipState>(TipState.Loading)
    val tipState: StateFlow<TipState> = _tipState

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    private var pollingJob: Job? = null

    init {
        AmaruBridge.initLogger()
        // Auto-start the node on app launch
        startNode("preprod")
    }

    fun startNode(network: String) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                _tipState.value = TipState.Bootstrapping("⏳ Starting node...")
                
                // Get data directory for blockchain storage
                val dataDir = context.filesDir.absolutePath
                
                val result = AmaruBridge.startNode(network, dataDir)
                
                if (result == 0L) {
                    _isRunning.value = true
                    startPolling()
                } else {
                    val errorMsg = when (result) {
                        -1L -> "Failed to get network name"
                        -2L -> "Failed to get data directory"
                        -3L -> "Invalid network name"
                        -4L -> "Failed to create runtime"
                        else -> "Unknown error: $result"
                    }
                    _tipState.value = TipState.Error(errorMsg)
                }
            } catch (e: Exception) {
                _tipState.value = TipState.Error("Error: ${e.message}")
            }
        }
    }

    fun stopNode() {
        pollingJob?.cancel()
        AmaruBridge.stopNode()
        _isRunning.value = false
        _tipState.value = TipState.Loading
    }

    private fun startPolling() {
        pollingJob = viewModelScope.launch(Dispatchers.IO) {
            while (isActive) {
                try {
                    val tipJson = AmaruBridge.getLatestTip()
                    val json = JSONObject(tipJson)
                    
                    val tip = TipInfo(
                        slot = json.getLong("slot"),
                        blockHash = json.getString("blockHash"),
                        blockNumber = json.getLong("blockNumber"),
                        epoch = json.getLong("epoch"),
                        isSyncing = json.getBoolean("isSyncing"),
                        status = json.getString("status")
                    )
                    
                    // Update UI based on status
                    when (tip.status) {
                        "Bootstrapping" -> {
                            _tipState.value = TipState.Bootstrapping("⏳ Preparing ledger...")
                        }
                        "DownloadingSnapshots" -> {
                            _tipState.value = TipState.Bootstrapping("📥 Downloading snapshots...")
                        }
                        "ImportingSnapshots" -> {
                            _tipState.value = TipState.Bootstrapping("📦 Importing blockchain data...")
                        }
                        "Syncing", "CaughtUp" -> {
                            if (tip.slot > 0) {
                                _tipState.value = TipState.Success(tip)
                            } else {
                                _tipState.value = TipState.Bootstrapping("🔌 Connecting to peers...")
                            }
                        }
                        else -> {
                            if (tip.slot > 0) {
                                _tipState.value = TipState.Success(tip)
                            } else {
                                _tipState.value = TipState.Bootstrapping("⏳ Starting node...")
                            }
                        }
                    }
                } catch (e: Exception) {
                    _tipState.value = TipState.Error("Polling error: ${e.message}")
                }
                
                delay(1000) // Poll every second for faster UI updates
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        stopNode()
    }
}

class AmaruViewModelFactory(private val context: Context) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return AmaruViewModel(context) as T
    }
}
