package com.comiccenter.comic_center

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

private const val WIDGET_PREFERENCES = "HomeWidgetPreferences"
private const val WIDGET_PAYLOAD = "yomi_widget_payload"

internal data class WidgetThemeTokens(
    val look: String,
    val dark: Boolean,
    val bg: Int,
    val card: Int,
    val fg: Int,
    val fg2: Int,
    val line: Int,
    val ac: Int,
    val onAc: Int,
) {
    val isPastel: Boolean get() = look == "pastel"
    val isCinema: Boolean get() = look == "cinema"
}

internal data class WidgetPayload(
    val theme: WidgetThemeTokens,
    val mangas: JSONArray,
    val continueReading: JSONObject?,
) {
    companion object {
        fun load(context: Context): WidgetPayload {
            val raw = context.getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE)
                .getString(WIDGET_PAYLOAD, null)
            val json = raw?.let { runCatching { JSONObject(it) }.getOrNull() }
                ?: JSONObject()
            val fallbackDark = context.resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
            val fallbackFg = if (fallbackDark) Color.WHITE else Color.BLACK
            val fallbackBg = if (fallbackDark) Color.BLACK else Color.WHITE
            val theme = WidgetThemeTokens(
                look = json.optString("look", "sumi")
                    .takeIf { it in setOf("sumi", "cinema", "pastel") } ?: "sumi",
                dark = json.optBoolean("dark", fallbackDark),
                bg = json.color("bg", fallbackBg),
                card = json.color("card", if (fallbackDark) Color.DKGRAY else Color.LTGRAY),
                fg = json.color("fg", fallbackFg),
                fg2 = json.color("fg2", Color.GRAY),
                line = json.color("line", Color.GRAY),
                ac = json.color("ac", fallbackFg),
                onAc = json.color("onAc", fallbackBg),
            )
            return WidgetPayload(
                theme = theme,
                mangas = json.optJSONArray("mangas") ?: JSONArray(),
                continueReading = json.optJSONObject("continueReading"),
            )
        }
    }
}

private fun JSONObject.color(name: String, fallback: Int): Int =
    if (has(name)) optLong(name).toInt() else fallback

internal fun WidgetThemeTokens.libraryLayout(): Int = when (look) {
    "cinema" -> R.layout.widget_library_cinema
    "pastel" -> R.layout.widget_library_pastel
    else -> R.layout.widget_library
}

internal fun WidgetThemeTokens.libraryItemLayout(): Int = when (look) {
    "cinema" -> R.layout.widget_library_item_cinema
    "pastel" -> R.layout.widget_library_item_pastel
    else -> R.layout.widget_library_item
}

internal fun WidgetThemeTokens.continueLayout(compact: Boolean): Int = when {
    look == "cinema" && compact -> R.layout.widget_continue_reading_small_cinema
    look == "cinema" -> R.layout.widget_continue_reading_cinema
    look == "pastel" && compact -> R.layout.widget_continue_reading_small_pastel
    look == "pastel" -> R.layout.widget_continue_reading_pastel
    compact -> R.layout.widget_continue_reading_small
    else -> R.layout.widget_continue_reading
}

internal fun RemoteViews.applyWidgetFrame(theme: WidgetThemeTokens) {
    setInt(R.id.widget_background_shape, "setColorFilter", theme.bg)
    if (!theme.isPastel) {
        setInt(R.id.widget_border_top, "setBackgroundColor", theme.line)
        setInt(R.id.widget_border_bottom, "setBackgroundColor", theme.line)
        setInt(R.id.widget_border_start, "setBackgroundColor", theme.line)
        setInt(R.id.widget_border_end, "setBackgroundColor", theme.line)
    }
}
