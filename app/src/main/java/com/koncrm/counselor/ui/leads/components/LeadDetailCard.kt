package com.koncrm.counselor.ui.leads.components

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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

private val AccentColor = Color(0xFFE67E22)
private val AccentLight = Color(0xFFF39C12)
private val IST_ZONE: ZoneId = ZoneId.of("Asia/Kolkata")

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
    val scrollState = rememberScrollState()

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 12.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(scrollState)
                .padding(24.dp)
        ) {
            // Close button row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(32.dp)
                        .background(
                            colors.surfaceVariant.copy(alpha = 0.5f),
                            CircleShape
                        )
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = colors.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // Avatar + Name section
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Avatar
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(
                                listOf(AccentColor, AccentLight)
                            )
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = detail.lead.studentName.take(2).uppercase(),
                        style = MaterialTheme.typography.headlineSmall,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(modifier = Modifier.width(16.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = detail.lead.studentName,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = colors.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Call button
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = AccentColor,
                        modifier = Modifier.clickable {
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${detail.lead.phoneNumber}"))
                            context.startActivity(intent)
                        }
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Call,
                                contentDescription = "Call",
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = detail.lead.phoneNumber,
                                style = MaterialTheme.typography.labelLarge,
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Stats Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                StatCard(
                    label = "Last Activity",
                    value = formatShortDate(detail.lastActivityAt) ?: "—",
                    modifier = Modifier.weight(1f)
                )
                StatCard(
                    label = "Next Follow-up",
                    value = formatShortDate(detail.nextFollowUpAt) ?: "—",
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Status section
            Text(
                text = "Status",
                style = MaterialTheme.typography.labelMedium,
                color = colors.onSurface.copy(alpha = 0.5f),
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.sp
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Scrollable status buttons
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                val statuses = listOf(
                    "new" to "New",
                    "contacted" to "Contacted",
                    "follow_up" to "Follow up",
                    "applied" to "Applied",
                    "not_interested" to "Not interested"
                )
                statuses.forEach { (status, label) ->
                    val isSelected = status == detail.lead.status
                    StatusChip(
                        label = label,
                        isSelected = isSelected,
                        enabled = !isSelected && !isUpdatingStatus,
                        onClick = { onUpdateStatus(status) }
                    )
                }
            }

            Spacer(modifier = Modifier.height(28.dp))

            // Tabs - scrollable
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                val tabs = listOf("Activity", "Follow-ups", "Calls", "Recordings")
                tabs.forEachIndexed { index, title ->
                    val isSelected = index == selectedTab
                    TabChip(
                        label = title,
                        isSelected = isSelected,
                        onClick = { onTabSelected(index) }
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
            
            HorizontalDivider(color = colors.outlineVariant.copy(alpha = 0.3f))

            Spacer(modifier = Modifier.height(20.dp))

            // Tab content
            when (selectedTab) {
                0 -> ActivitySection(
                    activities = detail.activities,
                    noteText = noteText,
                    isSaving = isSavingNote,
                    onNoteChange = onNoteChange,
                    onSubmit = onSubmitNote
                )
                1 -> FollowupSection(
                    followups = detail.followups,
                    dueAtMillis = followupDueAtMillis,
                    note = followupNote,
                    isSaving = isSchedulingFollowup,
                    onPickDate = onPickFollowupDate,
                    onNoteChange = onFollowupNoteChange,
                    onSchedule = onScheduleFollowup
                )
                2 -> CallsSection(
                    callLogs = callLogs,
                    filter = callLogFilter,
                    hasMore = hasMoreCallLogs,
                    onFilterChange = onCallLogFilterChange,
                    onLoadMore = onLoadMoreCallLogs
                )
                3 -> RecordingsSection(recordings = detail.recordings)
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

@Composable
private fun StatCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    val colors = MaterialTheme.colorScheme
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        color = colors.surfaceVariant.copy(alpha = 0.4f)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = colors.onSurface.copy(alpha = 0.5f),
                fontWeight = FontWeight.Medium
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.bodyLarge,
                color = colors.onSurface,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun StatusChip(
    label: String,
    isSelected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = if (isSelected) AccentColor else colors.surfaceVariant,
        shadowElevation = if (isSelected) 4.dp else 0.dp,
        modifier = Modifier.clickable(enabled = enabled, onClick = onClick)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = if (isSelected) Color.White else colors.onSurface.copy(alpha = 0.7f),
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
        )
    }
}

@Composable
private fun TabChip(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = if (isSelected) AccentColor else Color.Transparent,
        border = if (!isSelected) ButtonDefaults.outlinedButtonBorder(enabled = true) else null,
        modifier = Modifier.clickable(onClick = onClick)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = if (isSelected) Color.White else colors.onSurface.copy(alpha = 0.6f),
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
        )
    }
}

@Composable
private fun ActivitySection(
    activities: List<LeadActivity>,
    noteText: String,
    isSaving: Boolean,
    onNoteChange: (String) -> Unit,
    onSubmit: () -> Unit
) {
    val colors = MaterialTheme.colorScheme

    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        // Add note input
        OutlinedTextField(
            value = noteText,
            onValueChange = onNoteChange,
            placeholder = { Text("Add a note...") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AccentColor,
                cursorColor = AccentColor
            ),
            minLines = 2,
            maxLines = 4
        )

        Button(
            onClick = onSubmit,
            enabled = noteText.isNotBlank() && !isSaving,
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AccentColor),
            modifier = Modifier.align(Alignment.End)
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

        if (activities.isNotEmpty()) {
            Text(
                text = "Recent Activity",
                style = MaterialTheme.typography.labelMedium,
                color = colors.onSurface.copy(alpha = 0.5f),
                fontWeight = FontWeight.SemiBold
            )

            activities.take(5).forEach { activity ->
                ActivityItem(activity)
            }
        } else {
            EmptyState("No activity yet")
        }
    }
}

@Composable
private fun ActivityItem(activity: LeadActivity) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                colors.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(12.dp)
            )
            .padding(14.dp),
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(AccentColor)
                .offset(y = 4.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = activity.type.replace("_", " ").replaceFirstChar { it.uppercase() },
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = colors.onSurface
            )
            activity.body?.let { body ->
                Text(
                    text = body,
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(top = 4.dp),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        formatShortDate(activity.occurredAt)?.let { time ->
            Text(
                text = time,
                style = MaterialTheme.typography.labelSmall,
                color = colors.onSurface.copy(alpha = 0.4f)
            )
        }
    }
}

@Composable
private fun FollowupSection(
    followups: List<LeadFollowup>,
    dueAtMillis: Long?,
    note: String,
    isSaving: Boolean,
    onPickDate: () -> Unit,
    onNoteChange: (String) -> Unit,
    onSchedule: () -> Unit
) {
    val colors = MaterialTheme.colorScheme

    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        // Schedule new followup
        Text(
            text = "Schedule Follow-up",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = colors.onSurface
        )

        OutlinedButton(
            onClick = onPickDate,
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                Icons.Default.DateRange,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = formatEpochMillis(dueAtMillis) ?: "Pick date & time",
                fontWeight = FontWeight.Medium
            )
        }

        OutlinedTextField(
            value = note,
            onValueChange = onNoteChange,
            placeholder = { Text("Optional note") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            minLines = 2
        )

        Button(
            onClick = onSchedule,
            enabled = dueAtMillis != null && !isSaving,
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AccentColor),
            modifier = Modifier.fillMaxWidth()
        ) {
            if (isSaving) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(if (isSaving) "Scheduling..." else "Schedule Follow-up")
        }

        if (followups.isNotEmpty()) {
            HorizontalDivider(
                color = colors.outlineVariant.copy(alpha = 0.3f),
                modifier = Modifier.padding(vertical = 8.dp)
            )

            Text(
                text = "Scheduled",
                style = MaterialTheme.typography.labelMedium,
                color = colors.onSurface.copy(alpha = 0.5f),
                fontWeight = FontWeight.SemiBold
            )

            followups.take(3).forEach { followup ->
                FollowupItem(followup)
            }
        }
    }
}

