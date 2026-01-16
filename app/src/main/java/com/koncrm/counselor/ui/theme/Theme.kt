package com.koncrm.counselor.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val DarkColorScheme = darkColorScheme(
    primary = Ember500,
    secondary = Sky500,
    tertiary = Leaf500,
    background = Ink900,
    surface = Ink800,
    onPrimary = Ink900,
    onSecondary = Ink900,
    onTertiary = Ink900,
    onBackground = Sand100,
    onSurface = Sand100
)

private val LightColorScheme = lightColorScheme(
    primary = Ink900,
    secondary = Slate600,
    tertiary = Ember600,
    background = Mist50,
    surface = Sand100,
    onPrimary = Sand100,
    onSecondary = Mist50,
    onTertiary = Ink900,
    onBackground = Ink900,
    onSurface = Ink900
)

@Composable
fun KonCRMCounselorTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
