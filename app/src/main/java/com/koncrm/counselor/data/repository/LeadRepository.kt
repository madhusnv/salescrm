package com.koncrm.counselor.data.repository

import android.content.Context
import com.koncrm.counselor.data.local.AppDatabase
import com.koncrm.counselor.data.local.LeadEntity
import com.koncrm.counselor.data.local.PendingActionEntity
import com.koncrm.counselor.leads.LeadSummary
import com.koncrm.counselor.leads.LeadDetail
import com.koncrm.counselor.network.LeadApi
import kotlinx.coroutines.flow.Flow
import org.json.JSONObject

/**
 * Repository that manages lead data from both local Room database and remote API.
 * Provides offline-first data access with background sync capabilities.
 */
class LeadRepository(context: Context) {
    private val database = AppDatabase.getInstance(context)
    private val leadDao = database.leadDao()
    private val pendingDao = database.pendingActionDao()
    private val api = LeadApi()

    // --- Observable data from local database ---

    fun observeLeads(): Flow<List<LeadEntity>> = leadDao.getAllLeads()

    fun searchLeads(query: String): Flow<List<LeadEntity>> = leadDao.searchLeads(query)

    fun getLeadsByStatus(status: String): Flow<List<LeadEntity>> = leadDao.getLeadsByStatus(status)

    fun observePendingCount(): Flow<Int> = pendingDao.getPendingCount()

    // --- Sync from API to local database ---

    /**
     * Fetches leads from the API and caches them locally.
     * Returns the number of leads synced.
     */
    suspend fun syncLeads(): Result<Int> {
        return try {
            val result = api.listLeads(
                page = 1,
                pageSize = 500,
                status = null,
                search = null
            )

            result.fold(
                onSuccess = { leads ->
                    val entities = leads.map { it.toEntity() }
                    leadDao.insertLeads(entities)
                    Result.success(entities.size)
                },
                onFailure = { error ->
                    Result.failure(error)
                }
            )
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Gets a lead from cache, or fetches from API if not cached.
     */
    suspend fun getLead(id: Long): LeadEntity? {
        // Try cache first
        val cached = leadDao.getLeadById(id)
        if (cached != null) return cached

        // Fetch from API and cache
        return try {
            val result = api.getLead(id)
            result.getOrNull()?.let { detail ->
                val entity = detail.toEntity()
                leadDao.insertLead(entity)
                entity
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Finds a lead by phone number in local cache.
     */
    suspend fun findByPhone(phoneNumber: String): LeadEntity? {
        val normalized = normalizePhone(phoneNumber)
        return leadDao.findByPhone("%$normalized%")
    }

    // --- Offline action queue ---

    /**
     * Queues an action to be performed when online.
     */
    suspend fun queueAction(leadId: Long, actionType: String, payload: Map<String, Any>) {
        val json = JSONObject(payload).toString()
        pendingDao.insert(
            PendingActionEntity(
                leadId = leadId,
                actionType = actionType,
                payload = json
            )
        )
    }

    /**
     * Processes all pending actions. Returns the number successfully processed.
     */
    suspend fun processPendingActions(): Int {
        val pending = pendingDao.getAllPending()
        var processed = 0

        for (action in pending) {
            val success = try {
                when (action.actionType) {
                    "note" -> processNoteAction(action)
                    "status" -> processStatusAction(action)
                    "followup" -> processFollowupAction(action)
                    else -> true // Unknown action type, just delete it
                }
            } catch (e: Exception) {
                false
            }

            if (success) {
                pendingDao.deleteById(action.id)
                processed++
            } else if (action.retryCount < 3) {
                pendingDao.incrementRetry(action.id)
            } else {
                // Give up after 3 retries
                pendingDao.deleteById(action.id)
            }
        }

        return processed
    }

    private suspend fun processNoteAction(action: PendingActionEntity): Boolean {
        val json = JSONObject(action.payload)
        val text = json.optString("text", "")
        val result = api.addNote(action.leadId, text)
        return result.isSuccess
    }

    private suspend fun processStatusAction(action: PendingActionEntity): Boolean {
        val json = JSONObject(action.payload)
        val status = json.optString("status", "")
        val result = api.updateStatus(action.leadId, status)
        return result.isSuccess
    }

    private suspend fun processFollowupAction(action: PendingActionEntity): Boolean {
        val json = JSONObject(action.payload)
        val dueAt = json.optString("dueAt", "")
        val note = json.optString("note", "")
        val result = api.scheduleFollowup(action.leadId, dueAt, note)
        return result.isSuccess
    }

    // --- Conversion helpers ---

    private fun LeadSummary.toEntity(): LeadEntity {
        return LeadEntity(
            id = this.id,
            studentName = this.studentName,
            phoneNumber = this.phoneNumber,
            email = null, // LeadSummary doesn't have email
            status = this.status,
            universityId = null,
            universityName = this.universityName,
            counselorId = null,
            counselorName = this.counselorName,
            branchId = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
    }

    private fun LeadDetail.toEntity(): LeadEntity {
        return LeadEntity(
            id = this.lead.id,
            studentName = this.lead.studentName,
            phoneNumber = this.lead.phoneNumber,
            email = null,
            status = this.lead.status,
            universityId = null,
            universityName = this.lead.universityName,
            counselorId = null,
            counselorName = this.lead.counselorName,
            branchId = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
    }

    private fun normalizePhone(phone: String): String {
        val digits = phone.filter { it.isDigit() }
        return if (digits.length > 10) digits.takeLast(10) else digits
    }
}
