package com.koncrm.counselor.network

import android.content.Context
import android.util.Log
import com.koncrm.counselor.auth.SessionStore
import com.koncrm.counselor.auth.SessionTokens
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

private const val TAG = "ChannelManager"

class ChannelManager private constructor(context: Context) {
    private val sessionStore = SessionStore(context)
    private val channel = PhoenixChannel()
    private val authApi = AuthApi()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var heartbeatJob: Job? = null

    val events: SharedFlow<ChannelEvent> = channel.events
    val isConnected: StateFlow<Boolean> = channel.isConnected

    init {
        scope.launch {
            sessionStore.sessionFlow.collect { session ->
                when {
                    session == null -> {
                        Log.i(TAG, "Session cleared, disconnecting channel")
                        stopHeartbeat()
                        channel.disconnect()
                    }
                    session.userId > 0 -> {
                        Log.i(TAG, "Session available, connecting channel for user ${session.userId}")
                        channel.connect(session.accessToken, session.userId)
                        startHeartbeat()
                    }
                    else -> {
                        Log.w(TAG, "Session missing userId, attempting refresh")
                        val refreshed = refreshSession(session)
                        if (refreshed != null && refreshed.userId > 0) {
                            sessionStore.save(refreshed)
                            Log.i(TAG, "Refreshed session, connecting channel for user ${refreshed.userId}")
                            channel.connect(refreshed.accessToken, refreshed.userId)
                            startHeartbeat()
                        } else {
                            Log.w(TAG, "Unable to resolve userId for channel connection")
                            stopHeartbeat()
                            channel.disconnect()
                        }
                    }
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

    private suspend fun refreshSession(session: SessionTokens): SessionTokens? =
        withContext(Dispatchers.IO) {
            authApi.refreshTokenSync(session.refreshToken)
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
