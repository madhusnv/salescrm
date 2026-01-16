package com.koncrm.counselor.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import android.content.Intent
import android.net.Uri
import com.koncrm.counselor.leads.LeadDetail
import com.koncrm.counselor.leads.LeadSummary
import com.koncrm.counselor.leads.University
import com.koncrm.counselor.network.LeadApi
import com.koncrm.counselor.recordings.RecordingState
import com.koncrm.counselor.recordings.RecordingStore
import com.koncrm.counselor.leads.RecordingEntry
import com.koncrm.counselor.network.ApiConfig
import com.koncrm.counselor.work.CallNoteStore
import com.koncrm.counselor.work.CallLogSyncStats
import com.koncrm.counselor.work.CallLogSyncStore
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import android.app.DatePickerDialog
import android.app.TimePickerDialog

@Composable
fun LeadHomeScreen(
    accessToken: String,
    modifier: Modifier = Modifier
) {
    val colors = MaterialTheme.colorScheme
    val context = LocalContext.current
    val leadApi = remember { LeadApi() }
    val scope = rememberCoroutineScope()
    val leadsState = remember { mutableStateOf<List<LeadSummary>>(emptyList()) }
    val selectedLead = remember { mutableStateOf<LeadDetail?>(null) }
    val isLoading = remember { mutableStateOf(true) }
    val isLoadingMore = remember { mutableStateOf(false) }
    val leadPage = remember { mutableStateOf(1) }
    val pageSize = 20
    val hasMoreLeads = remember { mutableStateOf(true) }
    val searchQuery = remember { mutableStateOf("") }
    val statusFilter = remember { mutableStateOf("") }
    val statusMessage = remember { mutableStateOf<String?>(null) }
    val error = remember { mutableStateOf<String?>(null) }
    val noteText = remember { mutableStateOf("") }
    val isSavingNote = remember { mutableStateOf(false) }
    val statusUpdating = remember { mutableStateOf(false) }
    val followupDueAtMillis = remember { mutableStateOf<Long?>(null) }
    val followupNote = remember { mutableStateOf("") }
    val followupSaving = remember { mutableStateOf(false) }
    val selectedTab = remember { mutableStateOf(0) }
    val pendingCallNote = remember { mutableStateOf<PendingCallNote?>(null) }
    val pendingCallText = remember { mutableStateOf("") }
    val pendingCallSaving = remember { mutableStateOf(false) }
    val pendingLeadName = remember { mutableStateOf("") }
    val pendingUniversityId = remember { mutableStateOf<Long?>(null) }
    val pendingUniversityMenuOpen = remember { mutableStateOf(false) }
    val universities = remember { mutableStateOf<List<University>>(emptyList()) }
    val syncStore = remember { CallLogSyncStore(context) }
    val callNoteStore = remember { CallNoteStore(context) }
    val recordingStore = remember { RecordingStore(context) }
    val syncStats by syncStore.statsFlow()
        .collectAsState(initial = CallLogSyncStats(null, 0, 0, 0))
    val recordingState by recordingStore.stateFlow()
        .collectAsState(initial = RecordingState(false, "idle", null, null))
    val callLogsState = remember { mutableStateOf<List<com.koncrm.counselor.leads.CallLogEntry>>(emptyList()) }
    val callLogPage = remember { mutableStateOf(1) }
    val hasMoreCallLogs = remember { mutableStateOf(true) }
    val callLogFilter = remember { mutableStateOf("") }

    LaunchedEffect(accessToken) {
        isLoading.value = true
        error.value = null
        val universitiesResult = leadApi.listUniversities(accessToken)
        universitiesResult.onSuccess {
            universities.value = it
            if (pendingUniversityId.value == null && it.isNotEmpty()) {
                pendingUniversityId.value = it.first().id
            }
        }
        loadLeads(
            api = leadApi,
            accessToken = accessToken,
            reset = true,
            leadsState = leadsState,
            leadPage = leadPage,
            hasMore = hasMoreLeads,
            isLoading = isLoading,
            error = error,
            pageSize = pageSize,
            statusFilter = statusFilter.value,
            searchQuery = searchQuery.value
        )
    }

    LaunchedEffect(accessToken) {
        callNoteStore.pendingFlow().collect { pending ->
            pending?.let {
                val phone = normalizePhone(it.phoneNumber)
                if (phone.isNotBlank() && pendingCallNote.value == null) {
                    val match = findLeadByPhone(leadsState.value, phone)
                    pendingCallNote.value =
                        PendingCallNote(phoneNumber = phone, lead = match, endedAtMillis = it.endedAtMillis)
                    pendingCallText.value = ""
                    if (match == null) {
                        pendingLeadName.value = ""
                        if (pendingUniversityId.value == null && universities.value.isNotEmpty()) {
                            pendingUniversityId.value = universities.value.first().id
                        }
                    }
                }
            }
        }
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
            .padding(20.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Text(
                text = "Leads",
                style = MaterialTheme.typography.headlineMedium,
                color = colors.onBackground
            )
            Text(
                text = "Stay on top of your assignments and follow-ups.",
                style = MaterialTheme.typography.bodyLarge,
                color = colors.onBackground.copy(alpha = 0.7f),
                modifier = Modifier.padding(top = 6.dp, bottom = 16.dp)
            )

            CallSyncCard(stats = syncStats)
            RecordingStatusCard(
                state = recordingState,
                onConsentChange = { granted ->
                    scope.launch {
                        recordingStore.setConsentGranted(granted)
                    }
                }
            )

            LeadFilters(
                searchQuery = searchQuery.value,
                statusFilter = statusFilter.value,
                onSearchChange = { searchQuery.value = it },
                onStatusChange = { statusFilter.value = it },
                onApply = {
                    scope.launch {
                        isLoading.value = true
                        loadLeads(
                            api = leadApi,
                            accessToken = accessToken,
                            reset = true,
                            leadsState = leadsState,
                            leadPage = leadPage,
                            hasMore = hasMoreLeads,
                            isLoading = isLoading,
                            error = error,
                            pageSize = pageSize,
                            statusFilter = statusFilter.value,
                            searchQuery = searchQuery.value
                        )
                    }
                }
            )

            if (isLoading.value) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator(color = colors.primary)
                }
                return@Column
            }

            error.value?.let { message ->
                Text(
                    text = message,
                    color = colors.error,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
            }

            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxWidth().weight(1f)
            ) {
                items(leadsState.value) { lead ->
                    LeadCard(lead = lead) {
                        selectedLead.value = null
                        noteText.value = ""
                        selectedTab.value = 0
                        statusMessage.value = null
                        callLogsState.value = emptyList()
                        callLogPage.value = 1
                        hasMoreCallLogs.value = true
                        callLogFilter.value = ""
                        scope.launch {
                            loadLeadDetail(
                                accessToken,
                                lead.id,
                                leadApi,
                                selectedLead,
                                error,
                                callLogsState,
                                hasMoreCallLogs,
                                pageSize
                            )
                        }
                    }
                }
            }

            if (hasMoreLeads.value && !isLoadingMore.value && leadsState.value.isNotEmpty()) {
                Text(
                    text = "Load more leads",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.primary,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .padding(top = 12.dp)
                        .clickable {
                            isLoadingMore.value = true
                            scope.launch {
                                val nextPage = leadPage.value + 1
                                val result = leadApi.listLeads(
                                    accessToken,
                                    nextPage,
                                    pageSize,
                                    statusFilter.value,
                                    searchQuery.value
                                )
                                result.onSuccess { newLeads ->
                                    if (newLeads.isEmpty()) {
                                        hasMoreLeads.value = false
                                    } else {
                                        leadsState.value = leadsState.value + newLeads
                                        leadPage.value = nextPage
                                    }
                                }.onFailure {
                                    error.value = "Unable to load more leads."
                                }
                                isLoadingMore.value = false
                            }
                        }
                )
            }

            selectedLead.value?.let { detail ->
                LeadDetailCard(
                    detail = detail,
                    noteText = noteText.value,
                    isSavingNote = isSavingNote.value,
                    onNoteChange = { noteText.value = it },
                    onSubmitNote = {
                        if (noteText.value.isNotBlank() && !isSavingNote.value) {
                            isSavingNote.value = true
                            scope.launch {
                                val result = leadApi.addNote(accessToken, detail.lead.id, noteText.value)
                                isSavingNote.value = false
                                result.onSuccess {
                                    noteText.value = ""
                                    statusMessage.value = "Note saved."
                                    loadLeadDetail(
                                        accessToken,
                                        detail.lead.id,
                                        leadApi,
                                        selectedLead,
                                        error,
                                        callLogsState,
                                        hasMoreCallLogs,
                                        pageSize
                                    )
                                }.onFailure {
                                    error.value = "Unable to save note."
                                }
                            }
                        }
                    },
                    selectedTab = selectedTab.value,
                    onTabSelected = { selectedTab.value = it },
                    onUpdateStatus = { status ->
                        if (!statusUpdating.value) {
                            statusUpdating.value = true
                            scope.launch {
                                val result = leadApi.updateStatus(accessToken, detail.lead.id, status)
                                statusUpdating.value = false
                                result.onSuccess {
                                    statusMessage.value = "Status updated."
                                    loadLeadDetail(
                                        accessToken,
                                        detail.lead.id,
                                        leadApi,
                                        selectedLead,
                                        error,
                                        callLogsState,
                                        hasMoreCallLogs,
                                        pageSize
                                    )
                                }.onFailure {
                                    error.value = "Unable to update status."
                                }
                            }
                        }
                    },
                    followupDueAt = followupDueAtMillis.value,
                    followupNote = followupNote.value,
                    isFollowupSaving = followupSaving.value,
                    onFollowupPick = {
                        pickFollowupDateTime(
                            context = context,
                            currentMillis = followupDueAtMillis.value,
                            onSelected = { followupDueAtMillis.value = it }
                        )
                    },
                    onFollowupNoteChange = { followupNote.value = it },
                    onScheduleFollowup = {
                        val millis = followupDueAtMillis.value
                        if (millis != null && !followupSaving.value && millis > System.currentTimeMillis()) {
                            followupSaving.value = true
                            scope.launch {
                                val dueAtIso = Instant.ofEpochMilli(millis).toString()
                                val result = leadApi.scheduleFollowup(
                                    accessToken,
                                    detail.lead.id,
                                    dueAtIso,
                                    followupNote.value.ifBlank { null }
                                )
                                followupSaving.value = false
                                result.onSuccess {
                                    followupDueAtMillis.value = null
                                    followupNote.value = ""
                                    statusMessage.value = "Follow-up scheduled."
                                    loadLeadDetail(
                                        accessToken,
                                        detail.lead.id,
                                        leadApi,
                                        selectedLead,
                                        error,
                                        callLogsState,
                                        hasMoreCallLogs,
                                        pageSize
                                    )
                                }.onFailure {
                                    error.value = "Unable to schedule follow-up."
                                }
                            }
                        } else {
                            statusMessage.value = "Pick a future follow-up time."
                        }
                    },
                    statusMessage = statusMessage.value,
                    onClearMessage = { statusMessage.value = null },
                    callLogs = callLogsState.value,
                    recordings = detail.recordings,
                    hasMoreCallLogs = hasMoreCallLogs.value,
                    callLogFilter = callLogFilter.value,
                    onCallLogFilterChange = { callLogFilter.value = it },
                    onLoadMoreCallLogs = {
                        scope.launch {
                            val nextPage = callLogPage.value + 1
                            val result = leadApi.listCallLogs(accessToken, detail.lead.id, nextPage, pageSize)
                            result.onSuccess { newLogs ->
                                if (newLogs.isEmpty()) {
                                    hasMoreCallLogs.value = false
                                } else {
                                    callLogsState.value = callLogsState.value + newLogs
                                    callLogPage.value = nextPage
                                }
                            }.onFailure {
                                error.value = "Unable to load more call logs."
                            }
                        }
                    }
                )
            }
        }

        pendingCallNote.value?.let { pending ->
            CallNoteOverlay(
                pending = pending,
                noteText = pendingCallText.value,
                isSaving = pendingCallSaving.value,
                onNoteChange = { pendingCallText.value = it },
                onDismiss = {
                    pendingCallNote.value = null
                    scope.launch { callNoteStore.clear() }
                },
                onSave = {
                    val lead = pending.lead ?: return@CallNoteOverlay
                    if (pendingCallText.value.isBlank()) return@CallNoteOverlay
                    pendingCallSaving.value = true
                    scope.launch {
                        val result = leadApi.addNote(accessToken, lead.id, pendingCallText.value)
                        pendingCallSaving.value = false
                        result.onSuccess {
                            pendingCallNote.value = null
                            pendingCallText.value = ""
                            callNoteStore.clear()
                            statusMessage.value = "Post-call note saved."
                            loadLeadDetail(
                                accessToken,
                                lead.id,
                                leadApi,
                                selectedLead,
                                error,
                                callLogsState,
                                hasMoreCallLogs,
                                pageSize
                            )
                        }.onFailure {
                            error.value = "Unable to save post-call note."
                        }
                    }
                },
                showLeadCreation = pending.lead == null,
                leadName = pendingLeadName.value,
                universities = universities.value,
                selectedUniversityId = pendingUniversityId.value,
                isUniversityMenuOpen = pendingUniversityMenuOpen.value,
                onLeadNameChange = { pendingLeadName.value = it },
                onUniversitySelected = {
                    pendingUniversityId.value = it
                    pendingUniversityMenuOpen.value = false
                },
                onToggleUniversityMenu = { pendingUniversityMenuOpen.value = !pendingUniversityMenuOpen.value },
                onCreateLead = {
                    val phone = pending.phoneNumber
                    val name = pendingLeadName.value.ifBlank { "Unknown Lead" }
                    scope.launch {
                        val result = leadApi.createLead(accessToken, name, phone, pendingUniversityId.value)
                        result.onSuccess { newLead ->
                            leadsState.value = listOf(newLead) + leadsState.value
                            pendingCallNote.value = pending.copy(lead = newLead)
                            pendingLeadName.value = ""
                            statusMessage.value = "Lead created. Add your note."
                        }.onFailure {
                            error.value = "Unable to create lead."
                        }
                    }
                }
            )
        }
    }
}

