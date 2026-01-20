package com.koncrm.counselor.ui.leads.components

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.koncrm.counselor.leads.LeadSummary
import com.koncrm.counselor.leads.University
import com.koncrm.counselor.ui.leads.PendingCallNote

private val GradientStart = Color(0xFF6366F1)
private val GradientEnd = Color(0xFF8B5CF6)

@OptIn(ExperimentalMaterial3Api::class)

@Composable
fun CallNoteOverlay(
    pending: PendingCallNote,
    noteText: String,
    isSaving: Boolean,
    showLeadCreation: Boolean,
    leadName: String,
    universities: List<University>,
    selectedUniversityId: Long?,
    isUniversityMenuOpen: Boolean,
    onNoteChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onSave: () -> Unit,
    onLeadNameChange: (String) -> Unit,
    onUniversitySelected: (Long) -> Unit,
    onToggleUniversityMenu: () -> Unit,
    onCreateLead: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MaterialTheme.colorScheme

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.5f)),
        contentAlignment = Alignment.BottomCenter
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            shape = RoundedCornerShape(28.dp),
            colors = CardDefaults.cardColors(containerColor = colors.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 16.dp)
        ) {
            Column(modifier = Modifier.padding(24.dp)) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Post-call Note",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = colors.onSurface
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Dismiss",
                            tint = colors.onSurface.copy(alpha = 0.5f)
                        )
                    }
                }

                // Phone number
                Text(
                    text = "Call ended with ${pending.phoneNumber}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.onSurface.copy(alpha = 0.7f),
                    modifier = Modifier.padding(top = 8.dp)
                )

                // Lead status
                if (pending.lead != null) {
                    MatchedLeadBanner(lead = pending.lead)
                } else {
                    NoLeadBanner()
                }

                // Lead creation form
                AnimatedVisibility(
                    visible = showLeadCreation && pending.lead == null,
                    enter = fadeIn() + expandVertically(),
                    exit = fadeOut() + shrinkVertically()
                ) {
                    LeadCreationForm(
                        leadName = leadName,
                        universities = universities,
                        selectedUniversityId = selectedUniversityId,
                        isMenuOpen = isUniversityMenuOpen,
                        onNameChange = onLeadNameChange,
                        onUniversitySelected = onUniversitySelected,
                        onToggleMenu = onToggleUniversityMenu,
                        onCreate = onCreateLead
                    )
                }

                // Note input
                OutlinedTextField(
                    value = noteText,
                    onValueChange = onNoteChange,
                    placeholder = { Text("Outcome or next steps...") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = GradientStart,
                        cursorColor = GradientStart
                    ),
                    minLines = 3,
                    maxLines = 5
                )

                // Action buttons
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    OutlinedButton(
                        onClick = onDismiss,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Text("Dismiss")
                    }
                    
                    Button(
                        onClick = onSave,
                        enabled = pending.lead != null && noteText.isNotBlank() && !isSaving,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = GradientStart)
                    ) {
                        if (isSaving) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp),
                                color = Color.White,
                                strokeWidth = 2.dp
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                        }
                        Text(if (isSaving) "Saving..." else "Save Note")
                    }
                }
            }
        }
    }
}

@Composable
private fun MatchedLeadBanner(lead: LeadSummary) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp),
        shape = RoundedCornerShape(14.dp),
        color = Color(0xFF10B981).copy(alpha = 0.1f)
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(
                        Color(0xFF10B981),
                        RoundedCornerShape(50)
                    )
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(
                    text = "Matched lead",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color(0xFF059669)
                )
                Text(
                    text = lead.studentName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF047857)
                )
            }
        }
    }
}

@Composable
private fun NoLeadBanner() {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp),
        shape = RoundedCornerShape(14.dp),
        color = Color(0xFFF59E0B).copy(alpha = 0.1f)
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = null,
                tint = Color(0xFFD97706),
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "No matching lead found. Create one below.",
                style = MaterialTheme.typography.bodyMedium,
                color = Color(0xFFB45309)
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LeadCreationForm(
    leadName: String,
    universities: List<University>,
    selectedUniversityId: Long?,
    isMenuOpen: Boolean,
    onNameChange: (String) -> Unit,
    onUniversitySelected: (Long) -> Unit,
    onToggleMenu: () -> Unit,
    onCreate: () -> Unit
) {
    Column(
        modifier = Modifier.padding(top = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        OutlinedTextField(
            value = leadName,
            onValueChange = onNameChange,
            placeholder = { Text("Lead name") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            singleLine = true
        )

        // University selector
        if (universities.isNotEmpty()) {
            ExposedDropdownMenuBox(
                expanded = isMenuOpen,
                onExpandedChange = { onToggleMenu() }
            ) {
                OutlinedTextField(
                    value = universities.find { it.id == selectedUniversityId }?.name ?: "Select university",
                    onValueChange = {},
                    readOnly = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor(),
                    shape = RoundedCornerShape(12.dp),
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = isMenuOpen) }
                )
                
                ExposedDropdownMenu(
                    expanded = isMenuOpen,
                    onDismissRequest = onToggleMenu
                ) {
                    universities.forEach { university ->
                        DropdownMenuItem(
                            text = { Text(university.name) },
                            onClick = { onUniversitySelected(university.id) }
                        )
                    }
                }
            }
        }

        Button(
            onClick = onCreate,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981))
        ) {
            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Create Lead")
        }
    }
}
