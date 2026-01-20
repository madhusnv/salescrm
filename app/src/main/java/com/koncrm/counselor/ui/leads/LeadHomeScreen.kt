package com.koncrm.counselor.ui.leads

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.koncrm.counselor.ui.leads.components.*
import kotlinx.coroutines.launch

// Premium gradient colors
private val GradientStart = Color(0xFF6366F1)
private val GradientMid = Color(0xFF8B5CF6)
private val GradientEnd = Color(0xFFA855F7)
private val BackgroundLight = Color(0xFFFAFAFC)
private val BackgroundDark = Color(0xFF0F0F23)

@Composable
fun LeadHomeScreen(
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val viewModel: LeadHomeViewModel = viewModel(
        factory = LeadHomeViewModel.Factory(context)
    )
    val uiState by viewModel.uiState.collectAsState()
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()
    val colors = MaterialTheme.colorScheme

    // Background with subtle gradient
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        colors.background,
                        colors.surfaceVariant.copy(alpha = 0.3f)
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp)
        ) {
            // Header
            Text(
                text = "Leads",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                color = colors.onBackground,
                modifier = Modifier.padding(top = 16.dp, bottom = 8.dp)
            )

            // Stats Row
            StatsRow(
                syncStats = uiState.syncStats,
                recordingState = uiState.recordingState,
                onConsentChange = { viewModel.onEvent(LeadHomeEvent.SetRecordingConsent(it)) },
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Filters
            LeadFilters(
                searchQuery = uiState.searchQuery,
                statusFilter = uiState.statusFilter,
                onSearchChange = { viewModel.onEvent(LeadHomeEvent.UpdateSearchQuery(it)) },
                onStatusChange = { viewModel.onEvent(LeadHomeEvent.UpdateStatusFilter(it)) },
                onApply = { viewModel.onEvent(LeadHomeEvent.ApplyFilters) },
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Lead list
            Box(modifier = Modifier.weight(1f)) {
                when {
                    uiState.isLoading && uiState.leads.isEmpty() -> {
                        // Skeleton loading
                        LazyColumn(
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(5) {
                                LeadCardSkeleton()
                            }
                        }
                    }
                    uiState.leads.isEmpty() -> {
                        // Empty state
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = "No leads found",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = colors.onSurface.copy(alpha = 0.6f)
                                )
                                Text(
                                    text = "Try adjusting your filters",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = colors.onSurface.copy(alpha = 0.4f)
                                )
                            }
                        }
                    }
                    else -> {
                        LazyColumn(
                            state = listState,
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                            contentPadding = PaddingValues(bottom = 16.dp)
                        ) {
                            items(
                                items = uiState.leads,
                                key = { it.id }
                            ) { lead ->
                                LeadCard(
                                    lead = lead,
                                    onSelect = { viewModel.onEvent(LeadHomeEvent.SelectLead(lead)) }
                                )
                            }

                            // Load more trigger
                            if (uiState.hasMoreLeads && !uiState.isLoading) {
                                item {
                                    LaunchedEffect(Unit) {
                                        viewModel.onEvent(LeadHomeEvent.LoadMoreLeads)
                                    }
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(16.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        CircularProgressIndicator(
                                            modifier = Modifier.size(24.dp),
                                            color = GradientStart,
                                            strokeWidth = 2.dp
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // Error snackbar
                uiState.error?.let { error ->
                    Snackbar(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(16.dp),
                        action = {
                            TextButton(onClick = { viewModel.onEvent(LeadHomeEvent.ClearError) }) {
                                Text("Dismiss", color = Color.White)
                            }
                        },
                        containerColor = Color(0xFFEF4444)
                    ) {
                        Text(error, color = Color.White)
                    }
                }

                // Success snackbar
                uiState.statusMessage?.let { message ->
                    LaunchedEffect(message) {
                        kotlinx.coroutines.delay(2000)
                        viewModel.onEvent(LeadHomeEvent.ClearStatusMessage)
                    }
                    
                    Snackbar(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(16.dp),
                        containerColor = Color(0xFF10B981)
                    ) {
                        Text(message, color = Color.White)
                    }
                }
            }
        }

        // Lead detail overlay
        AnimatedVisibility(
            visible = uiState.selectedLead != null,
            enter = fadeIn() + slideInVertically { it / 2 },
            exit = fadeOut() + slideOutVertically { it / 2 }
        ) {
            uiState.selectedLead?.let { detail ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(colors.scrim.copy(alpha = 0.5f))
                        .padding(16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    LeadDetailCard(
                        detail = detail,
                        noteText = uiState.noteText,
                        isSavingNote = uiState.isSavingNote,
                        selectedTab = uiState.selectedTab,
                        followupDueAtMillis = uiState.followupDueAtMillis,
                        followupNote = uiState.followupNote,
                        isSchedulingFollowup = uiState.isSchedulingFollowup,
                        callLogs = uiState.callLogs,
                        hasMoreCallLogs = uiState.hasMoreCallLogs,
                        callLogFilter = uiState.callLogFilter,
                        isUpdatingStatus = uiState.isUpdatingStatus,
                        onNoteChange = { viewModel.onEvent(LeadHomeEvent.UpdateNoteText(it)) },
                        onSubmitNote = { viewModel.onEvent(LeadHomeEvent.SubmitNote) },
                        onTabSelected = { viewModel.onEvent(LeadHomeEvent.SelectTab(it)) },
                        onUpdateStatus = { viewModel.onEvent(LeadHomeEvent.UpdateLeadStatus(it)) },
                        onPickFollowupDate = {
                            pickFollowupDateTime(
                                context = context,
                                currentMillis = uiState.followupDueAtMillis,
                                onSelected = { viewModel.onEvent(LeadHomeEvent.SetFollowupDate(it)) }
                            )
                        },
                        onFollowupNoteChange = { viewModel.onEvent(LeadHomeEvent.UpdateFollowupNote(it)) },
                        onScheduleFollowup = { viewModel.onEvent(LeadHomeEvent.ScheduleFollowup) },
                        onCallLogFilterChange = { viewModel.onEvent(LeadHomeEvent.UpdateCallLogFilter(it)) },
                        onLoadMoreCallLogs = { viewModel.onEvent(LeadHomeEvent.LoadMoreCallLogs) },
                        onDismiss = { viewModel.onEvent(LeadHomeEvent.ClearSelection) },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }

        // Post-call note overlay
        AnimatedVisibility(
            visible = uiState.pendingCallNote != null,
            enter = fadeIn() + slideInVertically { it },
            exit = fadeOut() + slideOutVertically { it }
        ) {
            uiState.pendingCallNote?.let { pending ->
                CallNoteOverlay(
                    pending = pending,
                    noteText = uiState.pendingCallNoteText,
                    isSaving = uiState.isSavingCallNote,
                    showLeadCreation = uiState.showLeadCreation,
                    leadName = uiState.pendingLeadName,
                    universities = uiState.universities,
                    selectedUniversityId = uiState.pendingUniversityId,
                    isUniversityMenuOpen = uiState.isUniversityMenuOpen,
                    onNoteChange = { viewModel.onEvent(LeadHomeEvent.UpdateCallNoteText(it)) },
                    onDismiss = { viewModel.onEvent(LeadHomeEvent.DismissCallNote) },
                    onSave = { viewModel.onEvent(LeadHomeEvent.SaveCallNote) },
                    onLeadNameChange = { viewModel.onEvent(LeadHomeEvent.UpdatePendingLeadName(it)) },
                    onUniversitySelected = { viewModel.onEvent(LeadHomeEvent.SelectUniversity(it)) },
                    onToggleUniversityMenu = { viewModel.onEvent(LeadHomeEvent.ToggleUniversityMenu) },
                    onCreateLead = { viewModel.onEvent(LeadHomeEvent.CreateLeadFromCall) }
                )
            }
        }
    }
}
