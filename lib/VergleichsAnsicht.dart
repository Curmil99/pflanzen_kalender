import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../repositories/day_repo.dart';
import '../models/day_entry.dart';
import 'direkt_vergleich_nsicht.dart';
import 'models/vergleichseintrag.dart'; // Vergleichseintrag

enum VergleichsModus { relativ, datum }

enum VergleichsEventModus { solo, group }




class VergleichsAnsicht extends StatefulWidget {
  final String aktuellesEventName;
  final String kategorie;
  final int aktuellerTag;
  final int? startIndex;
  final VergleichsModus modus;  //relativ oder datum
  final VergleichsEventModus eventModus;  //solo oder group
  final String label;
  

  const VergleichsAnsicht({
    super.key,
    required this.aktuellesEventName,
    required this.kategorie,
    required this.aktuellerTag,
    this.startIndex,
    this.modus = VergleichsModus.datum,
    this.eventModus = VergleichsEventModus.group,
    this.label = '',
    
  });

  @override
  State<VergleichsAnsicht> createState() => _VergleichsAnsichtState();
  
}

class _VergleichsAnsichtState extends State<VergleichsAnsicht> {
  late String hauptEventName;
  late int hauptIndex;
  late VergleichsModus modus;
  late VergleichsEventModus eventModus;
  late Future<List<Vergleichseintrag>> vergleichseintraegeFuture;
  int tageIntervall = 365;
  final Set<int> _fixedIDs = {};


  @override
  void initState() {
    super.initState();
    hauptEventName = widget.aktuellesEventName;
    hauptIndex = widget.startIndex ?? widget.aktuellerTag;
    modus = widget.modus;
    eventModus = widget.eventModus;
    
    // erster Aufruf: initialLoad = true
    vergleichseintraegeFuture = _loadVergleichsdaten(initialLoad: true);
  }

  String _formatDateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
  
  DateTime? _getStartDatumFromList(List<DayEntry> entries) {
    if (entries.isEmpty) return null;
    final dates = entries
        .map((e) => DateTime.tryParse(e.datum))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }


