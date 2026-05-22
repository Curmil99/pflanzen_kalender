import 'package:flutter/material.dart';
import '../event_detail_screen.dart';
//import 'day_detail_screen.dart';
import '../../repositories/day_repo.dart'; 
import '../../utils/bilder_hinzufuegen.dart'; // Import hinzufügen
import '../../Screens/galerie_screen.dart';
import '../../Screens/notizen_screen.dart';



class EventListeScreen extends StatefulWidget {
  final String? eventName;
  final String kategorie;
  final DateTime selectedDate;

  EventListeScreen({
      this.eventName,
      required this.kategorie,
      DateTime? selectedDate,
  }) : selectedDate = selectedDate ?? DateTime.now();

  @override
  _EventListeScreenState createState() => _EventListeScreenState();
}

enum EventSortiermodus { alphabetisch, erstellungsdatum, laufzeit }



class _EventListeScreenState extends State<EventListeScreen> {
  EventSortiermodus _sortiermodus = EventSortiermodus.erstellungsdatum;

  bool _auswahlmodusE = false;   // ob wir gerade mehrere Events zum Löschen markieren
  Set<String> _markierteEvents = {};

  Map<EventSortiermodus, bool> _ascending = {
    EventSortiermodus.alphabetisch: true,
    EventSortiermodus.erstellungsdatum: true,
    EventSortiermodus.laufzeit: false, // Dauer macht meist Sinn absteigend
  };

  late List<String> _events;

  @override
  void initState() {
    super.initState();
    _events = DayRepo().getEvents(widget.kategorie);
  }

  Future<List<String>> _getSortedEvents() async {
    var events = List<String>.from(_events);

    if (_sortiermodus == EventSortiermodus.alphabetisch) {
      events.sort((a, b) => a.compareTo(b));
      if (!_ascending[_sortiermodus]!) events = events.reversed.toList();
      return events;
    }

    // Startdatum und Dauer berechnen
    final Map<String, DateTime> startDates = {};
    final Map<String, int> spans = {};

    await Future.wait(events.map((ev) async {
      final repo = DayRepo();
      final entries = await repo.watchEntries(widget.kategorie, ev).first;

      if (entries.isEmpty) {
        startDates[ev] = DateTime(2100);
        spans[ev] = 0;
        return;
      }

      final dates = entries.map((e) => DateTime.parse(e.datum)).toList()..sort();
      startDates[ev] = dates.first;
      spans[ev] = dates.last.difference(dates.first).inDays + 1;
    }));

    if (_sortiermodus == EventSortiermodus.erstellungsdatum) {
      events.sort((a, b) => startDates[a]!.compareTo(startDates[b]!));
    } else if (_sortiermodus == EventSortiermodus.laufzeit) {
      events.sort((a, b) => spans[b]!.compareTo(spans[a]!));
    }

    if (!_ascending[_sortiermodus]!) events = events.reversed.toList();

    return events;
  }

