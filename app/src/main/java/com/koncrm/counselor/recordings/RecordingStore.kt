package com.koncrm.counselor.recordings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.recordingStore by preferencesDataStore(name = "recording_store")

data class RecordingState(
    val consentGranted: Boolean,
    val lastStatus: String,
    val lastFileName: String?,
    val lastError: String?
)

class RecordingStore(private val context: Context) {
    private val consentKey = booleanPreferencesKey("consent_granted")
    private val statusKey = stringPreferencesKey("last_status")
    private val fileKey = stringPreferencesKey("last_file_name")
    private val errorKey = stringPreferencesKey("last_error")

    fun stateFlow(): Flow<RecordingState> {
        return context.recordingStore.data.map { prefs ->
            RecordingState(
                consentGranted = prefs[consentKey] ?: false,
                lastStatus = prefs[statusKey] ?: "idle",
                lastFileName = prefs[fileKey],
                lastError = prefs[errorKey]
            )
        }
    }

    suspend fun setConsentGranted(granted: Boolean) {
        context.recordingStore.edit { prefs ->
            prefs[consentKey] = granted
        }
    }

    suspend fun setStatus(status: String, fileName: String? = null, error: String? = null) {
        context.recordingStore.edit { prefs ->
            prefs[statusKey] = status
            if (fileName != null) {
                prefs[fileKey] = fileName
            }
            if (error != null) {
                prefs[errorKey] = error
            } else {
                prefs.remove(errorKey)
            }
        }
    }
}
