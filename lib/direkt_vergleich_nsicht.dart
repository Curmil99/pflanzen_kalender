import 'dart:io';
import 'package:flutter/material.dart';
import '../models/Nerv1.dart';

class DirektVergleichAnsicht extends StatefulWidget {
  final Vergleichseintrag aktuellerEintrag;
  final List<Vergleichseintrag> vergleichsEintraege;

  const DirektVergleichAnsicht({
    super.key,
    required this.aktuellerEintrag,
    required this.vergleichsEintraege,
  });

  @override
  State<DirektVergleichAnsicht> createState() => _DirektVergleichAnsichtState();
}

class _DirektVergleichAnsichtState extends State<DirektVergleichAnsicht> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final vergleichsEintrag = widget.vergleichsEintraege[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Direkter Vergleich')),
      body: Column(
        children: [
          // Oberes Bild: aktuelles Event
          Expanded(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.file(
                File(widget.aktuellerEintrag.eintrag.imagePaths.first),
                fit: BoxFit.contain,
              ),
            ),
          ),

          Divider(thickness: 2),

          // Unteres Bild: Vergleichsbild
          Expanded(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.file(
                File(vergleichsEintrag.eintrag.imagePaths.first),
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Button zum Wechseln
          if (_currentIndex < widget.vergleichsEintraege.length - 1)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentIndex++;
                  });
                },
                icon: Icon(Icons.arrow_right),
                label: Text(widget.vergleichsEintraege[_currentIndex + 1].eventName),
              ),
            ),
        ],
      ),
    );
  }
}
