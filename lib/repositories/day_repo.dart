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
    _storage[kat]?[event]?.remove(datum);          // Tag rauswerfen
    if (_storage[kat]?[event]?.isEmpty ?? false) { // Event leer? -> löschen
      _storage[kat]?.remove(event);
    }
  }


  // Ein Bild von einem Eintrag löschen
  void deleteImage(String kategorie, String event, String datum, String imagePath) {
    _storage[kategorie]?[event]?[datum]?.imagePaths.remove(imagePath);
  }

  // Alle Einträge (für Kalenderansicht, z.B. alle Events und Kategorien)
  Map<String, Map<String, Map<String, DayEntry>>> get allEntries => _storage;
}
