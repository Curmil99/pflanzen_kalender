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

    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bilder löschen'),
        content: Text(
          _markierteBilder.length == 1
              ? 'Willst du dieses Bild wirklich löschen?'
              : 'Willst du diese ${_markierteBilder.length} Bilder wirklich löschen?',
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

    final repo = DayRepo();
    final eintraege =
        await repo.watchEntries(widget.kategorie, widget.eventName).first;

    final Set<String> deletedFiles = {};
    int deletedCount = 0;

    for (final entry in eintraege) {
      final zuLoeschende =
          entry.imagePaths.where((p) => _markierteBilder.contains(p)).toList();
      if (zuLoeschende.isEmpty) continue;

      entry.imagePaths =
          entry.imagePaths.where((p) => !_markierteBilder.contains(p)).toList();

      final hasTitle = entry.title.trim().isNotEmpty;
      final hasNote = entry.note.trim().isNotEmpty;
      final hasImages = entry.imagePaths.isNotEmpty;

      if (!hasTitle && !hasNote && !hasImages) {
        await repo.deleteEntry(entry.kategorie, entry.event, entry.datum);
      } else {
        await repo.saveEntry(entry);
      }

      for (final pfad in zuLoeschende) {
        if (deletedFiles.contains(pfad)) continue;
        deletedFiles.add(pfad);
        try {
          final file = File(pfad);
          if (await file.exists()) await file.delete();
        } catch (_) {}
        deletedCount++;
      }
    }

    setState(() {
      _auswahlmodus = false;
      _markierteBilder.clear();
    });

    await _ladeBilder();

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

    return Scaffold(
      appBar: AppBar(
        title: Text(_auswahlmodus
            ? '${_markierteBilder.length} ausgewählt'
            : '${widget.eventName} Galerie'),
        actions: [
          // Sortier-Button
          IconButton(
            icon: Icon(_aufsteigend ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip: _aufsteigend ? 'Von alt zu neu' : 'Von neu zu alt',
            onPressed: () {
              setState(() => _aufsteigend = !_aufsteigend);
              _ladeBilder();
            },
          ),
          // Lösch-Button
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
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }
}
