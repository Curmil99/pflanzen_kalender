import 'package:flutter/material.dart';
import 'event_detail_screen.dart';
//import 'day_detail_screen.dart';
import '../repositories/day_repo.dart'; 


void main() {
  runApp(PflanzenApp());
}

class PflanzenApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pflanzen Kalender',
      theme: ThemeData(primarySwatch: Colors.green),
      home: KategorieListeScreen(),
    );
  }
}

class KategorieListeScreen extends StatefulWidget {
  @override
  _KategorieListeScreenState createState() => _KategorieListeScreenState(); // Erstellt den State für den Screen
}

class _KategorieListeScreenState extends State<KategorieListeScreen> {
  List<String> kategorien = ['Pflanzen', 'Kinder', 'Sonstiges']; // Liste mit Kategorien, änderbar

  void _showKategorieHinzufuegenDialog() {    // Funktion zum Hinzufügen einer neuen Kategorie
    final TextEditingController controller = TextEditingController(); // Controller fürs Texteingabefeld

    showDialog(
      context: context, // Kontext für Dialog
      builder: (context) {
        return AlertDialog( // Ein Dialogfenster
          title: Text('Kategorie hinzufügen'), // Titel im Dialog
          content: TextField(
            controller: controller, // Verbindet Textfeld mit Controller
            decoration: InputDecoration(hintText: 'Name der Kategorie'), // Hinweistext im Textfeld
            autofocus: true, // Tastatur öffnet sich automatisch
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Schließt den Dialog bei Klick auf 'Abbrechen'
              child: Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                String neuerName = controller.text.trim(); // Text aus Textfeld holen, Leerzeichen weg
                if (neuerName.isNotEmpty && !kategorien.contains(neuerName)) { // Prüfen ob Name nicht leer und nicht schon in der Liste
                  setState(() {
                    kategorien.add(neuerName); // Neue Kategorie zur Liste hinzufügen
                  });
                  Navigator.pop(context); // Dialog schließen
                }
                // Hier könnte man noch Fehlerbehandlung einbauen (z.B. Warnung bei leerem Namen)
              },
              child: Text('Hinzufügen'),
            ),
          ],
        );
      },
    );
  }


  void _showKategorieLoeschenDialog() {
    final Set<String> auswahl = {}; // speichert aktuell markierte Kategorien

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder umklammert den ganzen AlertDialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Kategorien löschen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: kategorien.map((kat) {
                    return CheckboxListTile(
                      title: Text(kat),
                      value: auswahl.contains(kat),
                      onChanged: (bool? checked) {
                        setDialogState(() {
                          // Dialog-STATE neu zeichnen
                          if (checked == true) {
                            auswahl.add(kat);
                          } else {
                            auswahl.remove(kat);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Abbrechen'),
                ),
                ElevatedButton(
                  // Button ist nur aktiv, wenn mindestens eine Kategorie ausgewählt ist
                  onPressed: auswahl.isEmpty
                      ? null
                      : () {
                          setState(() {
                            kategorien.removeWhere((kat) => auswahl.contains(kat));
                          });
                          Navigator.pop(context); // Dialog schließen
                        },
                  child: Text('Löschen'),
                ),
              ],
            );
          },
        );
      },
    );
  }



  void _showMenu() async {
    final result = await showMenu<String>(
      context: context, // Kontext für das Menü
      position: RelativeRect.fromLTRB(1000, 600, 10, 10), // Position des Menüs auf dem Bildschirm (kann angepasst werden)
      items: [
        PopupMenuItem(
          value: 'hinzufuegen', // Wert wenn ausgewählt
          child: Text('Kategorie hinzufügen'), // Text im Menüpunkt
        ),
        PopupMenuItem(
          value: 'loeschen',
          child: Text('Kategorie löschen'), // Noch nicht implementiert
        ),
      ],
    );

    if (result == 'hinzufuegen') {
      _showKategorieHinzufuegenDialog(); // Wenn 'Kategorie hinzufügen' gewählt wurde, Dialog öffnen
    } else if (result == 'loeschen') {
    _showKategorieLoeschenDialog(); // Hier den Lösch-Dialog öffnen
    }
    // Lösch-Funktion kann hier später ergänzt werden
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kategorien')), // Kopfzeile mit Titel
      body: ListView.builder(
        itemCount: kategorien.length, // Anzahl der Listeneinträge
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(kategorien[index]), // Text der Kategorie
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventListeScreen(
                    kategorie: kategorien[index],

                    ), // Öffnet die Event-Liste der Kategorie
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMenu, // Beim Klick öffnet sich das Menü
        child: Icon(Icons.add), // Plus-Symbol im Button
      ),
    );
  }
}

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

class _EventListeScreenState extends State<EventListeScreen> {
  // Map speichert für jede Kategorie ihre eigene Event‑Liste.
  // => In einer echten App wäre das eine DB‑Abfrage; für jetzt Memory‑Storage.
  static final Map<String, List<String>> _eventStore = {
    'Pflanzen': ['2023', '2024', '2025'],
    'Kinder': ['2021', '2022'],
    'Sonstiges': ['Test'],
  };

  List<String> get _events =>
      _eventStore.putIfAbsent(widget.kategorie, () => []); // Events der aktuellen Kategorie

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
                setState(() => _events.add(name)); // Event hinzufügen
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
                  ? null // deaktiviert, wenn nichts markiert
                  : () {
                      setState(() => _events.removeWhere(auswahl.contains));
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
  int _spanInTagen(String event) {
    final dateMap = DayRepo().allEntries[widget.kategorie]?[event];
    if (dateMap == null || dateMap.isEmpty) return 0;

    // alle Datum‑Strings (YYYY‑MM‑DD) sortieren
    final dates = dateMap.keys.toList()..sort();
    final first = DateTime.parse(dates.first);
    final last  = DateTime.parse(dates.last);

    // Differenz inkl. beider Tage → +1
    return last.difference(first).inDays + 1;
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
      appBar: AppBar(title: Text('${widget.kategorie} Events')),
      body: ListView.builder(
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          final span  = _spanInTagen(event);              // Tage‑Abstand berechnen
          
          return ListTile(
            title: Text(event),
            trailing: Text('$span'),               // Zahl anzeigen
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(
                    kategorie: widget.kategorie,   // aktuelle Kategorie
                    eventName: event,              // *dieses* Event
                  ),
                ),
              ).then((modified) {
                if (modified == true) {
                  setState(() {});                // sofort neu berechnen + anzeigen
                }
              });
            },
          );

        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showMenu, // Menü öffnen
        child: Icon(Icons.add), // Plus‑Icon
      ),
    );
  }
}

