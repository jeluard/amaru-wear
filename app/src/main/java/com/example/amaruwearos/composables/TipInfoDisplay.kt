package com.amaruwear.composables

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Text

@Composable
fun TipInfoDisplay(slot: ULong, epoch: ULong, blockNumber: ULong, blockHash: String, isSyncing: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Status indicator - only show if caught up
        if (!isSyncing) {
            Text(
                "✅ Caught Up",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF00DD00)
            )
            Spacer(modifier = Modifier.height(6.dp))
        }
        
        // Slot
        Text("Slot", fontSize = 10.sp, color = Color.White.copy(alpha = 0.6f))
        Text(slot.toString(), fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color(0xFF00D5FF))
        
        Spacer(modifier = Modifier.height(10.dp))
        
        // Epoch and Block in a row
        Row(
            horizontalArrangement = Arrangement.SpaceEvenly,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Epoch", fontSize = 9.sp, color = Color.White.copy(alpha = 0.6f))
                Text(epoch.toString(), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color(0xFF00D5FF))
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Block", fontSize = 9.sp, color = Color.White.copy(alpha = 0.6f))
                Text(blockNumber.toString(), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color(0xFF00D5FF))
            }
        }
        
        Spacer(modifier = Modifier.height(10.dp))
        
        // Block hash - truncated with ellipsis
        val displayHash = if (blockHash.length > 16) {
            "${blockHash.take(8)}...${blockHash.takeLast(8)}"
        } else if (blockHash.isNotEmpty() && blockHash != "pending") {
            blockHash
        } else {
            "..."
        }
        Text(
            displayHash,
            fontSize = 9.sp,
            color = Color.White.copy(alpha = 0.5f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 8.dp)
        )
    }
}