  Future<List<Vergleichseintrag>> _loadVergleichsdaten({
    bool initialLoad = false,
    int? intervall,
    List<Vergleichseintrag>? prevResult, // 🆕
  }) async {
    final result = <Vergleichseintrag>[];

    // benutze entweder das übergebene intervall oder den State-Wert
    final int usedIntervall = intervall ?? tageIntervall;

    
    debugPrint('=== _loadVergleichsdaten START ===');
    debugPrint('eventModus=$eventModus, modus=$modus, hauptEventName=$hauptEventName, hauptIndex=$hauptIndex');
    debugPrint('fixed IDs at load start: ${_fixedIDs.toList()}');
    debugPrint('prevResult IDs: ${prevResult?.map((p) => p.eintrag.id).toList()}');

    
    // 1) Hauptevent laden
    final currentEntries = 
      await DayRepo().watchEntries(widget.kategorie, hauptEventName).first;
    
    if (currentEntries.isEmpty) return [];

    // nach Datum sortieren
    currentEntries.sort((a, b) => a.datum.compareTo(b.datum));

    // Index absichern
    if (initialLoad) {
      // Nur beim ersten Laden: berechne Index anhand des relativen Tages
      final hauptStart = _getStartDatumFromList(currentEntries);
      if (hauptStart != null) {
        final targetDate = hauptStart.add(Duration(days: widget.aktuellerTag));
        int idx = currentEntries.indexWhere((e) {
          final d = DateTime.tryParse(e.datum);
          return d != null &&
                d.year == targetDate.year &&
                d.month == targetDate.month &&
                d.day == targetDate.day;
        });
        if (idx == -1) idx = 0; // Fallback
        hauptIndex = idx;
      } else {
        hauptIndex = 0;
      }
    } else {
      // später: einfach aktueller Index behalten
      if (hauptIndex < 0) hauptIndex = 0;
      if (hauptIndex >= currentEntries.length) hauptIndex = currentEntries.length - 1;
    }

    final hauptDatumEntry = currentEntries[hauptIndex];

    

    final hauptDatum = DateTime.tryParse(hauptDatumEntry.datum)!;
    
    // Startdatum des Events (erste vorhandene Aufnahme)
    final hauptStart = _getStartDatumFromList(currentEntries) ?? hauptDatum;

    // Berechne relativen Tag zum Startdatum
    final hauptRelativeDays =hauptDatum.difference(hauptStart).inDays;


    result.add(Vergleichseintrag(
      eventName: hauptEventName,
      tag: eventModus == VergleichsEventModus.solo ? 0 : hauptRelativeDays,
      eintrag: hauptDatumEntry,
      label: eventModus == VergleichsEventModus.solo
          ? '0 Tage'
          : (widget.label.isNotEmpty ? widget.label : hauptEventName),
    ));

    // 🔸 NEU: Ab hier prüfen, ob Solo-Modus aktiv ist
    if (eventModus == VergleichsEventModus.solo) {
      // Nur Einträge dieses Events (aus anderen Jahren)
      currentEntries.sort((a, b) => a.datum.compareTo(b.datum));

      final List<MapEntry<int, DateTime>> zielIntervalle = [];
      int tageIntervallLocal = usedIntervall;
      const int maxIntervalle = 5;
      final hauptDatum = DateTime.tryParse(hauptDatumEntry.datum)!;

      // Wir prüfen Intervalle rückwärts: z.B. 0-365 Tage zurück, 366-730 Tage zurück usw.
      for (int intervalIndex = 1; intervalIndex <= maxIntervalle; intervalIndex++) {
        // Intervall Grenzwerte in Tagen rückwärts
        final DateTime intervallEnd = hauptDatum.subtract(Duration(days: tageIntervallLocal * (intervalIndex - 1)));
        final DateTime intervallStart = hauptDatum.subtract(Duration(days: tageIntervallLocal * intervalIndex));

        // Prüfen, ob es Einträge gibt, die im Intervall [intervallStart, intervallEnd] liegen
        final existsInInterval = currentEntries.any((e) {
          final d = DateTime.tryParse(e.datum);
          if (d == null) return false;
          return !d.isBefore(intervallStart) && !d.isAfter(intervallEnd);
        });

        if (existsInInterval) {
          // Ziel-Datum für Suche merken: bspw. Beginn Intervall (= hauptDatum minus days)
          // Alternativ könnte auch intervallEnd genommen werden, je nachdem, was sinnvoller ist
          zielIntervalle.add(MapEntry(intervalIndex, intervallStart));
        }
      }

      final selectedEntryIds = <int>{hauptDatumEntry.id};

      // 🧊 SOLO: Fixierte Einträge übernehmen, falls sie in currentEntries liegen
      if (_fixedIDs.isNotEmpty) {
        for (final fixedId in _fixedIDs) {
          if (selectedEntryIds.contains(fixedId)) continue;

          final fixedEntry = currentEntries.where((e) => e.id == fixedId).firstOrNull;
          if (fixedEntry != null) {
            final reused = prevResult?.firstWhere(
                  (p) => p.eintrag.id == fixedId,
                  orElse: () => Vergleichseintrag(
                    eventName: hauptEventName,
                    tag: 0,
                    eintrag: fixedEntry,
                    label: 'Fixiert',
                  ),
                ) ??
                Vergleichseintrag(
                  eventName: hauptEventName,
                  tag: 0,
                  eintrag: fixedEntry,
                  label: 'Fixiert',
                );
            debugPrint('[SOLO-FIX] reusing fixed entry id=$fixedId from prevResult (event=$hauptEventName)');
            result.add(reused);
            selectedEntryIds.add(fixedId);
          } else {
            debugPrint('[SOLO-FIX] fixedId=$fixedId not found in currentEntries');
          }
        }
      }

      // Nun in der Schleife für jedes Ziel-Datum den nächstgelegenen Eintrag suchen
      for (final soloInterval in zielIntervalle) {
        final intervalIndex = soloInterval.key;
        final zielDatum = soloInterval.value;

        // Prüfen, ob es schon einen fixierten Eintrag für dieses Intervall gibt
        final hasFixedForInterval = result.any((r) {
          final d = DateTime.tryParse(r.eintrag.datum);
          if (d == null) return false;
          final diffDays = (d.difference(hauptDatum).inDays).abs();
          final intervalStart = tageIntervallLocal * (intervalIndex - 1);
          final intervalEnd = tageIntervallLocal * intervalIndex;
          return _fixedIDs.contains(r.eintrag.id) &&
              diffDays >= intervalStart &&
              diffDays < intervalEnd;
        });

        if (hasFixedForInterval) {
          debugPrint('[SOLO] skipping interval $intervalIndex (${tageIntervallLocal * (intervalIndex - 1)}-${tageIntervallLocal * intervalIndex} Tage), fixed entry exists');
          continue;
        }

        final closest = _findClosestEntryInList(currentEntries, zielDatum, excludeIds: selectedEntryIds);
        if (closest == null) {
          debugPrint('[SOLO] intervalIndex=$intervalIndex -> closest == null, skip');
          continue;
        }

        final d = DateTime.tryParse(closest.datum)!;
        final rel = d.difference(hauptDatum).inDays;
        final candidateId = closest.id;

        if (selectedEntryIds.contains(candidateId)) {
          debugPrint('[SOLO] intervalIndex=$intervalIndex candidateId=$candidateId already selected, skip');
          continue;
        }

        // 🔹 Eindeutiger Eventname für Solo-Vergleiche
        final soloKey = '${hauptEventName}_solo_$intervalIndex';

        debugPrint('[SOLO] intervalIndex=$intervalIndex candidateId=$candidateId soloKey=$soloKey rel=$rel');

        // 🔹 Prüfen, ob fixiert
        Vergleichseintrag? reused;
        if (candidateId != 0 && _fixedIDs.contains(candidateId)) {
          debugPrint('[SOLO] candidateId=$candidateId is FIXED');
          if (prevResult != null) {
            try {
              reused = prevResult.firstWhere((p) => p.eintrag.id == candidateId);
              debugPrint('[SOLO] reused found in prevResult for id=$candidateId (event=${reused.eventName})');
            } catch (e) {
              debugPrint('[SOLO] no reused found in prevResult for id=$candidateId -> will recreate but keep fixed in memory');
              reused = null;
            }
          } else {
            debugPrint('[SOLO] prevResult is null, cannot reuse for id=$candidateId');
          }
        } else {
          debugPrint('[SOLO] candidateId=$candidateId is NOT fixed');
        }

        if (reused != null) {
          // 🧊 Fixierter Eintrag bleibt
          result.add(reused);
          selectedEntryIds.add(candidateId);
          continue;
        }

        // Kein fixierter → neuen Eintrag erzeugen
        final int relativeTag = rel;
        final int intervalLength = tageIntervallLocal;
        final int ideal = ((relativeTag / intervalLength).round()) * intervalLength;
        final int differenz = relativeTag - ideal;
        final String diffString = differenz == 0
            ? ''
            : (differenz > 0 ? ' (+$differenz)' : ' ($differenz)');

        debugPrint('[SOLO] adding new Vergleichseintrag for id=$candidateId with label=$ideal Tage$diffString');

        result.add(Vergleichseintrag(
          eventName: soloKey,
          tag: rel,
          eintrag: closest,
          label: '$ideal Tage$diffString',
        ));
        selectedEntryIds.add(candidateId);
      }
      for (var i = 0; i < result.length; i++) {
        result[i] = Vergleichseintrag(
          eventName: result[i].eventName,
          tag: result[i].tag,
          eintrag: result[i].eintrag,
          label: _berechneLabel(result[i], result, usedIntervall, eventModus),
        );
      }
      return result;
    }







    // 2) Andere Events laden
    final alleEntries = await DayRepo().watchByKategorie(widget.kategorie).first;
  final grouped = <String, List<DayEntry>>{};
  for (var e in alleEntries) {
    grouped.putIfAbsent(e.event, () => []);
    grouped[e.event]!.add(e);
  }

  for (var kv in grouped.entries) {
    if (kv.key == hauptEventName) continue;

    // 🆕 Fixierungsprüfung:
    Vergleichseintrag? prevFixed;
      if (prevResult != null) {
        for (final p in prevResult) {
          if (_fixedIDs.contains(p.eintrag.id) && p.eventName == kv.key) {
            prevFixed = p;
            break;
          }
        }
      }

      if (prevFixed != null) {
        // 🧊 Fixierter Eintrag -> beibehalten
        result.add(prevFixed);
        continue;
      }

      // Normaler Ablauf (nicht fixiert)
      final startDatum = _getStartDatumFromList(kv.value);
      if (startDatum == null) continue;

      kv.value.sort((a, b) => a.datum.compareTo(b.datum));

      DayEntry? chosen;
      int relativeTag = 0;

      if (modus == VergleichsModus.relativ) {
        final zielDatum = startDatum.add(Duration(days: hauptRelativeDays));
        chosen = _findClosestEntryInList(kv.value, zielDatum);
        relativeTag = chosen != null
            ? DateTime.tryParse(chosen.datum)!.difference(startDatum).inDays
            : hauptRelativeDays;
        chosen ??= _makePlaceholderEntry(kv.key, zielDatum);
      } else {
        chosen = _findClosestEntryByDayMonthInList(kv.value, hauptDatum);
        relativeTag = chosen != null
            ? DateTime.tryParse(chosen.datum)!.difference(startDatum).inDays
            : 0;
        chosen ??= _makePlaceholderEntry(kv.key, hauptDatum);
      }

      result.add(Vergleichseintrag(
        eventName: kv.key,
        tag: relativeTag,
        eintrag: chosen,
        label: kv.key,
      ));
    }


    for (var i = 0; i < result.length; i++) {
      result[i] = Vergleichseintrag(
        eventName: result[i].eventName,
        tag: result[i].tag,
        eintrag: result[i].eintrag,
        label: _berechneLabel(result[i], result, usedIntervall, eventModus),
      );
    }

    return result;
  }

