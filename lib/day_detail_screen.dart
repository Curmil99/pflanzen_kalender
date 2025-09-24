import 'dart:io';                     // Für File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/day_entry.dart';        // DayEntry Modell
import '../repositories/day_repo.dart';  // DayRepo Singleton
import 'vergleichsansicht.dart';



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
  late final String _dateKey;
  late String _title = '' ;
  final List<File> _bilder = [];
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    _dateKey =
        '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';

    _loadEntry();
  }

  Future<void> _loadEntry() async {
    final entry =
        await DayRepo().getEntry(widget.kategorie, widget.eventName, _dateKey);

    if (entry != null) {
      setState(() {
        _title = entry.title;
        _noteCtrl.text = entry.note;
        _bilder.clear();
        _bilder.addAll(entry.imagePaths.map((p) => File(p)));
      });
    } else {
      setState(() {
        _title =
            '${widget.selectedDate.day}.${widget.selectedDate.month}.${widget.selectedDate.year}';
      });
    }
  }

  Future<void> _saveEntry() async {
    final entry = DayEntry(
      kategorie: widget.kategorie,
      event: widget.eventName,
      datum: _dateKey,
      title: _title,
      note: _noteCtrl.text,
      imagePaths: _bilder.map((f) => f.path).toList(),
    );

    await DayRepo().saveEntry(entry);
  }

  void _bearbeiteTitel() {
    final controller = TextEditingController(text: _title);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Titel bearbeiten'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              final t = controller.text.trim();
              if (t.isNotEmpty) _title = t;
              await _saveEntry();   // speichern direkt in Isar
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _bildHinzufuegen() async {
    final List<XFile>? picked =
        await ImagePicker().pickMultiImage();

    if (picked == null || picked.isEmpty) return;

    setState(() {
      _bilder.addAll(picked.map((x) => File(x.path)));
    });

    await _saveEntry(); // sofort in Isar speichern
  }



  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }







  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _bearbeiteTitel,          // Klick → Titel editieren
           child: Text(_title.isNotEmpty ? _title : 'Neuer Eintrag'),  // Default EventName nur optisch
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.compare),
            tooltip: 'Vergleichen',
            onPressed: () async {
              final date = widget.selectedDate;

              // Alle Einträge für diese Kategorie + Event laden
              final entries = await DayRepo().watchEntries(widget.kategorie, widget.eventName).first;

              if (entries.isEmpty) return;

              // Startdatum ermitteln
              final startDatum = entries
                  .map((e) => DateTime.tryParse(e.datum))
                  .whereType<DateTime>()
                  .toList()
                ..sort();

              if (startDatum.isEmpty) return;

              final relativerTag = date.difference(startDatum.first).inDays;

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
                    itemBuilder: (context, i) => Stack(
                      children: [
                        Image.file(_bilder[i], fit: BoxFit.cover),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _bilder.removeAt(i); // Nur lokal löschen
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.remove, color: Colors.white, size: 20),
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
          onPressed: () async {
            final hasContent = _noteCtrl.text.trim().isNotEmpty || _bilder.isNotEmpty;

            final entry = DayEntry(
              kategorie: widget.kategorie,
              event: widget.eventName,
              datum: _dateKey,
              title: _title,
              note: _noteCtrl.text,
              imagePaths: _bilder.map((f) => f.path).toList(),
            );

            if (hasContent) {
              await DayRepo().saveEntry(entry); // <-- nur noch Entry übergeben
            } else {
              await DayRepo().deleteEntry(widget.kategorie, widget.eventName, _dateKey);
            }

            Navigator.pop(context, true); // Kalender sofort neu zeichnen
          },
          child: const Text('Alles speichern'),
        ),
      ),



    );
  }
}
