package com.koncrm.counselor.recordings

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.koncrm.counselor.auth.SessionStore
import com.koncrm.counselor.network.LeadApi
import kotlinx.coroutines.flow.firstOrNull
import java.io.File
import java.time.Instant

class RecordingUploadWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val sessionStore = SessionStore(applicationContext)
        val session = sessionStore.sessionFlow.firstOrNull() ?: return Result.retry()

        val filePath = inputData.getString(KEY_FILE_PATH) ?: return Result.failure()
        val durationSeconds = inputData.getLong(KEY_DURATION_SECONDS, 0)
        val consentGranted = inputData.getBoolean(KEY_CONSENT_GRANTED, false)
        var leadId = inputData.getLong(KEY_LEAD_ID, 0).takeIf { it > 0 }
        val callLogId = inputData.getLong(KEY_CALL_LOG_ID, 0).takeIf { it > 0 }
        val phoneNumber = inputData.getString(KEY_PHONE_NUMBER)
        val recordedAt = inputData.getString(KEY_RECORDED_AT)

        val file = File(filePath)
        if (!file.exists()) return Result.failure()

        if (leadId == null && !phoneNumber.isNullOrBlank()) {
            val leadApi = LeadApi()
            val lookup = leadApi.findLeadIdByPhone(session.accessToken, phoneNumber)
            leadId = lookup.getOrNull()
        }

        val recordingStore = RecordingStore(applicationContext)
        recordingStore.setStatus("uploading", file.name)

        val manager = RecordingUploadManager()
        val result = manager.enqueueUpload(
            accessToken = session.accessToken,
            file = file,
            leadId = leadId,
            callLogId = callLogId,
            consentGranted = consentGranted,
            durationSeconds = durationSeconds,
            recordedAtIso = recordedAt?.takeIf { it.isNotBlank() } ?: Instant.now().toString()
        )

        return result.fold(
            onSuccess = {
                recordingStore.setStatus("uploaded", file.name)
                Result.success()
            },
            onFailure = { error ->
                recordingStore.setStatus("failed", file.name, error.message)
                Result.retry()
            }
        )
    }

    companion object {
        const val KEY_FILE_PATH = "file_path"
        const val KEY_DURATION_SECONDS = "duration_seconds"
        const val KEY_CONSENT_GRANTED = "consent_granted"
        const val KEY_LEAD_ID = "lead_id"
        const val KEY_CALL_LOG_ID = "call_log_id"
        const val KEY_PHONE_NUMBER = "phone_number"
        const val KEY_RECORDED_AT = "recorded_at"
    }
}