@Composable
private fun FollowupItem(followup: LeadFollowup) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                colors.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(12.dp)
            )
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.DateRange,
            contentDescription = null,
            tint = AccentColor,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = formatShortDate(followup.dueAt) ?: "—",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            followup.note?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.onSurface.copy(alpha = 0.6f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        StatusPill(status = followup.status)
    }
}

@Composable
private fun CallsSection(
    callLogs: List<CallLogEntry>,
    filter: String,
    hasMore: Boolean,
    onFilterChange: (String) -> Unit,
    onLoadMore: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // Filter chips
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            val filters = listOf("" to "All", "incoming" to "Incoming", "outgoing" to "Outgoing", "missed" to "Missed")
            filters.forEach { (value, label) ->
                val isSelected = filter == value
                FilterChip(
                    selected = isSelected,
                    onClick = { onFilterChange(value) },
                    label = { Text(label) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = AccentColor,
                        selectedLabelColor = Color.White
                    )
                )
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
                TextButton(
                    onClick = onLoadMore,
                    modifier = Modifier.align(Alignment.CenterHorizontally)
                ) {
                    Text("Load more", color = AccentColor, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun CallLogItem(call: CallLogEntry) {
    val colors = MaterialTheme.colorScheme
    val iconColor = when (call.callType) {
        "incoming" -> Color(0xFF10B981)
        "outgoing" -> Color(0xFF3B82F6)
        "missed" -> Color(0xFFEF4444)
        else -> colors.onSurface
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                colors.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(12.dp)
            )
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Call,
            contentDescription = call.callType,
            tint = iconColor,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = call.callType.replaceFirstChar { it.uppercase() },
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = formatShortDate(call.startedAt) ?: "—",
                style = MaterialTheme.typography.labelSmall,
                color = colors.onSurface.copy(alpha = 0.5f)
            )
        }
        Text(
            text = formatDuration(call.durationSeconds ?: 0),
            style = MaterialTheme.typography.labelMedium,
            color = colors.onSurface.copy(alpha = 0.6f),
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun RecordingsSection(recordings: List<RecordingEntry>) {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
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
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                colors.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(12.dp)
            )
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.PlayArrow,
            contentDescription = null,
            tint = AccentColor,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = formatDuration(recording.durationSeconds ?: 0) + " recording",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = formatShortDate(recording.recordedAt) ?: "—",
                style = MaterialTheme.typography.labelSmall,
                color = colors.onSurface.copy(alpha = 0.5f)
            )
        }
        recording.fileUrl?.let { url ->
            FilledTonalButton(
                onClick = {
                    val fullUrl = if (url.startsWith("http")) url else "${ApiConfig.BASE_URL}$url"
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(fullUrl))
                    context.startActivity(intent)
                },
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = AccentColor.copy(alpha = 0.15f)
                )
            ) {
                Icon(
                    Icons.Default.PlayArrow,
                    contentDescription = "Play",
                    modifier = Modifier.size(16.dp),
                    tint = AccentColor
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text("Play", color = AccentColor, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun EmptyState(message: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 32.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
        )
    }
}

// Utility functions
private fun formatShortDate(isoString: String?): String? {
    if (isoString.isNullOrBlank() || isoString == "null") return null
    return try {
        val instant = Instant.parse(isoString)
        val formatter = DateTimeFormatter.ofPattern("dd MMM, HH:mm").withZone(IST_ZONE)
        formatter.format(instant)
    } catch (e: Exception) {
        null
    }
}

private fun formatEpochMillis(millis: Long?): String? {
    if (millis == null || millis == 0L) return null
    val instant = Instant.ofEpochMilli(millis)
    val formatter = DateTimeFormatter.ofPattern("dd MMM, HH:mm").withZone(IST_ZONE)
    return formatter.format(instant)
}

private fun formatDuration(seconds: Long): String {
    val mins = seconds / 60
    val secs = seconds % 60
    return if (mins > 0) "${mins}m ${secs}s" else "${secs}s"
}

fun pickFollowupDateTime(
    context: Context,
    currentMillis: Long?,
    onSelected: (Long) -> Unit
) {
    val now = Instant.ofEpochMilli(currentMillis ?: System.currentTimeMillis())
        .atZone(IST_ZONE)

    DatePickerDialog(
        context,
        { _, year, month, day ->
            TimePickerDialog(
                context,
                { _, hour, minute ->
                    val dateTime = LocalDateTime.of(year, month + 1, day, hour, minute)
                    val millis = dateTime.atZone(IST_ZONE).toInstant().toEpochMilli()
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
