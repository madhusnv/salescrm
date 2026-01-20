package com.koncrm.counselor.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class CallLogApi(
    private val baseUrl: String = ApiConfig.BASE_URL
) {
    private val client: OkHttpClient
        get() = AuthenticatedHttpClient.getClient()

    suspend fun sendCallLog(payload: JSONObject): Result<String> =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("${baseUrl}/api/call-logs")
                .post(payload.toString().toRequestBody(JSON))
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        val errorBody = response.body?.string() ?: ""
                        throw IllegalStateException("Call log sync failed with ${response.code}: $errorBody")
                    }
                    val body = response.body?.string().orEmpty()
                    if (body.isBlank()) {
                        "created"
                    } else {
                        JSONObject(body).optString("status", "created")
                    }
                }
            }
        }

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}
