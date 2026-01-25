package com.koncrm.counselor.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.koncrm.counselor.MainActivity
import com.koncrm.counselor.call.CallEvent
import com.koncrm.counselor.call.CallStateTrackerImpl
import com.koncrm.counselor.auth.SessionStore
import com.koncrm.counselor.recordings.RecordingCompressionWorker
import com.koncrm.counselor.recordings.RecordingManager
import com.koncrm.counselor.recordings.RecordingStore
import com.koncrm.counselor.recordings.RecordingUploadWorker
import com.koncrm.counselor.work.CallNoteStore
import com.koncrm.counselor.work.CallLogSyncScheduler
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import java.io.File
import java.time.Instant
import java.util.concurrent.TimeUnit

class CallMonitoringService : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var callStateTracker: CallStateTrackerImpl? = null
    private var callNoteStore: CallNoteStore? = null
    private var recordingStore: RecordingStore? = null
    private var recordingManager: RecordingManager? = null
    private var activeRecordingFile: File? = null
    private var recordingStartedAtMillis: Long? = null
    private var recordingConsentGranted = false
    private var isTracking = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        callNoteStore = CallNoteStore(applicationContext)
        recordingStore = RecordingStore(applicationContext)
        recordingManager = RecordingManager(applicationContext)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> startTracking()
            else -> startTracking()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        callStateTracker?.stop()
        callStateTracker = null
        stopActiveRecording()
        isTracking = false
        serviceScope.cancel()
        super.onDestroy()
    }

    private fun startTracking() {
        if (isTracking) return
        isTracking = true
        serviceScope.launch {
            val sessionStore = SessionStore(applicationContext)
            val session = sessionStore.sessionFlow.first()
            if (session == null) {
                stopSelf()
                return@launch
            }

            val tracker = CallStateTrackerImpl(applicationContext)
            callStateTracker = tracker
            tracker.start()
            tracker.events.collect { event ->
                when (event) {
                    is CallEvent.Connected -> handleCallConnected()
                    is CallEvent.Ended -> handleCallEnded(event)
                    else -> Unit
                }
            }
        }
    }

    private suspend fun handleCallConnected() {
        val store = recordingStore ?: return
        val recordingState = store.stateFlow().firstOrNull() ?: return
        if (!recordingState.consentGranted || activeRecordingFile != null) return

        val manager = recordingManager ?: RecordingManager(applicationContext).also {
            recordingManager = it
        }
        manager.start()
            .onSuccess { file ->
                activeRecordingFile = file
                recordingStartedAtMillis = System.currentTimeMillis()
                recordingConsentGranted = recordingState.consentGranted
                store.setStatus("recording", file.name)
            }
            .onFailure { error ->
                store.setStatus("failed", error = error.message)
            }
    }

    private suspend fun handleCallEnded(event: CallEvent.Ended) {
        val phone = event.phoneNumber
        if (!phone.isNullOrBlank()) {
            callNoteStore?.setPending(
                phoneNumber = phone,
                endedAtMillis = Instant.now().toEpochMilli(),
                durationMillis = event.durationMillis
            )
        }

        CallLogSyncScheduler.enqueueNow(applicationContext)

        val file = activeRecordingFile ?: return
        val manager = recordingManager ?: return
        val store = recordingStore ?: return

        manager.stop()
            .onSuccess { result ->
                activeRecordingFile = null
                store.setStatus("queued", file.name)
                val recordedAtIso = recordingStartedAtMillis?.let {
                    Instant.ofEpochMilli(it).toString()
                } ?: Instant.now().toString()
                enqueueRecordingWork(
                    file = result.file,
                    durationSeconds = result.durationSeconds,
                    consentGranted = recordingConsentGranted,
                    phoneNumber = phone,
                    recordedAtIso = recordedAtIso
                )
                recordingStartedAtMillis = null
                recordingConsentGranted = false
            }
            .onFailure { error ->
                activeRecordingFile = null
                recordingStartedAtMillis = null
                recordingConsentGranted = false
                store.setStatus("failed", file.name, error.message)
            }
    }

    private fun enqueueRecordingWork(
        file: File,
        durationSeconds: Long,
        consentGranted: Boolean,
        phoneNumber: String?,
        recordedAtIso: String
    ) {
        val compression = OneTimeWorkRequestBuilder<RecordingCompressionWorker>()
            .setInputData(workDataOf(RecordingCompressionWorker.KEY_FILE_PATH to file.absolutePath))
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()

        val uploadConstraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val upload = OneTimeWorkRequestBuilder<RecordingUploadWorker>()
            .setInputData(
                workDataOf(
                    RecordingUploadWorker.KEY_FILE_PATH to file.absolutePath,
                    RecordingUploadWorker.KEY_DURATION_SECONDS to durationSeconds,
                    RecordingUploadWorker.KEY_CONSENT_GRANTED to consentGranted,
                    RecordingUploadWorker.KEY_PHONE_NUMBER to (phoneNumber ?: ""),
                    RecordingUploadWorker.KEY_RECORDED_AT to recordedAtIso
                )
            )
            .setConstraints(uploadConstraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()

        WorkManager.getInstance(applicationContext)
            .beginWith(compression)
            .then(upload)
            .enqueue()
    }

    private fun stopActiveRecording() {
        val file = activeRecordingFile ?: return
        val manager = recordingManager ?: return
        val store = recordingStore ?: return

        manager.stop()
            .onSuccess { result ->
                activeRecordingFile = null
                serviceScope.launch {
                    store.setStatus("queued", file.name)
                }
                val recordedAtIso = recordingStartedAtMillis?.let {
                    Instant.ofEpochMilli(it).toString()
                } ?: Instant.now().toString()
                enqueueRecordingWork(
                    file = result.file,
                    durationSeconds = result.durationSeconds,
                    consentGranted = recordingConsentGranted,
                    phoneNumber = null,
                    recordedAtIso = recordedAtIso
                )
                recordingStartedAtMillis = null
                recordingConsentGranted = false
            }
            .onFailure { error ->
                activeRecordingFile = null
                recordingStartedAtMillis = null
                recordingConsentGranted = false
                serviceScope.launch {
                    store.setStatus("failed", file.name, error.message)
                }
            }
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = Intent(this, CallMonitoringService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("KonCRM call tracking")
            .setContentText("Listening for call activity · Tap to log notes")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_menu_edit, "Open", openPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KonCRM Call Tracking",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val ACTION_START = "com.koncrm.counselor.action.CALL_MONITOR_START"
        const val ACTION_STOP = "com.koncrm.counselor.action.CALL_MONITOR_STOP"
        private const val CHANNEL_ID = "koncrm_call_monitor"
        private const val NOTIFICATION_ID = 1101
    }
}
