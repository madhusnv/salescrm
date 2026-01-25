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
import androidx.compose.runtime.rememberUpdatedState
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
import com.koncrm.counselor.data.repository.LeadRepository
import com.koncrm.counselor.recordings.RecordingState
import com.koncrm.counselor.recordings.RecordingStore
import com.koncrm.counselor.leads.RecordingEntry
import com.koncrm.counselor.network.ApiConfig
import com.koncrm.counselor.work.CallNoteStore
import com.koncrm.counselor.work.CallLogSyncStats
import com.koncrm.counselor.work.CallLogSyncStore
import com.koncrm.counselor.network.ChannelEvent
import com.koncrm.counselor.network.ChannelManager
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import android.app.DatePickerDialog
import android.app.TimePickerDialog

import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.foundation.border
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.material3.Surface
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp

@Composable
fun LeadHomeScreen(
    modifier: Modifier = Modifier
) {
    val colors = MaterialTheme.colorScheme
    val context = LocalContext.current
    val leadApi = remember { LeadApi() }
    val leadRepository = remember { LeadRepository(context) }
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
    val useCache = remember { mutableStateOf(false) }
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
    val cachedLeads by leadRepository.observeLeadSummaries()
        .collectAsState(initial = emptyList())
    val callLogsState = remember { mutableStateOf<List<com.koncrm.counselor.leads.CallLogEntry>>(emptyList()) }
    val callLogPage = remember { mutableStateOf(1) }
    val hasMoreCallLogs = remember { mutableStateOf(true) }
    val callLogFilter = remember { mutableStateOf("") }
    val channelManager = remember { ChannelManager.getInstance(context) }
    val displayLeads = if (useCache.value) {
        val search = searchQuery.value.trim()
        val status = statusFilter.value.trim()
        cachedLeads.filter { lead ->
            val matchesStatus = status.isBlank() || lead.status.equals(status, ignoreCase = true)
            val matchesSearch = search.isBlank() ||
                lead.studentName.contains(search, ignoreCase = true) ||
                lead.phoneNumber.contains(search) ||
                (lead.universityName?.contains(search, ignoreCase = true) ?: false)
            matchesStatus && matchesSearch
        }
    } else {
        leadsState.value
    }
    val displayLeadsState = rememberUpdatedState(displayLeads)

    LaunchedEffect(Unit) {
        isLoading.value = true
        error.value = null
        val universitiesResult = leadApi.listUniversities()
        universitiesResult.onSuccess {
            universities.value = it
            if (pendingUniversityId.value == null && it.isNotEmpty()) {
                pendingUniversityId.value = it.first().id
            }
        }
        loadLeads(
            api = leadApi,
            leadRepository = leadRepository,
            reset = true,
            leadsState = leadsState,
            leadPage = leadPage,
            hasMore = hasMoreLeads,
            isLoading = isLoading,
            error = error,
            useCache = useCache,
            pageSize = pageSize,
            statusFilter = statusFilter.value,
            searchQuery = searchQuery.value
        )
    }

    LaunchedEffect(Unit) {
        channelManager.events.collect { event ->
            when (event) {
                is ChannelEvent.LeadUpdated -> {
                    val status = event.status.trim()
                    if (status.isNotEmpty()) {
                        val current = leadsState.value
                        val updatedLead = current.firstOrNull { it.id == event.id }?.copy(status = status)
                        if (updatedLead != null) {
                            leadsState.value = current.map { lead ->
                                if (lead.id == updatedLead.id) updatedLead else lead
                            }
                            leadRepository.cacheLeads(listOf(updatedLead))
                        }
                        val detail = selectedLead.value
                        if (detail != null && detail.lead.id == event.id) {
                            selectedLead.value = detail.copy(
                                lead = detail.lead.copy(status = status)
                            )
                        }
                    }
                }
                else -> Unit
            }
        }
    }

    LaunchedEffect(Unit) {
        callNoteStore.pendingFlow().collect { pending ->
            pending?.let {
                val phone = normalizePhone(it.phoneNumber)
                if (phone.isNotBlank() && pendingCallNote.value == null) {
                    val match = findLeadByPhone(displayLeadsState.value, phone)
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
                text = "My Leads",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = colors.onBackground,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            StatsRow(
                syncStats = syncStats,
                recordingState = recordingState,
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
                            leadRepository = leadRepository,
                            reset = true,
                            leadsState = leadsState,
                            leadPage = leadPage,
                            hasMore = hasMoreLeads,
                            isLoading = isLoading,
                            error = error,
                            useCache = useCache,
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
                items(displayLeads) { lead ->
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

            if (hasMoreLeads.value && !isLoadingMore.value && displayLeads.isNotEmpty() && !useCache.value) {
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
                                        leadRepository.cacheLeads(newLeads)
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
                                val result = leadApi.addNote(detail.lead.id, noteText.value)
                                isSavingNote.value = false
                                result.onSuccess {
                                    noteText.value = ""
                                    statusMessage.value = "Note saved."
                                    loadLeadDetail(
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
                                val result = leadApi.updateStatus(detail.lead.id, status)
                                statusUpdating.value = false
                                result.onSuccess {
                                    statusMessage.value = "Status updated."
                                    loadLeadDetail(
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
                            val result = leadApi.listCallLogs(detail.lead.id, nextPage, pageSize)
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
                        val result = leadApi.addNote(lead.id, pendingCallText.value)
                        pendingCallSaving.value = false
                        result.onSuccess {
                            pendingCallNote.value = null
                            pendingCallText.value = ""
                            callNoteStore.clear()
                            statusMessage.value = "Post-call note saved."
                            loadLeadDetail(
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
                        val result = leadApi.createLead(name, phone, pendingUniversityId.value)
                        result.onSuccess { newLead ->
                            leadsState.value = listOf(newLead) + leadsState.value
                            leadRepository.cacheLeads(listOf(newLead))
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

private val IST_ZONE: ZoneId = ZoneId.of("Asia/Kolkata")

@Composable
private fun LeadCard(
    lead: LeadSummary,
    onSelect: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.5.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onSelect() }
            .padding(vertical = 4.dp)
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Avatar
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(androidx.compose.foundation.shape.CircleShape)
                    .background(
                         if (lead.studentName.isNotEmpty()) {
                             val hash = lead.studentName.hashCode()
                             val hue = kotlin.math.abs(hash % 360).toFloat()
                             androidx.compose.ui.graphics.Color.hsv(hue, 0.4f, 0.9f)
                         } else colors.primaryContainer
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = lead.studentName.take(1).uppercase(),
                    style = MaterialTheme.typography.titleMedium,
                    color = androidx.compose.ui.graphics.Color.Black.copy(alpha=0.7f),
                    fontWeight = FontWeight.Bold
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = lead.studentName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = colors.onSurface
                )
                Spacer(modifier = Modifier.height(2.dp))
                if (!lead.universityName.isNullOrBlank()) {
                     Text(
                        text = lead.universityName,
                        style = MaterialTheme.typography.bodySmall,
                        color = colors.primary,
                        fontWeight = FontWeight.Medium
                    )
                }
                Text(
                    text = lead.phoneNumber,
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.onSurface.copy(alpha = 0.5f)
                )
            }

            StatusPill(label = lead.status)
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
    val statuses = listOf(
        "" to "All",
        "new" to "New",
        "contacted" to "Contacted",
        "follow_up" to "Follow-up",
        "applied" to "Applied",
        "not_interested" to "Not interested"
    )

    Column(
        modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
    ) {
         OutlinedTextField(
             value = searchQuery,
             onValueChange = onSearchChange,
             placeholder = { Text("Search by name or phone", style = MaterialTheme.typography.bodyMedium, color = colors.onSurfaceVariant.copy(alpha=0.7f)) },
             leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = colors.onSurfaceVariant) },
             modifier = Modifier.fillMaxWidth(),
             shape = RoundedCornerShape(24.dp),
             colors = TextFieldDefaults.colors(
                 unfocusedContainerColor = colors.surfaceVariant.copy(alpha = 0.3f),
                 focusedContainerColor = colors.surfaceVariant.copy(alpha = 0.3f),
                 unfocusedIndicatorColor = Color.Transparent,
                 focusedIndicatorColor = Color.Transparent,
                 cursorColor = colors.primary
             ),
             singleLine = true
         )

         Spacer(modifier = Modifier.height(12.dp))

         Row(
             modifier = Modifier
                 .fillMaxWidth()
                 .horizontalScroll(rememberScrollState()),
             horizontalArrangement = Arrangement.spacedBy(8.dp)
         ) {
             statuses.forEach { (value, label) ->
                 val isSelected = statusFilter == value
                 val bgColor = if (isSelected) colors.primary else colors.surface
                 val contentColor = if (isSelected) colors.onPrimary else colors.onSurface.copy(alpha=0.7f)
                 val borderColor = if (isSelected) Color.Transparent else colors.outline.copy(alpha=0.3f)

                 Box(
                     modifier = Modifier
                         .clip(RoundedCornerShape(50))
                         .background(bgColor)
                         .border(1.dp, borderColor, RoundedCornerShape(50))
                         .clickable { onStatusChange(value) }
                         .padding(horizontal = 16.dp, vertical = 8.dp)
                 ) {
                     Text(
                         text = label,
                         style = MaterialTheme.typography.labelMedium,
                         color = contentColor,
                         fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                     )
                 }
             }
         }

         Text(
             text = "Apply filters",
             style = MaterialTheme.typography.labelLarge,
             color = colors.primary,
             fontWeight = FontWeight.SemiBold,
             modifier = Modifier
                 .align(Alignment.End)
                 .padding(top = 12.dp)
                 .clickable { onApply() }
         )
    }
}

// RecordingStatusCard removed/replaced by StatsRow

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
    val statuses = listOf(
        "new" to "New",
        "contacted" to "Contacted",
        "follow_up" to "Follow up",
        "applied" to "Applied",
        "not_interested" to "Not interested"
    )
    val colors = MaterialTheme.colorScheme

    LazyRow(
        modifier = Modifier.padding(top = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(statuses.size) { index ->
            val (status, label) = statuses[index]
            val isSelected = status == currentStatus
            val bgColor = if (isSelected) colors.primary else colors.surfaceVariant.copy(alpha = 0.6f)
            val textColor = if (isSelected) colors.onPrimary else colors.onSurface.copy(alpha = 0.8f)

            Surface(
                shape = RoundedCornerShape(20.dp),
                color = bgColor,
                shadowElevation = if (isSelected) 4.dp else 0.dp,
                modifier = Modifier.clickable(enabled = !isSelected) { onUpdateStatus(status) }
            ) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelMedium,
                    color = textColor,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
                )
            }
        }
    }
}

@Composable
private fun TabsRow(tabs: List<String>, selectedIndex: Int, onSelected: (Int) -> Unit) {
    val colors = MaterialTheme.colorScheme
    Surface(
        modifier = Modifier
            .padding(top = 20.dp)
            .fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = colors.surfaceVariant.copy(alpha = 0.4f)
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
                    color = if (isSelected) colors.primary else Color.Transparent,
                    shadowElevation = if (isSelected) 2.dp else 0.dp
                ) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) colors.onPrimary else colors.onSurface.copy(alpha = 0.6f),
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        modifier = Modifier.padding(vertical = 10.dp, horizontal = 4.dp)
                    )
                }
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
private fun StatsRow(
    syncStats: CallLogSyncStats,
    recordingState: RecordingState,
    onConsentChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
         // Sync Card
         Card(
             modifier = Modifier.weight(1f),
             colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha=0.4f)),
             shape = RoundedCornerShape(20.dp),
             elevation = CardDefaults.cardElevation(0.dp)
         ) {
             Column(modifier = Modifier.padding(16.dp)) {
                 Text("Call Sync", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                 Spacer(modifier = Modifier.height(8.dp))
                 Row(verticalAlignment = Alignment.Bottom) {
                     Text("${syncStats.syncedCount}", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                     Text(" new", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(bottom=4.dp))
                 }
             }
         }

         // Recording Card
         Card(
             modifier = Modifier.weight(1f),
             colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha=0.4f)),
             shape = RoundedCornerShape(20.dp),
             elevation = CardDefaults.cardElevation(0.dp)
         ) {
             Column(modifier = Modifier.padding(12.dp)) {
                 Row(
                     verticalAlignment = Alignment.CenterVertically,
                     horizontalArrangement = Arrangement.SpaceBetween,
                     modifier = Modifier.fillMaxWidth()
                 ) {
                     Text("Rec", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                     Switch(
                         checked = recordingState.consentGranted,
                         onCheckedChange = onConsentChange,
                         modifier = Modifier.scale(0.7f).height(30.dp)
                     )
                 }
                 Spacer(modifier = Modifier.height(4.dp))
                 Text(
                    if(recordingState.lastStatus == "recording") "Live 🔴" else "Active",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = if(recordingState.lastStatus == "recording") Color.Red else MaterialTheme.colorScheme.onSurface
                 )
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
    val (bgColor, textColor) = when (label.lowercase()) {
        "new" -> colors.primaryContainer to colors.onPrimaryContainer
        "contacted" -> Color(0xFFE0F2F1) to Color(0xFF0F766E) // Teal
        "follow_up" -> Color(0xFFFFF4DE) to Color(0xFFD97706) // Amber
        "applied" -> Color(0xFFDCFCE7) to Color(0xFF15803D) // Green
        "not_interested" -> Color(0xFFFEE2E2) to Color(0xFFB91C1C) // Red
        else -> colors.surfaceVariant to colors.onSurfaceVariant
    }

    Box(
        modifier = Modifier
            .background(bgColor, RoundedCornerShape(50)) // Pill shape
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(
            text = label.replace("_", " ").capitalize(java.util.Locale.ROOT),
            style = MaterialTheme.typography.labelSmall, // Smaller, tighter
            color = textColor,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun StatChip(title: String, value: String) {
    val colors = MaterialTheme.colorScheme
    // Handle "null" string from API response
    val displayValue = if (value.isBlank() || value == "null" || value == "--") "—" else value
    Column(
        modifier = Modifier
            .background(colors.surfaceVariant.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall,
            color = colors.onSurface.copy(alpha = 0.5f),
            letterSpacing = 0.5.sp
        )
        Text(
            text = displayValue,
            style = MaterialTheme.typography.bodyMedium,
            color = colors.onSurface,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}

private suspend fun loadLeadDetail(
    leadId: Long,
    api: LeadApi,
    state: androidx.compose.runtime.MutableState<LeadDetail?>,
    error: androidx.compose.runtime.MutableState<String?>,
    callLogsState: androidx.compose.runtime.MutableState<List<com.koncrm.counselor.leads.CallLogEntry>>,
    hasMoreCallLogs: androidx.compose.runtime.MutableState<Boolean>,
    pageSize: Int
) {
    val result = api.getLead(leadId)
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
    val formatter = DateTimeFormatter.ofPattern("dd MMM, HH:mm").withZone(IST_ZONE)
    return formatter.format(instant)
}

private fun formatIso(iso: String?): String? {
    if (iso.isNullOrBlank()) return null
    return runCatching {
        val instant = Instant.parse(iso)
        val formatter = DateTimeFormatter.ofPattern("dd MMM, HH:mm").withZone(IST_ZONE)
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
    leadRepository: LeadRepository,
    reset: Boolean,
    leadsState: androidx.compose.runtime.MutableState<List<LeadSummary>>,
    leadPage: androidx.compose.runtime.MutableState<Int>,
    hasMore: androidx.compose.runtime.MutableState<Boolean>,
    isLoading: androidx.compose.runtime.MutableState<Boolean>,
    error: androidx.compose.runtime.MutableState<String?>,
    useCache: androidx.compose.runtime.MutableState<Boolean>,
    pageSize: Int,
    statusFilter: String,
    searchQuery: String
) {
    if (reset) {
        leadPage.value = 1
        hasMore.value = true
    }
    val result = api.listLeads(leadPage.value, pageSize, statusFilter, searchQuery)
    result.onSuccess { leads ->
        leadsState.value = if (reset) leads else leadsState.value + leads
        if (leads.size < pageSize) {
            hasMore.value = false
        }
        useCache.value = false
        leadRepository.cacheLeads(leads)
    }.onFailure {
        error.value = "Unable to load leads. Showing cached data."
        useCache.value = true
        hasMore.value = false
    }
    isLoading.value = false
}

private fun pickFollowupDateTime(
    context: android.content.Context,
    currentMillis: Long?,
    onSelected: (Long) -> Unit
) {
    val now = Instant.ofEpochMilli(currentMillis ?: System.currentTimeMillis())
        .atZone(IST_ZONE)
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
                    val millis = dateTime.atZone(IST_ZONE).toInstant().toEpochMilli()
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
