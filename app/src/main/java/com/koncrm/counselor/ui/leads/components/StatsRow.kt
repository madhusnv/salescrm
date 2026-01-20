package com.koncrm.counselor.ui.leads.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.koncrm.counselor.recordings.RecordingState
import com.koncrm.counselor.work.CallLogSyncStats

private val GradientBlue = Color(0xFF3B82F6)
private val GradientIndigo = Color(0xFF6366F1)
private val GradientPurple = Color(0xFF8B5CF6)
private val AccentRed = Color(0xFFEF4444)

@Composable
fun StatsRow(
    syncStats: CallLogSyncStats,
    recordingState: RecordingState,
    onConsentChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Sync Stats Card
        StatCard(
            title = "Call Sync",
            value = "${syncStats.syncedCount}",
            subtitle = "synced today",
            icon = Icons.Default.Refresh,
            gradientColors = listOf(GradientBlue, GradientIndigo),
            modifier = Modifier.weight(1f)
        )

        // Recording Card
        RecordingCard(
            recordingState = recordingState,
            onConsentChange = onConsentChange,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String,
    subtitle: String,
    icon: ImageVector,
    gradientColors: List<Color>,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(gradientColors.map { it.copy(alpha = 0.12f) })
                )
                .padding(16.dp)
        ) {
            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = gradientColors.first(),
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = title,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    text = value,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = gradientColors.first()
                )
                
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                )
            }
        }
    }
}

@Composable
private fun RecordingCard(
    recordingState: RecordingState,
    onConsentChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val isRecording = recordingState.lastStatus == "recording"
    val gradientColors = if (isRecording) {
        listOf(AccentRed, Color(0xFFF97316))
    } else {
        listOf(GradientIndigo, GradientPurple)
    }

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(gradientColors.map { it.copy(alpha = 0.12f) })
                )
                .padding(16.dp)
        ) {
            Column {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Phone,
                            contentDescription = null,
                            tint = gradientColors.first(),
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = "Recording",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    
                    Switch(
                        checked = recordingState.consentGranted,
                        onCheckedChange = onConsentChange,
                        modifier = Modifier.scale(0.8f),
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = gradientColors.first(),
                            checkedTrackColor = gradientColors.first().copy(alpha = 0.3f)
                        )
                    )
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    text = if (isRecording) "Recording" else if (recordingState.consentGranted) "Ready" else "Off",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = gradientColors.first()
                )
                
                if (isRecording) {
                    Text(
                        text = "🔴 Live",
                        style = MaterialTheme.typography.labelSmall,
                        color = AccentRed
                    )
                }
            }
        }
    }
}
