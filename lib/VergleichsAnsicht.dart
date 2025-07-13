import 'dart:io'; // Ganz oben
import 'package:flutter/material.dart';
import '../repositories/day_repo.dart';
import '../models/day_entry.dart';

class VergleichsAnsicht extends StatefulWidget {
  final String aktuellesEventName;
  final String kategorie;
  final int aktuellerTag;

  const VergleichsAnsicht({
    super.key,
    required this.aktuellesEventName,
    required this.kategorie,
    required this.aktuellerTag,
  });

  @override
  State<VergleichsAnsicht> createState() => _VergleichsAnsichtState();
}

// Diese Funktion sucht den Eintrag, der dem Ziel-Datum am nächsten ist
DayEntry? _findClosestEntry(Map<String, DayEntry> dateMap, DateTime target) {
  DayEntry? closest;
  int minDiff = 999999;

  dateMap.forEach((key, entry) {
    final d = DateTime.tryParse(key);
    if (d == null) return;
    final diff = (d.difference(target).inDays).abs();
    if (diff < minDiff) {
      closest = entry;
      minDiff = diff;
    }
  });

  return closest;
}


class _VergleichsAnsichtState extends State<VergleichsAnsicht> {
  late List<_Vergleichseintrag> _vergleichseintraege;

  @override
  void initState() {
    super.initState();
    _vergleichseintraege = _loadVergleichsdaten();
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<_Vergleichseintrag> _loadVergleichsdaten() {
    final Map<String, Map<String, DayEntry>>? katMap =
        DayRepo().allEntries[widget.kategorie];

    if (katMap == null) return [];

    final List<_Vergleichseintrag> result = [];

    final currentEventMap = katMap[widget.aktuellesEventName];
    if (currentEventMap == null) return [];

    final startDatumAktuell = _getStartDatum(currentEventMap);
    if (startDatumAktuell == null) return [];

    final zielDatumAktuell = startDatumAktuell.add(Duration(days: widget.aktuellerTag));
    final eintragAktuell = currentEventMap[_dateKey(zielDatumAktuell)];

    if (eintragAktuell != null && eintragAktuell.imagePaths.isNotEmpty) {
      result.add(_Vergleichseintrag(
        eventName: widget.aktuellesEventName,
        tag: widget.aktuellerTag,
        eintrag: eintragAktuell,
      ));
    }

    katMap.forEach((event, dateMap) {
      if (event == widget.aktuellesEventName) return;

      final startDatum = _getStartDatum(dateMap);
      if (startDatum == null) return;

      final zielDatum = startDatum.add(Duration(days: widget.aktuellerTag));
      final closestEntry = _findClosestEntry(dateMap, zielDatum);

      if (closestEntry != null && closestEntry.imagePaths.isNotEmpty) {
        // Berechne den Tag des closestEntry relativ zum Startdatum dieses Events
        final entryDatum = DateTime.tryParse(closestEntry.datum);
        int relativeTag = 0;
        if (entryDatum != null) {
          relativeTag = entryDatum.difference(startDatum).inDays;
        }

        result.add(_Vergleichseintrag(
          eventName: event,
          tag: relativeTag,  // hier den korrekten Tag setzen
          eintrag: closestEntry,
        ));
      }
    });



    result.sort((a, b) => a.tag.compareTo(b.tag));
    return result;
  }

  DateTime? _getStartDatum(Map<String, DayEntry> dateMap) {
    final dates = dateMap.keys
        .map((k) => DateTime.tryParse(k))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vergleichsansicht')),
      body: ListView.builder(
        itemCount: _vergleichseintraege.length,
        itemBuilder: (_, index) {
          final eintrag = _vergleichseintraege[index];
          return ListTile(
            title: Text('${eintrag.eventName} (Tag ${eintrag.tag + 1})'),
            subtitle: Text(eintrag.eintrag.title),
            trailing: eintrag.eintrag.imagePaths.isNotEmpty
                ? Image.file(
                    File(eintrag.eintrag.imagePaths.first),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _Vergleichseintrag {
  final String eventName;
  final DayEntry eintrag;
  final int tag;

  _Vergleichseintrag({
    required this.eventName,
    required this.eintrag,
    required this.tag,
  });
}