  String _berechneLabel(Vergleichseintrag eintrag, List<Vergleichseintrag> alle, int tageIntervall, VergleichsEventModus eventModus) {
    if (eventModus == VergleichsEventModus.solo) {
        final hauptEintrag = alle.firstWhere(
          (e) => e.eventName == hauptEventName,
          orElse: () => alle[0],
        );
        final int relativeTag = eintrag.tag - hauptEintrag.tag;
        return '$relativeTag Tage';
    } else {
      return eintrag.eventName;
    }
  }


  DayEntry? _findClosestEntryInList(List<DayEntry> entries, DateTime target, {Set<int>? excludeIds}) {
    DayEntry? closest;
    int minDiff = 1 << 30;
    for (var e in entries) {
      if (excludeIds?.contains(e.id) == true) continue;
      final d = DateTime.tryParse(e.datum);
      if (d == null) continue;

      final diff = (d.difference(target).inDays).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = e;
      }
    }
    return closest;
  }

  DayEntry? _findClosestEntryByDayMonthInList(List<DayEntry> entries, DateTime target) {
    DayEntry? closest;
    int minDiff = 1 << 30;
    for (var e in entries) {
      final d = DateTime.tryParse(e.datum);
      if (d == null) continue;
      final dayOfYearA = DateTime(d.year, d.month, d.day).difference(DateTime(d.year, 1, 1)).inDays;
      final dayOfYearB = DateTime(target.year, target.month, target.day).difference(DateTime(target.year, 1, 1)).inDays;
      int diff = (dayOfYearA - dayOfYearB).abs();
      if (diff > 182) diff = 365 - diff;
      if (diff < minDiff) {
        minDiff = diff;
        closest = e;
      }
    }
    return closest;
  }

  // 🔹 Teil 3: Anpassung _onArrowPressed()
