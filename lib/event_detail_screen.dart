import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'day_detail_screen.dart';  // <– ganz oben ergänzen
import '../repositories/day_repo.dart'; //  unbedingt hinzufügen
import '../models/day_entry.dart';
import 'package:intl/intl.dart';


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

  List<DayEntry> _getAndereEventEintraege(DateTime date) {
    switch (_currentViewMode) {
      case CalendarViewMode.nurAktuellesEvent:
        return [];
      case CalendarViewMode.aktuelleAnsicht:
        return _getAndereEventsAktuellesJahr(date);
      case CalendarViewMode.vorjahreImMonat:
        return _getAndereEventsVorjahreImMonat(date);
      case CalendarViewMode.relativeTage:
        return _getAndereEventsRelativeTage(date);
    }
  }

  DateTime? getLastEventDate(String kategorie, String eventName) {
    final eventMap = DayRepo().allEntries[kategorie]?[eventName];
    if (eventMap == null || eventMap.isEmpty) return null;

    // Keys sind Strings im Format "JJJJ-MM-TT"
    final allDates = eventMap.keys.map((key) => DateTime.parse(key)).toList();
    allDates.sort();
    return allDates.last; // neuestes Datum
  }

  //Hier werden die anderen Tage rausgesucht, die aus den anderen Events

  List<DayEntry> _getAndereEventsAktuellesJahr(DateTime date) {
    final katMap = DayRepo().allEntries[widget.kategorie];
    if (katMap == null) return [];

    final dateKey = _keyFmt.format(date); 
    final List<DayEntry> result = [];

    katMap.forEach((event, dateMap) {
      if (event == widget.eventName) return; // aktuelles Event überspringen

      final entry = dateMap[dateKey];
      if (entry == null) return;

      if (entry.title.isNotEmpty || entry.note.isNotEmpty || entry.imagePaths.isNotEmpty) {
        result.add(entry);
      }
    });

    return result;
  }

  List<DayEntry> _getAndereEventsVorjahreImMonat(DateTime viewDate) {
    final katMap = DayRepo().allEntries[widget.kategorie];
    if (katMap == null) return [];

    final int ansichtsJahr = viewDate.year;
    final int systemJahr = DateTime.now().year;
    final int monat = viewDate.month;
    final int tag = viewDate.day;

    final List<DayEntry> result = [];

    katMap.forEach((event, dateMap) {
      if (event == widget.eventName) return;

      dateMap.forEach((key, entry) {
        // Nur valide YYYY-MM-DD Strings
        final date = DateTime.tryParse(key);
        if (date == null) return;

        // Filter für Monat/Tag & Vorjahr
        if (date.month != monat || date.day != tag) return;
        if (date.year >= ansichtsJahr || date.year > systemJahr) return;

        // Nur Einträge mit Inhalt
        if (entry.title.isEmpty && entry.note.isEmpty && entry.imagePaths.isEmpty) return;

        result.add(entry);
      });
    });

    return result;
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

  List<DayEntry> _getAndereEventsRelativeTage(DateTime date) {
  final katMap = DayRepo().allEntries[widget.kategorie];
  if (katMap == null) return [];
  final currentEventMap = katMap[widget.eventName];
  if (currentEventMap == null) return [];

  final startDatumAktuell = _getStartDatum(currentEventMap);
  if (startDatumAktuell == null) return [];

  final relativerTag = _stripTime(date).difference(_stripTime(startDatumAktuell)).inDays;
  if (relativerTag < 0) return [];

  final List<DayEntry> result = [];
  katMap.forEach((event, dateMap) {
    if (event == widget.eventName) return;

    final startDatum = _getStartDatum(dateMap);
    if (startDatum == null) return;

    final zielDatum = startDatum.add(Duration(days: relativerTag));
    final entry = dateMap[_dateKey(zielDatum)];
    if (entry == null) return;

    if (entry.title.isNotEmpty || entry.note.isNotEmpty || entry.imagePaths.isNotEmpty) {
      result.add(entry);
    }
  });

  return result;
}




  Widget _buildDayCell(DateTime date, bool isToday) {
  final dateKey = _dateKey(date);
  final current = DayRepo().getEntry(widget.kategorie, widget.eventName, dateKey);
  final andere = _getAndereEventEintraege(date);

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
          Text('${date.day}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          if (current != null && (current.title.isNotEmpty || current.note.isNotEmpty || current.imagePaths.isNotEmpty))
            _badge(current.title.isNotEmpty ? current.title : '', Colors.green.shade400, Colors.white),
          for (final e in andere)
            if (e.title.isNotEmpty || e.note.isNotEmpty || e.imagePaths.isNotEmpty)
              _badge(e.title, Colors.green.shade200, Colors.black87),
        ],
      ),
    ),
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
          headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (c, d, _) => _buildDayCell(d, false),
            todayBuilder:   (c, d, _) => _buildDayCell(d, true),
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

   floatingActionButton: FloatingActionButton(
      child: Icon(Icons.history),
      onPressed: () {
        final lastDate = getLastEventDate(widget.kategorie, widget.eventName);
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

      ),
    );
  }
}
