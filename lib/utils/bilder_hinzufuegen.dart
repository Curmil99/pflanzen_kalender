// lib/helpers/bilder_hinzufuegen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/day_entry.dart';
import '../repositories/day_repo.dart'; 
import 'package:exif/exif.dart';

import 'package:flutter/services.dart';


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
      final int? millis = await _channel.invokeMethod('getImageTakenDate', {'path': path});
      if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
      return null;
    } catch (e) {
      print('NativeDateHelper error: $e');
      return null;
    }
  }
}


// lib/helpers/bilder_hinzufuegen.dart

// Falls du getExifDate() hast

class BilderHelper {
  static Future<void> addBilderZuEvent({
    required BuildContext context,
    required String kategorie,
    required String eventName,
  }) async {
    final List<XFile>? picked = await ImagePicker().pickMultiImage();
    if (picked == null || picked.isEmpty) return;

    for (var xfile in picked) {
      final file = File(xfile.path);

      // --- 1. EXIF versuchen ---
      DateTime? takenDate = await getExifDate(file);

      // --- 2. Native Android fallback ---
      takenDate ??= await NativeDateHelper.getImageTakenDate(file.path);

      // --- 3. Letzter Fallback ---
      takenDate ??= await file.lastModified();

      final dateKey =
          '${takenDate.year}-${takenDate.month.toString().padLeft(2, '0')}-${takenDate.day.toString().padLeft(2, '0')}';

      // Bestehenden Eintrag prüfen
      final existingEntry = DayRepo().getEntry(kategorie, eventName, dateKey);
      final updatedImages = List<String>.from(existingEntry?.imagePaths ?? []);
      updatedImages.add(file.path);


      final formattedDate  =
        '${takenDate.day.toString().padLeft(2,'0')}.'
        '${takenDate.month.toString().padLeft(2,'0')}.'
        '${takenDate.year}';

      // Tag-Eintrag erstellen/aktualisieren
      final entry = DayEntry(
        kategorie: kategorie,
        event: eventName,
        datum: dateKey,
        title: (existingEntry != null && existingEntry.title.isNotEmpty) 
            ? existingEntry.title 
            : formattedDate ,   // Dummy-Titel = Datum
        note: existingEntry?.note ?? '',
        imagePaths: updatedImages,
      );


      DayRepo().saveEntry(kategorie, eventName, dateKey, entry);
    }

    // Widget aktualisieren
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${picked.length} Bilder hinzugefügt.')),
    );
  }
}
