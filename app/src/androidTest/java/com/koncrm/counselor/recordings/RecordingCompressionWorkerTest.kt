package com.koncrm.counselor.recordings

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.workDataOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class RecordingCompressionWorkerTest {
    @Test
    fun returnsSuccessWithSameFilePath() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val inputFile = File(context.cacheDir, "test_audio.m4a")
        inputFile.writeText("fake-audio")

        val worker = TestListenableWorkerBuilder<RecordingCompressionWorker>(context)
            .setInputData(workDataOf(RecordingCompressionWorker.KEY_FILE_PATH to inputFile.absolutePath))
            .build()

        val result = worker.doWork()
        assertTrue(result is androidx.work.ListenableWorker.Result.Success)

        val outputPath =
            (result as androidx.work.ListenableWorker.Result.Success).outputData.getString(
                RecordingCompressionWorker.KEY_FILE_PATH
            )
        assertEquals(inputFile.absolutePath, outputPath)
    }
}
