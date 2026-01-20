package com.koncrm.counselor.network

import com.koncrm.counselor.auth.SessionStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import java.util.concurrent.TimeUnit

/**
 * Provides a configured OkHttpClient with automatic token refresh capability.
 */
object AuthenticatedHttpClient {

    @Volatile
    private var instance: OkHttpClient? = null

    @Volatile
    private var sessionStore: SessionStore? = null

    /**
     * Initialize with the SessionStore. Must be called before using getClient().
     */
    fun init(sessionStore: SessionStore) {
        this.sessionStore = sessionStore
        this.instance = null // Reset client to rebuild with new session store
    }

    /**
     * Get the configured OkHttpClient with token refresh authenticator.
     */
    fun getClient(): OkHttpClient {
        return instance ?: synchronized(this) {
            instance ?: buildClient().also { instance = it }
        }
    }

    private fun buildClient(): OkHttpClient {
        val store = sessionStore
            ?: throw IllegalStateException("AuthenticatedHttpClient not initialized. Call init() first.")

        return OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .authenticator(TokenAuthenticator(store))
            .addInterceptor(AuthHeaderInterceptor(store))
            .build()
    }

    /**
     * Interceptor that adds the Authorization header to all requests.
     */
    private class AuthHeaderInterceptor(
        private val sessionStore: SessionStore
    ) : Interceptor {
        override fun intercept(chain: Interceptor.Chain): Response {
            val originalRequest = chain.request()

            // Skip if already has Authorization header or is an auth endpoint
            if (originalRequest.header("Authorization") != null ||
                !originalRequest.url.encodedPath.startsWith("/api/") ||
                originalRequest.url.encodedPath.contains("/api/auth/")) {
                return chain.proceed(originalRequest)
            }

            // Get current token synchronously
            val tokens = runBlocking {
                sessionStore.sessionFlow.first()
            }

            val request = if (tokens != null) {
                originalRequest.newBuilder()
                    .header("Authorization", "Bearer ${tokens.accessToken}")
                    .build()
            } else {
                originalRequest
            }

            return chain.proceed(request)
        }
    }
}
