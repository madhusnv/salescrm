package com.koncrm.counselor.recordings

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

private val Context.syncedStore by preferencesDataStore(name = "synced_recordings_store")

/**
 * Tracks which recordings from the SAF folder have been synced to avoid duplicates.
 */
class SyncedRecordingsStore(private val context: Context) {
    private val syncedUrisKey = stringSetPreferencesKey("synced_uris")

    /**
     * Check if a recording URI has already been synced
     */
    fun isSynced(uriString: String): Boolean {
        return runBlocking {
            val synced = context.syncedStore.data.first()[syncedUrisKey] ?: emptySet()
            synced.contains(uriString)
        }
    }

    /**
     * Mark a recording as synced
     */
    suspend fun markSynced(uriString: String, fileName: String) {
        context.syncedStore.edit { prefs ->
            val current = prefs[syncedUrisKey] ?: emptySet()
            prefs[syncedUrisKey] = current + uriString
        }
    }

    /**
     * Get count of synced recordings
     */
    suspend fun getSyncedCount(): Int {
        return context.syncedStore.data.first()[syncedUrisKey]?.size ?: 0
    }

    /**
     * Clear all synced records (for testing/reset)
     */
    suspend fun clearAll() {
        context.syncedStore.edit { prefs ->
            prefs.remove(syncedUrisKey)
        }
    }
}
