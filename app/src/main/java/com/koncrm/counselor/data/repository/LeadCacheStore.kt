package com.koncrm.counselor.data.repository

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

private val Context.leadCacheStore by preferencesDataStore(name = "lead_cache_store")

class LeadCacheStore(private val context: Context) {
    private val lastSyncedAtKey = longPreferencesKey("last_synced_at")

    suspend fun getLastSyncedAt(): Long? {
        val prefs = context.leadCacheStore.data.first()
        return prefs[lastSyncedAtKey]
    }

    suspend fun setLastSyncedAt(epochMillis: Long) {
        context.leadCacheStore.edit { prefs ->
            prefs[lastSyncedAtKey] = epochMillis
        }
    }
}
