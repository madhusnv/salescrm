package com.koncrm.counselor.auth

import com.koncrm.counselor.network.AuthApi

class AuthRepository(
    private val sessionStore: SessionStore,
    private val api: AuthApi = AuthApi()
) {
    suspend fun login(email: String, password: String): Result<Unit> {
        val result = api.login(email, password)

        return result.fold(
            onSuccess = { tokens ->
                sessionStore.save(tokens)
                Result.success(Unit)
            },
            onFailure = { error ->
                Result.failure(error)
            }
        )
    }

    suspend fun logout() {
        sessionStore.clear()
    }
}