  /* ---------- Event hinzufügen ---------- */
  void _showEventHinzufuegenDialog() {
    final controller = TextEditingController(); // zum Eingeben des Event‑Namens

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Event hinzufügen'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Name des Events (z.B. 2026)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Dialog schließen
            child: Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim(); // Leerzeichen weg
              if (name.isNotEmpty && !_events.contains(name)) {
                DayRepo().addEvent(widget.kategorie, name);
                setState(() => _events = DayRepo().getEvents(widget.kategorie)); // Event hinzufügen
                Navigator.pop(context);
              }
            },
            child: Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }



  /* ---------- Mehrere Events löschen ---------- */
  void _showEventsLoeschenDialog() {
    final Set<String> auswahl = {}; // speichert markierte Events

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Events löschen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _events.map((ev) {
                return CheckboxListTile(
                  title: Text(ev),
                  value: auswahl.contains(ev), // aktiv, falls ausgewählt
                  onChanged: (checked) {
                    setDlgState(() {
                      if (checked == true) {
                        auswahl.add(ev); // markieren
                      } else {
                        auswahl.remove(ev); // demarkieren
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Dialog schließen
              child: Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: auswahl.isEmpty
                  ? null
                  : () async {
                      // 1. Alle markierten Events aus der Datenbank löschen
                      for (final ev in auswahl) {
                        await DayRepo().deleteEvent(widget.kategorie, ev);
                      }

                      // 2. Auch lokal aus der Liste entfernen, damit UI aktualisiert wird
                      setState(() => _events = DayRepo().getEvents(widget.kategorie));

                      Navigator.pop(context);
                    },
              child: Text('Löschen'),
            ),

          ],
        ),
      ),
    );
  }

  /// Liefert die Zahl der Tage zwischen dem ersten und letzten Eintrag
  /// (inklusive beider Tage). Gibt 0 zurück, wenn gar kein Eintrag existiert.
  Future<int> _spanInTagen(String event) async {
    final repo = DayRepo();

    // Alle Einträge für die Kategorie + Event holen
    final entries = await repo.watchEntries(widget.kategorie, event).first;

    if (entries.isEmpty) return 0;

    // alle Datum‑Strings (YYYY‑MM‑DD) sortieren
    final dates = entries.map((e) => e.datum).toList()..sort();
    final first = DateTime.parse(dates.first);
    final last  = DateTime.parse(dates.last);

    // Differenz inkl. beider Tage → +1
    return last.difference(first).inDays + 1;
  }

  final Map<String, Future<Map<String, int>>> _eventStatsCache = {};

  Future<Map<String, int>> _getEventStats(String event) {
    return _eventStatsCache.putIfAbsent(event, () async {
      final repo = DayRepo();
      final entries = await repo.watchEntries(widget.kategorie, event).first;
      final dates = entries
          .map((e) => DateTime.parse(e.datum))
          .toList()
        ..sort();

      final span = dates.isEmpty ? 0 : dates.last.difference(dates.first).inDays + 1;
      final images = entries.fold<int>(0, (sum, entry) => sum + entry.imagePaths.length);
      final notes = entries.where((entry) => entry.note.trim().isNotEmpty).length;

      return {
        'entries': entries.length,
        'images': images,
        'notes': notes,
        'span': span,
      };
    });
  }

  Future<List<Map<String, dynamic>>> _getSortedEventsWithSpans() async {
    final events = await _getSortedEvents(); // sortiert nach gewähltem Modus
    final List<Map<String, dynamic>> result = [];

    for (var ev in events) {
      final span = await _spanInTagen(ev);
      result.add({'name': ev, 'span': span});
    }

    return result;
  }

  void _showEventInfo(String eventName) async {
    final stats = await _getEventStats(eventName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Event-Info: $eventName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timeline, color: Colors.green),
                title: Text('${stats['span']} Tage'),
                subtitle: const Text('Dauer des Events'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_note, color: Colors.green),
                title: Text('${stats['entries']} Einträge'),
                subtitle: const Text('Anzahl der Tageinträge'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: Text('${stats['images']} Bilder'),
                subtitle: const Text('Fotos, die zu diesem Event hinzugefügt wurden'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.note_alt, color: Colors.green),
                title: Text('${stats['notes']} Notizen'),
                subtitle: const Text('Textinhalte in den Einträgen'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  void _showEventBearbeitenDialog(String oldName) {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Event umbenennen'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Neuer Name des Events'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;

                final ok = await DayRepo().renameEvent(widget.kategorie, oldName, newName);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Name ungültig oder bereits vorhanden')));
                  return;
                }

                setState(() {
                  _events = DayRepo().getEvents(widget.kategorie);
                });

                Navigator.pop(context);
              },
              child: Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  /* ---------- Popup‑Menü (Plus‑Button) ---------- */
  void _showMenu() async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(1000, 600, 10, 10), // Menü‑Position
      items: [
        PopupMenuItem(value: 'hinzu', child: Text('Event hinzufügen')),
        PopupMenuItem(value: 'weg', child: Text('Event löschen')),
      ],
    );

    if (result == 'hinzu') {
      _showEventHinzufuegenDialog(); // Hinzufügen
    } else if (result == 'weg') {
      _showEventsLoeschenDialog(); // Löschen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_auswahlmodusE
            ? '${_markierteEvents.length} ausgewählt'
            : '${widget.kategorie} Events'),
        actions: [
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _markierteEvents.isEmpty
                  ? null
                  : () async {
                      // 1. Alle markierten Events aus der Datenbank löschen
                      for (final ev in _markierteEvents) {
                        await DayRepo().deleteEvent(widget.kategorie, ev);
                      }

                      // 2. Auch lokal aus der Liste entfernen, damit UI aktualisiert wird
                      setState(() {
                        _events = DayRepo().getEvents(widget.kategorie);
                        _markierteEvents.clear();
                        _auswahlmodusE = false;
                      });
                    },
            ),
          PopupMenuButton<EventSortiermodus>(
            icon: Icon(Icons.sort),
            onSelected: (mod) {
              setState(() {
                if (_sortiermodus == mod) {
                  _ascending[mod] = !_ascending[mod]!;
                } else {
                  _sortiermodus = mod;
                }
              });
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: EventSortiermodus.alphabetisch,
                child: Text('Alphabetisch'),
              ),
              PopupMenuItem(
                value: EventSortiermodus.erstellungsdatum,
                child: Text('Erstellungsdatum'),
              ),
              PopupMenuItem(
                value: EventSortiermodus.laufzeit,
                child: Text('Dauer in Tagen'),
              ),
            ],
          ),

          ],
        ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getSortedEventsWithSpans(), // neues Future
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final eventsWithSpans = snapshot.data!;

          return ListView.builder(
            itemCount: eventsWithSpans.length,
            itemBuilder: (context, index) {
              final eventData = eventsWithSpans[index];
              final eventName = eventData['name'] as String;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 3,
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  title: Text(
                    eventName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: _auswahlmodusE
                      ? Checkbox(
                          value: _markierteEvents.contains(eventName),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _markierteEvents.add(eventName);
                              } else {
                                _markierteEvents.remove(eventName);
                                if (_markierteEvents.isEmpty) _auswahlmodusE = false;
                              }
                            });
                          },
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              tooltip: 'Event-Info',
                              onPressed: () => _showEventInfo(eventName),
                            ),
                            IconButton(
                              onPressed: () async {
                                await BilderHelper.addBilderZuEvent(
                                  context: context,
                                  kategorie: widget.kategorie,
                                  eventName: eventName,
                                );
                                setState(() {});
                              },
                              icon: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Icons.photo, size: 28),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Icon(
                                      Icons.add_circle,
                                      size: 14,
                                      color: Colors.green.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.photo_library),
                              tooltip: 'Galerie öffnen',
                              onPressed: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GalerieScreen(
                                      kategorie: widget.kategorie,
                                      eventName: eventName,
                                    ),
                                  ),
                                );

                                if (updated == true) {
                                  setState(() {});
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.note_alt_outlined),
                              tooltip: 'Notizen öffnen',
                              onPressed: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NotizenScreen(
                                      kategorie: widget.kategorie,
                                      eventName: eventName,
                                    ),
                                  ),
                                );

                                if (updated == true) {
                                  setState(() {});
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Event umbenennen',
                              onPressed: () {
                                _showEventBearbeitenDialog(eventName);
                              },
                            ),
                          ],
                        ),
                  onTap: () {
                    if (_auswahlmodusE) {
                      setState(() {
                        if (_markierteEvents.contains(eventName)) {
                          _markierteEvents.remove(eventName);
                          if (_markierteEvents.isEmpty) _auswahlmodusE = false;
                        } else {
                          _markierteEvents.add(eventName);
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(
                            kategorie: widget.kategorie,
                            eventName: eventName,
                          ),
                        ),
                      ).then((modified) {
                        if (modified == true) setState(() {});
                      });
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      _auswahlmodusE = true;
                      _markierteEvents.add(eventName);
                    });
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMenu,
        child: Icon(Icons.add),
      ),
    );
  }

}