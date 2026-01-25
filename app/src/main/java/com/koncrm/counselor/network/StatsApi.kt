package com.koncrm.counselor.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

data class CounselorCallStats(
    val totalCalls: Int,
    val outgoingCalls: Int,
    val incomingCalls: Int,
    val missedCalls: Int,
    val totalDurationSeconds: Long,
    val leadsAssigned: Int
)

class StatsApi(
    private val baseUrl: String = ApiConfig.BASE_URL
) {
    private val client: OkHttpClient
        get() = AuthenticatedHttpClient.getClient()

    suspend fun getCounselorStats(filter: String = "today"): Result<CounselorCallStats> =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("${baseUrl}/api/counselor-stats?filter=$filter")
                .get()
                .build()

            runCatching {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        val errorBody = response.body?.string() ?: ""
                        throw IllegalStateException("Stats request failed with ${response.code}: $errorBody")
                    }
                    val body = response.body?.string().orEmpty()
                    val data = JSONObject(body).optJSONObject("data") ?: JSONObject()
                    CounselorCallStats(
                        totalCalls = data.optInt("total_calls", 0),
                        outgoingCalls = data.optInt("outgoing_calls", 0),
                        incomingCalls = data.optInt("incoming_calls", 0),
                        missedCalls = data.optInt("missed_calls", 0),
                        totalDurationSeconds = data.optLong("total_duration_seconds", 0),
                        leadsAssigned = data.optInt("leads_assigned", 0)
                    )
                }
            }
        }
}
