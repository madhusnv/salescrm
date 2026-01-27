package com.koncrm.counselor.ui

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.koncrm.counselor.network.CounselorCallStats
import com.koncrm.counselor.network.StatsApi
import java.time.LocalTime

// Premium color palette
private val AccentOrange = Color(0xFFE67E22)
private val AccentGreen = Color(0xFF10B981)
private val AccentBlue = Color(0xFF3B82F6)
private val AccentRed = Color(0xFFEF4444)
private val AccentPurple = Color(0xFF8B5CF6)

@Composable
fun DashboardScreen(
    modifier: Modifier = Modifier,
    onOpenCallStats: () -> Unit = {}
) {
    val colors = MaterialTheme.colorScheme
    val scrollState = rememberScrollState()
    
    val statsApi = remember { StatsApi() }
    val stats = remember { mutableStateOf<CounselorCallStats?>(null) }
    val isLoading = remember { mutableStateOf(true) }
    val error = remember { mutableStateOf<String?>(null) }
    
    // Load stats
    LaunchedEffect(Unit) {
        isLoading.value = true
        statsApi.getCounselorStats("today")
            .onSuccess { stats.value = it }
            .onFailure { error.value = it.message }
        isLoading.value = false
    }
    
    // Time-based greeting
    val greeting = remember {
        when (LocalTime.now().hour) {
            in 5..11 -> "Good morning"
            in 12..16 -> "Good afternoon"
            else -> "Good evening"
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(colors.background)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
        ) {
            // Header with gradient
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                AccentOrange.copy(alpha = 0.15f),
                                colors.background
                            )
                        )
                    )
                    .padding(24.dp)
            ) {
                Column {
                    Text(
                        text = "$greeting! 👋",
                        style = MaterialTheme.typography.headlineLarge,
                        fontWeight = FontWeight.Bold,
                        color = colors.onBackground
                    )
                    
                    Spacer(modifier = Modifier.height(8.dp))
                    
                    // Quick summary
                    if (stats.value != null) {
                        val s = stats.value!!
                        val summary = when {
                            s.totalCalls == 0 -> "Ready to start your day? Make your first call!"
                            s.missedCalls > 3 -> "You have ${s.missedCalls} missed calls to follow up"
                            s.totalCalls > 10 -> "Great work! You've made ${s.totalCalls} calls today 🔥"
                            else -> "You've made ${s.totalCalls} calls today"
                        }
                        Text(
                            text = summary,
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.onBackground.copy(alpha = 0.7f)
                        )
                    }
                }
            }
            
            Column(modifier = Modifier.padding(horizontal = 20.dp)) {
                // Loading state
                if (isLoading.value) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = AccentOrange)
                    }
                } else if (error.value != null) {
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = AccentRed.copy(alpha = 0.1f))
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Warning, null, tint = AccentRed)
                            Spacer(Modifier.width(12.dp))
                            Text("Unable to load stats", color = AccentRed)
                        }
                    }
                } else {
                    val s = stats.value ?: CounselorCallStats(0, 0, 0, 0, 0, 0)
                    
                    // Today's Performance Card
                    Text(
                        text = "TODAY'S PERFORMANCE",
                        style = MaterialTheme.typography.labelMedium,
                        color = colors.onBackground.copy(alpha = 0.5f),
                        letterSpacing = 1.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    
                    Spacer(modifier = Modifier.height(12.dp))
                    
                    // Main stats grid
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        MetricCard(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Outlined.Call,
                            iconBackground = AccentBlue,
                            value = s.totalCalls.toString(),
                            label = "Total Calls"
                        )
                        MetricCard(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Outlined.Phone,
                            iconBackground = AccentGreen,
                            value = s.outgoingCalls.toString(),
                            label = "Calls Made"
                        )
                    }
                    
                    Spacer(modifier = Modifier.height(12.dp))
                    
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        MetricCard(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Outlined.Warning,
                            iconBackground = AccentRed,
                            value = s.missedCalls.toString(),
                            label = "Missed",
                            highlight = s.missedCalls > 0
                        )
                        MetricCard(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Outlined.Person,
                            iconBackground = AccentPurple,
                            value = s.leadsAssigned.toString(),
                            label = "New Leads"
                        )
                    }
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    // Talk Time Card
                    TalkTimeCard(durationSeconds = s.totalDurationSeconds)
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    // Quick Actions
                    Text(
                        text = "QUICK ACTIONS",
                        style = MaterialTheme.typography.labelMedium,
                        color = colors.onBackground.copy(alpha = 0.5f),
                        letterSpacing = 1.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    
                    Spacer(modifier = Modifier.height(12.dp))
                    
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        QuickActionButton(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Default.Info,
                            label = "View Stats",
                            onClick = onOpenCallStats
                        )
                        QuickActionButton(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Default.DateRange,
                            label = "Follow-ups",
                            onClick = { /* TODO */ }
                        )
                    }
                    
                    Spacer(modifier = Modifier.height(32.dp))
                }
            }
        }
    }
}

@Composable
private fun MetricCard(
    modifier: Modifier = Modifier,
    icon: ImageVector,
    iconBackground: Color,
    value: String,
    label: String,
    highlight: Boolean = false
) {
    val colors = MaterialTheme.colorScheme
    
    Card(
        modifier = modifier.animateContentSize(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (highlight) iconBackground.copy(alpha = 0.08f) else colors.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(iconBackground.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconBackground,
                    modifier = Modifier.size(24.dp)
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Text(
                text = value,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = if (highlight) iconBackground else colors.onSurface
            )
            
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onSurface.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
private fun TalkTimeCard(durationSeconds: Long) {
    val colors = MaterialTheme.colorScheme
    val hours = durationSeconds / 3600
    val minutes = (durationSeconds % 3600) / 60
    val secs = durationSeconds % 60
    
    val formatted = when {
        hours > 0 -> "${hours}h ${minutes}m"
        minutes > 0 -> "${minutes}m ${secs}s"
        else -> "${secs}s"
    }
    
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = AccentOrange.copy(alpha = 0.1f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(AccentOrange.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Notifications,
                    contentDescription = null,
                    tint = AccentOrange,
                    modifier = Modifier.size(28.dp)
                )
            }
            
            Spacer(modifier = Modifier.width(16.dp))
            
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Total Talk Time",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.onSurface.copy(alpha = 0.6f)
                )
                Text(
                    text = formatted,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = AccentOrange
                )
            }
            
            // Mini progress indicator
            if (durationSeconds > 0) {
                val progress = minOf(durationSeconds.toFloat() / (60 * 60), 1f) // 1 hour target
                CircularProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.size(48.dp),
                    color = AccentOrange,
                    trackColor = AccentOrange.copy(alpha = 0.2f),
                    strokeWidth = 4.dp
                )
            }
        }
    }
}

@Composable
private fun QuickActionButton(
    modifier: Modifier = Modifier,
    icon: ImageVector,
    label: String,
    onClick: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    
    OutlinedCard(
        modifier = modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = colors.surface)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = AccentOrange,
                modifier = Modifier.size(28.dp)
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = colors.onSurface,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center
            )
        }
    }
}
