import 'package:isar/isar.dart';
import '../models/day_entry.dart';
import 'package:path_provider/path_provider.dart';

class DayRepo {
  static final DayRepo _instance = DayRepo._internal();
  factory DayRepo() => _instance;
  DayRepo._internal();

  late final Isar _isar;

  /// Muss vor Nutzung einmal aufgerufen werden
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [DayEntrySchema],
      directory: dir.path,
    );
  }

  // ---------- CRUD ----------

  Future<void> saveEntry(DayEntry entry) async {
    await _isar.writeTxn(() async {
      await _isar.dayEntrys.put(entry);
    });
  }

  Future<DayEntry?> getEntry(String kategorie, String event, String datum) async {
    return await _isar.dayEntrys
        .filter()
        .kategorieEqualTo(kategorie)
        .eventEqualTo(event)
        .datumEqualTo(datum)
        .findFirst();
  }

  Future<void> deleteEntry(String kategorie, String event, String datum) async {
    final entry = await getEntry(kategorie, event, datum);
    if (entry == null) return;
    await _isar.writeTxn(() async {
      await _isar.dayEntrys.delete(entry.id);
    });
  }

  Future<void> deleteImage(String kategorie, String event, String datum, String imagePath) async {
    final entry = await getEntry(kategorie, event, datum);
    if (entry == null) return;

    entry.imagePaths.remove(imagePath);

    final hasNote = entry.note.trim().isNotEmpty;
    final hasTitle = entry.title.trim().isNotEmpty;
    final hasImages = entry.imagePaths.isNotEmpty;

    await _isar.writeTxn(() async {
      if (!hasTitle && !hasNote && !hasImages) {
        await _isar.dayEntrys.delete(entry.id);
      } else {
        await _isar.dayEntrys.put(entry);
      }
    });
  }

  Future<void> updateNote(String kategorie, String event, String datum, String note) async {
    final entry = await getEntry(kategorie, event, datum);
    if (entry == null) return;

    entry.note = note;

    final hasTitle = entry.title.trim().isNotEmpty;
    final hasNote  = entry.note.trim().isNotEmpty;
    final hasImages = entry.imagePaths.isNotEmpty;

    await _isar.writeTxn(() async {
      if (!hasTitle && !hasNote && !hasImages) {
        await _isar.dayEntrys.delete(entry.id);
      } else {
        await _isar.dayEntrys.put(entry);
      }
    });
  }

 

  final Map<String, Map<String, DayEntry>> allEntries = {};

  Future<void> deleteEvent(String kategorie, String eventName) async {
    // Aus Cache löschen
    final katMap = allEntries[kategorie];
    if (katMap != null) {
      katMap.remove(eventName);
    }

    // Aus Datenbank löschen
    await _isar.writeTxn(() async {
      await _isar.dayEntrys
          .filter()
          .kategorieEqualTo(kategorie)
          .eventEqualTo(eventName)
          .deleteAll();
    });
  }



  // ---------- Streams ----------

  Stream<List<DayEntry>> watchAll() => _isar.dayEntrys.where().watch(fireImmediately: true);

  Stream<List<DayEntry>> watchByKategorie(String kategorie) =>
      _isar.dayEntrys.filter().kategorieEqualTo(kategorie).watch(fireImmediately: true);

  Stream<List<DayEntry>> watchEntries(String kategorie, String event) =>
      _isar.dayEntrys.filter().kategorieEqualTo(kategorie).eventEqualTo(event).watch(fireImmediately: true);
}
