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
                        throw IllegalStateException("Login failed with ${response.code}")
                    }

                    val body = response.body?.string().orEmpty()
                    val json = JSONObject(body)
                    val access = json.getString("access_token")
                    val refresh = json.getString("refresh_token")
                    val userId = resolveUserId(json)

                    SessionTokens(access, refresh, userId)
                }
            }
        }

    /**
     * Refreshes the access token using the refresh token.
     * Returns new SessionTokens on success, or null if refresh failed.
     */
    fun refreshTokenSync(refreshToken: String): SessionTokens? {
        val payload = JSONObject()
            .put("refresh_token", refreshToken)
            .toString()

        val request = Request.Builder()
            .url("$baseUrl/api/auth/refresh")
            .post(payload.toRequestBody(JSON))
            .build()

        return try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    null
                } else {
                    val body = response.body?.string().orEmpty()
                    val json = JSONObject(body)
                    val access = json.getString("access_token")
                    val refresh = json.getString("refresh_token")
                    val userId = resolveUserId(json)
                    SessionTokens(access, refresh, userId)
                }
            }
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }

    private fun resolveUserId(json: JSONObject): Long {
        val direct = json.optLong("user_id", 0L)
        if (direct > 0) return direct
        return json.optJSONObject("user")?.optLong("id", 0L) ?: 0L
    }
}
