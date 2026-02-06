package com.amaruwear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.ExperimentalAnimationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.material.*
import com.amaruwear.composables.BootstrappingView
import com.amaruwear.composables.TipInfoDisplay

@OptIn(ExperimentalAnimationApi::class)
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        System.loadLibrary("amaru_wear")
        
        setContent {
            val viewModel = viewModel<AmaruViewModel>(
                factory = AmaruViewModelFactory(applicationContext)
            )
            AmaruApp(viewModel)
        }
    }
}

@Composable
fun AmaruApp(viewModel: AmaruViewModel) {
    val tipState by viewModel.tipState.collectAsState()

    MaterialTheme(
        colors = Colors(
            primary = Color(0xFF0033A0),
            secondary = Color(0xFF00D5FF),
            error = Color(0xFFFF3333)
        )
    ) {
        Scaffold(
            timeText = { TimeText() }
        ) {
            Box(
                modifier = Modifier.fillMaxSize()
            ) {
                // Logo and title centered at top, below the time display
                Row(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 32.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.amaru_logo),
                        contentDescription = "Amaru Logo",
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "AMARU",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }
                
                // Main content centered
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                        .padding(top = 36.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    when (val state = tipState) {
                        is TipState.Bootstrapping -> {
                            BootstrappingView(state.message)
                        }
                        is TipState.Success -> {
                            TipInfoDisplay(
                                slot = state.tip.slot.toULong(),
                                epoch = state.tip.epoch.toULong(),
                                blockNumber = state.tip.blockNumber.toULong(),
                                blockHash = state.tip.blockHash,
                                isSyncing = state.tip.isSyncing
                            )
                        }
                        is TipState.Error -> {
                            ErrorView(state.message)
                        }
                        TipState.Loading -> {
                            LoadingView()
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun LoadingView() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("⏳")
        Spacer(modifier = Modifier.height(8.dp))
        Text("Loading...", style = MaterialTheme.typography.caption1)
    }
}

@Composable
fun ErrorView(message: String) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("❌")
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            message,
            style = MaterialTheme.typography.caption1,
            color = Color(0xFFFF3333)
        )
    }
}
