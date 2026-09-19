package com.comiccenter.comic_center

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** System file picker; copies only the selected backup, never a downloads tree. */
class BackupDocuments(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var exportFile: File? = null

    fun pick(tachiyomi: Boolean, result: MethodChannel.Result) {
        if (!begin(result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Providers often label .tachibk as application/octet-stream.
            type = "*/*"
            if (tachiyomi && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri(
                        "com.android.externalstorage.documents", "primary:Tachiyomi"))
            }
        }
        launch(intent, PICK)
    }

    fun save(path: String?, name: String?, result: MethodChannel.Result) {
        if (!begin(result)) return
        val file = path?.let(::File)
        // Accept only Yomi's own export directory, never arbitrary app files.
        val backupDir = File(activity.applicationInfo.dataDir, "app_flutter/backups")
        if (file == null || !file.isFile ||
            file.canonicalFile.parentFile != backupDir.canonicalFile) {
            finishError("INVALID_BACKUP", "The exported backup could not be found.")
            return
        }
        exportFile = file
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, name ?: "yomi_backup.json")
        }
        launch(intent, SAVE)
    }

    private fun begin(result: MethodChannel.Result): Boolean {
        if (pending != null) {
            result.error("PICKER_BUSY", "A backup file picker is already open.", null)
            return false
        }
        pending = result
        return true
    }

    @Suppress("DEPRECATION")
    private fun launch(intent: Intent, request: Int) {
        try {
            activity.startActivityForResult(intent, request)
        } catch (e: Exception) {
            finishError("PICKER_UNAVAILABLE", "No system file picker is available.")
        }
    }

    fun onResult(request: Int, resultCode: Int, data: Intent?): Boolean {
        if (request != PICK && request != SAVE) return false
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            finish(if (request == SAVE) false else null)
            return true
        }
        val source = exportFile
        executor.execute {
            var temporary: File? = null
            try {
                val value: Any = if (request == SAVE) {
                    requireNotNull(source)
                    activity.contentResolver.openOutputStream(uri, "wt").use { output ->
                        requireNotNull(output)
                        source.inputStream().use { it.copyTo(output) }
                    }
                    true
                } else {
                    val file = File.createTempFile("yomi_import_", ".backup", activity.cacheDir)
                    temporary = file
                    activity.contentResolver.openInputStream(uri).use { input ->
                        requireNotNull(input)
                        file.outputStream().use { output ->
                            val buffer = ByteArray(8192)
                            var total = 0L
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                total += count
                                require(total <= MAX_BYTES) { "Backup exceeds 32 MB." }
                                output.write(buffer, 0, count)
                            }
                        }
                    }
                    file.absolutePath
                }
                activity.runOnUiThread {
                    if (pending == null) temporary?.delete()
                    finish(value)
                }
            } catch (e: Exception) {
                temporary?.delete()
                activity.runOnUiThread {
                    finishError("BACKUP_FILE_FAILED", e.message ?: "Cannot access this backup file.")
                }
            }
        }
        return true
    }

    private fun finish(value: Any?) {
        val result = pending
        pending = null
        exportFile = null
        result?.success(value)
    }

    private fun finishError(code: String, message: String) {
        val result = pending
        pending = null
        exportFile = null
        result?.error(code, message, null)
    }

    fun dispose() {
        finish(null)
        executor.shutdown()
    }

    companion object {
        private const val PICK = 8401
        private const val SAVE = 8402
        private const val MAX_BYTES = 32L * 1024 * 1024
    }
}
