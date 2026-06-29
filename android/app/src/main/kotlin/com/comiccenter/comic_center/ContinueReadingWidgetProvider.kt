package com.comiccenter.comic_center

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.os.Build
import android.util.SizeF
import android.widget.RemoteViews
import org.json.JSONObject

class ContinueReadingWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val dataStr = prefs.getString("continue_reading_manga", null)
        val manga = dataStr?.let { runCatching { JSONObject(it) }.getOrNull() }

        // Render text-only views immediately so the widget is never blank
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val sizeMap = mapOf(
                SizeF(110f, 110f) to buildSmallViews(context, appWidgetId, manga),
                SizeF(250f, 110f) to buildLargeViews(context, appWidgetId, manga, null)
            )
            appWidgetManager.updateAppWidget(appWidgetId, RemoteViews(sizeMap))
        } else {
            appWidgetManager.updateAppWidget(appWidgetId, buildLargeViews(context, appWidgetId, manga, null))
        }

        // Load the cover image in the background, then push a second update
        val coverUrl = manga?.optString("coverUrl", "") ?: ""
        if (coverUrl.isNotEmpty()) {
            Thread {
                val bitmap = runCatching {
                    com.squareup.picasso.Picasso.get()
                        .load(coverUrl)
                        .resize(160, 232)
                        .centerCrop()
                        .get()
                        .let { roundedBitmap(it, 20f) }
                }.getOrNull()

                if (bitmap != null) {
                    val mgr = AppWidgetManager.getInstance(context)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val sizeMap = mapOf(
                            SizeF(110f, 110f) to buildSmallViews(context, appWidgetId, manga),
                            SizeF(250f, 110f) to buildLargeViews(context, appWidgetId, manga, bitmap)
                        )
                        mgr.updateAppWidget(appWidgetId, RemoteViews(sizeMap))
                    } else {
                        mgr.updateAppWidget(appWidgetId, buildLargeViews(context, appWidgetId, manga, bitmap))
                    }
                }
            }.start()
        }
    }

    // ── Small layout (2×2 or smaller): label + title + chapter, no cover ──────

    private fun buildSmallViews(context: Context, appWidgetId: Int, manga: JSONObject?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_continue_reading_small)

        if (manga != null) {
            views.setTextViewText(R.id.widget_cr_small_title, manga.optString("title", "Unknown"))
            views.setTextViewText(R.id.widget_cr_small_subtitle, chapterLabel(manga))
        } else {
            views.setTextViewText(R.id.widget_cr_small_title, "No active reading")
            views.setTextViewText(R.id.widget_cr_small_subtitle, "Start a comic!")
        }

        views.setOnClickPendingIntent(R.id.widget_cr_small_root, openPendingIntent(context, appWidgetId, manga))
        return views
    }

    // ── Large layout (4×2 or bigger): cover + info + Open button ─────────────

    private fun buildLargeViews(context: Context, appWidgetId: Int, manga: JSONObject?, cover: Bitmap?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_continue_reading)

        if (manga != null) {
            views.setTextViewText(R.id.widget_cr_title, manga.optString("title", "Unknown Title"))
            views.setTextViewText(R.id.widget_cr_subtitle, chapterLabel(manga))
        } else {
            views.setTextViewText(R.id.widget_cr_title, "No active reading")
            views.setTextViewText(R.id.widget_cr_subtitle, "Start reading a comic!")
        }

        cover?.let { views.setImageViewBitmap(R.id.widget_cr_cover, it) }

        val intent = openPendingIntent(context, appWidgetId, manga)
        views.setOnClickPendingIntent(R.id.widget_cr_root, intent)
        views.setOnClickPendingIntent(R.id.widget_cr_button, intent)
        return views
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun chapterLabel(manga: JSONObject): String {
        val num = manga.optDouble("lastReadChapterNumber", 0.0)
        return if (num > 0) {
            val str = if (num % 1 == 0.0) num.toInt().toString() else num.toString()
            "Chapter $str"
        } else {
            "Tap to read"
        }
    }

    private fun openPendingIntent(context: Context, appWidgetId: Int, manga: JSONObject?): PendingIntent {
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
            context, appWidgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun roundedBitmap(src: Bitmap, radius: Float): Bitmap {
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rect = RectF(0f, 0f, src.width.toFloat(), src.height.toFloat())
        canvas.drawRoundRect(rect, radius, radius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(src, 0f, 0f, paint)
        return out
    }
}
