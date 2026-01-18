package com.koncrm.counselor.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

class SessionStore(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val securePrefs: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        "secure_session_store",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private val _sessionFlow = MutableStateFlow<SessionTokens?>(loadTokens())
    val sessionFlow: Flow<SessionTokens?> = _sessionFlow.asStateFlow()

    private fun loadTokens(): SessionTokens? {
        val access = securePrefs.getString(ACCESS_TOKEN_KEY, null)
        val refresh = securePrefs.getString(REFRESH_TOKEN_KEY, null)
        val userId = securePrefs.getLong(USER_ID_KEY, 0L)
        return if (!access.isNullOrBlank() && !refresh.isNullOrBlank()) {
            SessionTokens(access, refresh, userId)
        } else {
            null
        }
    }

    suspend fun save(tokens: SessionTokens) = withContext(Dispatchers.IO) {
        securePrefs.edit()
            .putString(ACCESS_TOKEN_KEY, tokens.accessToken)
            .putString(REFRESH_TOKEN_KEY, tokens.refreshToken)
            .putLong(USER_ID_KEY, tokens.userId)
            .apply()
        _sessionFlow.value = tokens
    }

    suspend fun clear() = withContext(Dispatchers.IO) {
        securePrefs.edit()
            .remove(ACCESS_TOKEN_KEY)
            .remove(REFRESH_TOKEN_KEY)
            .remove(USER_ID_KEY)
            .apply()
        _sessionFlow.value = null
    }

    companion object {
        private const val ACCESS_TOKEN_KEY = "access_token"
        private const val REFRESH_TOKEN_KEY = "refresh_token"
        private const val USER_ID_KEY = "user_id"
    }
}

data class SessionTokens(
    val accessToken: String,
    val refreshToken: String,
    val userId: Long = 0L
)
