package com.koncrm.counselor.network

import com.koncrm.counselor.leads.CallLogEntry
import com.koncrm.counselor.leads.LeadActivity
import com.koncrm.counselor.leads.LeadDetail
import com.koncrm.counselor.leads.LeadFollowup
import com.koncrm.counselor.leads.LeadSummary
import com.koncrm.counselor.leads.University
import com.koncrm.counselor.leads.RecordingEntry
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONArray
import org.json.JSONObject

class LeadApi(
    private val baseUrl: String = ApiConfig.BASE_URL
) {
    private val client: OkHttpClient
        get() = AuthenticatedHttpClient.getClient()

    suspend fun listLeads(
        page: Int,
        pageSize: Int,
        status: String?,
        search: String?,
        universityId: Long? = null,
        activityFilter: String? = null,
        followupFilter: String? = null
    ): Result<List<LeadSummary>> =
        withContext(Dispatchers.IO) {
            val params = mutableListOf(
                "page=${page}",
                "page_size=${pageSize}"
            )
            if (!status.isNullOrBlank()) {
                params.add("status=${status}")
            }
            if (!search.isNullOrBlank()) {
                params.add("search=${java.net.URLEncoder.encode(search, "UTF-8")}")
            }
            if (universityId != null) {
                params.add("university_id=${universityId}")
            }
            if (!activityFilter.isNullOrBlank()) {
                params.add("activity_filter=${activityFilter}")
            }
            if (!followupFilter.isNullOrBlank()) {
                params.add("followup_filter=${followupFilter}")
            }
            val request = Request.Builder()
                .url("${baseUrl}/api/leads?${params.joinToString("&")}")
                .get()
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Lead list failed with ${response.code}")
                    }
                    val body = response.body?.string().orEmpty()
                    val data = JSONObject(body).getJSONArray("data")
                    parseLeadList(data)
                }
            }
        }

    suspend fun getLead(leadId: Long): Result<LeadDetail> =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("${baseUrl}/api/leads/${leadId}")
                .get()
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Lead detail failed with ${response.code}")
                    }
                    val body = response.body?.string().orEmpty()
                    val data = JSONObject(body).getJSONObject("data")
                    parseLeadDetail(data)
                }
            }
        }

    suspend fun listUniversities(): Result<List<University>> =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("${baseUrl}/api/universities")
                .get()
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Universities failed with ${response.code}")
                    }
                    val body = response.body?.string().orEmpty()
                    val data = JSONObject(body).getJSONArray("data")
                    (0 until data.length()).map { index ->
                        val item = data.getJSONObject(index)
                        University(
                            id = item.getLong("id"),
                            name = item.optString("name")
                        )
                    }
                }
            }
        }

    suspend fun createLead(
        studentName: String,
        phoneNumber: String,
        universityId: Long?
    ): Result<LeadSummary> =
        withContext(Dispatchers.IO) {
            val payload = JSONObject()
                .put("student_name", studentName)
                .put("phone_number", phoneNumber)
            if (universityId != null) {
                payload.put("university_id", universityId)
            }
            val request = Request.Builder()
                .url("${baseUrl}/api/leads")
                .post(payload.toString().toRequestBody(JSON))
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Create lead failed with ${response.code}")
                    }
                    val body = response.body?.string().orEmpty()
                    val data = JSONObject(body).getJSONObject("data")
                    parseLeadSummary(data)
                }
            }
        }

    suspend fun listCallLogs(
        leadId: Long,
        page: Int,
        pageSize: Int
    ): Result<List<CallLogEntry>> =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("${baseUrl}/api/call-logs?lead_id=${leadId}&page=${page}&page_size=${pageSize}")
                .get()
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Call logs failed with ${response.code}")
                    }
                    val body = response.body?.string().orEmpty()
                    val data = JSONObject(body).getJSONArray("data")
                    (0 until data.length()).map { index ->
                        val item = data.getJSONObject(index)
                        CallLogEntry(
                            id = item.getLong("id"),
                            callType = item.optString("call_type"),
                            startedAt = item.optString("started_at"),
                            durationSeconds = item.optLong("duration_seconds")
                        )
                    }
                }
            }
        }

    suspend fun addNote(leadId: Long, body: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            val payload = JSONObject().put("body", body)
            val request = Request.Builder()
                .url("${baseUrl}/api/leads/${leadId}/notes")
                .post(payload.toString().toRequestBody(JSON))
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Add note failed with ${response.code}")
                    }
                }
            }
        }

    suspend fun updateStatus(leadId: Long, status: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            val payload = JSONObject().put("status", status)
            val request = Request.Builder()
                .url("${baseUrl}/api/leads/${leadId}/status")
                .post(payload.toString().toRequestBody(JSON))
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Status update failed with ${response.code}")
                    }
                }
            }
        }

    suspend fun scheduleFollowup(
        leadId: Long,
        dueAt: String,
        note: String?
    ): Result<Unit> =
        withContext(Dispatchers.IO) {
            val payload = JSONObject()
                .put("due_at", dueAt)
                .put("note", note)
            val request = Request.Builder()
                .url("${baseUrl}/api/leads/${leadId}/followups")
                .post(payload.toString().toRequestBody(JSON))
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Follow-up failed with ${response.code}")
                    }
                }
            }
        }

    suspend fun findLeadIdByPhone(phoneNumber: String): Result<Long?> =
        listLeads(
            page = 1,
            pageSize = 5,
            status = null,
            search = phoneNumber
        ).map { leads ->
            if (leads.isEmpty()) {
                null
            } else {
                val normalized = normalizePhone(phoneNumber)
                leads.firstOrNull { normalizePhone(it.phoneNumber) == normalized }?.id
                    ?: leads.first().id
            }
        }

    private fun parseLeadList(array: JSONArray): List<LeadSummary> {
        val results = mutableListOf<LeadSummary>()
        for (i in 0 until array.length()) {
            val lead = array.getJSONObject(i)
            results.add(parseLeadSummary(lead))
        }
        return results
    }

    private fun parseLeadSummary(lead: JSONObject): LeadSummary {
        return LeadSummary(
            id = lead.getLong("id"),
            studentName = lead.optString("student_name"),
            phoneNumber = lead.optString("phone_number"),
            status = lead.optString("status"),
            universityName = lead.optJSONObject("university")?.optString("name"),
            counselorName = lead.optJSONObject("assigned_counselor")?.optString("full_name")
        )
    }

    private fun parseLeadDetail(data: JSONObject): LeadDetail {
        val lead = parseLeadSummary(data.getJSONObject("lead"))
        val activitiesArray = data.optJSONArray("activities") ?: JSONArray()
        val followupsArray = data.optJSONArray("followups") ?: JSONArray()
        val callLogsArray = data.optJSONArray("call_logs") ?: JSONArray()
        val recordingsArray = data.optJSONArray("recordings") ?: JSONArray()

        val activities = (0 until activitiesArray.length()).map { index ->
            val item = activitiesArray.getJSONObject(index)
            LeadActivity(
                id = item.getLong("id"),
                type = item.optString("activity_type"),
                body = item.optString("body"),
                occurredAt = item.optString("occurred_at"),
                userName = item.optJSONObject("user")?.optString("full_name")
            )
        }

        val followups = (0 until followupsArray.length()).map { index ->
            val item = followupsArray.getJSONObject(index)
            LeadFollowup(
                id = item.getLong("id"),
                dueAt = item.optString("due_at"),
                status = item.optString("status"),
                note = item.optString("note")
            )
        }

        val callLogs = (0 until callLogsArray.length()).map { index ->
            val item = callLogsArray.getJSONObject(index)
            CallLogEntry(
                id = item.getLong("id"),
                callType = item.optString("call_type"),
                startedAt = item.optString("started_at"),
                durationSeconds = item.optLong("duration_seconds")
            )
        }

        val recordings = (0 until recordingsArray.length()).map { index ->
            val item = recordingsArray.getJSONObject(index)
            RecordingEntry(
                id = item.getLong("id"),
                status = item.optString("status"),
                fileUrl = item.optString("file_url").ifBlank { null },
                durationSeconds = item.optLong("duration_seconds"),
                recordedAt = item.optString("recorded_at")
            )
        }

        return LeadDetail(
            lead = lead,
            lastActivityAt = data.getJSONObject("lead").optString("last_activity_at"),
            nextFollowUpAt = data.getJSONObject("lead").optString("next_follow_up_at"),
            activities = activities,
            followups = followups,
            callLogs = callLogs,
            recordings = recordings
        )
    }

    private fun normalizePhone(phone: String): String {
        val digits = phone.filter { it.isDigit() }
        return if (digits.length > 10) digits.takeLast(10) else digits
    }

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}
