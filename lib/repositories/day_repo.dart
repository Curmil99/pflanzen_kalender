import 'package:isar/isar.dart';
import '../models/day_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DayRepo {
  static final DayRepo _instance = DayRepo._internal();
  factory DayRepo() => _instance;
  DayRepo._internal();

  late final Isar _isar;
  late final SharedPreferences _prefs;
  Map<String, List<String>> _eventStore = {};
  List<String> _kategorien = [];
  Map<String, int> _kategorieIcons = {};
  static const String _kategorieKey = 'kategorien';
  static const String _kategorieIconsKey = 'kategorie_icons';

  /// Muss vor Nutzung einmal aufgerufen werden
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [DayEntrySchema],
      directory: dir.path,
    );
    _prefs = await SharedPreferences.getInstance();
    _eventStore = _loadEvents();
    _kategorien = _loadKategorien();
    _kategorieIcons = _loadKategorienIcons();
  }

  Map<String, int> _loadKategorienIcons() {
    final jsonStr = _prefs.getString(_kategorieIconsKey);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    final Map<String, dynamic> map = jsonDecode(jsonStr);
    return map.map((k, v) => MapEntry(k, v as int));
  }

  Future<void> _saveKategorienIcons() async {
    final jsonStr = jsonEncode(_kategorieIcons);
    await _prefs.setString(_kategorieIconsKey, jsonStr);
  }

  Map<String, List<String>> _loadEvents() {
    final json = _prefs.getString('events') ?? '{"Pflanzen":["2023","2024","2025"],"Kinder":["2021","2022"],"Sonstiges":["Test"]}';
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, List<String>.from(v)));
  }

  Future<void> _saveEvents() async {
    final json = jsonEncode(_eventStore);
    await _prefs.setString('events', json);
  }

  List<String> getEvents(String kategorie) => _eventStore[kategorie] ?? [];

  Future<void> addEvent(String kategorie, String event) async {
    _eventStore.putIfAbsent(kategorie, () => []).add(event);
    await _saveEvents();
  }

  List<String> _loadKategorien() {
    final list = _prefs.getStringList(_kategorieKey);
    if (list == null || list.isEmpty) {
      return ['Pflanzen', 'Kinder', 'Sonstiges'];
    }
    return List<String>.from(list);
  }

  Future<void> _saveKategorien() async {
    await _prefs.setStringList(_kategorieKey, _kategorien);
  }

  List<String> getKategorien() => List.unmodifiable(_kategorien);

  Future<bool> addKategorie(String kategorie) async {
    if (_kategorien.contains(kategorie)) return false;
    _kategorien.add(kategorie);
    await _saveKategorien();
    return true;
  }

  int? getKategorieIcon(String kategorie) => _kategorieIcons[kategorie];

  Future<void> setKategorieIcon(String kategorie, int codePoint) async {
    _kategorieIcons[kategorie] = codePoint;
    await _saveKategorienIcons();
  }

  /// Versucht, eine Kategorie umzubenennen. Liefert false, wenn der neue Name
  /// bereits existiert oder leer ist.
  Future<bool> renameKategorie(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    if (oldName == trimmed) return true; // nichts zu tun
    if (_kategorien.contains(trimmed)) return false; // Konflikt

    // 1) Liste aktualisieren
    final index = _kategorien.indexOf(oldName);
    if (index != -1) {
      _kategorien[index] = trimmed;
      await _saveKategorien();
    }

    // 2) Events-Mapping migrieren
    if (_eventStore.containsKey(oldName)) {
      final events = _eventStore.remove(oldName)!;
      _eventStore[trimmed] = events;
      await _saveEvents();
    }

    // 3) Icon mapping migrieren
    if (_kategorieIcons.containsKey(oldName)) {
      final icon = _kategorieIcons.remove(oldName)!;
      _kategorieIcons[trimmed] = icon;
      await _saveKategorienIcons();
    }

    // 4) Datenbank-Einträge anpassen
    await _isar.writeTxn(() async {
      final entries = await _isar.dayEntrys.filter().kategorieEqualTo(oldName).findAll();
      for (final e in entries) {
        e.kategorie = trimmed;
      }
      if (entries.isNotEmpty) await _isar.dayEntrys.putAll(entries);
    });

    return true;
  }

  Future<void> removeEvent(String kategorie, String event) async {
    _eventStore[kategorie]?.remove(event);
    await _saveEvents();
  }

  // ---------- CRUD ----------

  Future<void> saveEntry(DayEntry entry) async {
    final hasTitle  = entry.title.trim().isNotEmpty;
    final hasNote   = entry.note.trim().isNotEmpty;
    final hasImages = entry.imagePaths.isNotEmpty;

    await _isar.writeTxn(() async {
      if (!hasTitle && !hasNote && !hasImages) {
        // Falls der Eintrag komplett leer ist -> löschen
        await _isar.dayEntrys
            .filter()
            .kategorieEqualTo(entry.kategorie)
            .eventEqualTo(entry.event)
            .datumEqualTo(entry.datum)
            .deleteAll();
      } else {
        // Ansonsten speichern
        await _isar.dayEntrys.put(entry);
      }
    });
  }

  Future<void> deleteEntry(String kategorie, String event, String datum) async {
    await _isar.writeTxn(() async {
      await _isar.dayEntrys
          .filter()
          .kategorieEqualTo(kategorie)
          .eventEqualTo(event)
          .datumEqualTo(datum)
          .deleteAll();
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
    // Events aus Speicher entfernen
    await removeEvent(kategorie, eventName);

    // Aus Datenbank löschen
    await _isar.writeTxn(() async {
      await _isar.dayEntrys
          .filter()
          .kategorieEqualTo(kategorie)
          .eventEqualTo(eventName)
          .deleteAll();
    });
  }

  /// Versucht, ein Event innerhalb einer Kategorie umzubenennen.
  /// Liefert false, wenn der neue Name leer ist oder bereits existiert.
  Future<bool> renameEvent(String kategorie, String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    if (oldName == trimmed) return true;

    final events = _eventStore[kategorie] ?? [];
    if (events.contains(trimmed)) return false; // Konflikt

    // 1) Event-Liste aktualisieren
    final idx = events.indexOf(oldName);
    if (idx != -1) {
      events[idx] = trimmed;
      _eventStore[kategorie] = events;
      await _saveEvents();
    }

    // 2) Datenbank-Einträge anpassen
    await _isar.writeTxn(() async {
      final entries = await _isar.dayEntrys.filter().kategorieEqualTo(kategorie).eventEqualTo(oldName).findAll();
      for (final e in entries) {
        e.event = trimmed;
      }
      if (entries.isNotEmpty) await _isar.dayEntrys.putAll(entries);
    });

    return true;
  }

  Future<void> deleteKategorie(String kategorie) async {
    _kategorien.remove(kategorie);
    await _saveKategorien();

    await _isar.writeTxn(() async {
      await _isar.dayEntrys
          .filter()
          .kategorieEqualTo(kategorie)
          .deleteAll();
    });
  }



  // ---------- Streams ----------

  Stream<List<DayEntry>> watchAll() => _isar.dayEntrys.where().watch(fireImmediately: true);

  Stream<List<DayEntry>> watchByKategorie(String kategorie) =>
      _isar.dayEntrys.filter().kategorieEqualTo(kategorie).watch(fireImmediately: true);

  Stream<List<DayEntry>> watchEntries(String kategorie, String event) =>
      _isar.dayEntrys.filter().kategorieEqualTo(kategorie).eventEqualTo(event).watch(fireImmediately: true);
  
  Stream<DayEntry?> watchEntry(String kategorie, String event, String datum) {
    return _isar.dayEntrys
        .filter()
        .kategorieEqualTo(kategorie)
        .eventEqualTo(event)
        .datumEqualTo(datum)
        .watch(fireImmediately: true)
        .map((list) => list.isNotEmpty ? list.first : null);
  }
}
