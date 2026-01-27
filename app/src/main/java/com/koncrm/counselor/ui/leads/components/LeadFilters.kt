package com.koncrm.counselor.ui.leads.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.koncrm.counselor.leads.University

private val AccentIndigo = Color(0xFF6366F1)

@Composable
fun LeadFilters(
    searchQuery: String,
    statusFilter: String,
    universityFilter: Long?,
    activityFilter: String,
    followupFilter: String,
    universities: List<University>,
    isExpanded: Boolean,
    onSearchChange: (String) -> Unit,
    onStatusChange: (String) -> Unit,
    onUniversityChange: (Long?) -> Unit,
    onActivityChange: (String) -> Unit,
    onFollowupChange: (String) -> Unit,
    onToggleExpanded: () -> Unit,
    onClearAll: () -> Unit,
    onApply: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MaterialTheme.colorScheme
    var isFocused by remember { mutableStateOf(false) }

    val activeFilterCount = listOfNotNull(
        universityFilter,
        activityFilter.takeIf { it.isNotBlank() },
        followupFilter.takeIf { it.isNotBlank() }
    ).size

    val hasAnyFilter = statusFilter.isNotBlank() || 
        universityFilter != null || 
        activityFilter.isNotBlank() || 
        followupFilter.isNotBlank() ||
        searchQuery.isNotBlank()

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Search bar with premium styling
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(colors.surfaceVariant.copy(alpha = 0.5f))
                .border(
                    width = if (isFocused) 2.dp else 0.dp,
                    color = if (isFocused) AccentIndigo.copy(alpha = 0.5f) else Color.Transparent,
                    shape = RoundedCornerShape(14.dp)
                )
                .padding(horizontal = 14.dp, vertical = 12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = "Search",
                    tint = if (isFocused) AccentIndigo else colors.onSurface.copy(alpha = 0.5f),
                    modifier = Modifier.size(20.dp)
                )

                Spacer(modifier = Modifier.width(10.dp))

                BasicTextField(
                    value = searchQuery,
                    onValueChange = {
                        onSearchChange(it)
                        onApply()
                    },
                    modifier = Modifier
                        .weight(1f)
                        .onFocusChanged { isFocused = it.isFocused },
                    textStyle = TextStyle(
                        color = colors.onSurface,
                        fontSize = 15.sp
                    ),
                    singleLine = true,
                    cursorBrush = SolidColor(AccentIndigo),
                    decorationBox = { innerTextField ->
                        Box {
                            if (searchQuery.isEmpty()) {
                                Text(
                                    text = "Search leads...",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = colors.onSurface.copy(alpha = 0.4f)
                                )
                            }
                            innerTextField()
                        }
                    }
                )

                if (searchQuery.isNotEmpty()) {
                    IconButton(
                        onClick = {
                            onSearchChange("")
                            onApply()
                        },
                        modifier = Modifier.size(24.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Clear",
                            tint = colors.onSurface.copy(alpha = 0.5f),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }

        // Status filter chips
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            val filters = listOf(
                "" to "All",
                "new" to "New",
                "contacted" to "Contacted",
                "follow_up" to "Follow up",
                "applied" to "Applied",
                "not_interested" to "Not interested"
            )

            items(filters) { (value, label) ->
                FilterChip(
                    value = value,
                    label = label,
                    isSelected = statusFilter == value,
                    onClick = {
                        onStatusChange(value)
                        onApply()
                    }
                )
            }
        }

        // More Filters expand/collapse button
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .clickable { onToggleExpanded() }
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (isExpanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                contentDescription = if (isExpanded) "Collapse" else "Expand",
                tint = AccentIndigo,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = "More Filters",
                style = MaterialTheme.typography.labelLarge,
                color = AccentIndigo,
                fontWeight = FontWeight.Medium
            )
            if (activeFilterCount > 0) {
                Spacer(modifier = Modifier.width(8.dp))
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = AccentIndigo
                ) {
                    Text(
                        text = activeFilterCount.toString(),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                    )
                }
            }
        }

        // Expanded filter section
        AnimatedVisibility(
            visible = isExpanded,
            enter = expandVertically(),
            exit = shrinkVertically()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(colors.surfaceVariant.copy(alpha = 0.3f))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // University dropdown
                UniversityDropdown(
                    selectedId = universityFilter,
                    universities = universities,
                    onSelect = { 
                        onUniversityChange(it)
                        onApply()
                    }
                )

                // Activity filter
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "Activity",
                        style = MaterialTheme.typography.labelMedium,
                        color = colors.onSurface.copy(alpha = 0.7f)
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        val activityOptions = listOf(
                            "today" to "Today",
                            "week" to "This Week",
                            "stale" to "Stale"
                        )
                        activityOptions.forEach { (value, label) ->
                            FilterChip(
                                value = value,
                                label = label,
                                isSelected = activityFilter == value,
                                onClick = {
                                    onActivityChange(if (activityFilter == value) "" else value)
                                    onApply()
                                }
                            )
                        }
                    }
                }

                // Follow-up filter
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "Follow-up",
                        style = MaterialTheme.typography.labelMedium,
                        color = colors.onSurface.copy(alpha = 0.7f)
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        val followupOptions = listOf(
                            "overdue" to "Overdue",
                            "due_today" to "Due Today",
                            "upcoming" to "Upcoming"
                        )
                        followupOptions.forEach { (value, label) ->
                            FilterChip(
                                value = value,
                                label = label,
                                isSelected = followupFilter == value,
                                onClick = {
                                    onFollowupChange(if (followupFilter == value) "" else value)
                                    onApply()
                                }
                            )
                        }
                    }
                }

                // Clear All button
                if (hasAnyFilter) {
                    TextButton(
                        onClick = onClearAll,
                        modifier = Modifier.align(Alignment.End)
                    ) {
                        Text(
                            text = "Clear All Filters",
                            color = AccentIndigo,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun UniversityDropdown(
    selectedId: Long?,
    universities: List<University>,
    onSelect: (Long?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val colors = MaterialTheme.colorScheme
    val selectedUniversity = universities.find { it.id == selectedId }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "University",
            style = MaterialTheme.typography.labelMedium,
            color = colors.onSurface.copy(alpha = 0.7f)
        )
        
        Box {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .clickable { expanded = true },
                color = colors.surface,
                shape = RoundedCornerShape(10.dp),
                border = androidx.compose.foundation.BorderStroke(
                    1.dp,
                    if (selectedId != null) AccentIndigo else colors.outline.copy(alpha = 0.3f)
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = selectedUniversity?.name ?: "All Universities",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (selectedId != null) colors.onSurface else colors.onSurface.copy(alpha = 0.5f)
                    )
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowDown,
                        contentDescription = "Expand",
                        tint = colors.onSurface.copy(alpha = 0.5f),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                DropdownMenuItem(
                    text = { Text("All Universities") },
                    onClick = {
                        onSelect(null)
                        expanded = false
                    }
                )
                universities.forEach { university ->
                    DropdownMenuItem(
                        text = { Text(university.name) },
                        onClick = {
                            onSelect(university.id)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun FilterChip(
    value: String,
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val backgroundColor by animateColorAsState(
        targetValue = if (isSelected) AccentIndigo else colors.surfaceVariant.copy(alpha = 0.5f),
        label = "chipBackground"
    )
    val textColor by animateColorAsState(
        targetValue = if (isSelected) Color.White else colors.onSurface.copy(alpha = 0.7f),
        label = "chipText"
    )

    Surface(
        modifier = Modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = backgroundColor,
        shadowElevation = if (isSelected) 2.dp else 0.dp
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = textColor,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
        )
    }
}
