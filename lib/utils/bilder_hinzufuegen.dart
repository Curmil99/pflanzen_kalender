import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/day_entry.dart';
import '../repositories/day_repo.dart';
import 'package:exif/exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

Future<bool> ensureStoragePermission(BuildContext context) async {
  if (await Permission.photos.isGranted || await Permission.storage.isGranted) {
    return true;
  }
  final photosStatus = await Permission.photos.request();
  final storageStatus = await Permission.storage.request();
  if (photosStatus.isGranted || storageStatus.isGranted) return true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Zugriff auf Fotos wird benötigt.")),
  );
  return false;
}

Future<DateTime?> getExifDate(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final data = await readExifFromBytes(bytes);
    if (data.containsKey('Image DateTime')) {
      final str = data['Image DateTime']!.printable;
      return DateTime.tryParse(str.replaceAll(':', '-').replaceFirst(' ', 'T'));
    }
  } catch (_) {}
  return null;
}

class NativeDateHelper {
  static const _channel = MethodChannel('app.channel.images');

  static Future<DateTime?> getImageTakenDate(String path) async {
    try {
      final result = await _channel.invokeMethod('getImageDate', {'path': path});
      final int timestamp = result['timestamp'];
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> findOriginalPath(String cachePath) async {
    try {
      final result = await _channel.invokeMethod('findOriginalPath', {'path': cachePath});
      return result;
    } catch (_) {
      return null;
    }
  }
}

class BilderHelper {
  static Future<void> addBilderZuEvent({
    required BuildContext context,
    required String kategorie,
    required String eventName,
  }) async {
    if (!await ensureStoragePermission(context)) return;

    final List<XFile>? images = await ImagePicker().pickMultiImage();
    if (images == null || images.isEmpty) return;

    final repo = DayRepo();
  

    for (var image in images) {
      final file = File(image.path);
      File targetFile = file;

      // Originalpfad prüfen
      final originalPath = await NativeDateHelper.findOriginalPath(file.path);
      if (originalPath != null) targetFile = File(originalPath);

      // Datum bestimmen: EXIF → Native → Fallback
      DateTime? takenDate = await getExifDate(targetFile);
      takenDate ??= await NativeDateHelper.getImageTakenDate(targetFile.path);
      takenDate ??= await targetFile.lastModified();

      final dateKey =
          '${takenDate.year}-${takenDate.month.toString().padLeft(2, '0')}-${takenDate.day.toString().padLeft(2, '0')}';

      final existingEntry = await repo.getEntry(kategorie, eventName, dateKey);
      final updatedImages = List<String>.from(existingEntry?.imagePaths ?? []);
      updatedImages.add(targetFile.path);

      final formattedDate =
          '${takenDate.day.toString().padLeft(2, '0')}.'
          '${takenDate.month.toString().padLeft(2, '0')}.'
          '${takenDate.year}';

      final entry = DayEntry(
        kategorie: kategorie,
        event: eventName,
        datum: dateKey,
        title: existingEntry?.title.isNotEmpty == true ? existingEntry!.title : formattedDate,
        note: existingEntry?.note ?? '',
        imagePaths: updatedImages,
      );

      await repo.saveEntry(entry); // jetzt await
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${images.length} Bilder hinzugefügt.')),
    );
  }
}

