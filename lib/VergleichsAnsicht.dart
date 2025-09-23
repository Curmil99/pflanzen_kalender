import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../repositories/day_repo.dart';
import '../models/day_entry.dart';
import 'direkt_vergleich_nsicht.dart';
import '../models/Nerv1.dart'; // Vergleichseintrag

enum VergleichsModus { relativ, datum }

class VergleichsAnsicht extends StatefulWidget {
  final String aktuellesEventName;
  final String kategorie;
  final int? aktuellerTag;
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
  State<VergleichsAnsicht> createState() => _VergleichsAnsichtState();
}

class _VergleichsAnsichtState extends State<VergleichsAnsicht> {
  late String hauptEventName;
  late int hauptIndex;
  late VergleichsModus modus;
  late Future<List<Vergleichseintrag>> vergleichseintraegeFuture;

  @override
  void initState() {
    super.initState();
    modus = widget.modus;
    hauptEventName = widget.aktuellesEventName;
    hauptIndex = 0;
    vergleichseintraegeFuture = _loadVergleichsdaten();
  }

  String _formatDateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  DayEntry? _findClosestEntryByDayMonthInList(
      List<DayEntry> entries, DateTime target) {
    DayEntry? closest;
    int minDiff = 1 << 30;
    for (var e in entries) {
      final d = DateTime.tryParse(e.datum);
      if (d == null) continue;
      final dayOfYearA =
          DateTime(d.year, d.month, d.day).difference(DateTime(d.year, 1, 1)).inDays;
      final dayOfYearB =
          DateTime(target.year, target.month, target.day).difference(DateTime(target.year, 1, 1)).inDays;
      int diff = (dayOfYearA - dayOfYearB).abs();
      if (diff > 182) diff = 365 - diff;
      if (diff < minDiff) {
        minDiff = diff;
        closest = e;
      }
    }
    return closest;
  }

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

  Future<List<Vergleichseintrag>> _loadVergleichsdaten() async {
    // 1) Hauptevent laden
    final currentEntries =
        await DayRepo().watchEntries(widget.kategorie, hauptEventName).first;
    if (currentEntries.isEmpty) return [];

    final hauptStart = _getStartDatumFromList(currentEntries);
    if (hauptIndex >= currentEntries.length) hauptIndex = currentEntries.length - 1;
    final hauptDatumEntry = currentEntries[hauptIndex];
    final hauptDatum = DateTime.tryParse(hauptDatumEntry.datum)!;
    final hauptRelativeDays =
        hauptStart != null ? hauptDatum.difference(hauptStart).inDays : 0;

    final result = <Vergleichseintrag>[];
    result.add(Vergleichseintrag(
      eventName: hauptEventName,
      tag: hauptRelativeDays,
      eintrag: hauptDatumEntry,
    ));

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
          eventName: kv.key, tag: relativeTag, eintrag: chosen));
    }

    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _findClosestIndex(List<DateTime> dates, DateTime target) {
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

  // Pfeil-Handler unverändert: auf chosenIndex im FutureBuilder reagieren
  void _onArrowPressed(bool forward, Vergleichseintrag eintrag) async {
    final entries = await DayRepo().watchEntries(widget.kategorie, eintrag.eventName).first;
    if (entries.isEmpty) return;
    final dates = entries.map((e) => DateTime.tryParse(e.datum)!).toList()..sort();

    int idx = dates.indexWhere(
        (d) => _isSameDay(d, DateTime.tryParse(eintrag.eintrag.datum)!));
    if (idx == -1) idx = _findClosestIndex(dates, DateTime.tryParse(eintrag.eintrag.datum)!);

    int newIdx = forward ? min(idx + 1, dates.length - 1) : max(idx - 1, 0);

    setState(() {
      hauptEventName = eintrag.eventName;
      hauptIndex = newIdx;
      vergleichseintraegeFuture = _loadVergleichsdaten();
    });
  }

  void _onMakeEventMain(Vergleichseintrag eintrag) async {
    final entries = await DayRepo().watchEntries(widget.kategorie, eintrag.eventName).first;
    if (entries.isEmpty) return;
    final dates = entries.map((e) => DateTime.tryParse(e.datum)!).toList()..sort();
    DateTime? entryDate = DateTime.tryParse(eintrag.eintrag.datum);
    int idx = entryDate != null ? _findClosestIndex(dates, entryDate) : 0;

    setState(() {
      hauptEventName = eintrag.eventName;
      hauptIndex = idx.clamp(0, dates.length - 1);
      vergleichseintraegeFuture = _loadVergleichsdaten();
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
                          Text(
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final vergleichseintraege = await vergleichseintraegeFuture;
          if (vergleichseintraege.length < 2) return;
          final aktueller = vergleichseintraege.first;
          final List<Vergleichseintrag> vergleichsEintraege =
              vergleichseintraege.where((e) => e.eventName != aktueller.eventName).toList();

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
