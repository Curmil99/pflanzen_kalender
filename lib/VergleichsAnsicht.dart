import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../repositories/day_repo.dart';
import '../models/day_entry.dart';
import 'direkt_vergleich_nsicht.dart';
import '../models/Nerv1.dart'; // Vergleichseintrag

enum VergleichsModus {
  relativ,
  datum,
}

class VergleichsAnsicht extends StatefulWidget {
  final String aktuellesEventName;
  final String kategorie;

  // optional: altes API-Feld (relativer Tag seit Start) — backward compatible
  final int? aktuellerTag;

  // optional: neuer Start-Index (Position in der Event-Timeline)
  final int? startIndex;

  final VergleichsModus modus;

  const VergleichsAnsicht({
    super.key,
    required this.aktuellesEventName,
    required this.kategorie,
    this.aktuellerTag,
    this.startIndex,
    this.modus = VergleichsModus.relativ,
  });

  @override
  State<VergleichsAnsicht> createState() => VergleichsAnsichtState();
}

class VergleichsAnsichtState extends State<VergleichsAnsicht> {
  late String hauptEventName; // aktuell steuerndes Event
  late int hauptIndex; // Index in der Timeline des hauptEventName
  late VergleichsModus modus;
  late List<Vergleichseintrag> vergleichseintraege;

  @override
  void initState() {
    super.initState();
    modus = widget.modus;
    hauptEventName = widget.aktuellesEventName;

    // wir berechnen den Start-Index robust — unterstütze sowohl startIndex als auch alten "aktuellerTag"
    hauptIndex = 0;
    _initStartIndex();
    vergleichseintraege = _loadVergleichsdaten();
  }

  void _initStartIndex() {
    final katMap = DayRepo().allEntries[widget.kategorie];
    final currentEventMap = katMap?[hauptEventName];
    if (currentEventMap == null) {
      hauptIndex = 0;
      return;
    }

    final hauptDates = currentEventMap.keys
        .map((k) => DateTime.tryParse(k))
        .whereType<DateTime>()
        .toList()
      ..sort();

    if (hauptDates.isEmpty) {
      hauptIndex = 0;
      return;
    }

    if (widget.startIndex != null) {
      hauptIndex = widget.startIndex!.clamp(0, hauptDates.length - 1);
      return;
    }

    if (widget.aktuellerTag != null) {
      // altes Verhalten: aktuellerTag ist "Tage seit Start" — finde den nächsten Eintrag in der Timeline
      final start = _getStartDatum(currentEventMap);
      if (start != null) {
        final target = start.add(Duration(days: widget.aktuellerTag!));
        hauptIndex = _findClosestIndex(hauptDates, target);
        return;
      }
    }

    // default 0
    hauptIndex = 0;
  }

