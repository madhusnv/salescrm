package com.koncrm.counselor.recordings

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

data class RecordingInitResponse(
    val id: Long,
    val uploadUrl: String,
    val storageKey: String
)

class RecordingApi(
    private val baseUrl: String,
    private val client: OkHttpClient = OkHttpClient()
) {
    suspend fun initRecording(
        accessToken: String,
        leadId: Long?,
        callLogId: Long?,
        contentType: String,
        consentGranted: Boolean,
        recordedAtIso: String
    ): Result<RecordingInitResponse> =
        withContext(Dispatchers.IO) {
            val payload = JSONObject()
                .put("lead_id", leadId)
                .put("call_log_id", callLogId)
                .put("content_type", contentType)
                .put("consent_granted", consentGranted)
                .put("recorded_at", recordedAtIso)

            val request = Request.Builder()
                .url("${baseUrl}/api/recordings/init")
                .header("Authorization", "Bearer ${accessToken}")
                .post(payload.toString().toRequestBody(JSON))
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Recording init failed with ${response.code}")
                    }
                    val body = response.body?.string().orEmpty()
                    val data = JSONObject(body).getJSONObject("data")
                    RecordingInitResponse(
                        id = data.getLong("id"),
                        uploadUrl = data.getString("upload_url"),
                        storageKey = data.getString("storage_key")
                    )
                }
            }
        }

    suspend fun completeRecording(
        accessToken: String,
        recordingId: Long,
        fileUrl: String,
        fileSizeBytes: Long,
        durationSeconds: Long
    ): Result<Unit> =
        withContext(Dispatchers.IO) {
            val payload = JSONObject()
                .put("status", "uploaded")
                .put("file_url", fileUrl)
                .put("file_size_bytes", fileSizeBytes)
                .put("duration_seconds", durationSeconds)

            val request = Request.Builder()
                .url("${baseUrl}/api/recordings/${recordingId}/complete")
                .header("Authorization", "Bearer ${accessToken}")
                .post(payload.toString().toRequestBody(JSON))
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Recording complete failed with ${response.code}")
                    }
                }
            }
        }

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}
