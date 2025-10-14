import 'dart:io';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart'; // für firstWhereOrNull
import '../repositories/day_repo.dart';
import '../models/day_entry.dart';
import '../Screens/VollbildGalerieScreen.dart';

class GalerieScreen extends StatefulWidget {
  final String kategorie;
  final String eventName;

  const GalerieScreen({
    Key? key,
    required this.kategorie,
    required this.eventName,
  }) : super(key: key);

  @override
  State<GalerieScreen> createState() => _GalerieScreenState();
}

class _GalerieScreenState extends State<GalerieScreen> {
  List<String> _alleBilder = [];
  List<DayEntry> _alleEintraege = [];
  bool _auswahlmodus = false;
  Set<String> _markierteBilder = {};
  bool _aufsteigend = false; // false = neueste zuerst
  bool _etwasGeaendert = false;  //um UI in EventScreen zu aktualisieren


  @override
  void initState() {
    super.initState();
    _ladeBilder();
  }

  Future<void> _ladeBilder() async {
    final repo = DayRepo();
    final eintraege =
        await repo.watchEntries(widget.kategorie, widget.eventName).first;

    // sortieren
    eintraege.sort((a, b) => _aufsteigend
        ? a.datum.compareTo(b.datum)
        : b.datum.compareTo(a.datum));

    // Duplikate entfernen
    final Set<String> uniquePaths = {};
    final List<String> alleBilder = [];
    for (final entry in eintraege) {
      for (final pfad in entry.imagePaths) {
        if (uniquePaths.add(pfad)) alleBilder.add(pfad);
      }
    }

    setState(() {
      _alleEintraege = eintraege;
      _alleBilder = alleBilder;
    });
  }

  Future<void> _oeffneVollbild(int startIndex) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VollbildGalerieScreen(
          bilder: _alleBilder,
          startIndex: startIndex,
          eintraege: _alleEintraege,
          kategorie: widget.kategorie,
          eventName: widget.eventName,
        ),
      ),
    );

    // Wenn im Vollbild Änderungen gemacht wurden → neu laden
    // Wenn in Vollbild Änderungen an den Einträgen gemacht wurden, neu laden
    if (changed == true) {
      _ladeBilder();
    }
  }

  void _toggleAuswahlmodus(String bildPfad) {
    setState(() {
      _auswahlmodus = true;
      if (_markierteBilder.contains(bildPfad)) {
        _markierteBilder.remove(bildPfad);
        if (_markierteBilder.isEmpty) _auswahlmodus = false;
      } else {
        _markierteBilder.add(bildPfad);
      }
    });
  }

  Future<void> _loescheMarkierteBilder() async {
  if (_markierteBilder.isEmpty) return;

  final repo = DayRepo();
  final eintraege = await repo.watchEntries(widget.kategorie, widget.eventName).first;

  // 1. Vorab berechnen, wie viele Einträge durch das Löschen leer werden
  int zuLoeschendeEintraege = 0;
  for (final entry in eintraege) {
    final neueBilder = entry.imagePaths.where((p) => !_markierteBilder.contains(p)).toList();
    final hasNote = entry.note.trim().isNotEmpty;
    final hasImages = neueBilder.isNotEmpty;
    if (!hasNote && !hasImages) {
      zuLoeschendeEintraege++;
    }
  }

  // 2. Dialog anzeigen
  final bestaetigt = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Bilder löschen'),
      content: Text(
        _markierteBilder.length == 1
            ? 'Willst du dieses Bild wirklich löschen?'
            : 'Du hast ${_markierteBilder.length} Bilder ausgewählt.'
              '${zuLoeschendeEintraege > 0
                ? '\nMit dem Löschen werden auch $zuLoeschendeEintraege Eventeinträge vollständig gelöscht.'
                : ''}'
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen')),
      ],
    ),
  );

  if (bestaetigt != true) return;

  // 3. Bilder wirklich löschen
  final deletedFiles = <String>{};
  int deletedCount = 0;

  for (final entry in eintraege) {
    // Entferne alle markierten Bilder aus diesem Eintrag
    final neueBilder = entry.imagePaths.where((p) => !_markierteBilder.contains(p)).toList();

    // Prüfen, ob noch Inhalte vorhanden sind
    final hasNote = entry.note.trim().isNotEmpty;
    final hasImages = neueBilder.isNotEmpty;

    // Hole das Original aus der DB, um die ID zu haben
    final existing = await repo.getEntry(entry.kategorie, entry.event, entry.datum);
    if (existing != null) {
      entry.id = existing.id;
    }

    if (!hasNote && !hasImages) {
      // Wenn nichts mehr übrig ist → Eintrag löschen
      await repo.deleteEntry(entry.kategorie, entry.event, entry.datum);
    } else {
      // Wenn noch Inhalt da ist → Eintrag speichern (mit neuen Bildern)
      entry.imagePaths = neueBilder;
      await repo.saveEntry(entry);
    }
  }

  // Datei physisch löschen (nur einmal pro Bild)
  for (final bildPfad in _markierteBilder) {
    if (!deletedFiles.contains(bildPfad)) {
      deletedFiles.add(bildPfad);
      try {
        final file = File(bildPfad);
        if (await file.exists()) await file.delete();
        deletedCount++;
      } catch (_) {}
    }
  }

  // UI und interne Listen aktualisieren
  _alleBilder.removeWhere((pfad) => _markierteBilder.contains(pfad));
  _markierteBilder.clear();
  _auswahlmodus = false;

  setState(() {});
  await _ladeBilder();

  if (deletedCount > 0) {
    _etwasGeaendert = true;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(deletedCount == 0
          ? 'Keine Dateien gelöscht'
          : deletedCount == 1
              ? '1 Bild gelöscht'
              : '$deletedCount Bilder gelöscht'),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final hatBilder = _alleBilder.isNotEmpty;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _etwasGeaendert);
        return false; // verhindert doppeltes Poppen
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_auswahlmodus
              ? '${_markierteBilder.length} ausgewählt'
              : '${widget.eventName} Galerie'),
          actions: [
            IconButton(
              icon: Icon(_aufsteigend ? Icons.arrow_upward : Icons.arrow_downward),
              tooltip: _aufsteigend ? 'Von alt zu neu' : 'Von neu zu alt',
              onPressed: () {
                setState(() => _aufsteigend = !_aufsteigend);
                _ladeBilder();
              },
            ),
            if (_auswahlmodus)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed:
                    _markierteBilder.isEmpty ? null : _loescheMarkierteBilder,
              ),
          ],
        ),
        body: hatBilder
            ? GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: _alleBilder.length,
                itemBuilder: (context, index) {
                  final bildPfad = _alleBilder[index];
                  final markiert = _markierteBilder.contains(bildPfad);

                  return GestureDetector(
                    onTap: () {
                      if (_auswahlmodus) {
                        _toggleAuswahlmodus(bildPfad);
                      } else {
                        _oeffneVollbild(index);
                      }
                    },
                    onLongPress: () => _toggleAuswahlmodus(bildPfad),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(File(bildPfad), fit: BoxFit.cover),
                        ),
                        if (markiert)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: Icon(Icons.check_circle,
                                  color: Colors.white, size: 32),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              )
            : const Center(
                child: Text('Keine Bilder vorhanden',
                    style: TextStyle(color: Colors.grey)),
              ),
        floatingActionButton: _auswahlmodus
            ? FloatingActionButton.extended(
                onPressed: _loescheMarkierteBilder,
                label: const Text('Löschen'),
                icon: const Icon(Icons.delete),
              )
            : null,
      ),
    );
  }

}
