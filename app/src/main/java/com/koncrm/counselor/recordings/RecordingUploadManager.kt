package com.koncrm.counselor.recordings

import com.koncrm.counselor.network.ApiConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONObject
import java.io.File

data class UploadResult(
    val fileUrl: String,
    val fileSizeBytes: Long
)

class RecordingUploadManager(
    private val api: RecordingApi = RecordingApi(ApiConfig.BASE_URL),
    private val client: OkHttpClient = OkHttpClient()
) {
    suspend fun enqueueUpload(
        accessToken: String,
        file: File,
        leadId: Long?,
        callLogId: Long?,
        consentGranted: Boolean,
        durationSeconds: Long,
        recordedAtIso: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        val initResult = api.initRecording(
            accessToken = accessToken,
            leadId = leadId,
            callLogId = callLogId,
            contentType = "audio/m4a",
            consentGranted = consentGranted,
            recordedAtIso = recordedAtIso
        )

        initResult.fold(
            onSuccess = { init ->
                val uploadResult = uploadFile(accessToken, init.uploadUrl, file)
                uploadResult.fold(
                    onSuccess = { upload ->
                        api.completeRecording(
                            accessToken = accessToken,
                            recordingId = init.id,
                            fileUrl = upload.fileUrl,
                            fileSizeBytes = upload.fileSizeBytes,
                            durationSeconds = durationSeconds
                        )
                    },
                    onFailure = { error -> Result.failure(error) }
                )
            },
            onFailure = { error -> Result.failure(error) }
        )
    }

    private suspend fun uploadFile(
        accessToken: String,
        uploadUrl: String,
        file: File
    ): Result<UploadResult> = withContext(Dispatchers.IO) {
        val body = file.asRequestBody("audio/m4a".toMediaType())
        val request = Request.Builder()
            .url(uploadUrl)
            .header("Authorization", "Bearer ${accessToken}")
            .header("Accept", "application/json")
            .put(body)
            .build()

        runCatching {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw IllegalStateException("Recording upload failed with ${response.code}")
                }
                val responseBody = response.body?.string().orEmpty()
                val data = JSONObject(responseBody).getJSONObject("data")
                UploadResult(
                    fileUrl = data.getString("file_url"),
                    fileSizeBytes = data.getLong("file_size_bytes")
                )
            }
        }
    }
}