  String _formatDateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int _findClosestIndex(List<DateTime> dates, DateTime target) {
    if (dates.isEmpty) return 0;
    int bestIdx = 0;
    int bestDiff = (dates[0].difference(target).inDays).abs();
    for (int i = 1; i < dates.length; i++) {
      final diff = (dates[i].difference(target).inDays).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Abstand Tag/Monat ignoriert Jahr (für datum-Modus)
  int _dayMonthDiff(DateTime a, DateTime b) {
    final dayOfYearA = DateTime(a.year, a.month, a.day)
        .difference(DateTime(a.year, 1, 1))
        .inDays;
    final dayOfYearB = DateTime(b.year, b.month, b.day)
        .difference(DateTime(b.year, 1, 1))
        .inDays;
    int diff = (dayOfYearA - dayOfYearB).abs();
    return diff > 182 ? 365 - diff : diff;
  }

  DayEntry? _findClosestEntry(Map<String, DayEntry> dateMap, DateTime target) {
    DayEntry? closest;
    int minDiff = 1 << 30;
    dateMap.forEach((key, entry) {
      final d = DateTime.tryParse(key);
      if (d == null) return;
      final diff = (d.difference(target).inDays).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = entry;
      }
    });
    return closest;
  }

  DayEntry? _findClosestEntryByDayMonth(
      Map<String, DayEntry> dateMap, DateTime target) {
    DayEntry? closest;
    int minDiff = 1 << 30;
    dateMap.forEach((key, entry) {
      final d = DateTime.tryParse(key);
      if (d == null) return;
      final diff = _dayMonthDiff(d, target);
      if (diff < minDiff) {
        minDiff = diff;
        closest = entry;
      }
    });
    return closest;
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

  // Wenn es keinen echten Eintrag gibt, erzeugen wir einen Platzhalter (keine Bilder),
  // damit Events nicht verschwinden.
  DayEntry _makePlaceholderEntry(String eventName, DateTime date) {
    return DayEntry(
      kategorie: widget.kategorie,
      event: eventName,
      datum: _formatDateKey(date),
      title: '',
      note: '',
      imagePaths: [],
    );
  }

  List<Vergleichseintrag> _loadVergleichsdaten() {
    final Map<String, Map<String, DayEntry>>? katMap =
        DayRepo().allEntries[widget.kategorie];
    if (katMap == null) return [];

    final currentEventMap = katMap[hauptEventName];
    if (currentEventMap == null) return [];

    // Hauptevent-Daten (sortiert)
    final hauptDates = currentEventMap.keys
        .map((k) => DateTime.tryParse(k))
        .whereType<DateTime>()
        .toList()
      ..sort();

    if (hauptDates.isEmpty) return [];

    // Sicherstellen, dass hauptIndex gültig ist
    if (hauptIndex < 0) hauptIndex = 0;
    if (hauptIndex >= hauptDates.length) hauptIndex = hauptDates.length - 1;

    // Datum, das der hauptIndex repräsentiert
    final DateTime hauptDatum = hauptDates[hauptIndex];
    final String hauptDatumKey = _formatDateKey(hauptDatum);

    // Startdatum des Hauptevents (für relativen Modus)
    final DateTime? hauptStart = _getStartDatum(currentEventMap);

    // Für relativen Modus: berechne "Days since start" basierend auf hauptDatum
    final int hauptRelativeDays =
        (hauptStart != null) ? hauptDatum.difference(hauptStart).inDays : 0;

    final List<Vergleichseintrag> result = [];

    // 1) Hauptevent hinzufügen (wir wissen: hauptDatum existiert in currentEventMap)
    final DayEntry? hauptEntry = currentEventMap[hauptDatumKey];
    if (hauptEntry != null) {
      result.add(Vergleichseintrag(
        eventName: hauptEventName,
        tag: hauptRelativeDays,
        eintrag: hauptEntry,
      ));
    } else {
      // falls aus irgendeinem Grund key nicht vorhanden (sehr selten), füge Platzhalter
      result.add(Vergleichseintrag(
        eventName: hauptEventName,
        tag: hauptRelativeDays,
        eintrag: _makePlaceholderEntry(hauptEventName, hauptDatum),
      ));
    }

    // 2) Nebenevents: für jedes Event einen passenden Eintrag (oder Platzhalter)
    final List<Vergleichseintrag> andere = [];
    katMap.forEach((event, dateMap) {
      if (event == hauptEventName) return;

      final startDatum = _getStartDatum(dateMap);
      if (startDatum == null) {
        // kein Startdatum => ignorieren (keine Einträge)
        return;
      }

      DayEntry? chosen;
      int relativeTag = 0;

      if (modus == VergleichsModus.relativ) {
        // Wir benutzen die "relative days" vom hauptEvent und suchen das Datum im anderen Event,
        // das diesem relativen Tag entspricht (startDatum.other + hauptRelativeDays) und nehmen den nächsten Eintrag.
        final zielDatum = startDatum.add(Duration(days: hauptRelativeDays));
        chosen = _findClosestEntry(dateMap, zielDatum);

        if (chosen != null) {
          final entryDatum = DateTime.tryParse(chosen.datum);
          if (entryDatum != null) {
            relativeTag = entryDatum.difference(startDatum).inDays;
          }
        } else {
          // Kein nächster Eintrag: Erzeuge Platzhalter mit genauem zielDatum (sodass Tag korrekt angezeigt wird)
          relativeTag = hauptRelativeDays;
          chosen = _makePlaceholderEntry(event, zielDatum);
        }
      } else {
        // datum-Modus: wir haben ein hauptDatum (Tag+Monat relevant). Suche das entry im Jahreskreis.
        chosen = _findClosestEntryByDayMonth(dateMap, hauptDatum);
        if (chosen != null) {
          final entryDatum = DateTime.tryParse(chosen.datum);
          if (entryDatum != null) {
            relativeTag = entryDatum.difference(startDatum).inDays;
          }
        } else {
          // kein passender Eintrag gefunden -> placeholder: wähle das hauptDatum aber im Jahr des startDatum
          // (besser als nichts; Tag-Anzeige basiert trotzdem auf Tage-seit-Start)
          final assumed = DateTime(startDatum.year, hauptDatum.month, hauptDatum.day);
          relativeTag = assumed.difference(startDatum).inDays;
          chosen = _makePlaceholderEntry(event, assumed);
        }
      }

      andere.add(Vergleichseintrag(
        eventName: event,
        tag: relativeTag,
        eintrag: chosen,
      ));
    });

    // Optional: andere Events nach tag sortieren (klein → groß), Hauptevent bleibt oben
    andere.sort((a, b) => a.tag.compareTo(b.tag));
    result.addAll(andere);

    return result;
  }

  // Klick / Pfeil Handler: verschiebt Index oder macht das geklickte Event zum neuen HauptEvent
  void _onArrowPressed(bool forward, Vergleichseintrag eintrag) {
    // Wenn auf dem bereits aktiven Event geklickt wird, verschieben wir nur den hauptIndex.
    if (eintrag.eventName == hauptEventName) {
      final katMap = DayRepo().allEntries[widget.kategorie];
      final dateMap = katMap?[hauptEventName];
      if (dateMap == null) return;

      final dates = dateMap.keys
          .map((k) => DateTime.tryParse(k))
          .whereType<DateTime>()
          .toList()
        ..sort();

      if (forward && hauptIndex < dates.length - 1) {
        setState(() {
          hauptIndex++;
          vergleichseintraege = _loadVergleichsdaten();
        });
      } else if (!forward && hauptIndex > 0) {
        setState(() {
          hauptIndex--;
          vergleichseintraege = _loadVergleichsdaten();
        });
      }
      return;
    }

    // Klick auf Nebenevent: mache es zum neuen hauptEvent UND verschiebe seinen Index entsprechend
    final katMap = DayRepo().allEntries[widget.kategorie];
    final dateMap = katMap?[eintrag.eventName];
    if (dateMap == null) return;

    final dates = dateMap.keys
        .map((k) => DateTime.tryParse(k))
        .whereType<DateTime>()
        .toList()
      ..sort();

    if (dates.isEmpty) return;

    // Finde Index des aktuell angezeigten Eintrags in diesem Event (falls placeholder, match per datum-string)
    DateTime? currentDate;
    final parsed = DateTime.tryParse(eintrag.eintrag.datum);
    if (parsed != null) {
      currentDate = parsed;
    } else {
      // fallback: parse key trying basic format
      try {
        final parts = eintrag.eintrag.datum.split('-');
        if (parts.length >= 3) {
          currentDate = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {
        currentDate = null;
      }
    }
    int idx = -1;
    if (currentDate != null) {
      idx = dates.indexWhere((d) => _isSameDay(d, currentDate!));
      if (idx == -1) {
        idx = _findClosestIndex(dates, currentDate);
      }
    } else {
      idx = 0;
    }

    int newIdx = idx;
    if (forward) {
      if (idx < dates.length - 1) newIdx = idx + 1;
    } else {
      if (idx > 0) newIdx = idx - 1;
    }

    setState(() {
      hauptEventName = eintrag.eventName;
      hauptIndex = newIdx.clamp(0, max(0, dates.length - 1));
      vergleichseintraege = _loadVergleichsdaten();
    });
  }

  // Klick auf ein Event-Header: mache dieses Event zum Hauptevent (Index auf die passende Position)
  void _onMakeEventMain(Vergleichseintrag eintrag) {
    final katMap = DayRepo().allEntries[widget.kategorie];
    final dateMap = katMap?[eintrag.eventName];
    if (dateMap == null) return;

    final dates = dateMap.keys
        .map((k) => DateTime.tryParse(k))
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (dates.isEmpty) return;

    // finde Index des dargestellten Eintrags in diesem Event
    DateTime? entryDate = DateTime.tryParse(eintrag.eintrag.datum);
    int idx = 0;
    if (entryDate != null) {
      final found = dates.indexWhere((d) => _isSameDay(d, entryDate));
      idx = found == -1 ? _findClosestIndex(dates, entryDate) : found;
    }

    setState(() {
      hauptEventName = eintrag.eventName;
      hauptIndex = idx.clamp(0, dates.length - 1);
      vergleichseintraege = _loadVergleichsdaten();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vergleichsansicht'),
        backgroundColor: Colors.green[800],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        modus = VergleichsModus.relativ;
                        vergleichseintraege = _loadVergleichsdaten();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_right, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        modus = VergleichsModus.datum;
                        vergleichseintraege = _loadVergleichsdaten();
                      });
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Aktueller Modus: ${modus == VergleichsModus.relativ ? "Relativ" : "Datum"}',
                  style: const TextStyle(color: Colors.white70),
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

          return GestureDetector(
            onTap: () {
              if (eintrag.eventName != hauptEventName) {
                _onMakeEventMain(eintrag);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: EventName + Tag (Tap macht Event zum Haupt-Event)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        eintrag.eventName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text('Tag ${eintrag.tag + 1}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Titel + Pfeile (Pfeile bei jedem Event sichtbar; Klick macht Event zum Hauptevent und bewegt Index)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left),
                        onPressed: () => _onArrowPressed(false, eintrag),
                      ),
                      Expanded(
                        child: Text(
                          eintrag.eintrag.title.isNotEmpty
                              ? eintrag.eintrag.title
                              : 'Ohne Titel',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_right),
                        onPressed: () => _onArrowPressed(true, eintrag),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Bilder (können leer sein, wenn placeholder)
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
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (vergleichseintraege.length < 2) return;
          final Vergleichseintrag aktueller = vergleichseintraege.first;
          final List<Vergleichseintrag> vergleichsEintraege =
              vergleichseintraege
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
        child: const Icon(Icons.compare_arrows),
      ),
    );
  }
}
