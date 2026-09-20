package com.comiccenter.comic_center

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

class ContinueReadingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        updateWidget(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        options: Bundle = manager.getAppWidgetOptions(appWidgetId),
    ) {
        val payload = WidgetPayload.load(context)
        updateRemoteViews(context, manager, appWidgetId, options, payload, null)

        val manga = payload.continueReading ?: return
        val coverUrl = if (manga.isNull("coverUrl")) "" else manga.optString("coverUrl", "")
        if (coverUrl.isEmpty()) return
        Thread {
            val bitmap = WidgetCoverCache.render(context, coverUrl, 80, 116, payload.theme)
                ?: return@Thread
            val current = WidgetPayload.load(context)
            if (current.theme != payload.theme ||
                current.continueReading?.optLong("id") != manga.optLong("id")) return@Thread
            updateRemoteViews(context, manager, appWidgetId, options, current, bitmap)
        }.start()
    }

    private fun updateRemoteViews(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        options: Bundle,
        payload: WidgetPayload,
        cover: android.graphics.Bitmap?,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val views = sizeBuckets.associateWith { size ->
                val compact = isCompact(size.width.toInt(), size.height.toInt())
                buildViews(context, appWidgetId, payload, compact, cover)
            }
            manager.updateAppWidget(appWidgetId, RemoteViews(views))
        } else {
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 140)
            manager.updateAppWidget(
                appWidgetId,
                buildViews(context, appWidgetId, payload, isCompact(width, height), cover),
            )
        }
    }

    private fun buildViews(
        context: Context,
        appWidgetId: Int,
        payload: WidgetPayload,
        compact: Boolean,
        cover: android.graphics.Bitmap?,
    ): RemoteViews {
        val theme = payload.theme
        val manga = payload.continueReading
        val views = RemoteViews(context.packageName, theme.continueLayout(compact))
        views.applyWidgetFrame(theme)
        views.setTextColor(R.id.widget_cr_label, theme.ac)
        views.setTextColor(R.id.widget_cr_title, theme.fg)
        views.setTextColor(R.id.widget_cr_subtitle, theme.fg2)
        views.setInt(R.id.widget_cr_cover_placeholder, "setColorFilter", theme.card)
        views.setImageViewResource(R.id.widget_cr_cover, android.R.color.transparent)

        if (manga != null) {
            val rawTitle = manga.optString("title", "Unknown title")
            views.setTextViewText(
                R.id.widget_cr_title,
                if (theme.isCinema) rawTitle.uppercase() else rawTitle,
            )
            views.setTextViewText(R.id.widget_cr_subtitle, chapterLabel(manga))
        } else {
            views.setTextViewText(R.id.widget_cr_title, "No active reading")
            views.setTextViewText(R.id.widget_cr_subtitle, "Start a comic")
        }
        cover?.let { views.setImageViewBitmap(R.id.widget_cr_cover, it) }

        if (!compact) {
            val progress = manga?.let(::progressLabel).orEmpty()
            views.setTextColor(R.id.widget_cr_progress, theme.fg2)
            views.setTextViewText(R.id.widget_cr_progress, progress)
            views.setViewVisibility(
                R.id.widget_cr_progress,
                if (progress.isEmpty()) View.GONE else View.VISIBLE,
            )
            views.setInt(R.id.widget_cr_progress_rule, "setBackgroundColor", theme.ac)
            views.setInt(R.id.widget_cr_button_background, "setColorFilter", theme.ac)
            views.setTextColor(R.id.widget_cr_button, theme.onAc)
        }

        val intent = openPendingIntent(context, appWidgetId, manga)
        views.setOnClickPendingIntent(R.id.widget_cr_root, intent)
        if (!compact) views.setOnClickPendingIntent(R.id.widget_cr_button_container, intent)
        return views
    }

    private fun chapterLabel(manga: JSONObject): String {
        val number = manga.optDouble("lastReadChapterNumber", 0.0)
        if (number <= 0) return "Tap to read"
        val text = if (number % 1 == 0.0) number.toInt().toString() else number.toString()
        return "Chapter $text"
    }

    private fun progressLabel(manga: JSONObject): String {
        val parts = mutableListOf<String>()
        val page = manga.optInt("lastReadPage", 0)
        if (page > 0) parts += "Page ${page + 1}"
        val unread = manga.optInt("unreadCount", 0)
        if (unread > 0) parts += "$unread unread"
        return parts.joinToString("  ·  ")
    }

    private fun openPendingIntent(
        context: Context,
        appWidgetId: Int,
        manga: JSONObject?,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = "com.comiccenter.WIDGET_CONTINUE_READING"
            manga?.let {
                putExtra("widgetClick", true)
                putExtra("mangaId", it.optString("id", ""))
                putExtra("mangaTitle", it.optString("title", ""))
                putExtra("chapterNumber", it.optDouble("lastReadChapterNumber", 0.0))
            }
        }
        return PendingIntent.getActivity(
            context,
            appWidgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun isCompact(width: Int, height: Int): Boolean = width < 250 || height < 150

    companion object {
        private val sizeBuckets = listOf(
            SizeF(110f, 110f),
            SizeF(180f, 110f),
            SizeF(250f, 110f),
            SizeF(250f, 160f),
            SizeF(330f, 180f),
            SizeF(420f, 220f),
        )
    }
}
