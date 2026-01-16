package com.koncrm.counselor.recordings

import android.content.Context
import android.media.MediaRecorder
import java.io.File
import java.time.Instant

data class RecordingResult(
    val file: File,
    val durationSeconds: Long
)

class RecordingManager(private val context: Context) {
    private var recorder: MediaRecorder? = null
    private var startedAtMillis: Long? = null
    private var outputFile: File? = null

    fun start(): Result<File> {
        if (recorder != null) {
            return Result.failure(IllegalStateException("Recorder already running"))
        }

        val recordingsDir = File(context.filesDir, "recordings")
        if (!recordingsDir.exists()) {
            recordingsDir.mkdirs()
        }
        val file = File(recordingsDir, "call_${Instant.now().epochSecond}.m4a")
        outputFile = file

        return runCatching {
            val mediaRecorder = MediaRecorder()
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mediaRecorder.setAudioEncodingBitRate(96_000)
            mediaRecorder.setAudioSamplingRate(44_100)
            mediaRecorder.setOutputFile(file.absolutePath)
            mediaRecorder.prepare()
            mediaRecorder.start()
            recorder = mediaRecorder
            startedAtMillis = System.currentTimeMillis()
            file
        }
    }

    fun stop(): Result<RecordingResult> {
        val mediaRecorder = recorder ?: return Result.failure(IllegalStateException("Recorder not running"))
        val file = outputFile ?: return Result.failure(IllegalStateException("No output file"))
        return runCatching {
            mediaRecorder.stop()
            mediaRecorder.reset()
            mediaRecorder.release()
            recorder = null
            val durationMillis = (System.currentTimeMillis() - (startedAtMillis ?: System.currentTimeMillis()))
            RecordingResult(file = file, durationSeconds = durationMillis / 1000)
        }
    }
}