@Composable
private fun LeadCard(
    lead: LeadSummary,
    onSelect: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onSelect() }
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = lead.studentName,
                style = MaterialTheme.typography.titleMedium,
                color = colors.onSurface
            )
            Text(
                text = lead.phoneNumber,
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onSurface.copy(alpha = 0.6f)
            )
            Row(
                modifier = Modifier.padding(top = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                StatusPill(label = lead.status)
                lead.universityName?.let { name ->
                    Text(
                        text = name,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.onSurface.copy(alpha = 0.6f)
                    )
                }
            }
        }
    }
}

@Composable
private fun LeadFilters(
    searchQuery: String,
    statusFilter: String,
    onSearchChange: (String) -> Unit,
    onStatusChange: (String) -> Unit,
    onApply: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val statuses = listOf("" to "All", "new" to "New", "follow_up" to "Follow-up", "applied" to "Applied", "not_interested" to "Not interested")
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
    ) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchChange,
            placeholder = { Text(text = "Search by name or phone") },
            colors = TextFieldDefaults.colors(
                focusedIndicatorColor = colors.primary,
                unfocusedIndicatorColor = colors.secondary.copy(alpha = 0.4f),
                focusedLabelColor = colors.primary,
                cursorColor = colors.primary
            ),
            modifier = Modifier.fillMaxWidth()
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            statuses.forEach { (value, label) ->
                Box(
                    modifier = Modifier
                        .background(
                            if (statusFilter == value) colors.primary.copy(alpha = 0.18f)
                            else colors.surface.copy(alpha = 0.6f),
                            RoundedCornerShape(12.dp)
                        )
                        .clickable { onStatusChange(value) }
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelLarge,
                        color = if (statusFilter == value) colors.primary else colors.onSurface.copy(alpha = 0.7f)
                    )
                }
            }
        }
        Text(
            text = "Apply filters",
            style = MaterialTheme.typography.bodyMedium,
            color = colors.primary,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(top = 8.dp)
                .clickable { onApply() }
        )
    }
}

