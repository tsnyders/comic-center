package com.comiccenter.comic_center

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.util.LruCache
import com.squareup.picasso.Picasso
import java.io.File
import java.security.MessageDigest
import kotlin.math.max
import kotlin.math.roundToInt

internal object WidgetCoverCache {
    private const val MAX_DISK_BYTES = 32L * 1024L * 1024L
    private const val MAX_DISK_FILES = 48
    private val memory = object : LruCache<String, Bitmap>(8 * 1024) {
        override fun sizeOf(key: String, value: Bitmap): Int = value.allocationByteCount / 1024
    }

    @Synchronized
    fun render(
        context: Context,
        url: String,
        widthDp: Int,
        heightDp: Int,
        theme: WidgetThemeTokens,
    ): Bitmap? {
        val raw = memory.get(url) ?: readDisk(context, url) ?: download(context, url)
            ?: return null
        memory.put(url, raw)

        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).roundToInt().coerceIn(widthDp, 360)
        val height = (heightDp * density).roundToInt().coerceIn(heightDp, 540)
        val radius = if (theme.isPastel) 18f * density else 0f
        val border = if (theme.isPastel) 0f else max(1f, density)
        return cropAndStyle(raw, width, height, radius, border, theme.line)
    }

    private fun readDisk(context: Context, url: String): Bitmap? {
        val file = cacheFile(context, url)
        if (!file.isFile) return null
        val bitmap = BitmapFactory.decodeFile(file.path)
        if (bitmap == null) {
            file.delete()
            return null
        }
        file.setLastModified(System.currentTimeMillis())
        return bitmap
    }

    private fun download(context: Context, url: String): Bitmap? {
        val bitmap = runCatching {
            Picasso.get().load(url).resize(360, 540).centerCrop().get()
        }.getOrNull() ?: return null
        val file = cacheFile(context, url)
        runCatching {
            file.parentFile?.mkdirs()
            val temp = File(file.parentFile, "${file.name}.tmp")
            temp.outputStream().buffered().use {
                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, it)
            }
            if (!temp.renameTo(file)) {
                temp.copyTo(file, overwrite = true)
                temp.delete()
            }
            trimDisk(file.parentFile)
        }
        return bitmap
    }

    private fun cacheFile(context: Context, url: String): File {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(url.toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(File(context.cacheDir, "widget_covers"), "$digest.jpg")
    }

    private fun trimDisk(directory: File?) {
        val files = directory?.listFiles()?.filter { it.isFile && it.extension == "jpg" }
            ?.sortedByDescending { it.lastModified() } ?: return
        var bytes = files.sumOf { it.length() }
        for ((index, file) in files.withIndex()) {
            if (index < MAX_DISK_FILES && bytes <= MAX_DISK_BYTES) continue
            bytes -= file.length()
            file.delete()
        }
    }

    private fun cropAndStyle(
        source: Bitmap,
        width: Int,
        height: Int,
        radius: Float,
        borderWidth: Float,
        borderColor: Int,
    ): Bitmap {
        val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val rect = RectF(0f, 0f, width.toFloat(), height.toFloat())
        val scale = max(width.toFloat() / source.width, height.toFloat() / source.height)
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate(
                (width - source.width * scale) / 2f,
                (height - source.height * scale) / 2f,
            )
        }
        val imagePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).also {
                it.setLocalMatrix(matrix)
            }
        }
        canvas.drawRoundRect(rect, radius, radius, imagePaint)
        if (borderWidth > 0f) {
            val half = borderWidth / 2f
            val borderRect = RectF(half, half, width - half, height - half)
            val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = borderColor
                style = Paint.Style.STROKE
                strokeWidth = borderWidth
            }
            canvas.drawRoundRect(borderRect, radius, radius, borderPaint)
        }
        return output
    }

    // ponytail: accept Flutter cache file paths in the payload if protected
    // cover hosts later require source-specific request headers.
}
