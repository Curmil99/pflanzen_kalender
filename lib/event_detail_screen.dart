import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'day_detail_screen.dart';  // <– ganz oben ergänzen
import '../repositories/day_repo.dart'; //  unbedingt hinzufügen
import '../models/day_entry.dart';
import 'package:intl/intl.dart';


// Dieser Screen ist die Kalenderansicht


enum CalendarViewMode {
  nurAktuellesEvent,
  vorjahreImMonat,
  relativeTage,
  aktuelleAnsicht,
}



class EventDetailScreen extends StatefulWidget {
  final String kategorie;
  final String eventName;

  EventDetailScreen({required this.kategorie, required this.eventName});

  @override
  _EventDetailScreenState createState() => _EventDetailScreenState();
}


class _EventDetailScreenState extends State<EventDetailScreen> {
  DateTime _focusedDay = DateTime.now();
  bool _modified = false;               // <– Merkt, ob etwas geändert wurde
  


  // Hilfsfunktion: DateKey erzeugen (z.B. "2025-07-09")
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}';
  }

  // Hier wied die Ansicht vom ViewMode/Anischt ausgewählt
  CalendarViewMode _currentViewMode = CalendarViewMode.aktuelleAnsicht;

  String getViewModeName(CalendarViewMode mode) {
    switch (mode) {
      case CalendarViewMode.nurAktuellesEvent:
        return 'Nur aktuelles Event';
      case CalendarViewMode.vorjahreImMonat:
        return 'Vorjahre im Monat';
      case CalendarViewMode.relativeTage:
        return 'Relative Tage';
      case CalendarViewMode.aktuelleAnsicht:
        return 'Aktuelle Ansicht';
    }
  }



  static final _keyFmt = DateFormat('yyyy-MM-dd');

  Stream<List<DayEntry>> _getAndereEventEintraegeStream(DateTime date) {
    switch (_currentViewMode) {
      case CalendarViewMode.nurAktuellesEvent:
        return getAktuellesEventVorjahreStream(date); 
      case CalendarViewMode.aktuelleAnsicht:
        return getAndereEventsAktuellesJahrStream(date);
      case CalendarViewMode.vorjahreImMonat:
        return getAndereEventsVorjahreImMonatStream(date);
      case CalendarViewMode.relativeTage:
        return getAndereEventsRelativeTageStream(date);
    }
  }



  Future<DateTime?> getFirstLastEventDate(String kategorie, String eventName, bool isFirst) async {
    final entries = await DayRepo().watchEntries(kategorie, eventName).first;
    if (entries.isEmpty) return null;

    // Liste der Datumswerte
    final allDates = entries
        .map((e) => DateTime.tryParse(e.datum))
        .whereType<DateTime>()
        .toList();
    if (allDates.isEmpty) return null;

    allDates.sort();

    debugPrint('All dates for $kategorie/$eventName: ${allDates.map((d) => d.toIso8601String()).toList()}');
    debugPrint('isFirst: $isFirst, returning: ${isFirst ? allDates.first : allDates.last}');

    if (isFirst) 
      return allDates.first;
    else
      return allDates.last;
  }


  Stream<List<DayEntry>> getAktuellesEventVorjahreStream(DateTime viewDate) {
    final int ansichtsJahr = viewDate.year;
    final int monat = viewDate.month;
    final int tag = viewDate.day;

    return DayRepo().watchEntries(widget.kategorie, widget.eventName).map((entries) {
      final result = <DayEntry>[];

      for (var entry in entries) {
        final date = DateTime.tryParse(entry.datum);
        if (date == null) continue;

        // Filter: nur Einträge aus Vorjahren am gleichen Tag/Monat
        if (date.year >= ansichtsJahr) continue;
        if (date.month != monat || date.day != tag) continue;

        // Nur Einträge mit Inhalt
        if (entry.title.isEmpty && entry.note.isEmpty && entry.imagePaths.isEmpty) continue;

        result.add(entry);
      }

      // Älteste zuerst sortieren
      result.sort((a, b) => a.datum.compareTo(b.datum));

      return result;
    });
  }

  //Hier werden die anderen Tage rausgesucht, die aus den anderen Events sind
  Stream<List<DayEntry>> getAndereEventsAktuellesJahrStream(DateTime date) {
    final dateKey = _keyFmt.format(date);

    // Stream aller Einträge für die Kategorie
    return DayRepo().watchByKategorie(widget.kategorie).map((entries) {
      final result = <DayEntry>[];

      for (var entry in entries) {
        // Aktuelles Event überspringen
        if (entry.event == widget.eventName) continue;

        if (entry.datum == dateKey &&
            (entry.title.isNotEmpty || entry.note.isNotEmpty || entry.imagePaths.isNotEmpty)) {
          result.add(entry);
        }
      }

      // Optional: nach Datum sortieren, falls mehrere pro Tag (nicht nötig hier, da nur ein Datum pro key)
      // result.sort((a, b) => a.datum.compareTo(b.datum));

      return result;
    });
  }


  Stream<List<DayEntry>> getAndereEventsVorjahreImMonatStream(DateTime viewDate) {
    final int ansichtsJahr = viewDate.year;
    final int systemJahr = DateTime.now().year;
    final int monat = viewDate.month;
    final int tag = viewDate.day;

    return DayRepo().watchByKategorie(widget.kategorie).map((entries) {
      final result = <DayEntry>[];

      for (var entry in entries) {
        if (entry.event == widget.eventName) continue; // aktuelles Event überspringen

        final date = DateTime.tryParse(entry.datum);
        if (date == null) continue;

        // Filter: Monat/Tag & Vorjahr
        if (date.month != monat || date.day != tag) continue;
        if (date.year >= ansichtsJahr || date.year > systemJahr) continue;

        // Nur Einträge mit Inhalt
        if (entry.title.isEmpty && entry.note.isEmpty && entry.imagePaths.isEmpty) continue;

        result.add(entry);
      }

      // Optional: sortieren nach Datum (älteste zuerst)
      result.sort((a, b) => a.datum.compareTo(b.datum));

      return result;
    });
  }


    DateTime? _getStartDatum(Map<String, DayEntry> dateMap) {
      if (dateMap.isEmpty) return null;
      final dates = dateMap.keys
          .map((k) => DateTime.tryParse(k))
          .whereType<DateTime>()
          .toList();
      if (dates.isEmpty) return null;
      dates.sort();
      return dates.first;
    }

    DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);


  Stream<List<DayEntry>> getAndereEventsRelativeTageStream(DateTime date) {
    return DayRepo().watchByKategorie(widget.kategorie).map((entries) {
      // Einträge pro Event gruppieren
      final Map<String, Map<String, DayEntry>> katMap = {};
      for (var entry in entries) {
        katMap.putIfAbsent(entry.event, () => {});
        katMap[entry.event]![entry.datum] = entry;
      }

      final currentEventMap = katMap[widget.eventName];
      if (currentEventMap == null) return <DayEntry>[];

      final startDatumAktuell = _getStartDatum(currentEventMap);
      if (startDatumAktuell == null) return <DayEntry>[];

      final relativerTag = _stripTime(date).difference(_stripTime(startDatumAktuell)).inDays;
      if (relativerTag < 0) return <DayEntry>[];

      final result = <DayEntry>[];

      katMap.forEach((event, dateMap) {
        if (event == widget.eventName) return;

        final startDatum = _getStartDatum(dateMap);
        if (startDatum == null) return;

        final zielDatum = startDatum.add(Duration(days: relativerTag));
        final zielEntry = dateMap['${zielDatum.year}-${zielDatum.month.toString().padLeft(2,'0')}-${zielDatum.day.toString().padLeft(2,'0')}'];

        if (zielEntry != null &&
            (zielEntry.title.isNotEmpty ||
            zielEntry.note.isNotEmpty ||
            zielEntry.imagePaths.isNotEmpty)) {
          result.add(zielEntry);
        }
      });

      return result;
    });
  }



  Widget _buildDayCell(DateTime date, bool isToday) {
    final dateKey = _dateKey(date);

    return StreamBuilder<DayEntry?>(
      stream: DayRepo()
          .watchEntries(widget.kategorie, widget.eventName)
          .map((entries) {
        try {
          return entries.firstWhere((e) => e.datum == dateKey);
        } catch (_) {
          return null;
        }
      }),
      builder: (context, currentSnapshot) {
        final current = currentSnapshot.data;

        return StreamBuilder<List<DayEntry>>(
          stream: _getAndereEventEintraegeStream(date),
          builder: (context, andereSnapshot) {
            final andere = andereSnapshot.data ?? [];

            // Deduplizieren nach Event + Datum
            final Map<String, DayEntry> uniqueAndere = {};
            for (var e in andere) {
              final key = '${e.event}-${e.datum}';
              if (!uniqueAndere.containsKey(key)) {
                uniqueAndere[key] = e;
              }
            }
            final finalAndere = uniqueAndere.values.toList();

            return Container(
              width: double.infinity,
              margin: EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, width: 0.6),
                borderRadius: BorderRadius.circular(6),
                color: isToday ? Colors.green.shade100 : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${date.day}',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (current != null &&
                        (current.title.isNotEmpty ||
                            current.note.isNotEmpty ||
                            current.imagePaths.isNotEmpty))
                      _badge(
                          _currentViewMode == CalendarViewMode.nurAktuellesEvent
                            ? DateTime.parse(current.datum).year.toString() // nur Jahr
                            : current.event,
                          Colors.green.shade400,
                          Colors.white),
                    for (final e in finalAndere)
                      if (e.title.isNotEmpty || e.note.isNotEmpty || e.imagePaths.isNotEmpty)
                        GestureDetector(
                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DayDetailScreen(
                                  kategorie: e.kategorie,
                                  eventName: e.event,
                                  selectedDate: DateTime.parse(e.datum), // dein dateKey ist String
                                ),
                              ),
                            );
                            if (changed == true) {
                              _modified = true;
                              setState(() {});
                            }
                          },
                          child: _badge(
                            _currentViewMode == CalendarViewMode.nurAktuellesEvent  //Bei nur aktuelles Event wird das Jahr und nicht der Eventname angezeigt
                              ? DateTime.parse(e.datum).year.toString()
                              : e.event,
                            Colors.green.shade200,
                            Colors.black87,
                          ),
                        ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  // kleines Hilfs‑Widget für Badges
  Widget _badge(String text, Color bg, Color fg) => Container(
        margin: EdgeInsets.only(top: 2),
        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
        child: Text(text,
            style: TextStyle(fontSize: 10, color: fg),
            overflow: TextOverflow.ellipsis),
      );


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _modified);   // Ändert Rückgabe‑Wert
        return false;                        // Verhindert automatisches Pop
      },
      child: Scaffold(
        appBar: AppBar(                       // Die vier verschiedenen Ansichten im Kalender rechts oben
          title: Text('${widget.eventName} – ${widget.kategorie}'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  getViewModeName(_currentViewMode),
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            PopupMenuButton<CalendarViewMode>(
              icon: Icon(Icons.visibility),
              onSelected: (mode) {
                setState(() {
                  _currentViewMode = mode;
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: CalendarViewMode.nurAktuellesEvent,
                  child: Text('Nur aktuelles Event'),
                ),
                PopupMenuItem(
                  value: CalendarViewMode.vorjahreImMonat,
                  child: Text('Vorjahre im Monat'),
                ),
                PopupMenuItem(
                  value: CalendarViewMode.relativeTage,
                  child: Text('Relative Tage'),
                ),
                PopupMenuItem(
                  value: CalendarViewMode.aktuelleAnsicht,
                  child: Text('Aktuelle Ansicht'),
                ),
              ],
            ),
          ],
        ),

        body: TableCalendar(
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.month,
          rowHeight: 80,
          headerVisible: true,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) =>
                '${DateFormat.MMMM(locale).format(date)} ${date.year}',
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (c, d, _) => _buildDayCell(d, false),
            todayBuilder: (c, d, _) => _buildDayCell(d, true),
            headerTitleBuilder: (context, date) {
              return GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _focusedDay,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _focusedDay = pickedDate;
                    });
                  }
                },
                child: Center(
                  child: Text(
                    '${DateFormat.MMMM().format(date)} ${date.year}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
          onPageChanged: (day) => setState(() => _focusedDay = day),
          onDaySelected: (selectedDay, _) async {
            // ⇣⇣ DayDetailScreen aufrufen und Rückgabe abfangen
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => DayDetailScreen(
                  kategorie: widget.kategorie,
                  eventName: widget.eventName,
                  selectedDate: selectedDay,
                ),
              ),
            );

            if (changed == true) {
              _modified = true;     // Merken, dass etwas passiert ist
              setState(() {});      // Kalender sofort refreshen
            }
          },
        ),

        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'firstEvent',
              child: Icon(Icons.first_page),
              onPressed: () async {
                final firstDate = await getFirstLastEventDate(widget.kategorie, widget.eventName, true);
                if (firstDate != null) {
                  setState(() {
                    _focusedDay = firstDate;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Keine Einträge vorhanden")),
                  );
                }
              },
            ),
            SizedBox(width: 16),
            FloatingActionButton(
              heroTag: 'lastEvent',
              child: Icon(Icons.last_page),
              onPressed: () async {
                final lastDate = await getFirstLastEventDate(widget.kategorie, widget.eventName, false);
                if (lastDate != null) {
                  setState(() {
                    _focusedDay = lastDate;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Keine Einträge vorhanden")),
                  );
                }
              },
            ),
          ],
        ),


      ),
    );
  }
}
