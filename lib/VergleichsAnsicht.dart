import 'dart:io'; // Ganz oben
import 'package:flutter/material.dart';
import '../repositories/day_repo.dart';
import '../models/day_entry.dart';
import 'direkt_vergleich_nsicht.dart';
import '../models/Nerv1.dart'; // Importiere dein Vergleichseintrag Modell




enum VergleichsModus {
  relativ,
  datum,
}



class VergleichsAnsicht extends StatefulWidget {
  final String aktuellesEventName;
  final String kategorie;
  final int aktuellerTag;

    // NEU: Modus
  final VergleichsModus modus;

  const VergleichsAnsicht({
    super.key,
    required this.aktuellesEventName,
    required this.kategorie,
    required this.aktuellerTag,
    this.modus = VergleichsModus.relativ, // Default ist relativer Modus
  });

  @override
  State<VergleichsAnsicht> createState() => VergleichsAnsichtState();
}


/// Hilfsfunktion: Abstand zwischen zwei Daten nur nach Tag+Monat, Jahr wird ignoriert
int _dayMonthDiff(DateTime a, DateTime b) {
  final dayOfYearA = DateTime(a.year, a.month, a.day).difference(DateTime(a.year, 1, 1)).inDays;
  final dayOfYearB = DateTime(b.year, b.month, b.day).difference(DateTime(b.year, 1, 1)).inDays;

  int diff = (dayOfYearA - dayOfYearB).abs();

  // Weil das Jahr zyklisch ist, den kürzeren Weg nehmen (z. B. 30.12 ↔ 02.01 = 3 Tage, nicht 363)
  return diff > 182 ? 365 - diff : diff;
}

/// Sucht das Datum in dateMap, das im Jahreskreis am nächsten zu target liegt (Jahr ignoriert)
DayEntry? _findClosestEntryByDayMonth(Map<String, DayEntry> dateMap, DateTime target) {
  DayEntry? closest;
  int minDiff = 9999;

  dateMap.forEach((key, entry) {
    final d = DateTime.tryParse(key);
    if (d == null) return;
    final diff = _dayMonthDiff(d, target);
    if (diff < minDiff) {
      closest = entry;
      minDiff = diff;
    }
  });

  return closest;
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


class VergleichsAnsichtState extends State<VergleichsAnsicht> {
  late List<Vergleichseintrag> vergleichseintraege;
  VergleichsModus modus = VergleichsModus.relativ; // Startmodus

  @override
  void initState() {
    super.initState();
    vergleichseintraege = _loadVergleichsdaten();
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Vergleichseintrag> _loadVergleichsdaten() {
    final Map<String, Map<String, DayEntry>>? katMap =
        DayRepo().allEntries[widget.kategorie];

    if (katMap == null) return [];

    final List<Vergleichseintrag> result = [];

    final currentEventMap = katMap[widget.aktuellesEventName];
    if (currentEventMap == null) return [];

    final startDatumAktuell = _getStartDatum(currentEventMap);
    if (startDatumAktuell == null) return [];

    final zielDatumAktuell = startDatumAktuell.add(Duration(days: widget.aktuellerTag));
    final eintragAktuell = currentEventMap[_dateKey(zielDatumAktuell)];

    if (eintragAktuell != null && eintragAktuell.imagePaths.isNotEmpty) {
      result.add(Vergleichseintrag(
        eventName: widget.aktuellesEventName,
        tag: widget.aktuellerTag,
        eintrag: eintragAktuell,
      ));

    }

    katMap.forEach((event, dateMap) {
      if (event == widget.aktuellesEventName) return;

      final startDatum = _getStartDatum(dateMap);
      if (startDatum == null) return;

      DayEntry? closestEntry;
      int relativeTag = 0;

      if (modus == VergleichsModus.relativ) {
        // wie bisher: Tag relativ zum Event berechnen
        final zielDatum = startDatum.add(Duration(days: widget.aktuellerTag));
        closestEntry = _findClosestEntry(dateMap, zielDatum);

        if (closestEntry != null) {
          final entryDatum = DateTime.tryParse(closestEntry.datum);
          if (entryDatum != null) {
            relativeTag = entryDatum.difference(startDatum).inDays;
          }
        }
      } else {
        // datum-Modus: wähle den Eintrag, der dem gleichen Kalendertag wie aktuelles Event entspricht
        DateTime target = zielDatumAktuell;
        closestEntry = _findClosestEntryByDayMonth(dateMap, target);

        if (closestEntry != null) {
          final entryDatum = DateTime.tryParse(closestEntry.datum);
          if (entryDatum != null) {
            relativeTag = entryDatum.difference(startDatum).inDays;
          }
        }
      }

      if (closestEntry != null && closestEntry.imagePaths.isNotEmpty) {
        result.add(Vergleichseintrag(
          eventName: event,
          tag: relativeTag,
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
      appBar: AppBar(
        title: const Text('Vergleichsansicht'),
        backgroundColor: Colors.green[800], // AppBar dunkler
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Linker Pfeil
                  IconButton(
                    icon: Icon(Icons.arrow_left, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        modus = VergleichsModus.relativ;
                        vergleichseintraege = _loadVergleichsdaten();
                      });
                    },
                  ),

                  // Rechter Pfeil
                  IconButton(
                    icon: Icon(Icons.arrow_right, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        modus = VergleichsModus.datum;
                        vergleichseintraege = _loadVergleichsdaten();
                      });
                    },
                  ),
                ],
              ),
              // Anzeige des aktuellen Modus
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Aktueller Modus: ${modus == VergleichsModus.relativ ? "Relativ" : "Datum"}',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: vergleichseintraege.length,
        itemBuilder: (_, index) {
          final eintrag = vergleichseintraege[index];
          return Padding(   //Der Padding Teil ist für die Ansicht da (also Event Name, Tag und Bilder) und auch, dass die Bilder Scoollbar sind
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // EventName + Tag in einer Zeile
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      eintrag.eventName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text('Tag ${eintrag.tag + 1}'),
                  ],
                ),

                const SizedBox(height: 4),

                // Titel falls gewünscht
                if (eintrag.eintrag.title.isNotEmpty)
                  Text(
                    eintrag.eintrag.title,
                    style: TextStyle(color: Colors.grey[600]),
                  ),

                const SizedBox(height: 8),

                // Bildreihe horizontal scrollbar
                if (eintrag.eintrag.imagePaths.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: eintrag.eintrag.imagePaths.length,
                      itemBuilder: (_, imgIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Image.file(
                            File(eintrag.eintrag.imagePaths[imgIndex]),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (vergleichseintraege.length < 2) return;

          // Schritt 2: Typen explizit angeben
          final Vergleichseintrag aktueller = vergleichseintraege.first;
          final List<Vergleichseintrag> vergleichsEintraege = vergleichseintraege   
            .where((e) => e.eventName != aktueller.eventName)
            .toList();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DirektVergleichAnsicht(
                aktuellerEintrag: aktueller,
                vergleichsEintraege: vergleichsEintraege,
              ),
            ),
          );

        },
        child: Icon(Icons.compare_arrows),
      ),

    );
  }
}

