// lib/models/day_entry.dart
// Modell für einen einzelnen Tag mit Titel, Notiz und Bildpfaden
class DayEntry {
  final String kategorie;
  final String event;
  final String datum; // z.B. "2025-07-02"
  String title;
  String note;
  List<String> imagePaths;

  DayEntry({
    required this.kategorie,
    required this.event,
    required this.datum,
    this.title = '',
    this.note = '',
    this.imagePaths = const [],
  });
}
