import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/day_entry.dart';
import '../repositories/day_repo.dart';
import 'package:exif/exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

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

DateTime? parseWhatsAppDateFromPath(String fileName) {
  final regex = RegExp(r'^(IMG|VID)-(\d{4})(\d{2})(\d{2})-WA\d+');
  final match = regex.firstMatch(fileName);

  if (match == null) return null;

  final year = int.tryParse(match.group(2)!);
  final month = int.tryParse(match.group(3)!);
  final day = int.tryParse(match.group(4)!);

  if (year == null || month == null || day == null) return null;

  return DateTime(year, month, day);
}

class BilderHelper {
  static Future<void> addBilderZuEvent({
    required BuildContext context,
    required String kategorie,
    required String eventName,
  }) async {
    if (!await ensureStoragePermission(context)) return;

    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 10,
        requestType: RequestType.image,
      ),
    );
    if (assets == null || assets.isEmpty) return;

    final repo = DayRepo();

    // Bilder nach Datum gruppieren (falls mehrere Tage vorkommen)
    final Map<String, List<String>> dateToPaths = {};

    for (var asset in assets) {
      final file = await asset.file;
      if (file == null) continue;

      final title = asset.title ?? '';
      debugPrint('Asset title: $title');
      debugPrint('Asset path: ${file.path}');

      // Datum bestimmen: EXIF → WhatsApp-Dateiname → Fallback
      DateTime? takenDate = await getExifDate(file);
      debugPrint('EXIF date: $takenDate');
      takenDate ??= parseWhatsAppDateFromPath(title);
      debugPrint('WhatsApp date from title: $takenDate');
      takenDate ??= await file.lastModified();
      debugPrint('Fallback lastModified: $takenDate');

      final dateKey =
          '${takenDate.year}-${takenDate.month.toString().padLeft(2, '0')}-${takenDate.day.toString().padLeft(2, '0')}';

      dateToPaths.putIfAbsent(dateKey, () => []);
      dateToPaths[dateKey]!.add(file.path);
    }

    // Jetzt pro Datum den passenden Entry updaten
    for (var entryDate in dateToPaths.keys) {
      final existingEntry = await repo.getEntry(kategorie, eventName, entryDate);
      final updatedImages = List<String>.from(existingEntry?.imagePaths ?? []);
      updatedImages.addAll(dateToPaths[entryDate]!);

      // Titel fallback: Datum, wenn leer
      final dateParts = entryDate.split("-");
      final formattedDate = "${dateParts[2]}.${dateParts[1]}.${dateParts[0]}";

      final entry = DayEntry(
        kategorie: kategorie,
        event: eventName,
        datum: entryDate,
        title: existingEntry?.title.isNotEmpty == true
            ? existingEntry!.title
            : formattedDate,
        note: existingEntry?.note ?? '',
        imagePaths: updatedImages,
      );

      await repo.saveEntry(entry);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${assets.length} Bilder hinzugefügt.')),
    );
  }
}
