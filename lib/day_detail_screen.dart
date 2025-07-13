import 'dart:io';                     // Für File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/day_entry.dart';        // DayEntry Modell
import '../repositories/day_repo.dart';  // DayRepo Singleton
import 'VergleichsAnsicht.dart';



class DayDetailScreen extends StatefulWidget {
  final String kategorie;             // z.B. "Pflanzen"
  final String eventName;             // z.B. "2025"
  final DateTime selectedDate;        // angeklicktes Datum

  DayDetailScreen({
    required this.kategorie,
    required this.eventName,
    required this.selectedDate,
  });

  @override
  _DayDetailScreenState createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late final String _dateKey;     // <- oben im State anlegen (late final)
  late String _title;                        // aktueller Titel (editierbar)
  final List<File> _bilder = [];             // lokale Bild‑Liste
  final TextEditingController _noteCtrl =
      TextEditingController();               // Notizen‑Feld

  @override
  void initState() {
    super.initState();

    // Schlüssel (Datum als String)
    final dateKey = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2,'0')}-${widget.selectedDate.day.toString().padLeft(2,'0')}';

    _dateKey = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2,'0')}-${widget.selectedDate.day.toString().padLeft(2,'0')}';

    // Gespeicherte DayEntry aus dem Singleton holen
    final savedEntry = DayRepo().getEntry(widget.kategorie, widget.eventName, dateKey);

    if (savedEntry != null) {
      _title = savedEntry.title;                          // Titel laden
      _noteCtrl.text = savedEntry.note;                   // Notiz laden
      _bilder.clear();
      _bilder.addAll(savedEntry.imagePaths.map((path) => File(path))); // Bilder laden (Dateipfade in File-Objekte)
    } else {
      _title = '${widget.selectedDate.day}.${widget.selectedDate.month}.${widget.selectedDate.year}';
    }
  }

  DateTime? _getStartDatum(Map<String, DayEntry> dateMap) {
    final dates = dateMap.keys
        .map((k) => DateTime.tryParse(k))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }



  /* ---------- Titel bearbeiten ---------- */
  void _bearbeiteTitel() {
    final controller = TextEditingController(text: _title);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Titel bearbeiten'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              setState(() => _title = controller.text.trim().isEmpty ? _title : controller.text.trim());
              _speichereAktuellenEintrag();   // Änderung speichern
              Navigator.pop(context);
            },
            child: Text('Speichern'),
          ),
        ],
      ),
    );
  }

  /* ---------- Bild aus Galerie hinzufügen ---------- */
  Future<void> _bildHinzufuegen() async {
    final List<XFile> picked =
      await ImagePicker().pickMultiImage();   // <– statt pickImage

    if (picked.isNotEmpty) {
    setState(() {
      _bilder.addAll(picked.map((x) => File(x.path)));  // alle Pfade übernehmen
    });
    _speichereAktuellenEintrag();  // falls du direkt nach Picker speichern willst
  }
}

  void _speichereAktuellenEintrag() {
    final dateKey = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2,'0')}-${widget.selectedDate.day.toString().padLeft(2,'0')}';

    final entry = DayEntry(
      kategorie: widget.kategorie,
      event: widget.eventName,
      datum: dateKey,
      title: _title,
      note: _noteCtrl.text,
      imagePaths: _bilder.map((f) => f.path).toList(),
    );

  
    final bool hasContent = _title.trim().isNotEmpty || _noteCtrl.text.trim().isNotEmpty || _bilder.isNotEmpty;
    if (hasContent) {
      DayRepo().saveEntry(widget.kategorie, widget.eventName, dateKey, entry);
    } else {
      DayRepo().deleteEntry(widget.kategorie, widget.eventName, dateKey);
    }
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _bearbeiteTitel,          // Klick → Titel editieren
          child: Text(_title),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.compare),
            tooltip: 'Vergleichen',
            onPressed: () {
              final date = widget.selectedDate;
              final katMap = DayRepo().allEntries[widget.kategorie];
              final currentEventMap = katMap?[widget.eventName];

              if (currentEventMap == null) return;

              final startDatum = _getStartDatum(currentEventMap);
              if (startDatum == null) return;

              final relativerTag = date.difference(startDatum).inDays;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VergleichsAnsicht(
                    aktuellesEventName: widget.eventName,
                    kategorie: widget.kategorie,
                    aktuellerTag: relativerTag,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(                               // obere Hälfte – Bilder
            flex: 1,
            child: _bilder.isEmpty
                ? Center(child: Text('Keine Bilder'))
                : GridView.builder(
                    padding: EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,         // 3 Bilder pro Zeile
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _bilder.length,
                    itemBuilder: (context, i) => Stack(                           // 1. Stack als Container für Bild + Icon
                    children: [
                      Image.file(_bilder[i], fit: BoxFit.cover),                // 2. Bild anzeigen
                      Positioned(                                               // 3. Minus-Icon oben rechts positionieren
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            // final removedPath = _bilder[i].path;      // Pfad merken
                            setState(() => _bilder.removeAt(i));      // aus UI‑Liste raus
                            // DayRepo().deleteImage(                    // auch im RAM‑Repo löschen
                            //   widget.kategorie,
                            //   widget.eventName,
                            //   _dateKey,                               // YYYY‑MM‑DD
                            //   removedPath,
                            // );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.remove, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
          Divider(height: 1),
          Expanded(                               // untere Hälfte – Notizfeld
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _noteCtrl,
                maxLines: null,                  // beliebig viele Zeilen
                expands: true,                   // füllt gesamten Platz
                decoration: InputDecoration(
                  hintText: 'Notizen…',
                  border: OutlineInputBorder(),
                ),
               // onChanged: (_) => _speichereAktuellenEintrag(),   // ← sofort speichern
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _bildHinzufuegen,             // Bild aus Galerie wählen
        child: Icon(Icons.add_photo_alternate),
      ),
      
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: ElevatedButton(
          onPressed: () {
            final bool hasContent =
                 _title.trim().isNotEmpty || _noteCtrl.text.trim().isNotEmpty || _bilder.isNotEmpty;

            if (hasContent) {
              // speichern
              DayRepo().saveEntry(
                widget.kategorie,
                widget.eventName,
                _dateKey,
                DayEntry(
                  kategorie: widget.kategorie,
                  event: widget.eventName,
                  datum: _dateKey,
                  title: _title,
                  note: _noteCtrl.text,
                  imagePaths: _bilder.map((f) => f.path).toList(),
                ),
              );
            } else {
              // alles leer -> Eintrag komplett entfernen
              DayRepo().deleteEntry(
                widget.kategorie,
                widget.eventName,
                _dateKey,
              );
            }

            Navigator.pop(context, true); // Kalender sofort neu zeichnen
          },
          child: const Text('Alles speichern'),
        ),
      ),


    );
  }
}
