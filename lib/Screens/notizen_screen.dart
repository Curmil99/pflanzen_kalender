import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/day_repo.dart';
import '../models/day_entry.dart';

class NotizenScreen extends StatefulWidget {
  final String kategorie;
  final String eventName;

  const NotizenScreen({
    Key? key,
    required this.kategorie,
    required this.eventName,
  }) : super(key: key);

  @override
  State<NotizenScreen> createState() => _NotizenScreenState();
}

class _NotizenScreenState extends State<NotizenScreen> {
  final _repo = DayRepo();
  List<DayEntry> _alleEintraege = [];
  bool _aufsteigend = false;
  bool _etwasGeaendert = false;

  @override
  void initState() {
    super.initState();
    _ladeEintraege();
  }

  Future<void> _ladeEintraege() async {
    // Nur beim ersten Laden wirklich aus dem Repo holen
    if (_alleEintraege.isEmpty) {
      final eintraege =
          await _repo.watchEntries(widget.kategorie, widget.eventName).first;
      _alleEintraege = eintraege;
    }

    // Sortierung nur auf einer Kopie anwenden
    final sortierteEintraege = List<DayEntry>.from(_alleEintraege)
      ..sort((a, b) =>
          _aufsteigend ? a.datum.compareTo(b.datum) : b.datum.compareTo(a.datum));

    setState(() {
      _alleEintraege = sortierteEintraege;
    });
  }


  Future<bool> _onWillPop() async {
    if (!_etwasGeaendert) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Änderungen speichern?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ja')),
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Nein')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abbrechen')),
        ],
      ),
    );

    if (result == true) {
      await _speichereAlleEintraege();
      return true;
    } else if (result == false) {
      return true; // ohne speichern verlassen
    } else {
      return false; // abbrechen
    }
  }

  Future<void> _speichereAlleEintraege() async {
    for (final entry in _alleEintraege) {
      await _repo.saveEntry(entry);
    }
    _etwasGeaendert = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Änderungen gespeichert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd.MM.yyyy');

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.eventName} Notizen'),
          actions: [
            IconButton(
              icon: Icon(_aufsteigend ? Icons.arrow_upward : Icons.arrow_downward),
              tooltip: _aufsteigend ? 'Von alt zu neu' : 'Von neu zu alt',
              onPressed: () {
                setState(() => _aufsteigend = !_aufsteigend);
                _ladeEintraege();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: _alleEintraege.isEmpty
              ? const Center(
                child: Text('Keine Einträge vorhanden',
                    style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _alleEintraege.length,
                itemBuilder: (context, index) {
                  final entry = _alleEintraege[index];
                  final datum =
                      format.format(DateTime.parse(entry.datum));

                  final controller =
                      TextEditingController(text: entry.note);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title.trim() != datum
                                ? '$datum – ${entry.title.isNotEmpty ? entry.title : widget.eventName}'
                                : datum,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller,
                            maxLines: null,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Notiz hier eingeben...',
                            ),
                            onChanged: (text) {
                              entry.note = text;
                              _etwasGeaendert = true;
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}
