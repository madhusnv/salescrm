package com.koncrm.counselor.ui.leads.components

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.koncrm.counselor.leads.*
import com.koncrm.counselor.network.ApiConfig
import java.time.*
import java.time.format.DateTimeFormatter

private val GradientStart = Color(0xFF6366F1)
private val GradientEnd = Color(0xFF8B5CF6)

@Composable
fun LeadDetailCard(
    detail: LeadDetail,
    noteText: String,
    isSavingNote: Boolean,
    selectedTab: Int,
    followupDueAtMillis: Long?,
    followupNote: String,
    isSchedulingFollowup: Boolean,
    callLogs: List<CallLogEntry>,
    hasMoreCallLogs: Boolean,
    callLogFilter: String,
    isUpdatingStatus: Boolean,
    onNoteChange: (String) -> Unit,
    onSubmitNote: () -> Unit,
    onTabSelected: (Int) -> Unit,
    onUpdateStatus: (String) -> Unit,
    onPickFollowupDate: () -> Unit,
    onFollowupNoteChange: (String) -> Unit,
    onScheduleFollowup: () -> Unit,
    onCallLogFilterChange: (String) -> Unit,
    onLoadMoreCallLogs: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MaterialTheme.colorScheme
    val context = LocalContext.current

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            // Header with avatar, name, and close button
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top
            ) {
                // Avatar
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(Brush.linearGradient(listOf(GradientStart, GradientEnd))),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = detail.lead.studentName.take(2).uppercase(),
                        style = MaterialTheme.typography.titleLarge,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(modifier = Modifier.width(16.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = detail.lead.studentName,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = colors.onSurface
                    )
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(top = 4.dp)
                    ) {
                        // Call button
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = GradientStart.copy(alpha = 0.1f),
                            modifier = Modifier.clickable {
                                val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${detail.lead.phoneNumber}"))
                                context.startActivity(intent)
                            }
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Call,
                                    contentDescription = "Call",
                                    tint = GradientStart,
                                    modifier = Modifier.size(14.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = detail.lead.phoneNumber,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = GradientStart,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                        
                        StatusPill(status = detail.lead.status)
                    }
                }

                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = colors.onSurface.copy(alpha = 0.5f)
                    )
                }
            }

            // Stats chips
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatChip(
                    title = "Last Activity",
                    value = formatRelativeTime(detail.lastActivityAt) ?: "—",
                    modifier = Modifier.weight(1f)
                )
                StatChip(
                    title = "Next Follow-up",
                    value = formatRelativeTime(detail.nextFollowUpAt) ?: "—",
                    modifier = Modifier.weight(1f)
                )
            }

            // Status buttons
            StatusButtonRow(
                currentStatus = detail.lead.status,
                isUpdating = isUpdatingStatus,
                onUpdateStatus = onUpdateStatus
            )

            // Tabs
            TabRow(
                tabs = listOf("Notes", "Activity", "Follow-ups", "Calls", "Recordings"),
                selectedIndex = selectedTab,
                onSelected = onTabSelected
            )

            // Tab content
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
            ) {
                when (selectedTab) {
                    0 -> NoteInput(
                        noteText = noteText,
                        isSaving = isSavingNote,
                        onNoteChange = onNoteChange,
                        onSubmit = onSubmitNote
                    )
                    1 -> ActivityList(activities = detail.activities)
                    2 -> FollowupTab(
                        followups = detail.followups,
                        dueAtMillis = followupDueAtMillis,
                        note = followupNote,
                        isSaving = isSchedulingFollowup,
                        onPickDate = onPickFollowupDate,
                        onNoteChange = onFollowupNoteChange,
                        onSchedule = onScheduleFollowup
                    )
                    3 -> CallLogTab(
                        callLogs = callLogs,
                        filter = callLogFilter,
                        hasMore = hasMoreCallLogs,
                        onFilterChange = onCallLogFilterChange,
                        onLoadMore = onLoadMoreCallLogs
                    )
                    4 -> RecordingTab(recordings = detail.recordings)
                }
            }
        }
    }
}

@Composable
private fun StatChip(
    title: String,
    value: String,
    modifier: Modifier = Modifier
) {
    val displayValue = if (value.isBlank() || value == "null") "—" else value
    
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                letterSpacing = 0.5.sp
            )
            Text(
                text = displayValue,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
    }
}

