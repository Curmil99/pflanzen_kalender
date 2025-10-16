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

    const DayDetailScreen({
    required this.kategorie,
    required this.eventName,
    required this.selectedDate,
    Key? key,
  }) : super(key: key);

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late final String _dateKey;
  late final String _formattedDate; // Für Anzeige (TT.MM.JJJJ)
  late String _title = '' ;
  List<File> _bilder = [];
  final TextEditingController _noteCtrl = TextEditingController();

  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();

    _dateKey =
        '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';

    // 👉 Neues Format für Anzeige (TT.MM.JJJJ)
    _formattedDate = 
    '${widget.selectedDate.day.toString().padLeft(2, '0')}.${widget.selectedDate.month.toString().padLeft(2, '0')}.${widget.selectedDate.year}';
    
    
  }

 

  Future<void> _saveEntry() async {
    final existing = await DayRepo().getEntry(widget.kategorie, widget.eventName, _dateKey);

    String finalTitle = _title;

    // Falls der Titel aktuell nur das Datum ist oder leer → nimm Event-Namen
    if (finalTitle.trim().isEmpty || finalTitle == _formattedDate) {
      finalTitle = widget.eventName;
    }

    final updated = existing ??
        DayEntry(
          kategorie: widget.kategorie,
          event: widget.eventName,
          datum: _dateKey,
          title: finalTitle,
          note: '',
          imagePaths: [],
        );

    updated.title = finalTitle;
    updated.note = _noteCtrl.text;
    updated.imagePaths = _bilder.map((f) => f.path).toList();

    await DayRepo().saveEntry(updated);
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
    final List<XFile>? picked = await ImagePicker().pickMultiImage();
    if (picked == null || picked.isEmpty) return;

    final newPaths = picked.map((x) => x.path).toList();

    // Aktuellen Eintrag aus DB holen
    final existingEntry = await DayRepo()
        .getEntry(widget.kategorie, widget.eventName, _dateKey);

    final updatedEntry = existingEntry ??
         DayEntry(
          kategorie: widget.kategorie,
          event: widget.eventName,
          datum: _dateKey,
          title: _title,
          note: _noteCtrl.text,
          imagePaths: [],
        );

    // Vorhandene Pfade beibehalten und neue hinzufügen
    final allPaths = {...updatedEntry.imagePaths, ...newPaths}.toList();
    updatedEntry.imagePaths = allPaths;

    await DayRepo().saveEntry(updatedEntry);

    // Jetzt auch im UI aktualisieren
    setState(() {
      _bilder
        ..clear()
        ..addAll(allPaths.map((p) => File(p)));
    });
  }



  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }







  @override
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DayEntry>>(
      stream: DayRepo().watchEntries(widget.kategorie, widget.eventName),
      builder: (context, snapshot) {
        if (!_initialLoaded && snapshot.hasData) {
          final entry = snapshot.data!.firstWhere(
            (e) => e.datum == _dateKey,
            orElse: () => DayEntry(
              kategorie: widget.kategorie,
              event: widget.eventName,
              datum: _dateKey,
              title: '',
              note: '',
              imagePaths: [],
            ),
          );
          
          // Wenn kein Titel gespeichert ist → Platzhalter setzen (Datum)
          if (entry.title.trim().isEmpty) {
            _title = _formattedDate; // Anzeige: z. B. 15.10.2025
          } else {
            _title = entry.title; // bereits gespeicherter Titel
          }

          
          _noteCtrl.text = entry.note;
          _bilder = entry.imagePaths.map((p) => File(p)).toList();

          _initialLoaded = true; // danach nicht mehr überschreiben
        }


        // --- DEIN GANZER Scaffold-Code kommt HIER rein ---
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: _bearbeiteTitel,
              child: Text(_title.isNotEmpty ? _title : _formattedDate),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.compare),
                tooltip: 'Vergleichen',
                onPressed: () async {
                  final date = widget.selectedDate;

                  final entries = await DayRepo()
                      .watchEntries(widget.kategorie, widget.eventName)
                      .first;

                  if (entries.isEmpty) return;

                  final startDatum = entries
                      .map((e) => DateTime.tryParse(e.datum))
                      .whereType<DateTime>()
                      .toList()
                    ..sort();

                  if (startDatum.isEmpty) return;

                  final relativerTag =
                      date.difference(startDatum.first).inDays;

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
              Expanded(
                flex: 1,
                child: _bilder.isEmpty
                    ? const Center(child: Text('Keine Bilder'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
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
                                    _bilder.removeAt(i);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const Divider(height: 1),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _noteCtrl,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: 'Notizen…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            onPressed: _bildHinzufuegen,
            child: const Icon(Icons.add_photo_alternate),
          ),

          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: () async {
                final hasNote = _noteCtrl.text.trim().isNotEmpty;
                final hasImages = _bilder.isNotEmpty;
                final hasContent = hasNote || hasImages;

                // Hole bestehenden Eintrag (falls vorhanden)
                final existing = await DayRepo().getEntry(widget.kategorie, widget.eventName, _dateKey);

                final entryToSave = DayEntry(
                  kategorie: widget.kategorie,
                  event: widget.eventName,
                  datum: _dateKey,
                  title: _title,
                  note: _noteCtrl.text,
                  imagePaths: _bilder.map((f) => f.path).toList(),
                );

                // WICHTIG: Setze die ID, wenn der Eintrag schon existiert!
                if (existing != null) {
                  entryToSave.id = existing.id;
                }

                if (hasContent) {
                  await DayRepo().saveEntry(entryToSave);
                } else {
                  await DayRepo().deleteEntry(widget.kategorie, widget.eventName, _dateKey);
                }

                Navigator.pop(context, true);
              },
              child: const Text('Alles speichern'),
            ),
          ),
        );
      },
    );
  }

}
