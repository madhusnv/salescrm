package com.koncrm.counselor

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.koncrm.counselor.auth.AuthRepository
import com.koncrm.counselor.auth.SessionStore
import com.koncrm.counselor.permissions.PermissionGate
import com.koncrm.counselor.services.CallMonitoringService
import com.koncrm.counselor.ui.LoginScreen
import com.koncrm.counselor.ui.Sprint0Screen
import com.koncrm.counselor.ui.navigation.MainNavigation
import com.koncrm.counselor.ui.theme.KonCRMCounselorTheme
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import android.content.Intent
import kotlinx.coroutines.launch
import com.koncrm.counselor.network.AuthenticatedHttpClient
import com.koncrm.counselor.work.CallLogSyncScheduler

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            KonCRMCounselorTheme {
                val sessionStore = remember { SessionStore(applicationContext) }
                
                // Initialize AuthenticatedHttpClient with SessionStore for automatic token refresh
                LaunchedEffect(Unit) {
                    AuthenticatedHttpClient.init(sessionStore)
                }
                
                val authRepository = remember { AuthRepository(sessionStore) }
                val session by sessionStore.sessionFlow.collectAsState(initial = null)
                val scope = rememberCoroutineScope()

                Scaffold(contentWindowInsets = WindowInsets.safeDrawing) { padding ->
                    Box(modifier = Modifier.padding(padding)) {
                        val currentSession = session
                        if (currentSession == null) {
                            CallMonitoringServiceController(enabled = false)
                            LoginScreen(authRepository = authRepository, onLoginSuccess = {})
                        } else {
                            // Schedule call log sync when user is logged in
                            LaunchedEffect(currentSession) {
                                CallLogSyncScheduler.schedule(applicationContext)
                            }
                            PermissionGate {
                                CallMonitoringServiceController(enabled = true)
                                MainNavigation(
                                    session = currentSession,
                                    onLogout = {
                                        scope.launch {
                                            sessionStore.clear()
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CallMonitoringServiceController(enabled: Boolean) {
    val context = LocalContext.current
    LaunchedEffect(enabled) {
        val intent = Intent(context, CallMonitoringService::class.java).apply {
            action =
                if (enabled) CallMonitoringService.ACTION_START else CallMonitoringService.ACTION_STOP
        }
        if (enabled) {
            ContextCompat.startForegroundService(context, intent)
        } else {
            context.stopService(intent)
        }
    }
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    KonCRMCounselorTheme {
        Sprint0Screen()
    }
}
