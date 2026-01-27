package com.koncrm.counselor.ui.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.koncrm.counselor.auth.SessionTokens
import com.koncrm.counselor.ui.CallStatsScreen
import com.koncrm.counselor.ui.DashboardScreen
import com.koncrm.counselor.ui.leads.LeadHomeScreen
import com.koncrm.counselor.ui.SettingsScreen

sealed class BottomNavItem(
    val route: String,
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    data object Dashboard : BottomNavItem(
        route = "dashboard",
        title = "Home",
        selectedIcon = Icons.Filled.Home,
        unselectedIcon = Icons.Outlined.Home
    )
    data object Leads : BottomNavItem(
        route = "leads",
        title = "Leads",
        selectedIcon = Icons.Filled.Person,
        unselectedIcon = Icons.Outlined.Person
    )
    data object Settings : BottomNavItem(
        route = "settings",
        title = "Settings",
        selectedIcon = Icons.Filled.Settings,
        unselectedIcon = Icons.Outlined.Settings
    )
}

@Composable
fun MainNavigation(
    session: SessionTokens,
    onLogout: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    var selectedItem by remember { mutableStateOf<BottomNavItem>(BottomNavItem.Dashboard) }
    var showCallStats by remember { mutableStateOf(false) }
    val items = listOf(BottomNavItem.Dashboard, BottomNavItem.Leads, BottomNavItem.Settings)

    Scaffold(
        bottomBar = {
            if (!showCallStats) {
                NavigationBar(
                    containerColor = colors.surface,
                    tonalElevation = 8.dp
                ) {
                    items.forEach { item ->
                        val selected = selectedItem.route == item.route
                        NavigationBarItem(
                            icon = {
                                Icon(
                                    imageVector = if (selected) item.selectedIcon else item.unselectedIcon,
                                    contentDescription = item.title
                                )
                            },
                            label = {
                                Text(
                                    text = item.title,
                                    style = MaterialTheme.typography.labelSmall
                                )
                            },
                            selected = selected,
                            onClick = { selectedItem = item },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = colors.primary,
                                selectedTextColor = colors.primary,
                                indicatorColor = colors.primaryContainer,
                                unselectedIconColor = colors.onSurface.copy(alpha = 0.6f),
                                unselectedTextColor = colors.onSurface.copy(alpha = 0.6f)
                            )
                        )
                    }
                }
            }
        }
    ) { paddingValues ->
        if (showCallStats) {
            CallStatsScreen(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                onBack = { showCallStats = false }
            )
        } else {
            when (selectedItem) {
                BottomNavItem.Dashboard -> {
                    DashboardScreen(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(paddingValues),
                        onOpenCallStats = { showCallStats = true }
                    )
                }
                BottomNavItem.Leads -> {
                    LeadHomeScreen(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(paddingValues)
                    )
                }
                BottomNavItem.Settings -> {
                    SettingsScreen(
                        onLogout = onLogout,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(paddingValues)
                    )
                }
            }
        }
    }
}
