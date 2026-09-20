package com.example.asasfans.next

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

// Keep the original app's Diana brand pink; dark rose is used for text contrast.
internal val DianaPink = Color(0xFFE799B0)
internal val DianaRose = Color(0xFFB85B78)
internal val DianaDeepRose = Color(0xFF8A3E59)

internal fun asasColorScheme(dark: Boolean): ColorScheme = if (dark) darkColorScheme(
    primary = DianaPink, onPrimary = Color(0xFF451E2C),
    primaryContainer = Color(0xFF663247), onPrimaryContainer = Color(0xFFFFD9E5),
    inversePrimary = DianaDeepRose,
    secondary = Color(0xFFE5B9C8), onSecondary = Color(0xFF432733),
    secondaryContainer = Color(0xFF61364A), onSecondaryContainer = Color(0xFFFFD9E5),
    tertiary = Color(0xFFEABBC1), onTertiary = Color(0xFF45272D),
    tertiaryContainer = Color(0xFF603D43), onTertiaryContainer = Color(0xFFFFD9DF),
    background = Color(0xFF171318), onBackground = Color(0xFFF0E6EB),
    surface = Color(0xFF211C20), onSurface = Color(0xFFF0E6EB),
    surfaceVariant = Color(0xFF473940), onSurfaceVariant = Color(0xFFCDBEC5),
    outline = Color(0xFF9B8993), outlineVariant = Color(0xFF4A3D44),
    surfaceTint = DianaPink, inverseSurface = Color(0xFFF0E6EB), inverseOnSurface = Color(0xFF352C32),
    surfaceDim = Color(0xFF171318), surfaceBright = Color(0xFF40353D),
    surfaceContainerLowest = Color(0xFF120E12), surfaceContainerLow = Color(0xFF282127),
    surfaceContainer = Color(0xFF2D252B), surfaceContainerHigh = Color(0xFF382E35), surfaceContainerHighest = Color(0xFF43383F),
) else lightColorScheme(
    primary = DianaDeepRose, onPrimary = Color.White,
    primaryContainer = Color(0xFFF6D3DD), onPrimaryContainer = Color(0xFF451E2C),
    inversePrimary = DianaPink,
    secondary = DianaDeepRose, onSecondary = Color.White,
    secondaryContainer = DianaPink, onSecondaryContainer = Color(0xFF451E2C),
    tertiary = Color(0xFF824852), onTertiary = Color.White,
    tertiaryContainer = Color(0xFFFFDADF), onTertiaryContainer = Color(0xFF512A34),
    background = Color(0xFFFFF8FA), onBackground = Color(0xFF2B2227),
    surface = Color.White, onSurface = Color(0xFF2B2227),
    surfaceVariant = Color(0xFFF2E3E9), onSurfaceVariant = Color(0xFF73636D),
    outline = Color(0xFF927B86), outlineVariant = Color(0xFFEADBE2),
    surfaceTint = DianaPink, inverseSurface = Color(0xFF352C32), inverseOnSurface = Color(0xFFFBEFF4),
    surfaceDim = Color(0xFFE7D8DF), surfaceBright = Color(0xFFFFF8FA),
    surfaceContainerLowest = Color.White, surfaceContainerLow = Color(0xFFFBEDF2),
    surfaceContainer = Color(0xFFF6E6ED), surfaceContainerHigh = Color(0xFFF1E0E8), surfaceContainerHighest = Color(0xFFEBD9E2),
)
