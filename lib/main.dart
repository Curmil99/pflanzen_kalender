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
                    eventName: 'hier bin ich',
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
  final String eventName;
  final String kategorie;
  final DateTime selectedDate;

  EventListeScreen({
    required this.eventName,
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
            trailing: Text('$span'),                      // Zahl anzeigen
            onTap: () {
                            // Beim Navigieren zum DayDetailScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(
                    kategorie: widget.kategorie,
                    eventName: event,
                   
                  ),
                ),
              ).then((saved) {
                if (saved == true) {
                  setState(() {
                    // trigger Neu-Laden oder Refresh
                  });
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




/*
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
*/