@Composable
private fun StatusButtonRow(
    currentStatus: String,
    isUpdating: Boolean,
    onUpdateStatus: (String) -> Unit
) {
    val statuses = listOf(
        "new" to "New",
        "follow_up" to "Follow up",
        "applied" to "Applied",
        "not_interested" to "Not interested"
    )

    LazyRow(
        modifier = Modifier.padding(top = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(statuses.size) { index ->
            val (status, label) = statuses[index]
            val isSelected = status == currentStatus
            
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = if (isSelected) GradientStart else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                shadowElevation = if (isSelected) 4.dp else 0.dp,
                modifier = Modifier.clickable(enabled = !isSelected && !isUpdating) { 
                    onUpdateStatus(status) 
                }
            ) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelMedium,
                    color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
                )
            }
        }
    }
}

@Composable
private fun TabRow(
    tabs: List<String>,
    selectedIndex: Int,
    onSelected: (Int) -> Unit
) {
    Surface(
        modifier = Modifier
            .padding(top = 20.dp)
            .fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
    ) {
        Row(
            modifier = Modifier.padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            tabs.forEachIndexed { index, title ->
                val isSelected = index == selectedIndex
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .clickable { onSelected(index) },
                    shape = RoundedCornerShape(10.dp),
                    color = if (isSelected) GradientStart else Color.Transparent,
                    shadowElevation = if (isSelected) 2.dp else 0.dp
                ) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        maxLines = 1,
                        modifier = Modifier
                            .padding(vertical = 10.dp)
                            .fillMaxWidth()
                            .wrapContentWidth(Alignment.CenterHorizontally)
                    )
                }
            }
        }
    }
}

@Composable
private fun NoteInput(
    noteText: String,
    isSaving: Boolean,
    onNoteChange: (String) -> Unit,
    onSubmit: () -> Unit
) {
    Column {
        OutlinedTextField(
            value = noteText,
            onValueChange = onNoteChange,
            placeholder = { Text("Add a note...") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = GradientStart,
                cursorColor = GradientStart
            ),
            minLines = 3,
            maxLines = 5
        )
        
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp),
            horizontalArrangement = Arrangement.End
        ) {
            Button(
                onClick = onSubmit,
                enabled = noteText.isNotBlank() && !isSaving,
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = GradientStart)
            ) {
                if (isSaving) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        color = Color.White,
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text(if (isSaving) "Saving..." else "Save Note")
            }
        }
    }
}

@Composable
private fun ActivityList(activities: List<LeadActivity>) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (activities.isEmpty()) {
            EmptyState("No activity yet")
        } else {
            activities.take(5).forEach { activity ->
                ActivityItem(activity)
            }
        }
    }
}

@Composable
private fun ActivityItem(activity: LeadActivity) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(10.dp)
            )
            .padding(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(GradientStart)
                .offset(y = 4.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = activity.type.replace("_", " ").replaceFirstChar { it.uppercase() },
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            activity.body?.let { body ->
                Text(
                    text = body,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    modifier = Modifier.padding(top = 2.dp)
                )
            }
        }
        formatRelativeTime(activity.occurredAt)?.let { time ->
            Text(
                text = time,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
        }
    }
}

@Composable
private fun FollowupTab(
    followups: List<LeadFollowup>,
    dueAtMillis: Long?,
    note: String,
    isSaving: Boolean,
    onPickDate: () -> Unit,
    onNoteChange: (String) -> Unit,
    onSchedule: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // Existing followups
        if (followups.isNotEmpty()) {
            followups.take(3).forEach { followup ->
                FollowupItem(followup)
            }
        }

        // Schedule new followup
        Text(
            text = "Schedule Follow-up",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(top = 8.dp)
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedButton(
                onClick = onPickDate,
                shape = RoundedCornerShape(10.dp)
            ) {
                Icon(Icons.Default.DateRange, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text(formatEpochMillis(dueAtMillis) ?: "Pick date & time")
            }
        }

        OutlinedTextField(
            value = note,
            onValueChange = onNoteChange,
            placeholder = { Text("Optional note") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Button(
            onClick = onSchedule,
            enabled = dueAtMillis != null && !isSaving,
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = GradientStart)
        ) {
            if (isSaving) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), color = Color.White, strokeWidth = 2.dp)
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(if (isSaving) "Scheduling..." else "Schedule")
        }
    }
}