// Übergibt die aktuelle Liste an _loadVergleichsdaten(prevResult: ...)
void _onArrowPressed(bool forward, Vergleichseintrag eintrag) async {
  // Prüfe, ob es ein künstliches Solo-Event ist (enthält "_solo_")
  if (eintrag.eventName.contains('_solo_')) {
    // Im Solo-Modus: nur den hauptIndex zum aktuellen Eintrag-Datum setzen
    final entries =
        await DayRepo().watchEntries(widget.kategorie, hauptEventName).first;
    if (entries.isEmpty) return;

    entries.sort((a, b) => a.datum.compareTo(b.datum));

    // Finde den Index des aktuellen Eintrags im Hauptevent
    int newIdx = 0;
    final entryDate = DateTime.tryParse(eintrag.eintrag.datum);
    if (entryDate != null) {
      newIdx = entries.indexWhere(
          (e) => _isSameDay(DateTime.tryParse(e.datum)!, entryDate));
      if (newIdx == -1) newIdx = 0;
    }

    final prevResult = await vergleichseintraegeFuture;

    setState(() {
      hauptIndex = newIdx;
      debugPrint('[SOLO-ARROW] jumped to index=$newIdx for date=${eintrag.eintrag.datum} in event=$hauptEventName');
      vergleichseintraegeFuture = _loadVergleichsdaten(prevResult: prevResult);
    });
    return;
  }

  // Im Group-Modus: normales Verhalten (zu anderem Event wechseln)
  final entries =
      await DayRepo().watchEntries(widget.kategorie, eintrag.eventName).first;
  if (entries.isEmpty) return;

  entries.sort((a, b) => a.datum.compareTo(b.datum));

  // aktuelle Vergleichsdaten abrufen, bevor sie überschrieben werden
  final prevResult = await vergleichseintraegeFuture;

  if (eintrag.eventName == hauptEventName) {
    int newIdx =
        forward ? min(hauptIndex + 1, entries.length - 1) : max(hauptIndex - 1, 0);
    setState(() {
      hauptIndex = newIdx;
      debugPrint('--- onArrowPressed ---');
      debugPrint('moving forward=$forward for event=${eintrag.eventName}');
      vergleichseintraegeFuture =
          _loadVergleichsdaten(prevResult: prevResult);
    });
  } else {
    int idx = 0;
    final entryDate = DateTime.tryParse(eintrag.eintrag.datum);
    if (entryDate != null) {
      idx = entries.indexWhere(
          (e) => _isSameDay(DateTime.tryParse(e.datum)!, entryDate));
      if (idx == -1) idx = 0;
    }
    setState(() {
      hauptEventName = eintrag.eventName;
      hauptIndex = idx;
      vergleichseintraegeFuture =
          _loadVergleichsdaten(prevResult: prevResult);
    });
  }
}


  void _onMakeEventMain(Vergleichseintrag eintrag) async {
    final entries = await DayRepo().watchEntries(widget.kategorie, eintrag.eventName).first;
    if (entries.isEmpty) return;

    entries.sort((a, b) => a.datum.compareTo(b.datum));

    int idx = 0;
    final entryDate = DateTime.tryParse(eintrag.eintrag.datum);
    if (entryDate != null) {
      idx = entries.indexWhere((e) => _isSameDay(DateTime.tryParse(e.datum)!, entryDate));
      if (idx == -1) idx = 0;
    }

    setState(() {
      hauptEventName = eintrag.eventName;
      hauptIndex = idx;
      vergleichseintraegeFuture = _loadVergleichsdaten();
    });
  }

  void _showIntervallDialog() async {
    final TextEditingController controller = TextEditingController(text: tageIntervall.toString());
    final int? newInterval = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tage Intervall setzen'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Intervall in Tagen',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Abbrechen
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                Navigator.of(context).pop(value);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (newInterval != null && newInterval > 0 && newInterval != tageIntervall) {
      setState(() {
    tageIntervall = newInterval;
    vergleichseintraegeFuture = _loadVergleichsdaten(intervall: tageIntervall);
      });
      
    }

  }

  //Für vollbildanzeige
  void _showImageViewer(BuildContext context, List<String> imagePaths, int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        PageController controller = PageController(initialPage: initialIndex);

        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: imagePaths.length,
                itemBuilder: (_, index) {
                  return InteractiveViewer(
                    child: Image.file(
                      File(imagePaths[index]),
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
              Positioned(
                top: 30,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vergleichsansicht'),
        backgroundColor: Colors.green[800],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ---- LINKS: Modus & Navigation ----
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Modus: ',
                            style: TextStyle(color: Colors.white70)),
                        IconButton(
                          icon: const Icon(Icons.arrow_left, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              modus = VergleichsModus.relativ;
                              vergleichseintraegeFuture = _loadVergleichsdaten();
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_right, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              modus = VergleichsModus.datum;
                              vergleichseintraegeFuture = _loadVergleichsdaten();
                            });
                          },
                        ),
                        if (eventModus == VergleichsEventModus.solo)
                          IconButton(
                            icon: const Icon(Icons.timer),
                            tooltip: 'Intervall ändern',
                            onPressed: _showIntervallDialog,
                          ),
                        
                      ],
                    ),
                    Text(
                      'Aktueller Modus: ${modus == VergleichsModus.relativ ? "Relativ" : "Datum"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),

                // ---- Solo / Group Switch Button----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('Group',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('Solo',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Transform.scale(
                      scale: 1.1,
                      child: RotatedBox(
                        quarterTurns: 1, // Switch horizontal drehen
                        child: Switch(
                          value: eventModus == VergleichsEventModus.solo,
                          onChanged: (value) {
                            setState(() {
                              eventModus = value
                                  ? VergleichsEventModus.solo
                                  : VergleichsEventModus.group;
                              vergleichseintraegeFuture = _loadVergleichsdaten();
                            });
                          },
                          activeColor: Colors.white,
                          inactiveThumbColor: Colors.white70,
                          activeTrackColor: Colors.green[600],
                          inactiveTrackColor: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      body: FutureBuilder<List<Vergleichseintrag>>(
        future: vergleichseintraegeFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final vergleichseintraege = snapshot.data!;
          return ListView.builder(
            itemCount: vergleichseintraege.length,
            itemBuilder: (_, index) {
              final eintrag = vergleichseintraege[index];
              return GestureDetector(
                onTap: () => _onMakeEventMain(eintrag),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          eventModus == VergleichsEventModus.solo
                              ? Text(
                                  eintrag.label.isNotEmpty
                                    ? eintrag.label
                                    : '0 Tage',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                )
                              : Text(
                                  eintrag.eventName,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                          Row(
                            children: [
                              const Text("Fixieren"),
                              Checkbox(
                                value: _fixedIDs.contains(eintrag.eintrag.id),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      debugPrint('[FIX] added id=${eintrag.eintrag.id} for event=${eintrag.eventName}');
                                      _fixedIDs.add(eintrag.eintrag.id);
                                    } else {
                                      debugPrint('[FIX] removed id=${eintrag.eintrag.id} for event=${eintrag.eventName}');
                                      _fixedIDs.remove(eintrag.eintrag.id);
                                    }
                                    debugPrint('[FIX] current fixed IDs: ${_fixedIDs.toList()}');
                                  });
                                },
                              ),
                            ],
                          ),
                          if (eventModus != VergleichsEventModus.solo)
                            Text('Tag ${eintrag.tag + 1}'),
                        ],
                      ),

                      const SizedBox(height: 4),
                      // Titel + Pfeile
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.arrow_left),
                              onPressed: () => _onArrowPressed(false, eintrag)),
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
                              onPressed: () => _onArrowPressed(true, eintrag)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Bilder
                      if (eintrag.eintrag.imagePaths.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: eintrag.eintrag.imagePaths.length,
                            itemBuilder: (_, imgIndex) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onTap: () => _showImageViewer(context, eintrag.eintrag.imagePaths, imgIndex),
                                  child: Image.file(
                                    File(eintrag.eintrag.imagePaths[imgIndex]),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final vergleichseintraege = await vergleichseintraegeFuture;
          if (vergleichseintraege.length < 2) return;

          final aktueller = vergleichseintraege.first;
          List<Vergleichseintrag> vergleichsEintraege;

          if (eventModus == VergleichsEventModus.solo) {
            // Im Solo‑Modus sollen alle Einträge (außer dem aktuellen) verglichen werden
            vergleichsEintraege =
                vergleichseintraege.where((e) => e != aktueller).toList();
          } else {
            // Im Gruppenmodus wie bisher: nur andere Events
            vergleichsEintraege =
                vergleichseintraege.where((e) => e.eventName != aktueller.eventName).toList();
          }

          if (vergleichsEintraege.isEmpty) return;

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
