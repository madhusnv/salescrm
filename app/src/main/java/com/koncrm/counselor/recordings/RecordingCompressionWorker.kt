package com.koncrm.counselor.recordings

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.io.File

class RecordingCompressionWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val inputPath = inputData.getString(KEY_FILE_PATH) ?: return Result.failure()
        val file = File(inputPath)
        if (!file.exists()) return Result.failure()

        // Placeholder: compression pipeline can be added here later.
        return Result.success(workDataOf(KEY_FILE_PATH to inputPath))
    }

    companion object {
        const val KEY_FILE_PATH = "file_path"
    }
}
