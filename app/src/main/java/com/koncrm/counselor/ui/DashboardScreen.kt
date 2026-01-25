package com.koncrm.counselor.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.koncrm.counselor.network.ChannelEvent
import com.koncrm.counselor.network.ChannelManager
import com.koncrm.counselor.recordings.RecordingStore
import com.koncrm.counselor.work.CallLogSyncStats
import com.koncrm.counselor.work.CallLogSyncStore
import com.koncrm.counselor.work.CallLogSyncWorker
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun DashboardScreen(
    modifier: Modifier = Modifier,
    onOpenCallStats: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val scrollState = rememberScrollState()

    val syncStore = remember { CallLogSyncStore(context) }
    val stats by syncStore.statsFlow().collectAsState(initial = CallLogSyncStats(null, 0, 0, 0))

    val recordingStore = remember { RecordingStore(context) }
    val recordingState by recordingStore.stateFlow().collectAsState(initial = null)

    val isSyncing = remember { mutableStateOf(false) }

    // Real-time channel connection
    val channelManager = remember { ChannelManager.getInstance(context) }
    val isChannelConnected by channelManager.isConnected.collectAsState()
    val recentEvents = remember { mutableStateOf<List<String>>(emptyList()) }

    // Listen for real-time events
    LaunchedEffect(Unit) {
        channelManager.events.collect { event ->
            when (event) {
                is ChannelEvent.CallSynced -> {
                    recentEvents.value = (listOf("📞 Call synced: ${event.phoneNumber}") + recentEvents.value).take(5)
                }
                is ChannelEvent.LeadUpdated -> {
                    recentEvents.value = (listOf("📝 Lead updated: ${event.studentName}") + recentEvents.value).take(5)
                }
                is ChannelEvent.LeadAssigned -> {
                    recentEvents.value = (listOf("🎯 New lead: ${event.studentName}") + recentEvents.value).take(5)
                }
                is ChannelEvent.RecordingUploaded -> {
                    val duration = "${event.durationSeconds}s"
                    recentEvents.value = (listOf("🎙️ Recording uploaded: $duration") + recentEvents.value).take(5)
                }
                is ChannelEvent.RecordingStatus -> {
                    recentEvents.value = (listOf("🎙️ Recording ${event.status}") + recentEvents.value).take(5)
                }
                else -> {}
            }
        }
    }

    Box(
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
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(20.dp)
        ) {
            // Header
            Text(
                text = "Dashboard",
                style = MaterialTheme.typography.headlineLarge,
                color = colors.onBackground,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "Call sync & activity overview",
                style = MaterialTheme.typography.bodyLarge,
                color = colors.onBackground.copy(alpha = 0.6f),
                modifier = Modifier.padding(top = 4.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))

            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = colors.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Call Stats",
                        style = MaterialTheme.typography.titleMedium,
                        color = colors.onSurface,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "See today’s calls, missed calls, and leads assigned.",
                        style = MaterialTheme.typography.bodySmall,
                        color = colors.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.padding(top = 4.dp)
                    )
                    Button(
                        onClick = onOpenCallStats,
                        colors = ButtonDefaults.buttonColors(containerColor = colors.primary),
                        modifier = Modifier.padding(top = 12.dp)
                    ) {
                        Text(text = "View Call Stats")
                    }
                }
            }

            // Sync Status Card
            SyncStatusCard(
                stats = stats,
                isSyncing = isSyncing.value,
                isChannelConnected = isChannelConnected,
                onSyncNow = {
                    isSyncing.value = true
                    scope.launch {
                        val request = OneTimeWorkRequestBuilder<CallLogSyncWorker>().build()
                        WorkManager.getInstance(context).enqueue(request)
                        kotlinx.coroutines.delay(2000)
                        isSyncing.value = false
                    }
                }
            )

            // Recent Events (real-time)
            if (recentEvents.value.isNotEmpty()) {
                Spacer(modifier = Modifier.height(16.dp))
                RecentEventsCard(events = recentEvents.value)
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Stats Grid
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatCard(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Default.CheckCircle,
                    iconColor = Color(0xFF4CAF50),
                    value = stats.syncedCount.toString(),
                    label = "Synced",
                    sublabel = "calls uploaded"
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Default.Refresh,
                    iconColor = Color(0xFFFF9800),
                    value = stats.duplicateCount.toString(),
                    label = "Duplicates",
                    sublabel = "already in system"
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatCard(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Default.Warning,
                    iconColor = Color(0xFFF44336),
                    value = stats.failureCount.toString(),
                    label = "Failed",
                    sublabel = "needs retry"
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Default.Call,
                    iconColor = colors.primary,
                    value = (stats.syncedCount + stats.duplicateCount).toString(),
                    label = "Total",
                    sublabel = "calls processed"
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Recording Status
            RecordingStatusSection(
                consentGranted = recordingState?.consentGranted ?: false
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Quick Tips
            QuickTipsCard()
        }
    }
}

@Composable
private fun SyncStatusCard(
    stats: CallLogSyncStats,
    isSyncing: Boolean,
    isChannelConnected: Boolean,
    onSyncNow: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val lastSyncFormatted = if ((stats.lastSyncedAt ?: 0L) > 0L) {
        val formatter = SimpleDateFormat("MMM dd, hh:mm a", Locale.getDefault())
        formatter.format(Date(stats.lastSyncedAt ?: 0L))
    } else {
        "Never"
    }

    val statusColor = if (isChannelConnected) Color(0xFF4CAF50) else Color(0xFFFF9800)
    val statusText = if (isChannelConnected) "Live" else "Offline"

    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(20.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Call Sync",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.onSurface
                    )
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(top = 4.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(statusColor)
                        )
                        Text(
                            text = statusText,
                            style = MaterialTheme.typography.bodySmall,
                            color = statusColor,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.padding(start = 6.dp)
                        )
                    }
                }

                Button(
                    onClick = onSyncNow,
                    enabled = !isSyncing,
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = colors.primary,
                        contentColor = colors.onPrimary
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        text = if (isSyncing) "Syncing..." else "Sync Now",
                        modifier = Modifier.padding(start = 8.dp),
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Surface(
                shape = RoundedCornerShape(12.dp),
                color = colors.surfaceVariant.copy(alpha = 0.5f)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text(
                            text = "Last sync",
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.onSurface.copy(alpha = 0.5f)
                        )
                        Text(
                            text = lastSyncFormatted,
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.onSurface,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            text = "Interval",
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.onSurface.copy(alpha = 0.5f)
                        )
                        Text(
                            text = "Every 15 min",
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.onSurface,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StatCard(
    modifier: Modifier = Modifier,
    icon: ImageVector,
    iconColor: Color,
    value: String,
    label: String,
    sublabel: String
) {
    val colors = MaterialTheme.colorScheme

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(iconColor.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(22.dp)
                )
            }

            Text(
                text = value,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = colors.onSurface,
                modifier = Modifier.padding(top = 12.dp)
            )

            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = colors.onSurface
            )

            Text(
                text = sublabel,
                style = MaterialTheme.typography.bodySmall,
                color = colors.onSurface.copy(alpha = 0.5f)
            )
        }
    }
}

