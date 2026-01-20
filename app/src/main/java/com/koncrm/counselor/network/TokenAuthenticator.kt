package com.koncrm.counselor.network

import com.koncrm.counselor.auth.SessionStore
import com.koncrm.counselor.auth.SessionTokens
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import okhttp3.Authenticator
import okhttp3.Request
import okhttp3.Response
import okhttp3.Route

/**
 * OkHttp Authenticator that automatically refreshes expired access tokens.
 * When a 401 response is received, it attempts to refresh the token and retry the request.
 */
class TokenAuthenticator(
    private val sessionStore: SessionStore,
    private val authApi: AuthApi = AuthApi()
) : Authenticator {

    @Volatile
    private var isRefreshing = false
    private val lock = Any()

    override fun authenticate(route: Route?, response: Response): Request? {
        // Don't retry if we've already tried refreshing for this request chain
        if (responseCount(response) >= 2) {
            return null
        }

        // Don't try to refresh auth endpoints themselves
        if (response.request.url.encodedPath.contains("/api/auth/")) {
            return null
        }

        val currentTokens = runBlocking { 
            sessionStore.sessionFlow.first()
        }

        if (currentTokens == null) {
            return null
        }

        synchronized(lock) {
            // Check if another thread already refreshed the token
            val latestTokens = runBlocking {
                sessionStore.sessionFlow.first()
            }

            // If token changed since the failed request, retry with new token
            if (latestTokens != null && latestTokens.accessToken != getTokenFromRequest(response.request)) {
                return response.request.newBuilder()
                    .header("Authorization", "Bearer ${latestTokens.accessToken}")
                    .build()
            }

            // Perform refresh
            if (!isRefreshing) {
                isRefreshing = true
                try {
                    val newTokens = authApi.refreshTokenSync(currentTokens.refreshToken)
                    if (newTokens != null) {
                        runBlocking { sessionStore.save(newTokens) }
                        return response.request.newBuilder()
                            .header("Authorization", "Bearer ${newTokens.accessToken}")
                            .build()
                    } else {
                        // Refresh failed - clear session to force re-login
                        runBlocking { sessionStore.clear() }
                        return null
                    }
                } finally {
                    isRefreshing = false
                }
            }
        }

        return null
    }

    private fun responseCount(response: Response): Int {
        var count = 1
        var prior = response.priorResponse
        while (prior != null) {
            count++
            prior = prior.priorResponse
        }
        return count
    }

    private fun getTokenFromRequest(request: Request): String? {
        val authHeader = request.header("Authorization") ?: return null
        return if (authHeader.startsWith("Bearer ")) {
            authHeader.removePrefix("Bearer ")
        } else {
            null
        }
    }
}
