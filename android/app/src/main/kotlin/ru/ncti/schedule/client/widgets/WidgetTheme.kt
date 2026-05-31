package ru.ncti.schedule.client.widgets

import android.content.SharedPreferences
import android.graphics.Color
import ru.ncti.schedule.client.R

/// Resolved theme values the three widget providers read on every redraw.
/// Everything lives in `HomeWidget` shared prefs pushed by the Dart side.
data class WidgetTheme(
    val accent: Int,
    val isDark: Boolean,
) {
    val backgroundRes: Int
        get() = if (isDark) R.drawable.widget_background_dark
                else R.drawable.widget_background_light

    val titleColor: Int
        get() = if (isDark) Color.parseColor("#F1F5F9")
                else Color.parseColor("#0F172A")

    val subtleColor: Int
        get() = if (isDark) Color.parseColor("#94A3B8")
                else Color.parseColor("#64748B")

    val bodyColor: Int
        get() = if (isDark) Color.parseColor("#E2E8F0")
                else Color.parseColor("#0F172A")

    /// Accent colour used for headline labels ("Идёт сейчас", "Далее", etc.).
    /// On light theme we just use the raw accent (navy on white reads fine).
    /// On dark theme the navy card background eats raw accent — blue-on-blue
    /// dropped below AA — so we lighten the accent toward white by 55% so it
    /// reads clearly on the dark card without abandoning its tinted feel.
    val headlineColor: Int
        get() = if (isDark) mixToward(accent, Color.WHITE, 0.55f) else accent

    companion object {
        // Brand navy — matches `appDefaultSeedLight` in lib/common/theme.dart.
        // Kept in sync by hand: the widget provider runs outside the Dart VM
        // so we can't pull the constant in directly.
        private const val DEFAULT_ACCENT = "#0B3B7C"

        fun read(prefs: SharedPreferences): WidgetTheme {
            val hex = prefs.getString("widget_theme_accent", DEFAULT_ACCENT)
                ?: DEFAULT_ACCENT
            val accent = parseHexSafely(hex, Color.parseColor(DEFAULT_ACCENT))
            val dark = prefs.getBoolean("widget_theme_dark", false)
            return WidgetTheme(accent = accent, isDark = dark)
        }

        private fun parseHexSafely(hex: String, fallback: Int): Int {
            return try {
                Color.parseColor(hex)
            } catch (_: Exception) {
                fallback
            }
        }

        /// Linear-RGB interpolation from [a] toward [b] by [t] in [0, 1].
        /// Good enough for contrast adjustments on widget text — we don't need
        /// perceptual (Oklab/HSL) blending at the scale of a single label.
        internal fun mixToward(a: Int, b: Int, t: Float): Int {
            val clamped = t.coerceIn(0f, 1f)
            val ar = Color.red(a);   val ag = Color.green(a);   val ab = Color.blue(a)
            val br = Color.red(b);   val bg = Color.green(b);   val bb = Color.blue(b)
            val r = (ar + (br - ar) * clamped).toInt().coerceIn(0, 255)
            val g = (ag + (bg - ag) * clamped).toInt().coerceIn(0, 255)
            val bl = (ab + (bb - ab) * clamped).toInt().coerceIn(0, 255)
            return Color.rgb(r, g, bl)
        }
    }
}
