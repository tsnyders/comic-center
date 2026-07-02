package com.comiccenter.comic_center

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.KeyEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "yomi/platform"
    private val volumeKeyChannel = "yomi/volume_keys"

    private var volumeKeyInterceptEnabled = false
    private var volumeEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, volumeKeyChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    volumeEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVolumeKeyIntercept" -> {
                        volumeKeyInterceptEnabled =
                            call.argument<Boolean>("enabled") ?: false
                        result.success(null)
                    }
                    // Hardware/OS profile used by the Dart side to decide
                    // whether to run in reduced-motion / low-spec mode.
                    "getDeviceProfile" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memInfo = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(memInfo)
                        result.success(mapOf(
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "totalMemBytes" to memInfo.totalMem,
                            "isLowRamDevice" to am.isLowRamDevice,
                            "model" to Build.MODEL,
                            "manufacturer" to Build.MANUFACTURER,
                        ))
                    }
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
                            result.error("INVALID_URL", "URL argument is null", null)
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
                            result.error("INVALID_PATH", "Path argument is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Intercept hardware volume keys while the reader requests it, forwarding
    // them to Flutter as page-turn events. When disabled, the keys behave
    // normally (system volume control).
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumeKeyInterceptEnabled && event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeEventSink?.success("up")
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeEventSink?.success("down")
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
