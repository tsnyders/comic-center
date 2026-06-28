package com.comiccenter.comic_center

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONObject

class ContinueReadingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_continue_reading)
            
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val dataStr = prefs.getString("continue_reading_manga", null)
            
            if (dataStr != null) {
                try {
                    val manga = JSONObject(dataStr)
                    views.setTextViewText(R.id.widget_cr_title, manga.optString("title", "Unknown Title"))
                    
                    val chapterNum = manga.optDouble("lastReadChapterNumber", 0.0)
                    if (chapterNum > 0) {
                        // Format chapter number
                        val chapterStr = if (chapterNum % 1 == 0.0) chapterNum.toInt().toString() else chapterNum.toString()
                        views.setTextViewText(R.id.widget_cr_subtitle, "Continue Chapter $chapterStr")
                    } else {
                        views.setTextViewText(R.id.widget_cr_subtitle, "Continue Reading")
                    }
                    
                    val coverUrl = manga.optString("coverUrl", "")
                    if (coverUrl.isNotEmpty()) {
                        // Use Picasso directly. AppWidgetProvider onUpdate runs on main thread,
                        // but get() shouldn't be called on main thread. We need to thread it.
                        Thread {
                            try {
                                val bitmap = com.squareup.picasso.Picasso.get().load(coverUrl).get()
                                views.setImageViewBitmap(R.id.widget_cr_cover, bitmap)
                                appWidgetManager.updateAppWidget(appWidgetId, views)
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }.start()
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            } else {
                views.setTextViewText(R.id.widget_cr_title, "No active reading")
                views.setTextViewText(R.id.widget_cr_subtitle, "Start reading a comic!")
            }
            
            // Initial update before image loads
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
