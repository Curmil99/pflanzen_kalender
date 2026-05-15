import 'package:flutter/material.dart';
import '../repositories/day_repo.dart'; 
import '../Screens/events_screen.dart';


class KategorieListeScreen extends StatefulWidget {
  @override
  _KategorieListeScreenState createState() => _KategorieListeScreenState(); // Erstellt den State für den Screen
}

class _KategorieListeScreenState extends State<KategorieListeScreen> {
  List<String> kategorien = [];

  bool _auswahlmodusK = false;   // ob wir gerade mehrere Kategorien zum Löschen markieren
  Set<String> _markierteKategorien = {};

  @override
  void initState() {
    super.initState();
    kategorien = List<String>.from(DayRepo().getKategorien());
  }

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
              onPressed: () async {
                String neuerName = controller.text.trim(); // Text aus Textfeld holen, Leerzeichen weg
                if (neuerName.isNotEmpty) {
                  final added = await DayRepo().addKategorie(neuerName);
                  if (added) {
                    setState(() {
                      kategorien.add(neuerName); // Neue Kategorie zur Liste hinzufügen
                    });
                    Navigator.pop(context); // Dialog schließen
                  }
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
    final Set<String> auswahl = {};

    showDialog(
      context: context,
      builder: (context) {
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
                  onPressed: auswahl.isEmpty
                      ? null
                      : () async {
                          // 1. Alle markierten Kategorien aus der Datenbank löschen
                          for (final kat in auswahl) {
                            await DayRepo().deleteKategorie(kat);
                          }
                          // 2. Auch lokal aus der Liste entfernen, damit UI aktualisiert wird
                          setState(() => kategorien.removeWhere(auswahl.contains));
                          Navigator.pop(context);
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
      appBar: AppBar(
        title: Text(
          _auswahlmodusK
              ? '${_markierteKategorien.length} ausgewählt'
              : 'Kategorien',
        ),
        actions: [
          if (_auswahlmodusK)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _markierteKategorien.isEmpty
                  ? null
                  : () async {
                      // 1. Löschen aus Datenbank (wenn du das in DayRepo hast)
                      for (final kat in _markierteKategorien) {
                        await DayRepo().deleteKategorie(kat);
                      }

                      // 2. Lokal aus Liste entfernen
                      setState(() {
                        kategorien.removeWhere(_markierteKategorien.contains);
                        _markierteKategorien.clear();
                        _auswahlmodusK = false;
                      });
                    },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          itemCount: kategorien.length,
        itemBuilder: (context, index) {
          final kategorie = kategorien[index];

          return ListTile(
            title: Text(kategorie),
            trailing: _auswahlmodusK
                ? Checkbox(
                    value: _markierteKategorien.contains(kategorie),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _markierteKategorien.add(kategorie);
                        } else {
                          _markierteKategorien.remove(kategorie);
                          if (_markierteKategorien.isEmpty) {
                            _auswahlmodusK = false;
                          }
                        }
                      });
                    },
                  )
                : const Icon(Icons.folder),
            onTap: () {
              if (_auswahlmodusK) {
                setState(() {
                  if (_markierteKategorien.contains(kategorie)) {
                    _markierteKategorien.remove(kategorie);
                    if (_markierteKategorien.isEmpty) _auswahlmodusK = false;
                  } else {
                    _markierteKategorien.add(kategorie);
                  }
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventListeScreen(kategorie: kategorie),
                  ),
                );
              }
            },
            onLongPress: () {
              setState(() {
                _auswahlmodusK = true;
                _markierteKategorien.add(kategorie);
              });
            },
          );
        },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMenu,
        child: const Icon(Icons.add),
      ),
    );
  }
}