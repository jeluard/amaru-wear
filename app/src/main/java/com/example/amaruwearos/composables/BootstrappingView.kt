package com.amaruwear.composables

import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Text

@Composable
fun BootstrappingView(message: String) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val scale by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = EaseInOutCubic),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale"
    )
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("🔄", fontSize = 48.sp, modifier = Modifier.scale(scale))
        Spacer(modifier = Modifier.height(12.dp))
        Text("Bootstrapping", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color(0xFF00D5FF), textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(8.dp))
        Text(message, fontSize = 11.sp, color = Color.White.copy(alpha = 0.8f), textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 8.dp))
    }
}