@Composable
private fun RecordingStatusCard(
    state: RecordingState,
    onConsentChange: (Boolean) -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val statusLabel = when (state.lastStatus) {
        "recording" -> "Recording live"
        "queued" -> "Queued for upload"
        "uploading" -> "Uploading recording"
        "uploaded" -> "Recording uploaded"
        "failed" -> "Upload failed"
        else -> "Idle"
    }

    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Call recordings",
                        style = MaterialTheme.typography.titleMedium,
                        color = colors.onSurface
                    )
                    Text(
                        text = if (state.consentGranted) "Consent captured · $statusLabel" else "Consent required to record",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.onSurface.copy(alpha = 0.7f),
                        modifier = Modifier.padding(top = 6.dp)
                    )
                }
                Switch(
                    checked = state.consentGranted,
                    onCheckedChange = onConsentChange
                )
            }
            state.lastFileName?.let { name ->
                Text(
                    text = "Last file: $name",
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
            state.lastError?.let { error ->
                Text(
                    text = "Error: $error",
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.error,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
        }
    }
}

@Composable
private fun LeadDetailCard(
    detail: LeadDetail,
    noteText: String,
    isSavingNote: Boolean,
    onNoteChange: (String) -> Unit,
    onSubmitNote: () -> Unit,
    selectedTab: Int,
    onTabSelected: (Int) -> Unit,
    onUpdateStatus: (String) -> Unit,
    followupDueAt: Long?,
    followupNote: String,
    isFollowupSaving: Boolean,
    onFollowupPick: () -> Unit,
    onFollowupNoteChange: (String) -> Unit,
    onScheduleFollowup: () -> Unit,
    statusMessage: String?,
    onClearMessage: () -> Unit,
    callLogs: List<com.koncrm.counselor.leads.CallLogEntry>,
    recordings: List<RecordingEntry>,
    hasMoreCallLogs: Boolean,
    callLogFilter: String,
    onCallLogFilterChange: (String) -> Unit,
    onLoadMoreCallLogs: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val context = LocalContext.current
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp)
    ) {
        Column(modifier = Modifier.padding(18.dp)) {
            Text(
                text = "Lead detail",
                style = MaterialTheme.typography.titleMedium,
                color = colors.onSurface
            )
            Text(
                text = detail.lead.studentName,
                style = MaterialTheme.typography.titleLarge,
                color = colors.onSurface,
                modifier = Modifier.padding(top = 8.dp)
            )
            Row(
                modifier = Modifier.padding(top = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = detail.lead.phoneNumber,
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.onSurface.copy(alpha = 0.6f)
                )
                Card(
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = colors.primary),
                    modifier = Modifier.clickable {
                        val intent = Intent(Intent.ACTION_DIAL).apply {
                            data = Uri.parse("tel:${detail.lead.phoneNumber}")
                        }
                        context.startActivity(intent)
                    }
                ) {
                    Text(
                        text = "📞 Call",
                        style = MaterialTheme.typography.labelMedium,
                        color = colors.onPrimary,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                    )
                }
            }
            Row(
                modifier = Modifier.padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatChip(title = "Last activity", value = detail.lastActivityAt ?: "--")
                StatChip(title = "Next follow-up", value = detail.nextFollowUpAt ?: "--")
            }
            StatusRow(currentStatus = detail.lead.status, onUpdateStatus = onUpdateStatus)

            statusMessage?.let { message ->
                Row(
                    modifier = Modifier.padding(top = 6.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.onSurface.copy(alpha = 0.7f),
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = "Clear",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.primary,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .padding(start = 12.dp)
                            .clickable { onClearMessage() }
                    )
                }
            }

            TabsRow(
                tabs = listOf("Activity", "Follow-ups", "Calls", "Recordings"),
                selectedIndex = selectedTab,
                onSelected = onTabSelected
            )

            when (selectedTab) {
                0 -> ActivityList(detail)
                1 -> FollowupList(detail, followupDueAt, followupNote, isFollowupSaving, onFollowupPick, onFollowupNoteChange, onScheduleFollowup)
                2 -> CallLogList(callLogs, hasMoreCallLogs, callLogFilter, onCallLogFilterChange, onLoadMoreCallLogs)
                3 -> RecordingList(recordings)
            }

            Text(
                text = "Add a note",
                style = MaterialTheme.typography.titleMedium,
                color = colors.onSurface,
                modifier = Modifier.padding(top = 16.dp)
            )
            OutlinedTextField(
                value = noteText,
                onValueChange = onNoteChange,
                placeholder = { Text(text = "Capture call outcome or next steps") },
                colors = TextFieldDefaults.colors(
                    focusedIndicatorColor = colors.primary,
                    unfocusedIndicatorColor = colors.secondary.copy(alpha = 0.4f),
                    focusedLabelColor = colors.primary,
                    cursorColor = colors.primary
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
            )
            Row(
                modifier = Modifier.padding(top = 10.dp),
                horizontalArrangement = Arrangement.End
            ) {
                Text(
                    text = if (isSavingNote) "Saving..." else "Save note",
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (isSavingNote) colors.onSurface.copy(alpha = 0.6f) else colors.primary,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable(enabled = !isSavingNote && noteText.isNotBlank()) {
                        onSubmitNote()
                    }
                )
            }
        }
    }
}

