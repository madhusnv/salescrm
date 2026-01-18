package com.koncrm.counselor.recordings

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import androidx.work.*
import com.koncrm.counselor.auth.SessionStore
import com.koncrm.counselor.network.ApiConfig
import com.koncrm.counselor.network.LeadApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.InputStream
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * Worker that scans the user-selected SAF folder for call recordings,
 * matches them to leads by phone number, and uploads them to the backend.
 */
class FolderRecordingSyncWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    private val folderStore = RecordingFolderStore(applicationContext)
    private val syncedStore = SyncedRecordingsStore(applicationContext)
    private val sessionStore = SessionStore(applicationContext)
    private val leadApi = LeadApi()
    private val recordingApi = RecordingApi(ApiConfig.BASE_URL)
    private val client = OkHttpClient()

    override suspend fun doWork(): Result {
        val session = sessionStore.sessionFlow.firstOrNull() ?: return Result.retry()
        
        // Initialize AuthenticatedHttpClient for this worker context  
        com.koncrm.counselor.network.AuthenticatedHttpClient.init(sessionStore)
        
        val folderUri = folderStore.getFolderUri() ?: return Result.success() // No folder selected

        return withContext(Dispatchers.IO) {
            try {
                val files = folderStore.listRecordingFiles()
                var uploadedCount = 0
                var failedCount = 0

                for (file in files) {
                    // Skip already synced files
                    if (syncedStore.isSynced(file.uri.toString())) {
                        continue
                    }

                    // Try to extract phone number from filename
                    val phoneNumber = extractPhoneFromFilename(file.name)
                    
                    // Find matching lead
                    var leadId: Long? = null
                    if (phoneNumber != null) {
                        val lookupResult = leadApi.findLeadIdByPhone(phoneNumber)
                        leadId = lookupResult.getOrNull()
                    }

                    // Upload the recording
                    val uploadResult = uploadRecording(
                        fileUri = file.uri,
                        fileName = file.name,
                        leadId = leadId,
                        recordedAtMillis = file.lastModified,
                        fileSizeBytes = file.size
                    )

                    if (uploadResult.isSuccess) {
                        syncedStore.markSynced(file.uri.toString(), file.name)
                        uploadedCount++
                    } else {
                        failedCount++
                    }
                }

                Result.success(
                    workDataOf(
                        KEY_UPLOADED_COUNT to uploadedCount,
                        KEY_FAILED_COUNT to failedCount
                    )
                )
            } catch (e: Exception) {
                Result.retry()
            }
        }
    }

    private suspend fun uploadRecording(
        fileUri: Uri,
        fileName: String,
        leadId: Long?,
        recordedAtMillis: Long,
        fileSizeBytes: Long
    ): kotlin.Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            // 1. Init recording
            val recordedAtIso = Instant.ofEpochMilli(recordedAtMillis).toString()
            val contentType = guessContentType(fileName)

            val initResult = recordingApi.initRecording(
                leadId = leadId,
                callLogId = null,
                contentType = contentType,
                consentGranted = true, // User explicitly selected this folder
                recordedAtIso = recordedAtIso
            ).getOrThrow()

            // 2. Upload file bytes
            val inputStream: InputStream = applicationContext.contentResolver.openInputStream(fileUri)
                ?: throw IllegalStateException("Cannot read file: $fileUri")
            
            val fileBytes = inputStream.use { it.readBytes() }
            
            val uploadRequest = Request.Builder()
                .url(initResult.uploadUrl)
                .put(fileBytes.toRequestBody(contentType.toMediaType()))
                .build()

            val uploadResponse = client.newCall(uploadRequest).execute()
            if (!uploadResponse.isSuccessful) {
                throw IllegalStateException("Upload failed: ${uploadResponse.code}")
            }

            val uploadBody = uploadResponse.body?.string() ?: "{}"
            val uploadData = JSONObject(uploadBody).optJSONObject("data")
            val fileUrl = uploadData?.optString("file_url") ?: ""
            val uploadedSize = uploadData?.optLong("file_size_bytes") ?: fileSizeBytes

            // 3. Complete recording
            // Estimate duration from file size (rough: 12kB/sec for m4a)
            val estimatedDuration = (fileSizeBytes / 12000).coerceAtLeast(1)

            recordingApi.completeRecording(
                recordingId = initResult.id,
                fileUrl = fileUrl,
                fileSizeBytes = uploadedSize,
                durationSeconds = estimatedDuration
            ).getOrThrow()
        }
    }

    private fun extractPhoneFromFilename(filename: String): String? {
        // Extract digits from filename
        val digits = filename.filter { it.isDigit() }
        
        // Phone numbers are typically 10+ digits
        return if (digits.length >= 10) {
            digits.takeLast(10)
        } else {
            null
        }
    }

    private fun guessContentType(filename: String): String {
        return when {
            filename.endsWith(".m4a", ignoreCase = true) -> "audio/mp4"
            filename.endsWith(".mp3", ignoreCase = true) -> "audio/mpeg"
            filename.endsWith(".amr", ignoreCase = true) -> "audio/amr"
            filename.endsWith(".wav", ignoreCase = true) -> "audio/wav"
            filename.endsWith(".ogg", ignoreCase = true) -> "audio/ogg"
            filename.endsWith(".3gp", ignoreCase = true) -> "audio/3gpp"
            else -> "audio/mpeg"
        }
    }

    companion object {
        const val WORK_NAME = "folder_recording_sync"
        const val KEY_UPLOADED_COUNT = "uploaded_count"
        const val KEY_FAILED_COUNT = "failed_count"

        /**
         * Enqueue a one-time sync
         */
        fun enqueueSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<FolderRecordingSyncWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.KEEP, request)
        }

        /**
         * Schedule periodic sync (every 15 minutes when on WiFi)
         */
        fun schedulePeriodicSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.UNMETERED)
                .build()

            val request = PeriodicWorkRequestBuilder<FolderRecordingSyncWorker>(
                15, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    "${WORK_NAME}_periodic",
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )
        }
    }
}
