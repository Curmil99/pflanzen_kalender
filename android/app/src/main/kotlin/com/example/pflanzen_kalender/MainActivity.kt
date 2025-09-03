package com.example.pflanzen_kalender

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import android.provider.MediaStore
import android.net.Uri


class MainActivity: FlutterActivity() {
    private val CHANNEL = "app.channel.images"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getImageTakenDate") {
                val path = call.argument<String>("path")
                if (path != null) {
                    try {
                        val file = File(path)
                        val exif = ExifInterface(file)

                        val dateStr = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
                            ?: exif.getAttribute(ExifInterface.TAG_DATETIME)

                        if (dateStr != null) {
                            val sdf = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US)
                            val date = sdf.parse(dateStr)
                            result.success(date?.time)
                        } else {
                            // kein EXIF gefunden
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("EXIF_ERROR", "Fehler beim Auslesen: ${e.message}", null)
                    }
                } else {
                    result.error("NO_PATH", "Kein Pfad übergeben", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
