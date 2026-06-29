package com.comiccenter.comic_center

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class LibraryWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        LibraryWidgetFactory(applicationContext)
}

class LibraryWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var mangas = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        mangas = JSONArray(prefs.getString("recently_updated_mangas", "[]") ?: "[]")
    }

    override fun onDestroy() {}
    override fun getCount(): Int = minOf(mangas.length(), 10)

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_library_item)
        if (position >= mangas.length()) return views

        val manga = mangas.getJSONObject(position)
        val title = manga.optString("title", "Unknown Title")
        val mangaId = manga.optString("id", "")
        val unreadCount = manga.optInt("unreadCount", 0)

        views.setTextViewText(R.id.item_title, title)
        views.setTextViewText(R.id.item_badge, if (unreadCount > 0) "$unreadCount new" else "")

        val coverUrl = manga.optString("coverUrl", "")
        if (coverUrl.isNotEmpty()) {
            try {
                val raw = com.squareup.picasso.Picasso.get()
                    .load(coverUrl)
                    .resize(96, 136)
                    .centerCrop()
                    .get()
                views.setImageViewBitmap(R.id.item_cover, roundedBitmap(raw, 16f))
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Fill-in intent carries manga ID; the template PendingIntent delivers it to MainActivity
        val fillIn = Intent().apply {
            putExtra("widgetClick", true)
            putExtra("mangaId", mangaId)
            putExtra("mangaTitle", title)
        }
        views.setOnClickFillInIntent(R.id.item_root, fillIn)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

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
