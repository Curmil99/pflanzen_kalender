// lib/repositories/day_repo.dart
// Singleton, das alle DayEntry-Objekte während der App-Laufzeit im RAM hält
import '../models/day_entry.dart';

class DayRepo {
  static final DayRepo _instance = DayRepo._internal();

  factory DayRepo() {
    return _instance;
  }

  DayRepo._internal();

  final Map<String, Map<String, Map<String, DayEntry>>> _storage = {};
  // _storage[kategorie][event][datum] = DayEntry

  DayEntry? getEntry(String kategorie, String event, String datum) {
    return _storage[kategorie]?[event]?[datum];
  }

  void saveEntry(String kategorie, String event, String datum, DayEntry entry) {
    _storage.putIfAbsent(kategorie, () => {});
    _storage[kategorie]!.putIfAbsent(event, () => {});
    _storage[kategorie]![event]![datum] = entry;
  }

  void deleteEntry(String kat, String event, String datum) {
    _storage[kat]?[event]?.remove(datum);
    if (_storage[kat]?[event]?.isEmpty ?? false) {
      _storage[kat]?.remove(event);
    }
  }

  void deleteImage(String kategorie, String event, String datum, String imagePath) {
    final entry = _storage[kategorie]?[event]?[datum];
    if (entry == null) return;

    entry.imagePaths.remove(imagePath);
     // Prüfen, ob noch Inhalt da ist
    final hasNote = entry.note.trim().isNotEmpty;
    if (entry.imagePaths.isEmpty && !hasNote) {
      deleteEntry(kategorie, event, datum);
  }

  // Kalender aktualisieren
  // setState muss in der Widget-Klasse aufgerufen werden, nicht hier
}

  void updateNote(String kategorie, String event, String datum, String note) {
    final entry = _storage[kategorie]?[event]?[datum];
    if (entry == null) return;

    entry.note = note;
    _cleanupEntryIfEmpty(kategorie, event, datum);
  }

  // Hilfsfunktion: löscht leeren Eintrag
  void _cleanupEntryIfEmpty(String kategorie, String event, String datum) {
    final entry = _storage[kategorie]?[event]?[datum];
    if (entry == null) return;

    final hasTitle = entry.title.trim().isNotEmpty;
    final hasNote  = entry.note.trim().isNotEmpty;
    final hasImages = entry.imagePaths.isNotEmpty;

    if (!hasTitle && !hasNote && !hasImages) {
      deleteEntry(kategorie, event, datum);
    }
  }



  // **Wiederhergestellter Getter, damit alte Dateien funktionieren**
  Map<String, Map<String, Map<String, DayEntry>>> get allEntries => _storage;
}
