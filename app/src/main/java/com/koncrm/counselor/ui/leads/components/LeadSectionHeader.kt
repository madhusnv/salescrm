package com.koncrm.counselor.ui.leads.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

data class StatusConfig(
    val label: String,
    val indicatorColor: Color,
    val backgroundColor: Color
)

fun getStatusConfig(status: String): StatusConfig {
    return when (status.lowercase()) {
        "new" -> StatusConfig(
            label = "New",
            indicatorColor = Color(0xFFEF4444),
            backgroundColor = Color(0xFFEEF2FF)
        )
        "follow_up" -> StatusConfig(
            label = "Follow Up",
            indicatorColor = Color(0xFFF59E0B),
            backgroundColor = Color(0xFFFEF3C7)
        )
        "contacted" -> StatusConfig(
            label = "Contacted",
            indicatorColor = Color(0xFF14B8A6),
            backgroundColor = Color(0xFFE0F2F1)
        )
        "applied" -> StatusConfig(
            label = "Applied",
            indicatorColor = Color(0xFF10B981),
            backgroundColor = Color(0xFFD1FAE5)
        )
        "not_interested" -> StatusConfig(
            label = "Not Interested",
            indicatorColor = Color(0xFF9CA3AF),
            backgroundColor = Color(0xFFF3F4F6)
        )
        else -> StatusConfig(
            label = status.replace("_", " ").replaceFirstChar { it.uppercase() },
            indicatorColor = Color(0xFF6B7280),
            backgroundColor = Color(0xFFF9FAFB)
        )
    }
}

@Composable
fun LeadSectionHeader(
    status: String,
    count: Int,
    modifier: Modifier = Modifier
) {
    val config = getStatusConfig(status)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(config.indicatorColor)
        )

        Text(
            text = config.label,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
            letterSpacing = 0.3.sp
        )

        Surface(
            shape = RoundedCornerShape(12.dp),
            color = config.backgroundColor
        ) {
            Text(
                text = count.toString(),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                color = config.indicatorColor,
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        HorizontalDivider(
            modifier = Modifier.weight(2f),
            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
            thickness = 1.dp
        )
    }
}
