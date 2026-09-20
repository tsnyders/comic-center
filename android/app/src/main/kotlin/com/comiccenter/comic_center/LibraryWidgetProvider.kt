package com.comiccenter.comic_center

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews

class LibraryWidgetProvider : AppWidgetProvider() {
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
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val payload = WidgetPayload.load(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val views = sizeBuckets.associateWith {
                buildViews(context, appWidgetId, payload.theme)
            }
            manager.updateAppWidget(appWidgetId, RemoteViews(views))
        } else {
            manager.updateAppWidget(
                appWidgetId,
                buildViews(context, appWidgetId, payload.theme),
            )
        }
        manager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
    }

    private fun buildViews(
        context: Context,
        appWidgetId: Int,
        theme: WidgetThemeTokens,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, theme.libraryLayout())
        views.applyWidgetFrame(theme)
        views.setTextColor(R.id.widget_overline, theme.fg2)
        views.setTextColor(R.id.widget_title, theme.fg)
        views.setTextColor(R.id.widget_see_all, theme.ac)
        views.setTextColor(R.id.widget_empty, theme.fg2)

        val serviceIntent = Intent(context, LibraryWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_list, serviceIntent)
        views.setEmptyView(R.id.widget_list, R.id.widget_empty)

        val templateIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = "com.comiccenter.WIDGET_OPEN_MANGA"
        }
        views.setPendingIntentTemplate(
            R.id.widget_list,
            PendingIntent.getActivity(
                context,
                appWidgetId,
                templateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            ),
        )

        val seeAllIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = "com.comiccenter.WIDGET_SEE_ALL"
        }
        views.setOnClickPendingIntent(
            R.id.widget_see_all,
            PendingIntent.getActivity(
                context,
                appWidgetId + 10_000,
                seeAllIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        return views
    }

    companion object {
        private val sizeBuckets = listOf(
            SizeF(110f, 130f),
            SizeF(180f, 130f),
            SizeF(250f, 130f),
            SizeF(250f, 250f),
            SizeF(330f, 250f),
            SizeF(420f, 370f),
        )
    }
}
