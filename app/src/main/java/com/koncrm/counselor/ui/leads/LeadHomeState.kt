package com.koncrm.counselor.ui.leads

import com.koncrm.counselor.leads.LeadDetail
import com.koncrm.counselor.leads.LeadSummary
import com.koncrm.counselor.leads.University
import com.koncrm.counselor.leads.CallLogEntry
import com.koncrm.counselor.recordings.RecordingState
import com.koncrm.counselor.work.CallLogSyncStats

/**
 * UI state for the Lead Home screen
 */
data class LeadHomeUiState(
    // Lead list state
    val leads: List<LeadSummary> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val hasMoreLeads: Boolean = true,
    val currentPage: Int = 1,
    
    // Filters
    val searchQuery: String = "",
    val statusFilter: String = "",
    val universityFilter: Long? = null,
    val activityFilter: String = "",  // "", "today", "week", "stale"
    val followupFilter: String = "",  // "", "overdue", "due_today", "upcoming"
    val isFilterExpanded: Boolean = false,
    
    // Selected lead detail
    val selectedLead: LeadDetail? = null,
    val selectedTab: Int = 0,
    
    // Call logs pagination
    val callLogs: List<CallLogEntry> = emptyList(),
    val hasMoreCallLogs: Boolean = true,
    val callLogPage: Int = 1,
    val callLogFilter: String = "",
    
    // Note input
    val noteText: String = "",
    val isSavingNote: Boolean = false,
    
    // Follow-up scheduling
    val followupDueAtMillis: Long? = null,
    val followupNote: String = "",
    val isSchedulingFollowup: Boolean = false,
    
    // Status update
    val isUpdatingStatus: Boolean = false,
    
    // Error/success messages
    val error: String? = null,
    val statusMessage: String? = null,
    
    // Sync stats
    val syncStats: CallLogSyncStats = CallLogSyncStats(null, 0, 0, 0),
    val recordingState: RecordingState = RecordingState(false, "idle", null, null),
    
    // Post-call note overlay
    val pendingCallNote: PendingCallNote? = null,
    val pendingCallNoteText: String = "",
    val isSavingCallNote: Boolean = false,
    val showLeadCreation: Boolean = true,
    val pendingLeadName: String = "",
    val pendingUniversityId: Long? = null,
    val isUniversityMenuOpen: Boolean = false,
    val universities: List<University> = emptyList()
)

/**
 * Pending post-call note data
 */
data class PendingCallNote(
    val phoneNumber: String,
    val lead: LeadSummary?,
    val endedAtMillis: Long?
)

/**
 * Events that can be triggered from the UI
 */
sealed class LeadHomeEvent {
    // Navigation
    data class SelectLead(val lead: LeadSummary) : LeadHomeEvent()
    object ClearSelection : LeadHomeEvent()
    
    // Filters
    data class UpdateSearchQuery(val query: String) : LeadHomeEvent()
    data class UpdateStatusFilter(val status: String) : LeadHomeEvent()
    data class UpdateUniversityFilter(val universityId: Long?) : LeadHomeEvent()
    data class UpdateActivityFilter(val filter: String) : LeadHomeEvent()
    data class UpdateFollowupFilter(val filter: String) : LeadHomeEvent()
    object ToggleFilterExpanded : LeadHomeEvent()
    object ClearAllFilters : LeadHomeEvent()
    object ApplyFilters : LeadHomeEvent()
    object RefreshLeads : LeadHomeEvent()
    object LoadMoreLeads : LeadHomeEvent()
    
    // Lead detail actions
    data class SelectTab(val index: Int) : LeadHomeEvent()
    data class UpdateNoteText(val text: String) : LeadHomeEvent()
    object SubmitNote : LeadHomeEvent()
    data class UpdateLeadStatus(val status: String) : LeadHomeEvent()
    
    // Follow-up
    data class SetFollowupDate(val millis: Long) : LeadHomeEvent()
    data class UpdateFollowupNote(val note: String) : LeadHomeEvent()
    object ScheduleFollowup : LeadHomeEvent()
    
    // Call logs
    data class UpdateCallLogFilter(val filter: String) : LeadHomeEvent()
    object LoadMoreCallLogs : LeadHomeEvent()
    
    // Sync/Recording
    data class SetRecordingConsent(val granted: Boolean) : LeadHomeEvent()
    
    // Post-call note
    data class UpdateCallNoteText(val text: String) : LeadHomeEvent()
    object DismissCallNote : LeadHomeEvent()
    object SaveCallNote : LeadHomeEvent()
    data class UpdatePendingLeadName(val name: String) : LeadHomeEvent()
    data class SelectUniversity(val id: Long) : LeadHomeEvent()
    object ToggleUniversityMenu : LeadHomeEvent()
    object CreateLeadFromCall : LeadHomeEvent()
    
    // Messages
    object ClearError : LeadHomeEvent()
    object ClearStatusMessage : LeadHomeEvent()
}
