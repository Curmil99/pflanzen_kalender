import 'package:isar/isar.dart';

part 'day_entry.g.dart';

@collection
class DayEntry {
  Id id = Isar.autoIncrement; // Automatische ID

  late String kategorie;
  late String event;
  late String datum;

  String title = '';
  String note = '';

  List<String> imagePaths = [];

  DayEntry({
    required this.kategorie,
    required this.event,
    required this.datum,
    this.title = '',
    this.note = '',
    this.imagePaths = const [],
    
  });
}
