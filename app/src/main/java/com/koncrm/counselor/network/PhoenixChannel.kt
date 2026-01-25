package com.koncrm.counselor.network

import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import okhttp3.*
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

private const val TAG = "PhoenixChannel"

sealed class ChannelEvent {
    data class LeadUpdated(val id: Long, val studentName: String, val status: String) : ChannelEvent()
    data class CallSynced(val id: Long, val phoneNumber: String, val callType: String) : ChannelEvent()
    data class LeadAssigned(val id: Long, val studentName: String, val phoneNumber: String) : ChannelEvent()
    data class StatsUpdated(val synced: Int, val pending: Int) : ChannelEvent()
    data class RecordingUploaded(val id: Long, val leadId: Long?, val status: String, val durationSeconds: Long) : ChannelEvent()
    data class RecordingStatus(val id: Long, val status: String) : ChannelEvent()
    object Connected : ChannelEvent()
    object Disconnected : ChannelEvent()
    data class Error(val message: String) : ChannelEvent()
}

class PhoenixChannel(
    private val baseUrl: String = ApiConfig.BASE_URL
) {
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    private var webSocket: WebSocket? = null
    private val refCounter = AtomicInteger(0)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val _events = MutableSharedFlow<ChannelEvent>(replay = 0, extraBufferCapacity = 64)
    val events: SharedFlow<ChannelEvent> = _events.asSharedFlow()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private var currentToken: String? = null
    private var currentUserId: Long? = null
    private var reconnectJob: Job? = null

    fun connect(token: String, userId: Long) {
        if (webSocket != null && currentToken == token) {
            Log.d(TAG, "Already connected")
            return
        }

        currentToken = token
        currentUserId = userId

        val wsUrl = baseUrl
            .replace("http://", "ws://")
            .replace("https://", "wss://") + "/socket/websocket?token=$token&vsn=2.0.0"

        Log.i(TAG, "Connecting to: $wsUrl")

        val request = Request.Builder()
            .url(wsUrl)
            .build()

        webSocket = client.newWebSocket(request, createListener())
    }

    fun disconnect() {
        Log.i(TAG, "Disconnecting")
        reconnectJob?.cancel()
        webSocket?.close(1000, "Client disconnect")
        webSocket = null
        currentToken = null
        currentUserId = null
        _isConnected.value = false
    }

    private fun createListener() = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            Log.i(TAG, "WebSocket opened")
            _isConnected.value = true
            scope.launch { _events.emit(ChannelEvent.Connected) }

            currentUserId?.let { userId ->
                joinChannel("user:$userId")
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            Log.d(TAG, "Received: $text")
            handleMessage(text)
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            Log.i(TAG, "WebSocket closing: $code $reason")
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            Log.i(TAG, "WebSocket closed: $code $reason")
            _isConnected.value = false
            scope.launch { _events.emit(ChannelEvent.Disconnected) }
            scheduleReconnect()
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            Log.e(TAG, "WebSocket failure", t)
            _isConnected.value = false
            scope.launch { _events.emit(ChannelEvent.Error(t.message ?: "Connection failed")) }
            scheduleReconnect()
        }
    }

    private fun joinChannel(topic: String) {
        val ref = nextRef()
        val payload = JSONArray()
            .put(ref)
            .put(ref)
            .put(topic)
            .put("phx_join")
            .put(JSONObject())
        webSocket?.send(payload.toString())
        Log.i(TAG, "Joining channel: $topic")
    }

    private fun handleMessage(text: String) {
        try {
            when (val parsed = JSONTokener(text).nextValue()) {
                is JSONArray -> handleArrayMessage(parsed)
                is JSONObject -> handleObjectMessage(parsed)
                else -> Log.w(TAG, "Unknown message format: $text")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse message", e)
        }
    }

    private fun handleArrayMessage(message: JSONArray) {
        val event = message.optString(3, "")
        val payload = message.optJSONObject(4) ?: JSONObject()
        handleEvent(event, payload)
    }

    private fun handleObjectMessage(message: JSONObject) {
        val event = message.optString("event", "")
        val payload = message.optJSONObject("payload") ?: JSONObject()
        handleEvent(event, payload)
    }

    private fun handleEvent(event: String, payload: JSONObject) {
        scope.launch {
            when (event) {
                "lead:updated" -> {
                    _events.emit(ChannelEvent.LeadUpdated(
                        id = payload.optLong("id"),
                        studentName = payload.optString("student_name", ""),
                        status = payload.optString("status", "")
                    ))
                }
                "call:synced" -> {
                    _events.emit(ChannelEvent.CallSynced(
                        id = payload.optLong("id"),
                        phoneNumber = payload.optString("phone_number", ""),
                        callType = payload.optString("call_type", "")
                    ))
                }
                "lead:assigned" -> {
                    _events.emit(ChannelEvent.LeadAssigned(
                        id = payload.optLong("id"),
                        studentName = payload.optString("student_name", ""),
                        phoneNumber = payload.optString("phone_number", "")
                    ))
                }
                "stats:updated" -> {
                    _events.emit(ChannelEvent.StatsUpdated(
                        synced = payload.optInt("synced", 0),
                        pending = payload.optInt("pending", 0)
                    ))
                }
                "recording:uploaded" -> {
                    _events.emit(ChannelEvent.RecordingUploaded(
                        id = payload.optLong("id"),
                        leadId = payload.optLong("lead_id").takeIf { it > 0 },
                        status = payload.optString("status", ""),
                        durationSeconds = payload.optLong("duration_seconds", 0)
                    ))
                }
                "recording:status" -> {
                    _events.emit(ChannelEvent.RecordingStatus(
                        id = payload.optLong("id"),
                        status = payload.optString("status", "")
                    ))
                }
                "phx_reply" -> {
                    val status = payload.optString("status")
                    Log.d(TAG, "Channel reply: $status")
                }
                "phx_error" -> {
                    Log.e(TAG, "Channel error: $payload")
                }
                "presence_state" -> {
                    Log.d(TAG, "Channel presence: $payload")
                }
            }
        }
    }

    private fun scheduleReconnect() {
        if (currentToken == null) return

        reconnectJob?.cancel()
        reconnectJob = scope.launch {
            delay(5000)
            Log.i(TAG, "Attempting reconnect...")
            currentToken?.let { token ->
                currentUserId?.let { userId ->
                    connect(token, userId)
                }
            }
        }
    }

    fun sendHeartbeat() {
        val ref = nextRef()
        val payload = JSONArray()
            .put(JSONObject.NULL)
            .put(ref)
            .put("phoenix")
            .put("heartbeat")
            .put(JSONObject())
        webSocket?.send(payload.toString())
    }

    private fun nextRef(): String = refCounter.incrementAndGet().toString()
}
