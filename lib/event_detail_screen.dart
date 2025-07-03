import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'day_detail_screen.dart';  // <– ganz oben ergänzen
import '../repositories/day_repo.dart'; //  unbedingt hinzufügen
import '../models/day_entry.dart';


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


  // HIER ist widget.kategorie / widget.eventName verfügbar
  List<DayEntry> _getAndereEventEintraege(String dateKey) {
    final katMap = DayRepo().allEntries[widget.kategorie];
    if (katMap == null) return [];

    final List<DayEntry> result = [];
    katMap.forEach((event, dateMap) {
      if (event == widget.eventName) return;      // aktuelles Event überspringen
      final entry = dateMap[dateKey];
      if (entry != null && entry.title.isNotEmpty) result.add(entry);
    });
    return result;
  }

  Widget _buildDayCell(DateTime date, bool isToday) {
    final dateKey = '${date.year}-${date.month.toString().padLeft(2,"0")}-${date.day.toString().padLeft(2,"0")}';

    final current = DayRepo().getEntry(widget.kategorie, widget.eventName, dateKey);

    final andere = _getAndereEventEintraege(dateKey);
   
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),

            // Aktueller Event – kräftige Farbe
            if (current != null && current.title.isNotEmpty)
              _badge(current.title, Colors.green.shade400, Colors.white),

            // Andere Events – blassere Farbe
            if (_currentViewMode == CalendarViewMode.aktuelleAnsicht)...[
              for (final e in andere)
                _badge(e.title, Colors.green.shade200, Colors.black87),
            ]
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
      ),
    );
  }
}
