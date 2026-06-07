package com.comiccenter.comic_center

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "yomi/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url != null) {
                            try {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                startActivity(intent)
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("OPEN_URL_FAILED", e.message, null)
                            }
                        } else {
                            result.error("INVALID_URL", "URL is null", null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            try {
                                val file = File(path)
                                val uri = FileProvider.getUriForFile(
                                    this,
                                    "${packageName}.provider",
                                    file,
                                )
                                val intent = Intent(Intent.ACTION_INSTALL_PACKAGE)
                                intent.data = uri
                                intent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                                startActivity(intent)
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("INSTALL_FAILED", e.message, null)
                            }
                        } else {
                            result.error("INVALID_PATH", "Path is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
