package com.koncrm.counselor.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.koncrm.counselor.network.CounselorCallStats
import com.koncrm.counselor.network.StatsApi

@Composable
fun CallStatsScreen(
    modifier: Modifier = Modifier,
    onBack: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val api = remember { StatsApi() }
    val stats = remember { mutableStateOf<CounselorCallStats?>(null) }
    val isLoading = remember { mutableStateOf(true) }
    val error = remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        isLoading.value = true
        error.value = null
        val result = api.getCounselorStats()
        result.onSuccess { stats.value = it }
            .onFailure { error.value = "Unable to load call stats" }
        isLoading.value = false
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        colors.primary.copy(alpha = 0.08f),
                        colors.background,
                        colors.background
                    )
                )
            )
            .padding(20.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.clickable { onBack() }
        ) {
            Icon(
                imageVector = Icons.Filled.ArrowBack,
                contentDescription = "Back",
                tint = colors.onBackground,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = "Back",
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onBackground.copy(alpha = 0.7f),
                modifier = Modifier.padding(start = 8.dp)
            )
        }

        Text(
            text = "Call Stats",
            style = MaterialTheme.typography.headlineLarge,
            color = colors.onBackground,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 16.dp)
        )
        Text(
            text = "Today’s call performance",
            style = MaterialTheme.typography.bodyLarge,
            color = colors.onBackground.copy(alpha = 0.6f),
            modifier = Modifier.padding(top = 4.dp)
        )

        Spacer(modifier = Modifier.height(20.dp))

        when {
            isLoading.value -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            error.value != null -> {
                Text(
                    text = error.value ?: "",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.error
                )
            }
            stats.value != null -> {
                val data = stats.value!!
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard(title = "Total Calls", value = data.totalCalls.toString())
                    StatCard(title = "Calls Made", value = data.outgoingCalls.toString())
                    StatCard(title = "Incoming Calls", value = data.incomingCalls.toString())
                    StatCard(title = "Missed Calls", value = data.missedCalls.toString())
                    StatCard(
                        title = "Total Duration",
                        value = formatDuration(data.totalDurationSeconds)
                    )
                    StatCard(title = "Leads Assigned Today", value = data.leadsAssigned.toString())
                }
            }
        }
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String
) {
    val colors = MaterialTheme.colorScheme
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall,
                color = colors.onSurface.copy(alpha = 0.6f)
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                color = colors.onSurface,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}

private fun formatDuration(seconds: Long): String {
    val safeSeconds = if (seconds < 0) 0 else seconds
    val hours = safeSeconds / 3600
    val minutes = (safeSeconds % 3600) / 60
    val secs = safeSeconds % 60
    return if (hours > 0) {
        String.format("%d:%02d:%02d", hours, minutes, secs)
    } else {
        String.format("%d:%02d", minutes, secs)
    }
}
