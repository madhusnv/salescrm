package com.koncrm.counselor.ui.leads.components

import androidx.compose.animation.animateColorAsState
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

private val AccentIndigo = Color(0xFF6366F1)

@Composable
fun LeadFilters(
    searchQuery: String,
    statusFilter: String,
    onSearchChange: (String) -> Unit,
    onStatusChange: (String) -> Unit,
    onApply: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MaterialTheme.colorScheme
    var isFocused by remember { mutableStateOf(false) }

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