@Composable
private fun StatusRow(currentStatus: String, onUpdateStatus: (String) -> Unit) {
    val statuses = listOf("new", "follow_up", "applied", "not_interested")
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier.padding(top = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        statuses.forEach { status ->
            Box(
                modifier = Modifier
                    .background(
                        if (status == currentStatus) colors.primary.copy(alpha = 0.18f)
                        else colors.surface.copy(alpha = 0.7f),
                        RoundedCornerShape(12.dp)
                    )
                    .clickable(enabled = status != currentStatus) { onUpdateStatus(status) }
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Text(
                    text = status.replace("_", " "),
                    style = MaterialTheme.typography.labelLarge,
                    color = if (status == currentStatus) colors.primary else colors.onSurface.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@Composable
private fun TabsRow(tabs: List<String>, selectedIndex: Int, onSelected: (Int) -> Unit) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .padding(top = 16.dp)
            .fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        tabs.forEachIndexed { index, title ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .background(
                        if (index == selectedIndex) colors.primary.copy(alpha = 0.2f)
                        else colors.surface.copy(alpha = 0.6f),
                        RoundedCornerShape(12.dp)
                    )
                    .clickable { onSelected(index) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (index == selectedIndex) colors.primary else colors.onSurface.copy(alpha = 0.6f)
                )
            }
        }
    }
}

@Composable
private fun ActivityList(detail: LeadDetail) {
    val colors = MaterialTheme.colorScheme
    Column(modifier = Modifier.padding(top = 12.dp)) {
        if (detail.activities.isEmpty()) {
            Text(
                text = "No activity yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onSurface.copy(alpha = 0.6f)
            )
        } else {
            detail.activities.take(5).forEach { activity ->
                val timeLabel = formatIso(activity.occurredAt)
                Text(
                    text = "${activity.type} · ${activity.body ?: ""}".trim(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.onSurface.copy(alpha = 0.8f)
                )
                if (timeLabel != null) {
                    Text(
                        text = timeLabel,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.onSurface.copy(alpha = 0.5f),
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun FollowupList(
    detail: LeadDetail,
    dueAt: Long?,
    note: String,
    isSaving: Boolean,
    onPickDueAt: () -> Unit,
    onNoteChange: (String) -> Unit,
    onSchedule: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    Column(modifier = Modifier.padding(top = 12.dp)) {
        if (detail.followups.isEmpty()) {
            Text(
                text = "No follow-ups yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onSurface.copy(alpha = 0.6f)
            )
        } else {
            detail.followups.take(3).forEach { followup ->
                Text(
                    text = "${followup.status} · ${formatIso(followup.dueAt) ?: "--"}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.onSurface.copy(alpha = 0.7f)
                )
            }
        }

        Text(
            text = "Schedule follow-up",
            style = MaterialTheme.typography.labelLarge,
            color = colors.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.padding(top = 12.dp)
        )
        Row(
            modifier = Modifier.padding(top = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = formatEpoch(dueAt),
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onSurface
            )
            Text(
                text = "Pick date & time",
                style = MaterialTheme.typography.bodyMedium,
                color = colors.primary,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable { onPickDueAt() }
            )
        }
        OutlinedTextField(
            value = note,
            onValueChange = onNoteChange,
            placeholder = { Text(text = "Optional note") },
            colors = TextFieldDefaults.colors(
                focusedIndicatorColor = colors.primary,
                unfocusedIndicatorColor = colors.secondary.copy(alpha = 0.4f),
                focusedLabelColor = colors.primary,
                cursorColor = colors.primary
            ),
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
        )
        Text(
            text = if (isSaving) "Scheduling..." else "Schedule follow-up",
            style = MaterialTheme.typography.bodyMedium,
            color = if (isSaving) colors.onSurface.copy(alpha = 0.6f) else colors.primary,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(top = 10.dp)
                .clickable(enabled = !isSaving && dueAt != null) { onSchedule() }
        )
    }
}

@Composable
private fun CallLogList(
    callLogs: List<com.koncrm.counselor.leads.CallLogEntry>,
    hasMore: Boolean,
    filter: String,
    onFilterChange: (String) -> Unit,
    onLoadMore: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val filters = listOf("" to "All", "incoming" to "Incoming", "outgoing" to "Outgoing", "missed" to "Missed")
    val filteredLogs =
        if (filter.isBlank()) callLogs else callLogs.filter { it.callType == filter }

    Column(modifier = Modifier.padding(top = 12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            filters.forEach { (value, label) ->
                Box(
                    modifier = Modifier
                        .background(
                            if (filter == value) colors.primary.copy(alpha = 0.18f)
                            else colors.surface.copy(alpha = 0.6f),
                            RoundedCornerShape(12.dp)
                        )
                        .clickable { onFilterChange(value) }
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelLarge,
                        color = if (filter == value) colors.primary else colors.onSurface.copy(alpha = 0.7f)
                    )
                }
            }
        }

        if (filteredLogs.isEmpty()) {
            Text(
                text = "No calls logged yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onSurface.copy(alpha = 0.6f)
            )
        } else {
            filteredLogs.take(5).forEach { call ->
                val timeLabel = formatIso(call.startedAt)
                Text(
                    text = "${call.callType} · ${call.durationSeconds ?: 0}s · ${timeLabel ?: "--"}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.onSurface.copy(alpha = 0.7f)
                )
            }
            if (hasMore) {
                Text(
                    text = "Load more calls",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.primary,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .padding(top = 10.dp)
                        .clickable { onLoadMore() }
                )
            }
        }
    }
}

@Composable
private fun RecordingList(recordings: List<RecordingEntry>) {
    val colors = MaterialTheme.colorScheme
    val context = LocalContext.current

    Column(modifier = Modifier.padding(top = 12.dp)) {
        if (recordings.isEmpty()) {
            Text(
                text = "No recordings available.",
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onSurface.copy(alpha = 0.6f)
            )
        } else {
            recordings.take(5).forEach { recording ->
                val timeLabel = formatIso(recording.recordedAt)
                Text(
                    text = "${recording.status} · ${recording.durationSeconds ?: 0}s · ${timeLabel ?: "--"}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.onSurface.copy(alpha = 0.7f)
                )
                recording.fileUrl?.let { url ->
                    Text(
                        text = "Play recording",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.primary,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .padding(top = 4.dp, bottom = 8.dp)
                            .clickable {
                                val fullUrl = resolveRecordingUrl(url)
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(fullUrl))
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                context.startActivity(intent)
                            }
                    )
                }
            }
        }
    }
}

@Composable
private fun CallSyncCard(stats: CallLogSyncStats) {
    val colors = MaterialTheme.colorScheme
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Call sync",
                style = MaterialTheme.typography.titleMedium,
                color = colors.onSurface
            )
            Text(
                text = "Last sync: ${formatEpoch(stats.lastSyncedAt)}",
                style = MaterialTheme.typography.bodyMedium,
                color = colors.onSurface.copy(alpha = 0.6f),
                modifier = Modifier.padding(top = 4.dp)
            )
            Row(
                modifier = Modifier.padding(top = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(text = "New ${stats.syncedCount}", style = MaterialTheme.typography.bodyMedium)
                Text(text = "Dupes ${stats.duplicateCount}", style = MaterialTheme.typography.bodyMedium)
                if (stats.failureCount > 0) {
                    Text(
                        text = "Failed ${stats.failureCount}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.error
                    )
                }
            }
        }
    }
}

@Composable
private fun CallNoteOverlay(
    pending: PendingCallNote,
    noteText: String,
    isSaving: Boolean,
    onNoteChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onSave: () -> Unit,
    showLeadCreation: Boolean,
    leadName: String,
    universities: List<University>,
    selectedUniversityId: Long?,
    isUniversityMenuOpen: Boolean,
    onLeadNameChange: (String) -> Unit,
    onUniversitySelected: (Long) -> Unit,
    onToggleUniversityMenu: () -> Unit,
    onCreateLead: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.onSurface.copy(alpha = 0.35f))
            .padding(20.dp),
        contentAlignment = Alignment.BottomCenter
    ) {
        Card(
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = colors.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 10.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = "Post-call note",
                    style = MaterialTheme.typography.titleMedium,
                    color = colors.onSurface
                )
                Text(
                    text = "Call ended with ${pending.phoneNumber}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.onSurface.copy(alpha = 0.7f),
                    modifier = Modifier.padding(top = 6.dp)
                )
                if (pending.lead != null) {
                    Text(
                        text = "Matched lead: ${pending.lead.studentName}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.onSurface.copy(alpha = 0.7f),
                        modifier = Modifier.padding(top = 6.dp)
                    )
                } else {
                    Text(
                        text = "No matching lead found. Create one now.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.onSurface.copy(alpha = 0.7f),
                        modifier = Modifier.padding(top = 6.dp)
                    )
                }

                if (showLeadCreation && pending.lead == null) {
                    OutlinedTextField(
                        value = leadName,
                        onValueChange = onLeadNameChange,
                        placeholder = { Text(text = "Lead name") },
                        colors = TextFieldDefaults.colors(
                            focusedIndicatorColor = colors.primary,
                            unfocusedIndicatorColor = colors.secondary.copy(alpha = 0.4f),
                            focusedLabelColor = colors.primary,
                            cursorColor = colors.primary
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 12.dp)
                    )

                    if (universities.isNotEmpty()) {
                        Column(modifier = Modifier.padding(top = 10.dp)) {
                            Text(
                                text = "University",
                                style = MaterialTheme.typography.labelLarge,
                                color = colors.onSurface.copy(alpha = 0.6f)
                            )
                            Text(
                                text = universities.firstOrNull { it.id == selectedUniversityId }?.name
                                    ?: "Select university",
                                style = MaterialTheme.typography.bodyMedium,
                                color = colors.primary,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .padding(top = 6.dp)
                                    .clickable { onToggleUniversityMenu() }
                            )
                            if (isUniversityMenuOpen) {
                                Column(modifier = Modifier.padding(top = 6.dp)) {
                                    universities.take(5).forEach { university ->
                                        Text(
                                            text = university.name,
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = colors.onSurface.copy(alpha = 0.8f),
                                            modifier = Modifier
                                                .padding(vertical = 4.dp)
                                                .clickable { onUniversitySelected(university.id) }
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Text(
                        text = "Create lead",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.primary,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .padding(top = 12.dp)
                            .clickable { onCreateLead() }
                    )
                }
                OutlinedTextField(
                    value = noteText,
                    onValueChange = onNoteChange,
                    placeholder = { Text(text = "Outcome or next steps") },
                    colors = TextFieldDefaults.colors(
                        focusedIndicatorColor = colors.primary,
                        unfocusedIndicatorColor = colors.secondary.copy(alpha = 0.4f),
                        focusedLabelColor = colors.primary,
                        cursorColor = colors.primary
                    ),
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
                )
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "Dismiss",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.clickable { onDismiss() }
                    )
                    val canSave = pending.lead != null && noteText.isNotBlank() && !isSaving
                    Text(
                        text = if (isSaving) "Saving..." else "Save note",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (canSave) colors.primary else colors.onSurface.copy(alpha = 0.4f),
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable(enabled = canSave) { onSave() }
                    )
                }
            }
        }
    }
}

@Composable
private fun StatusPill(label: String) {
    val colors = MaterialTheme.colorScheme
    Box(
        modifier = Modifier
            .background(colors.primary.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(
            text = label.replace("_", " "),
            style = MaterialTheme.typography.labelLarge,
            color = colors.primary,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun StatChip(title: String, value: String) {
    val colors = MaterialTheme.colorScheme
    Column(
        modifier = Modifier
            .background(colors.surface.copy(alpha = 0.7f), RoundedCornerShape(16.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .width(150.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            color = colors.onSurface.copy(alpha = 0.6f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = colors.onSurface
        )
    }
}

private suspend fun loadLeadDetail(
    accessToken: String,
    leadId: Long,
    api: LeadApi,
    state: androidx.compose.runtime.MutableState<LeadDetail?>,
    error: androidx.compose.runtime.MutableState<String?>,
    callLogsState: androidx.compose.runtime.MutableState<List<com.koncrm.counselor.leads.CallLogEntry>>,
    hasMoreCallLogs: androidx.compose.runtime.MutableState<Boolean>,
    pageSize: Int
) {
    val result = api.getLead(accessToken, leadId)
    result.onSuccess { detail ->
        state.value = detail
        callLogsState.value = detail.callLogs
        hasMoreCallLogs.value = detail.callLogs.size >= pageSize
    }.onFailure {
        error.value = "Unable to load lead detail."
    }
}

private fun normalizePhone(phone: String): String {
    val digits = phone.filter { it.isDigit() }
    return if (digits.length > 10) digits.takeLast(10) else digits
}

private fun findLeadByPhone(leads: List<LeadSummary>, phone: String): LeadSummary? {
    return leads.firstOrNull { normalizePhone(it.phoneNumber) == phone }
}

private fun resolveRecordingUrl(url: String): String {
    return if (url.startsWith("http")) url else "${ApiConfig.BASE_URL}${url}"
}

private fun formatEpoch(epochMillis: Long?): String {
    if (epochMillis == null || epochMillis == 0L) return "--"
    val instant = Instant.ofEpochMilli(epochMillis)
    val formatter = DateTimeFormatter.ofPattern("dd MMM, HH:mm").withZone(ZoneId.systemDefault())
    return formatter.format(instant)
}

private fun formatIso(iso: String?): String? {
    if (iso.isNullOrBlank()) return null
    return runCatching {
        val instant = Instant.parse(iso)
        val formatter = DateTimeFormatter.ofPattern("dd MMM, HH:mm").withZone(ZoneId.systemDefault())
        formatter.format(instant)
    }.getOrNull()
}

private data class PendingCallNote(
    val phoneNumber: String,
    val lead: LeadSummary?,
    val endedAtMillis: Long?
)

private suspend fun loadLeads(
    api: LeadApi,
    accessToken: String,
    reset: Boolean,
    leadsState: androidx.compose.runtime.MutableState<List<LeadSummary>>,
    leadPage: androidx.compose.runtime.MutableState<Int>,
    hasMore: androidx.compose.runtime.MutableState<Boolean>,
    isLoading: androidx.compose.runtime.MutableState<Boolean>,
    error: androidx.compose.runtime.MutableState<String?>,
    pageSize: Int,
    statusFilter: String,
    searchQuery: String
) {
    if (reset) {
        leadPage.value = 1
        hasMore.value = true
    }
    val result = api.listLeads(accessToken, leadPage.value, pageSize, statusFilter, searchQuery)
    result.onSuccess { leads ->
        leadsState.value = if (reset) leads else leadsState.value + leads
        if (leads.size < pageSize) {
            hasMore.value = false
        }
    }.onFailure {
        error.value = "Unable to load leads."
    }
    isLoading.value = false
}

private fun pickFollowupDateTime(
    context: android.content.Context,
    currentMillis: Long?,
    onSelected: (Long) -> Unit
) {
    val now = Instant.ofEpochMilli(currentMillis ?: System.currentTimeMillis())
        .atZone(ZoneId.systemDefault())
    val date = LocalDate.of(now.year, now.month, now.dayOfMonth)
    val time = LocalTime.of(now.hour, now.minute)

    DatePickerDialog(
        context,
        { _, year, month, dayOfMonth ->
            val pickedDate = LocalDate.of(year, month + 1, dayOfMonth)
            TimePickerDialog(
                context,
                { _, hour, minute ->
                    val pickedTime = LocalTime.of(hour, minute)
                    val dateTime = LocalDateTime.of(pickedDate, pickedTime)
                    val millis = dateTime.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                    onSelected(millis)
                },
                time.hour,
                time.minute,
                false
            ).show()
        },
        date.year,
        date.monthValue - 1,
        date.dayOfMonth
    ).show()
}
