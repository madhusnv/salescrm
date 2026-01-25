package com.koncrm.counselor.ui.leads.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.koncrm.counselor.leads.LeadSummary

// Premium color palette
private val GradientStart = Color(0xFF6366F1) // Indigo
private val GradientEnd = Color(0xFF8B5CF6) // Purple
private val AccentGreen = Color(0xFF10B981)
private val AccentAmber = Color(0xFFF59E0B)
private val AccentRed = Color(0xFFEF4444)
private val SurfaceLight = Color(0xFFF8FAFC)

@Composable
fun LeadCard(
    lead: LeadSummary,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(
            defaultElevation = 2.dp,
            hoveredElevation = 6.dp
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar with gradient
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(listOf(GradientStart, GradientEnd))
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = lead.studentName.take(2).uppercase(),
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.width(14.dp))

            // Lead info
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = lead.studentName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(4.dp))

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Phone chip
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .background(
                                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                                RoundedCornerShape(6.dp)
                            )
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Call,
                            contentDescription = null,
                            modifier = Modifier.size(12.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = formatPhone(lead.phoneNumber),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    // University if available
                    lead.universityName?.let { uni ->
                        Text(
                            text = uni,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Status pill and chevron
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                StatusPill(status = lead.status)
                Icon(
                    imageVector = Icons.Default.KeyboardArrowRight,
                    contentDescription = "View details",
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}

@Composable
fun StatusPill(
    status: String,
    modifier: Modifier = Modifier
) {
    val (backgroundColor, textColor, label) = when (status.lowercase()) {
        "new" -> Triple(
            Color(0xFFEEF2FF), // Light indigo
            Color(0xFF4F46E5), // Indigo
            "New"
        )
        "contacted" -> Triple(
            Color(0xFFE0F2F1), // Light teal
            Color(0xFF0F766E), // Teal
            "Contacted"
        )
        "follow_up" -> Triple(
            Color(0xFFFEF3C7), // Light amber
            Color(0xFFD97706), // Amber
            "Follow up"
        )
        "applied" -> Triple(
            Color(0xFFD1FAE5), // Light green
            Color(0xFF059669), // Green
            "Applied"
        )
        "not_interested" -> Triple(
            Color(0xFFFEE2E2), // Light red
            Color(0xFFDC2626), // Red
            "Not interested"
        )
        else -> Triple(
            MaterialTheme.colorScheme.surfaceVariant,
            MaterialTheme.colorScheme.onSurfaceVariant,
            status.replace("_", " ").replaceFirstChar { it.uppercase() }
        )
    }

    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(20.dp),
        color = backgroundColor
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = textColor,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            letterSpacing = 0.3.sp
        )
    }
}

@Composable
fun LeadCardSkeleton(
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )
            Spacer(modifier = Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.6f)
                        .height(18.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                )
                Spacer(modifier = Modifier.height(8.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.4f)
                        .height(14.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
                )
            }
        }
    }
}

private fun formatPhone(phone: String): String {
    val digits = phone.filter { it.isDigit() }
    return if (digits.length == 10) {
        "${digits.substring(0, 5)} ${digits.substring(5)}"
    } else {
        phone
    }
}
