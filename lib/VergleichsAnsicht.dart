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


  Future<List<Vergleichseintrag>> _loadVergleichsdaten({bool initialLoad = false, int intervall = 365}) async {
    final result = <Vergleichseintrag>[];
    
    
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
    

    // Berechne relativen Tag
    final hauptRelativeDays =hauptDatum.difference(hauptDatum).inDays;

    final int relativeTag = hauptRelativeDays; // tatsächlicher Offset
    final int interval = tageIntervall;
    final int ideal = ((relativeTag / interval).round()) * interval;
    final int differenz = relativeTag - ideal;
    final String diffString = differenz == 0
        ? ''
        : (differenz > 0 ? ' (+$differenz)' : ' ($differenz)');
    
    result.add(Vergleichseintrag(
      eventName: hauptEventName,
      tag: hauptRelativeDays,
      eintrag: hauptDatumEntry,
      label: widget.label.isNotEmpty
      ? widget.label
      : (eventModus == VergleichsEventModus.solo
          ? '$ideal Tage$diffString'
          : hauptEventName),
));

    // 🔸 NEU: Ab hier prüfen, ob Solo-Modus aktiv ist
    // 🔸 NEU: Solo-Modus mit Tagesabstand
   // 🔸 NEU: Solo-Modus prüfen
    if (eventModus == VergleichsEventModus.solo) {
    // Nur Einträge dieses Events (aus anderen Jahren)
    currentEntries.sort((a, b) => a.datum.compareTo(b.datum));

    // Jahr des Haupteintrags bestimmen
    final List<DateTime> zielDaten = [];

    int tageIntervall = intervall;
    const int maxIntervalle = 5; // prüfe bis zu 5 Intervalle rückwärts

    // Hauptdatum, z.B. 15.8.2023
    final hauptDatum = DateTime.tryParse(hauptDatumEntry.datum)!;

    // Wir prüfen Intervalle rückwärts: z.B. 0-365 Tage zurück, 366-730 Tage zurück usw.
    for (int i = 1; i <= maxIntervalle; i++) {
      // Intervall Grenzwerte in Tagen rückwärts
      final DateTime intervallEnd = hauptDatum.subtract(Duration(days: tageIntervall * (i - 1)));
      final DateTime intervallStart = hauptDatum.subtract(Duration(days: tageIntervall * i));

      // Prüfen, ob es Einträge gibt, die im Intervall [intervallStart, intervallEnd] liegen
      final existsInInterval = currentEntries.any((e) {
        final d = DateTime.tryParse(e.datum);
        if (d == null) return false;
        // Datum d liegt im Intervall
        return !d.isBefore(intervallStart) && !d.isAfter(intervallEnd);
      });

      if (existsInInterval) {
        // Ziel-Datum für Suche merken: bspw. Beginn Intervall (= hauptDatum minus days)
        // Alternativ könnte auch intervallEnd genommen werden, je nachdem, was sinnvoller ist
        zielDaten.add(intervallStart);
      }
    }

    // Nun in der Schleife für jedes Ziel-Datum den nächstgelegenen Eintrag suchen
    for (final zielDatum in zielDaten) {
      final closest = _findClosestEntryInList(currentEntries, zielDatum);

      if (closest != null) {
        final d = DateTime.tryParse(closest.datum)!;
        final rel = d.difference(hauptDatum).inDays;

        // Vermeide Duplikate oder Haupteintrag nochmal
        
          // Label individuell berechnen:
                          // Hauptbild ist die 0-Referenz
          final int relativeTag = rel;          // Abstand dieses Eintrags zur Basis
          final int interval = tageIntervall;
          final int ideal = ((relativeTag / interval).round()) * interval;
          final int differenz = relativeTag - ideal;
          final String diffString =
              differenz == 0 ? '' : (differenz > 0 ? ' (+$differenz)' : ' ($differenz)');          

          result.add(Vergleichseintrag(
            eventName: hauptEventName,
            tag: rel,
            eintrag: closest,
            label: '$ideal Tage$diffString', // <-- jetzt individuell!
          ));
        
      }
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
        label: _berechneLabel(result[i], result, tageIntervall, eventModus),
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
        if (relativeTag == 0) return '0 Tage';
        final int interval = tageIntervall;
        final int ideal = ((relativeTag / interval).round()) * interval;
        final int differenz = relativeTag - ideal;
        final String diffString = differenz == 0
            ? ''
            : (differenz > 0 ? ' (+$differenz)' : ' ($differenz)');
      return '$ideal Tage$diffString';
    } else {
      return eintrag.eventName;
    }
  }


  DayEntry? _findClosestEntryInList(List<DayEntry> entries, DateTime target) {
    DayEntry? closest;
    int minDiff = 1 << 30;
    for (var e in entries) {
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

  void _onArrowPressed(bool forward, Vergleichseintrag eintrag) async {
    final entries = await DayRepo().watchEntries(widget.kategorie, eintrag.eventName).first;
    if (entries.isEmpty) return;

    entries.sort((a, b) => a.datum.compareTo(b.datum));

    if (eintrag.eventName == hauptEventName) {
      int newIdx = forward ? min(hauptIndex + 1, entries.length - 1) : max(hauptIndex - 1, 0);
      setState(() {
        hauptIndex = newIdx;
        vergleichseintraegeFuture = _loadVergleichsdaten();
      });
    } else {
      // Klick auf Nebenevent -> neues HauptEvent
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

                // ---- RECHTS: Solo / Group Switch ----
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
                            ? Builder(
                              builder: (_) {
                                final int baseTag = vergleichseintraege.isNotEmpty ? vergleichseintraege[0].tag : 0;
                                final int relativeTag = eintrag.tag - baseTag;

                                if (relativeTag == 0) {
                                  return const Text(
                                    '0 Tage',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  );
                                }

                                final int interval = tageIntervall;

                                // Das nächstliegende oder vorherige Vielfache von 365, das kleiner oder gleich relativeTag ist
                                final int ideal = ( (relativeTag / interval).round() ) * interval;


                                final int differenz = relativeTag - ideal;

                                final String diffString = differenz == 0
                                    ? ''
                                    : (differenz > 0 ? ' (+$differenz)' : ' ($differenz)');

                                return Text(
                                  '$ideal Tage$diffString',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                );
                              },
                          )
                        : Text(
                            eintrag.eventName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        
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
