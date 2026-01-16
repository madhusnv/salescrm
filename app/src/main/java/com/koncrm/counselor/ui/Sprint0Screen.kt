package com.koncrm.counselor.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.koncrm.counselor.work.CallLogSyncScheduler

@Composable
fun Sprint0Screen() {
    val context = LocalContext.current
    val colors = MaterialTheme.colorScheme
    val scrollState = rememberScrollState()
    LaunchedEffect(Unit) {
        CallLogSyncScheduler.schedule(context)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        colors.primary.copy(alpha = 0.08f),
                        colors.background
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(scrollState)
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Column {
                Text(
                    text = "KonCRM Counselor",
                    style = MaterialTheme.typography.headlineMedium,
                    color = colors.onBackground
                )
                Text(
                    text = "Today’s focus: calls, notes, and follow-ups.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = colors.onBackground.copy(alpha = 0.7f),
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            Card(
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = colors.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Sprint 0 status",
                        style = MaterialTheme.typography.titleMedium,
                        color = colors.onSurface
                    )
                    Text(
                        text = "Call tracking and sync modules are queued next. You’ll see lead activity here once the pipeline is live.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.onSurface.copy(alpha = 0.7f),
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = colors.surface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Sync",
                            style = MaterialTheme.typography.labelLarge,
                            color = colors.onSurface.copy(alpha = 0.6f)
                        )
                        Text(
                            text = "Scheduled",
                            style = MaterialTheme.typography.titleMedium,
                            color = colors.onSurface
                        )
                    }
                }
                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = colors.surface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Calls today",
                            style = MaterialTheme.typography.labelLarge,
                            color = colors.onSurface.copy(alpha = 0.6f)
                        )
                        Text(
                            text = "--",
                            style = MaterialTheme.typography.titleMedium,
                            color = colors.onSurface
                        )
                    }
                }
            }

            Card(
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = colors.surface)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Next actions",
                        style = MaterialTheme.typography.titleMedium,
                        color = colors.onSurface
                    )
                    Column(modifier = Modifier.padding(top = 12.dp)) {
                        Row(modifier = Modifier.padding(bottom = 10.dp)) {
                            Box(
                                modifier = Modifier
                                    .height(8.dp)
                                    .width(8.dp)
                                    .background(colors.tertiary, RoundedCornerShape(4.dp))
                            )
                            Text(
                                text = "Review pending call logs once enabled.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = colors.onSurface.copy(alpha = 0.7f),
                                modifier = Modifier.padding(start = 10.dp)
                            )
                        }
                        Row {
                            Box(
                                modifier = Modifier
                                    .height(8.dp)
                                    .width(8.dp)
                                    .background(colors.tertiary, RoundedCornerShape(4.dp))
                            )
                            Text(
                                text = "Keep permissions enabled for call tracking.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = colors.onSurface.copy(alpha = 0.7f),
                                modifier = Modifier.padding(start = 10.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
