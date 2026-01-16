package com.koncrm.counselor.work

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.callLogStore by preferencesDataStore(name = "call_log_sync")

class CallLogSyncStore(private val context: Context) {
    private val lastSyncKey = longPreferencesKey("last_synced_at")
    private val syncedCountKey = intPreferencesKey("last_synced_count")
    private val duplicateCountKey = intPreferencesKey("last_duplicate_count")
    private val failureCountKey = intPreferencesKey("last_failure_count")

    suspend fun getLastSyncedAt(): Long? {
        val prefs = context.callLogStore.data.first()
        return prefs[lastSyncKey]
    }

    suspend fun setLastSyncedAt(epochMillis: Long) {
        context.callLogStore.edit { prefs ->
            prefs[lastSyncKey] = epochMillis
        }
    }

    suspend fun setStats(synced: Int, duplicates: Int, failures: Int, lastSyncedAt: Long?) {
        context.callLogStore.edit { prefs ->
            prefs[syncedCountKey] = synced
            prefs[duplicateCountKey] = duplicates
            prefs[failureCountKey] = failures
            if (lastSyncedAt != null) {
                prefs[lastSyncKey] = lastSyncedAt
            }
        }
    }

    fun statsFlow(): Flow<CallLogSyncStats> {
        return context.callLogStore.data.map { prefs ->
            CallLogSyncStats(
                lastSyncedAt = prefs[lastSyncKey],
                syncedCount = prefs[syncedCountKey] ?: 0,
                duplicateCount = prefs[duplicateCountKey] ?: 0,
                failureCount = prefs[failureCountKey] ?: 0
            )
        }
    }
}

data class CallLogSyncStats(
    val lastSyncedAt: Long?,
    val syncedCount: Int,
    val duplicateCount: Int,
    val failureCount: Int
)
