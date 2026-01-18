package com.koncrm.counselor.network

import android.content.Context
import android.util.Log
import com.koncrm.counselor.auth.SessionStore
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

private const val TAG = "ChannelManager"

class ChannelManager private constructor(context: Context) {
    private val sessionStore = SessionStore(context)
    private val channel = PhoenixChannel()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var heartbeatJob: Job? = null

    val events: SharedFlow<ChannelEvent> = channel.events
    val isConnected: StateFlow<Boolean> = channel.isConnected

    init {
        scope.launch {
            sessionStore.sessionFlow.collect { session ->
                if (session != null && session.userId > 0) {
                    Log.i(TAG, "Session available, connecting channel for user ${session.userId}")
                    channel.connect(session.accessToken, session.userId)
                    startHeartbeat()
                } else {
                    Log.i(TAG, "Session cleared, disconnecting channel")
                    stopHeartbeat()
                    channel.disconnect()
                }
            }
        }
    }

    private fun startHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (isActive) {
                delay(30_000)
                if (channel.isConnected.value) {
                    channel.sendHeartbeat()
                }
            }
        }
    }

    private fun stopHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = null
    }

    fun disconnect() {
        stopHeartbeat()
        channel.disconnect()
    }

    companion object {
        @Volatile
        private var instance: ChannelManager? = null

        fun getInstance(context: Context): ChannelManager {
            return instance ?: synchronized(this) {
                instance ?: ChannelManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
