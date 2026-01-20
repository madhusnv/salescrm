package com.koncrm.counselor.ui.leads

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.koncrm.counselor.leads.LeadSummary
import com.koncrm.counselor.network.LeadApi
import com.koncrm.counselor.recordings.RecordingStore
import com.koncrm.counselor.work.CallLogSyncStore
import com.koncrm.counselor.work.CallNoteStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant

class LeadHomeViewModel(
    private val leadApi: LeadApi = LeadApi(),
    private val syncStore: CallLogSyncStore,
    private val recordingStore: RecordingStore,
    private val callNoteStore: CallNoteStore
) : ViewModel() {

    private val _uiState = MutableStateFlow(LeadHomeUiState())
    val uiState: StateFlow<LeadHomeUiState> = _uiState.asStateFlow()

    private val pageSize = 20
    private val callLogPageSize = 10

    init {
        loadLeads(reset = true)
        loadUniversities()
        observeStores()
    }

    private fun observeStores() {
        viewModelScope.launch {
            syncStore.statsFlow().collect { stats ->
                _uiState.update { it.copy(syncStats = stats) }
            }
        }
        viewModelScope.launch {
            recordingStore.stateFlow().collect { state ->
                _uiState.update { it.copy(recordingState = state) }
            }
        }
        viewModelScope.launch {
            callNoteStore.pendingFlow().collect { pending ->
                if (pending != null) {
                    val matchedLead = findLeadByPhone(_uiState.value.leads, pending.phoneNumber)
                    _uiState.update { 
                        it.copy(
                            pendingCallNote = PendingCallNote(
                                phoneNumber = pending.phoneNumber,
                                lead = matchedLead,
                                endedAtMillis = pending.endedAtMillis
                            ),
                            showLeadCreation = matchedLead == null
                        )
                    }
                }
            }
        }
    }

    fun onEvent(event: LeadHomeEvent) {
        when (event) {
            is LeadHomeEvent.SelectLead -> selectLead(event.lead)
            is LeadHomeEvent.ClearSelection -> clearSelection()
            is LeadHomeEvent.UpdateSearchQuery -> updateSearchQuery(event.query)
            is LeadHomeEvent.UpdateStatusFilter -> updateStatusFilter(event.status)
            is LeadHomeEvent.ApplyFilters -> loadLeads(reset = true)
            is LeadHomeEvent.LoadMoreLeads -> loadMoreLeads()
            is LeadHomeEvent.SelectTab -> selectTab(event.index)
            is LeadHomeEvent.UpdateNoteText -> updateNoteText(event.text)
            is LeadHomeEvent.SubmitNote -> submitNote()
            is LeadHomeEvent.UpdateLeadStatus -> updateLeadStatus(event.status)
            is LeadHomeEvent.SetFollowupDate -> setFollowupDate(event.millis)
            is LeadHomeEvent.UpdateFollowupNote -> updateFollowupNote(event.note)
            is LeadHomeEvent.ScheduleFollowup -> scheduleFollowup()
            is LeadHomeEvent.UpdateCallLogFilter -> updateCallLogFilter(event.filter)
            is LeadHomeEvent.LoadMoreCallLogs -> loadMoreCallLogs()
            is LeadHomeEvent.SetRecordingConsent -> setRecordingConsent(event.granted)
            is LeadHomeEvent.UpdateCallNoteText -> updateCallNoteText(event.text)
            is LeadHomeEvent.DismissCallNote -> dismissCallNote()
            is LeadHomeEvent.SaveCallNote -> saveCallNote()
            is LeadHomeEvent.UpdatePendingLeadName -> updatePendingLeadName(event.name)
            is LeadHomeEvent.SelectUniversity -> selectUniversity(event.id)
            is LeadHomeEvent.ToggleUniversityMenu -> toggleUniversityMenu()
            is LeadHomeEvent.CreateLeadFromCall -> createLeadFromCall()
            is LeadHomeEvent.ClearError -> clearError()
            is LeadHomeEvent.ClearStatusMessage -> clearStatusMessage()
        }
    }

    private fun loadLeads(reset: Boolean) {
        viewModelScope.launch {
            if (reset) {
                _uiState.update { it.copy(currentPage = 1, hasMoreLeads = true, isLoading = true) }
            } else {
                _uiState.update { it.copy(isLoading = true) }
            }

            val state = _uiState.value
            val result = leadApi.listLeads(
                page = state.currentPage,
                pageSize = pageSize,
                status = state.statusFilter.ifBlank { null },
                search = state.searchQuery.ifBlank { null }
            )

            result.onSuccess { leads ->
                _uiState.update { 
                    it.copy(
                        leads = if (reset) leads else it.leads + leads,
                        hasMoreLeads = leads.size >= pageSize,
                        isLoading = false
                    )
                }
            }.onFailure { error ->
                _uiState.update { 
                    it.copy(
                        error = "Failed to load leads",
                        isLoading = false
                    )
                }
            }
        }
    }

    private fun loadMoreLeads() {
        val state = _uiState.value
        if (state.isLoading || !state.hasMoreLeads) return
        _uiState.update { it.copy(currentPage = it.currentPage + 1) }
        loadLeads(reset = false)
    }

    private fun loadUniversities() {
        viewModelScope.launch {
            leadApi.listUniversities().onSuccess { universities ->
                _uiState.update { it.copy(universities = universities) }
            }
        }
    }

    private fun selectLead(lead: LeadSummary) {
        viewModelScope.launch {
            val result = leadApi.getLead(lead.id)
            result.onSuccess { detail ->
                _uiState.update { 
                    it.copy(
                        selectedLead = detail,
                        callLogs = detail.callLogs,
                        hasMoreCallLogs = detail.callLogs.size >= callLogPageSize,
                        callLogPage = 1,
                        selectedTab = 0,
                        noteText = "",
                        followupDueAtMillis = null,
                        followupNote = ""
                    )
                }
            }.onFailure {
                _uiState.update { it.copy(error = "Failed to load lead details") }
            }
        }
    }

    private fun clearSelection() {
        _uiState.update { 
            it.copy(
                selectedLead = null,
                callLogs = emptyList(),
                noteText = "",
                selectedTab = 0
            )
        }
    }

    private fun updateSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
    }

    private fun updateStatusFilter(status: String) {
        _uiState.update { it.copy(statusFilter = status) }
    }

    private fun selectTab(index: Int) {
        _uiState.update { it.copy(selectedTab = index) }
    }

    private fun updateNoteText(text: String) {
        _uiState.update { it.copy(noteText = text) }
    }

    private fun submitNote() {
        val state = _uiState.value
        val lead = state.selectedLead ?: return
        if (state.noteText.isBlank()) return

        viewModelScope.launch {
            _uiState.update { it.copy(isSavingNote = true) }
            val result = leadApi.addNote(lead.lead.id, state.noteText)
            result.onSuccess {
                _uiState.update { it.copy(noteText = "", statusMessage = "Note saved") }
                reloadSelectedLead()
            }.onFailure {
                _uiState.update { it.copy(error = "Failed to save note") }
            }
            _uiState.update { it.copy(isSavingNote = false) }
        }
    }

    private fun updateLeadStatus(status: String) {
        val state = _uiState.value
        val lead = state.selectedLead ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(isUpdatingStatus = true) }
            val result = leadApi.updateStatus(lead.lead.id, status)
            result.onSuccess {
                _uiState.update { it.copy(statusMessage = "Status updated") }
                reloadSelectedLead()
            }.onFailure {
                _uiState.update { it.copy(error = "Failed to update status") }
            }
            _uiState.update { it.copy(isUpdatingStatus = false) }
        }
    }

    private fun setFollowupDate(millis: Long) {
        _uiState.update { it.copy(followupDueAtMillis = millis) }
    }

    private fun updateFollowupNote(note: String) {
        _uiState.update { it.copy(followupNote = note) }
    }

    private fun scheduleFollowup() {
        val state = _uiState.value
        val lead = state.selectedLead ?: return
        val dueAt = state.followupDueAtMillis ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(isSchedulingFollowup = true) }
            val dueAtIso = Instant.ofEpochMilli(dueAt).toString()
            val result = leadApi.scheduleFollowup(
                lead.lead.id,
                dueAtIso,
                state.followupNote.ifBlank { null }
            )
            result.onSuccess {
                _uiState.update { 
                    it.copy(
                        followupDueAtMillis = null,
                        followupNote = "",
                        statusMessage = "Follow-up scheduled"
                    )
                }
                reloadSelectedLead()
            }.onFailure {
                _uiState.update { it.copy(error = "Failed to schedule follow-up") }
            }
            _uiState.update { it.copy(isSchedulingFollowup = false) }
        }
    }

    private fun updateCallLogFilter(filter: String) {
        _uiState.update { it.copy(callLogFilter = filter) }
    }

    private fun loadMoreCallLogs() {
        val state = _uiState.value
        val lead = state.selectedLead ?: return

        viewModelScope.launch {
            val nextPage = state.callLogPage + 1
            val result = leadApi.listCallLogs(lead.lead.id, nextPage, callLogPageSize)
            result.onSuccess { newLogs ->
                if (newLogs.isEmpty()) {
                    _uiState.update { it.copy(hasMoreCallLogs = false) }
                } else {
                    _uiState.update { 
                        it.copy(
                            callLogs = it.callLogs + newLogs,
                            callLogPage = nextPage,
                            hasMoreCallLogs = newLogs.size >= callLogPageSize
                        )
                    }
                }
            }
        }
    }

    private fun setRecordingConsent(granted: Boolean) {
        viewModelScope.launch {
            recordingStore.setConsentGranted(granted)
        }
    }

    private fun updateCallNoteText(text: String) {
        _uiState.update { it.copy(pendingCallNoteText = text) }
    }

    private fun dismissCallNote() {
        _uiState.update { 
            it.copy(
                pendingCallNote = null,
                pendingCallNoteText = "",
                pendingLeadName = "",
                pendingUniversityId = null
            )
        }
        viewModelScope.launch { callNoteStore.clear() }
    }

    private fun saveCallNote() {
        val state = _uiState.value
        val pending = state.pendingCallNote ?: return
        val lead = pending.lead ?: return
        if (state.pendingCallNoteText.isBlank()) return

        viewModelScope.launch {
            _uiState.update { it.copy(isSavingCallNote = true) }
            val result = leadApi.addNote(lead.id, state.pendingCallNoteText)
            result.onSuccess {
                dismissCallNote()
                _uiState.update { it.copy(statusMessage = "Post-call note saved") }
            }.onFailure {
                _uiState.update { it.copy(error = "Failed to save note") }
            }
            _uiState.update { it.copy(isSavingCallNote = false) }
        }
    }

    private fun updatePendingLeadName(name: String) {
        _uiState.update { it.copy(pendingLeadName = name) }
    }

    private fun selectUniversity(id: Long) {
        _uiState.update { it.copy(pendingUniversityId = id, isUniversityMenuOpen = false) }
    }

    private fun toggleUniversityMenu() {
        _uiState.update { it.copy(isUniversityMenuOpen = !it.isUniversityMenuOpen) }
    }

    private fun createLeadFromCall() {
        val state = _uiState.value
        val pending = state.pendingCallNote ?: return
        val name = state.pendingLeadName.ifBlank { "Unknown Lead" }

        viewModelScope.launch {
            val result = leadApi.createLead(name, pending.phoneNumber, state.pendingUniversityId)
            result.onSuccess { newLead ->
                _uiState.update { 
                    it.copy(
                        leads = listOf(newLead) + it.leads,
                        pendingCallNote = pending.copy(lead = newLead),
                        showLeadCreation = false
                    )
                }
            }.onFailure {
                _uiState.update { it.copy(error = "Failed to create lead") }
            }
        }
    }

    private fun reloadSelectedLead() {
        val state = _uiState.value
        val lead = state.selectedLead ?: return
        viewModelScope.launch {
            leadApi.getLead(lead.lead.id).onSuccess { detail ->
                _uiState.update { 
                    it.copy(
                        selectedLead = detail,
                        callLogs = detail.callLogs
                    )
                }
            }
        }
    }

    private fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    private fun clearStatusMessage() {
        _uiState.update { it.copy(statusMessage = null) }
    }

    private fun findLeadByPhone(leads: List<LeadSummary>, phone: String): LeadSummary? {
        val normalized = normalizePhone(phone)
        return leads.firstOrNull { normalizePhone(it.phoneNumber) == normalized }
    }

    private fun normalizePhone(phone: String): String {
        val digits = phone.filter { it.isDigit() }
        return if (digits.length > 10) digits.takeLast(10) else digits
    }

    class Factory(
        private val context: Context
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return LeadHomeViewModel(
                leadApi = LeadApi(),
                syncStore = CallLogSyncStore(context),
                recordingStore = RecordingStore(context),
                callNoteStore = CallNoteStore(context)
            ) as T
        }
    }
}
