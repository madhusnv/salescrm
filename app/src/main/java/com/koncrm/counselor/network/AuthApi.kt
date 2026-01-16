package com.koncrm.counselor.network

import com.koncrm.counselor.auth.SessionTokens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class AuthApi(
    private val baseUrl: String = ApiConfig.BASE_URL,
    private val client: OkHttpClient = OkHttpClient()
) {
    suspend fun login(email: String, password: String): Result<SessionTokens> =
        withContext(Dispatchers.IO) {
            val payload = JSONObject()
                .put("email", email)
                .put("password", password)
                .toString()

            val request = Request.Builder()
                .url("$baseUrl/api/auth/login")
                .post(payload.toRequestBody(JSON))
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Login failed with ${'$'}{response.code}")
                    }

                    val body = response.body?.string().orEmpty()
                    val json = JSONObject(body)
                    val access = json.getString("access_token")
                    val refresh = json.getString("refresh_token")

                    SessionTokens(access, refresh)
                }
            }
        }

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}
