package com.comiccenter.comic_center

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.io.File

class LibraryWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return LibraryWidgetFactory(this.applicationContext)
    }
}

class LibraryWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var mangas = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val data = prefs.getString("recently_updated_mangas", "[]")
        mangas = JSONArray(data ?: "[]")
    }

    override fun onDestroy() {}

    override fun getCount(): Int = mangas.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_library_item)
        if (position < mangas.length()) {
            val manga = mangas.getJSONObject(position)
            views.setTextViewText(R.id.item_title, manga.optString("title", "Unknown Title"))
            
            val unreadCount = manga.optInt("unreadCount", 0)
            if (unreadCount > 0) {
                views.setTextViewText(R.id.item_badge, "$unreadCount unread")
            } else {
                views.setTextViewText(R.id.item_badge, "")
            }
            
            val coverUrl = manga.optString("coverUrl", "")
            if (coverUrl.isNotEmpty()) {
                try {
                    val bitmap = com.squareup.picasso.Picasso.get().load(coverUrl).get()
                    views.setImageViewBitmap(R.id.item_cover, bitmap)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