@Composable
private fun FollowupItem(followup: LeadFollowup) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(10.dp)
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.DateRange,
            contentDescription = null,
            tint = GradientStart,
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = formatRelativeTime(followup.dueAt) ?: "—",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            followup.note?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
        }
        StatusPill(status = followup.status)
    }
}

@Composable
private fun CallLogTab(
    callLogs: List<CallLogEntry>,
    filter: String,
    hasMore: Boolean,
    onFilterChange: (String) -> Unit,
    onLoadMore: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        // Filter chips
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            val filters = listOf("" to "All", "incoming" to "Incoming", "outgoing" to "Outgoing", "missed" to "Missed")
            items(filters.size) { index ->
                val (value, label) = filters[index]
                val isSelected = filter == value
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = if (isSelected) GradientStart.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    modifier = Modifier.clickable { onFilterChange(value) }
                ) {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelMedium,
                        color = if (isSelected) GradientStart else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                    )
                }
            }
        }

        val filteredLogs = if (filter.isBlank()) callLogs else callLogs.filter { it.callType == filter }

        if (filteredLogs.isEmpty()) {
            EmptyState("No calls logged")
        } else {
            filteredLogs.take(5).forEach { call ->
                CallLogItem(call)
            }
            if (hasMore) {
                TextButton(onClick = onLoadMore) {
                    Text("Load more", color = GradientStart)
                }
            }
        }
    }
}

@Composable
private fun CallLogItem(call: CallLogEntry) {
    val iconColor = when (call.callType) {
        "incoming" -> Color(0xFF10B981)
        "outgoing" -> Color(0xFF3B82F6)
        "missed" -> Color(0xFFEF4444)
        else -> MaterialTheme.colorScheme.onSurface
    }
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(10.dp)
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Call,
            contentDescription = call.callType,
            tint = iconColor,
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = call.callType.replaceFirstChar { it.uppercase() },
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = formatRelativeTime(call.startedAt) ?: "—",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
        }
        Text(
            text = "${call.durationSeconds ?: 0}s",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
    }
}

@Composable
private fun RecordingTab(recordings: List<RecordingEntry>) {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (recordings.isEmpty()) {
            EmptyState("No recordings")
        } else {
            recordings.take(5).forEach { recording ->
                RecordingItem(recording, context)
            }
        }
    }
}

@Composable
private fun RecordingItem(recording: RecordingEntry, context: Context) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(10.dp)
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.PlayArrow,
            contentDescription = null,
            tint = GradientStart,
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "${recording.durationSeconds ?: 0}s recording",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = formatRelativeTime(recording.recordedAt) ?: "—",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
        }
        recording.fileUrl?.let { url ->
            TextButton(
                onClick = {
                    val fullUrl = if (url.startsWith("http")) url else "${ApiConfig.BASE_URL}$url"
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(fullUrl))
                    context.startActivity(intent)
                }
            ) {
                Icon(Icons.Default.PlayArrow, contentDescription = "Play", modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Play", color = GradientStart)
            }
        }
    }
}

@Composable
private fun EmptyState(message: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
        )
    }
}

// Utility functions
private fun formatRelativeTime(isoString: String?): String? {
    if (isoString.isNullOrBlank() || isoString == "null") return null
    return try {
        val instant = Instant.parse(isoString)
        val formatter = DateTimeFormatter.ofPattern("dd MMM, HH:mm").withZone(ZoneId.systemDefault())
        formatter.format(instant)
    } catch (e: Exception) {
        null
    }
}

private fun formatEpochMillis(millis: Long?): String? {
    if (millis == null || millis == 0L) return null
    val instant = Instant.ofEpochMilli(millis)
    val formatter = DateTimeFormatter.ofPattern("dd MMM, HH:mm").withZone(ZoneId.systemDefault())
    return formatter.format(instant)
}

fun pickFollowupDateTime(
    context: Context,
    currentMillis: Long?,
    onSelected: (Long) -> Unit
) {
    val now = Instant.ofEpochMilli(currentMillis ?: System.currentTimeMillis())
        .atZone(ZoneId.systemDefault())

    DatePickerDialog(
        context,
        { _, year, month, day ->
            TimePickerDialog(
                context,
                { _, hour, minute ->
                    val dateTime = LocalDateTime.of(year, month + 1, day, hour, minute)
                    val millis = dateTime.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                    onSelected(millis)
                },
                now.hour,
                now.minute,
                false
            ).show()
        },
        now.year,
        now.monthValue - 1,
        now.dayOfMonth
    ).show()
}
