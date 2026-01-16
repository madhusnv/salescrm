package com.koncrm.counselor.auth

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "session_store")

class SessionStore(private val context: Context) {
    private val accessTokenKey = stringPreferencesKey("access_token")
    private val refreshTokenKey = stringPreferencesKey("refresh_token")

    val sessionFlow: Flow<SessionTokens?> =
        context.dataStore.data.map { prefs ->
            val access = prefs[accessTokenKey]
            val refresh = prefs[refreshTokenKey]
            if (access.isNullOrBlank() || refresh.isNullOrBlank()) {
                null
            } else {
                SessionTokens(access, refresh)
            }
        }

    suspend fun save(tokens: SessionTokens) {
        context.dataStore.edit { prefs ->
            prefs[accessTokenKey] = tokens.accessToken
            prefs[refreshTokenKey] = tokens.refreshToken
        }
    }

    suspend fun clear() {
        context.dataStore.edit { prefs ->
            prefs.remove(accessTokenKey)
            prefs.remove(refreshTokenKey)
        }
    }
}

data class SessionTokens(
    val accessToken: String,
    val refreshToken: String
)
