package com.comiccenter.comic_center

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class LibraryWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        LibraryWidgetFactory(applicationContext)
}

class LibraryWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var theme = WidgetPayload.load(context).theme
    private var mangas = JSONArray()

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        val payload = WidgetPayload.load(context)
        theme = payload.theme
        mangas = payload.mangas
    }

    override fun onDestroy() = Unit

    override fun getCount(): Int = minOf(mangas.length(), 12)

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, theme.libraryItemLayout())
        if (position !in 0 until mangas.length()) return views
        val manga = mangas.optJSONObject(position) ?: return views
        val rawTitle = manga.optString("title", "Unknown title")
        val title = if (theme.isCinema) rawTitle.uppercase() else rawTitle
        val unreadCount = manga.optInt("unreadCount", 0)

        views.setTextViewText(R.id.item_title, title)
        views.setTextColor(R.id.item_title, theme.fg)
        views.setInt(R.id.item_cover_placeholder, "setColorFilter", theme.card)
        views.setImageViewResource(R.id.item_cover, android.R.color.transparent)
        if (unreadCount > 0) {
            val count = if (unreadCount > 999) "999+" else unreadCount.toString()
            val badge = if (theme.isCinema) "$count NEW" else count
            val badgeColor = if (theme.isPastel) theme.fg else theme.ac
            val badgeTextColor = if (theme.isPastel) theme.bg else theme.onAc
            views.setViewVisibility(R.id.item_badge_background, View.VISIBLE)
            views.setViewVisibility(R.id.item_badge, View.VISIBLE)
            views.setInt(R.id.item_badge_background, "setColorFilter", badgeColor)
            views.setTextColor(R.id.item_badge, badgeTextColor)
            views.setTextViewText(R.id.item_badge, badge)
        } else {
            views.setViewVisibility(R.id.item_badge_background, View.GONE)
            views.setViewVisibility(R.id.item_badge, View.GONE)
        }

        val coverUrl = if (manga.isNull("coverUrl")) "" else manga.optString("coverUrl", "")
        if (coverUrl.isNotEmpty()) {
            WidgetCoverCache.render(context, coverUrl, 64, 88, theme)?.let {
                views.setImageViewBitmap(R.id.item_cover, it)
            }
        }

        val fillIn = Intent().apply {
            putExtra("widgetClick", true)
            putExtra("mangaId", manga.optString("id", ""))
            putExtra("mangaTitle", rawTitle)
        }
        views.setOnClickFillInIntent(R.id.item_root, fillIn)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 3

    override fun getItemId(position: Int): Long =
        mangas.optJSONObject(position)?.optLong("id", position.toLong()) ?: position.toLong()

    override fun hasStableIds(): Boolean = true
}