@Composable
private fun RecordingStatusSection(consentGranted: Boolean) {
    val colors = MaterialTheme.colorScheme

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Call Recording",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    color = colors.onSurface
                )
                Text(
                    text = if (consentGranted) "Consent given - recording enabled" else "Recording disabled",
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(top = 2.dp)
                )
            }

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(
                        if (consentGranted) Color(0xFF4CAF50).copy(alpha = 0.15f)
                        else colors.surfaceVariant
                    )
                    .padding(horizontal = 12.dp, vertical = 6.dp)
            ) {
                Text(
                    text = if (consentGranted) "Active" else "Off",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Medium,
                    color = if (consentGranted) Color(0xFF4CAF50) else colors.onSurface.copy(alpha = 0.6f)
                )
            }
        }
    }
}

@Composable
private fun QuickTipsCard() {
    val colors = MaterialTheme.colorScheme

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = colors.primary.copy(alpha = 0.08f)
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = "💡 Quick Tips",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = colors.onSurface
            )

            Spacer(modifier = Modifier.height(12.dp))

            TipItem("Calls sync automatically every 15 minutes")
            TipItem("Use 'Sync Now' to force immediate sync")
            TipItem("Enable recording consent in Settings for better lead tracking")
        }
    }
}

@Composable
private fun TipItem(text: String) {
    val colors = MaterialTheme.colorScheme

    Row(
        modifier = Modifier.padding(vertical = 4.dp),
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = "•",
            style = MaterialTheme.typography.bodyMedium,
            color = colors.primary,
            modifier = Modifier.padding(end = 8.dp, top = 2.dp)
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = colors.onSurface.copy(alpha = 0.8f)
        )
    }
}

@Composable
private fun RecentEventsCard(events: List<String>) {
    val colors = MaterialTheme.colorScheme

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = colors.primaryContainer.copy(alpha = 0.3f)
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF4CAF50))
                )
                Text(
                    text = "Live Activity",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.onSurface,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            events.forEach { event ->
                Text(
                    text = event,
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.onSurface.copy(alpha = 0.8f),
                    modifier = Modifier.padding(vertical = 2.dp)
                )
            }
        }
    }
}
