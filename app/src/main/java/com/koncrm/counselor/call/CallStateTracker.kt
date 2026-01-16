package com.koncrm.counselor.call

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean

interface CallStateTracker {
    val events: Flow<CallEvent>
    fun start(): Boolean
    fun stop()
}

class CallStateTrackerImpl(
    private val context: Context
) : CallStateTracker {
    private val telephonyManager =
        context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val started = AtomicBoolean(false)
    private val _events = MutableSharedFlow<CallEvent>(extraBufferCapacity = 4)
    override val events: Flow<CallEvent> = _events

    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var lastNumber: String? = null
    private var callStartTime: Long? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    @Suppress("DEPRECATION")
    private val phoneStateListener by lazy {
        object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                handleStateChange(state, phoneNumber)
            }
        }
    }

    private val telephonyCallback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
        override fun onCallStateChanged(state: Int) {
            handleStateChange(state, null)
        }
    }

    @Suppress("DEPRECATION")
    override fun start(): Boolean {
        if (started.getAndSet(true)) return true
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephonyManager.registerTelephonyCallback(context.mainExecutor, telephonyCallback)
            } else {
                // PhoneStateListener must be created and registered on a thread with a Looper
                mainHandler.post {
                    try {
                        telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
                    } catch (e: SecurityException) {
                        android.util.Log.w("CallStateTracker", "Permission denied for call state", e)
                    }
                }
            }
            true
        } catch (e: SecurityException) {
            android.util.Log.w("CallStateTracker", "Permission denied for call state", e)
            started.set(false)
            false
        }
    }

    @Suppress("DEPRECATION")
    override fun stop() {
        if (!started.getAndSet(false)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyManager.unregisterTelephonyCallback(telephonyCallback)
        } else {
            mainHandler.post {
                telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
            }
        }
    }

    private fun handleStateChange(state: Int, phoneNumber: String?) {
        if (state == lastState && phoneNumber.isNullOrBlank()) {
            return
        }
        if (!phoneNumber.isNullOrBlank()) {
            lastNumber = phoneNumber
        }

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                lastNumber = phoneNumber ?: lastNumber
                callStartTime = null
                scope.launch {
                    _events.emit(CallEvent.Ringing(lastNumber))
                }
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                callStartTime = System.currentTimeMillis()
                scope.launch {
                    _events.emit(CallEvent.Connected(lastNumber))
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (lastState == TelephonyManager.CALL_STATE_OFFHOOK ||
                    lastState == TelephonyManager.CALL_STATE_RINGING
                ) {
                    val duration = callStartTime?.let { System.currentTimeMillis() - it }
                    scope.launch {
                        _events.emit(CallEvent.Ended(lastNumber, duration))
                    }
                }
                callStartTime = null
                lastNumber = null
            }
        }
        lastState = state
    }
}

sealed class CallEvent {
    data class Ringing(val phoneNumber: String?) : CallEvent()
    data class Connected(val phoneNumber: String?) : CallEvent()
    data class Ended(val phoneNumber: String?, val durationMillis: Long?) : CallEvent()
}
