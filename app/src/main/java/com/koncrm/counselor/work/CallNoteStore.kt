package com.koncrm.counselor.work

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.callNoteStore by preferencesDataStore(name = "pending_call_note")

data class PendingCallNoteData(
    val phoneNumber: String,
    val endedAtMillis: Long,
    val durationMillis: Long?
)

class CallNoteStore(private val context: Context) {
    private val phoneKey = stringPreferencesKey("phone_number")
    private val endedAtKey = longPreferencesKey("ended_at")
    private val durationKey = longPreferencesKey("duration_ms")

    fun pendingFlow(): Flow<PendingCallNoteData?> {
        return context.callNoteStore.data.map { prefs ->
            val phone = prefs[phoneKey]
            val endedAt = prefs[endedAtKey]
            if (phone.isNullOrBlank() || endedAt == null) {
                null
            } else {
                val duration = prefs[durationKey]
                PendingCallNoteData(phone, endedAt, duration)
            }
        }
    }

    suspend fun setPending(phoneNumber: String, endedAtMillis: Long, durationMillis: Long?) {
        context.callNoteStore.edit { prefs ->
            prefs[phoneKey] = phoneNumber
            prefs[endedAtKey] = endedAtMillis
            if (durationMillis != null) {
                prefs[durationKey] = durationMillis
            } else {
                prefs.remove(durationKey)
            }
        }
    }

    suspend fun clear() {
        context.callNoteStore.edit { prefs ->
            prefs.remove(phoneKey)
            prefs.remove(endedAtKey)
            prefs.remove(durationKey)
        }
    }
}
