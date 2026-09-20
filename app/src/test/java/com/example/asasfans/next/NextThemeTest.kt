package com.example.asasfans.next

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import org.junit.Assert.*
import org.junit.Test

class NextThemeTest {
    @Test fun lightThemeUsesTheOriginalDianaPinkForSelectedControls() {
        val scheme = asasColorScheme(false)
        assertEquals(Color(0xFFE799B0), DianaPink)
        assertEquals(Color(0xFFB85B78), DianaRose)
        assertEquals(Color(0xFF8A3E59), DianaDeepRose)
        assertEquals(DianaPink, scheme.secondaryContainer)
        assertEquals(DianaDeepRose, scheme.primary)
    }

    @Test fun darkThemeKeepsTheSameBrandAccent() {
        val scheme = asasColorScheme(true)
        assertEquals(DianaPink, scheme.primary)
        assertEquals(DianaPink, scheme.surfaceTint)
    }

    @Test fun textAndSelectedLabelsHaveReadableContrastInBothThemes() {
        for (dark in listOf(false, true)) {
            val scheme = asasColorScheme(dark)
            for ((foreground, background) in listOf(
                scheme.onSurface to scheme.surface,
                scheme.onSurfaceVariant to scheme.surface,
                scheme.onSecondaryContainer to scheme.secondaryContainer,
                scheme.primary to scheme.background,
                scheme.onPrimary to scheme.primary,
            )) {
                val a = foreground.luminance(); val b = background.luminance()
                assertTrue("Text contrast must be at least 4.5:1", (maxOf(a, b) + .05f) / (minOf(a, b) + .05f) >= 4.5f)
            }
        }
    }
}
