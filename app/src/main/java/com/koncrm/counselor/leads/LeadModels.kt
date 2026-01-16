package com.koncrm.counselor.leads

data class LeadSummary(
    val id: Long,
    val studentName: String,
    val phoneNumber: String,
    val status: String,
    val universityName: String?,
    val counselorName: String?
)

data class LeadDetail(
    val lead: LeadSummary,
    val lastActivityAt: String?,
    val nextFollowUpAt: String?,
    val activities: List<LeadActivity>,
    val followups: List<LeadFollowup>,
    val callLogs: List<CallLogEntry>,
    val recordings: List<RecordingEntry>
)

data class LeadActivity(
    val id: Long,
    val type: String,
    val body: String?,
    val occurredAt: String?,
    val userName: String?
)

data class LeadFollowup(
    val id: Long,
    val dueAt: String?,
    val status: String,
    val note: String?
)

data class CallLogEntry(
    val id: Long,
    val callType: String,
    val startedAt: String?,
    val durationSeconds: Long?
)

data class RecordingEntry(
    val id: Long,
    val status: String,
    val fileUrl: String?,
    val durationSeconds: Long?,
    val recordedAt: String?
)

data class University(
    val id: Long,
    val name: String
)
