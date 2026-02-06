package com.amaruwear.composables

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Text

@Composable
fun SyncStatusIndicator(status: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF001A40))
            .padding(8.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        val (indicator, color) = when {
            status.contains("Bootstrapping") -> "🔄" to Color(0xFFFFAA00)
            status.contains("Syncing") -> "⬇️" to Color(0xFF00D5FF)
            status.contains("CaughtUp") -> "✅" to Color(0xFF00DD00)
            status.contains("Error") -> "❌" to Color(0xFFFF3333)
            else -> "⏳" to Color.Gray
        }
        
        Text(indicator, fontSize = 12.sp)
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            status.replace("_", " "),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = color
        )
    }
}
