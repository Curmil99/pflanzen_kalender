package com.example.pflanzen_kalender

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import android.provider.MediaStore
import android.util.Log

data class ImageDateResult(
    val timestamp: Long,
    val source: String // "exif", "media_store", "whatsapp_filename", "last_modified", "snapchat_media_store"
)

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app.channel.images"
    private val TAG = "ImageDateDebug"

    private fun normalizeToMs(value: Long?, alreadyMs: Boolean): Long? {
        if (value == null || value <= 0) return null
        return if (alreadyMs) value else value * 1000
    }

    private fun queryMediaStoreByNameAndSize(fileName: String, sizeBytes: Long): Long? {
        val projection = arrayOf(
            MediaStore.Images.Media.DATE_TAKEN,
            MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.DATE_MODIFIED,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.RELATIVE_PATH
        )

        val selection = "${MediaStore.Images.Media.DISPLAY_NAME} = ? AND ${MediaStore.Images.Media.SIZE} = ?"
        val selectionArgs = arrayOf(fileName, sizeBytes.toString())

        var bestTs: Long? = null
        var bestIsSnapPath = false

        contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection, selection, selectionArgs, null
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val takenMs   = normalizeToMs(cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_TAKEN)), true)
                val addedMs   = normalizeToMs(cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)), false)
                val modifiedMs = normalizeToMs(cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_MODIFIED)), false)
                val relPath = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.RELATIVE_PATH)) ?: ""

                val candidate = takenMs ?: addedMs ?: modifiedMs
                if (candidate != null) {
                    val isSnap = relPath.contains("Snapchat", ignoreCase = true)
                    val replace = when {
                        bestTs == null -> true
                        isSnap && !bestIsSnapPath -> true
                        isSnap == bestIsSnapPath && candidate > (bestTs ?: 0L) -> true
                        else -> false
                    }
                    if (replace) {
                        bestTs = candidate
                        bestIsSnapPath = isSnap
                    }
                }
            }
        }

        return bestTs
    }

    private fun getMediaStoreDateForSnapchat(file: File): Long? {
        return queryMediaStoreByNameAndSize(file.name, file.length())
    }

    private fun getWhatsAppDate(file: File): Long? {
        val regex = Regex("""IMG-(\d{8})-WA\d+""")
        val match = regex.find(file.name)
        if (match != null) {
            val datePart = match.groupValues[1]
            val format = SimpleDateFormat("yyyyMMdd", Locale.US)
            return format.parse(datePart)?.time
        }
        return null
    }

    private fun getImageTakenDate(file: File): ImageDateResult {
        try {
            // 1 EXIF
            try {
                val exif = ExifInterface(file)
                val dateStr = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
                    ?: exif.getAttribute(ExifInterface.TAG_DATETIME)
                if (dateStr != null) {
                    val sdf = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US)
                    val date = sdf.parse(dateStr)
                    if (date != null) return ImageDateResult(date.time, "exif")
                }
            } catch (_: Exception) {}

            // 2 WhatsApp
            getWhatsAppDate(file)?.let { return ImageDateResult(it, "whatsapp_filename") }

            // 3 Snapchat MediaStore
            if (file.name.startsWith("Snapchat-")) {
                getMediaStoreDateForSnapchat(file)?.let { return ImageDateResult(it, "snapchat_media_store") }
            }

            // 4 Fallback MediaStore generell
            queryMediaStoreByNameAndSize(file.name, file.length())?.let { return ImageDateResult(it, "media_store") }

            // 5 Fallback File.lastModified
            return ImageDateResult(file.lastModified(), "last_modified")

        } catch (_: Exception) {
            return ImageDateResult(file.lastModified(), "error")
        }
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getImageDate") {
                val path = call.argument<String>("path")
                if (path != null) {
                    val file = File(path)
                    val dateResult = getImageTakenDate(file)
                    result.success(mapOf("timestamp" to dateResult.timestamp, "source" to dateResult.source))
                } else {
                    result.error("NO_PATH", "Kein Pfad übergeben", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
