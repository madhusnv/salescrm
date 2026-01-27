package com.koncrm.counselor.work

import android.content.Context
import android.provider.CallLog
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.koncrm.counselor.auth.SessionStore
import com.koncrm.counselor.data.repository.LeadRepository
import com.koncrm.counselor.network.CallLogApi
import com.koncrm.counselor.recordings.RecordingStore
import com.koncrm.counselor.util.LeadPhoneIndex
import kotlinx.coroutines.flow.first
import org.json.JSONObject
import java.time.Instant
import android.util.Log

private const val TAG = "CallLogSyncWorker"
private const val LEAD_CACHE_MAX_AGE_MS = 60 * 60 * 1000L

class CallLogSyncWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        Log.i(TAG, "Starting call log sync...")
        val sessionStore = SessionStore(applicationContext)

        // Initialize AuthenticatedHttpClient for this worker context
        com.koncrm.counselor.network.AuthenticatedHttpClient.init(sessionStore)

        val session = sessionStore.sessionFlow.first()
        if (session == null) {
            Log.w(TAG, "No session, retrying later")
            return Result.retry()
        }
        Log.d(TAG, "Session found, proceeding with sync")

        val leadRepository = LeadRepository(applicationContext)
        val lastLeadSyncAt = leadRepository.getLastSyncedAt()
        val now = System.currentTimeMillis()
        val cacheStale = lastLeadSyncAt == null || now - lastLeadSyncAt > LEAD_CACHE_MAX_AGE_MS
        if (cacheStale) {
            val leadSync = leadRepository.syncLeads()
            if (leadSync.isFailure) {
                Log.w(TAG, "Lead cache refresh failed; retrying sync later")
                return Result.retry()
            }
        }
        val leadIndex: LeadPhoneIndex = leadRepository.buildPhoneIndex()
        if (leadIndex.isEmpty()) {
            Log.i(TAG, "Lead cache is empty; will skip non-lead calls")
        }

        val syncStore = CallLogSyncStore(applicationContext)
        val lastSyncedAt = syncStore.getLastSyncedAt() ?: 0L
        val lastSyncedCallId = syncStore.getLastSyncedCallId() ?: 0L
        Log.d(TAG, "Last synced at: $lastSyncedAt")
        val api = CallLogApi()
        val recordingStore = RecordingStore(applicationContext)
        val recordingState = recordingStore.stateFlow().first()

        val resolver = applicationContext.contentResolver
        val projection = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION
        )
        var newestTimestamp = lastSyncedAt
        var newestCallId = lastSyncedCallId
        var hasFailures = false
        var syncedCount = 0
        var duplicateCount = 0
        var failureCount = 0
        var skippedCount = 0

        val batchSize = 50
        while (true) {
            val selection =
                if (newestTimestamp > 0L) {
                    "(${CallLog.Calls.DATE} > ?) OR (${CallLog.Calls.DATE} = ? AND ${CallLog.Calls._ID} > ?)"
                } else {
                    null
                }
            val selectionArgs =
                if (newestTimestamp > 0L) {
                    arrayOf(
                        newestTimestamp.toString(),
                        newestTimestamp.toString(),
                        newestCallId.toString()
                    )
                } else {
                    null
                }
            val sortOrder = "${CallLog.Calls.DATE} ASC, ${CallLog.Calls._ID} ASC"

            val cursor = try {
                resolver.query(
                    CallLog.Calls.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder
                )
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException querying call log", e)
                return Result.retry()
            }

            var batchCount = 0
            cursor?.use {
                val idIndex = it.getColumnIndex(CallLog.Calls._ID)
                val numberIndex = it.getColumnIndex(CallLog.Calls.NUMBER)
                val typeIndex = it.getColumnIndex(CallLog.Calls.TYPE)
                val dateIndex = it.getColumnIndex(CallLog.Calls.DATE)
                val durationIndex = it.getColumnIndex(CallLog.Calls.DURATION)

                while (it.moveToNext() && batchCount < batchSize) {
                    batchCount += 1
                    val callId = it.getLong(idIndex)
                    val number = it.getString(numberIndex).orEmpty()
                    val callType = mapCallType(it.getInt(typeIndex))
                    val timestamp = it.getLong(dateIndex)
                    val durationSeconds = it.getLong(durationIndex)
                    val leadId = leadIndex.findLeadId(number)

                    if (leadId == null) {
                        skippedCount += 1
                        if (timestamp > newestTimestamp) {
                            newestTimestamp = timestamp
                            newestCallId = callId
                        } else if (timestamp == newestTimestamp && callId > newestCallId) {
                            newestCallId = callId
                        }
                        Log.d(TAG, "Skipping non-lead call log")
                        continue
                    }

                    val startedAt = Instant.ofEpochMilli(timestamp)
                    val endedAt = if (durationSeconds > 0) {
                        Instant.ofEpochMilli(timestamp + durationSeconds * 1000)
                    } else {
                        null
                    }

                    val payload = JSONObject()
                        .put("phone_number", number)
                        .put("call_type", callType)
                        .put("device_call_id", callId.toString())
                        .put("started_at", startedAt.toString())
                        .put("ended_at", endedAt?.toString())
                        .put("duration_seconds", durationSeconds)
                        .put("consent_granted", recordingState.consentGranted)
                        .put("consent_recorded_at", endedAt?.toString() ?: startedAt.toString())
                        .put("consent_source", "android")
                        .put(
                            "metadata",
                            JSONObject().put("call_log_id", callId).put("source", "android")
                        )

                    val result = api.sendCallLog(payload)
                    if (result.isFailure) {
                        failureCount += 1
                        Log.e(TAG, "Call log sync failed: ${result.exceptionOrNull()?.message}")
                        hasFailures = true
                        break
                    } else {
                        when (result.getOrNull()) {
                            "duplicate" -> duplicateCount += 1
                            "ignored" -> skippedCount += 1
                            else -> syncedCount += 1
                        }
                        if (timestamp > newestTimestamp) {
                            newestTimestamp = timestamp
                            newestCallId = callId
                        } else if (timestamp == newestTimestamp && callId > newestCallId) {
                            newestCallId = callId
                        }
                }
            }
            }

            if (hasFailures || batchCount == 0) {
                break
            }
        }

        syncStore.setStats(syncedCount, duplicateCount, failureCount, newestTimestamp, newestCallId)
        Log.i(
            TAG,
            "Sync complete: synced=$syncedCount, duplicates=$duplicateCount, failures=$failureCount, skipped=$skippedCount"
        )

        return if (hasFailures) Result.retry() else Result.success()
    }

    private fun mapCallType(type: Int): String {
        return when (type) {
            CallLog.Calls.INCOMING_TYPE -> "incoming"
            CallLog.Calls.OUTGOING_TYPE -> "outgoing"
            CallLog.Calls.MISSED_TYPE -> "missed"
            CallLog.Calls.REJECTED_TYPE -> "rejected"
            CallLog.Calls.BLOCKED_TYPE -> "blocked"
            else -> "unknown"
        }
    }

}
