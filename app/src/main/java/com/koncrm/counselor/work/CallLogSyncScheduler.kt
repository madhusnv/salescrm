package com.koncrm.counselor.work

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.BackoffPolicy
import java.util.concurrent.TimeUnit

object CallLogSyncScheduler {
    private const val WORK_NAME = "call_log_sync"
    private const val WORK_NAME_IMMEDIATE = "call_log_sync_immediate"

    fun schedule(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = PeriodicWorkRequestBuilder<CallLogSyncWorker>(
            15, TimeUnit.MINUTES
        ).setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
    }

    fun enqueueNow(context: Context, initialDelaySeconds: Long = 10) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = OneTimeWorkRequestBuilder<CallLogSyncWorker>()
            .setConstraints(constraints)
            .setInitialDelay(initialDelaySeconds, TimeUnit.SECONDS)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            WORK_NAME_IMMEDIATE,
            ExistingWorkPolicy.REPLACE,
            request
        )
    }
}
