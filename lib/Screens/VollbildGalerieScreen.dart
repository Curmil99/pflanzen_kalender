import 'dart:io';
import 'package:flutter/material.dart';
import '../models/day_entry.dart';
import '../day_detail_screen.dart';

class VollbildGalerieScreen extends StatefulWidget {
  final List<String> bilder;
  final List<DayEntry> eintraege;
  final String kategorie;
  final String eventName;
  final int startIndex;
  final Future<void> Function()? onChanged; // Callback

  const VollbildGalerieScreen({
    super.key,
    required this.bilder,
    required this.eintraege,
    required this.kategorie,
    required this.eventName,
    required this.startIndex,
    this.onChanged,
  });

  @override
  State<VollbildGalerieScreen> createState() => _VollbildGalerieScreenState();
}

class _VollbildGalerieScreenState extends State<VollbildGalerieScreen> {
  late PageController _controller;
  int _aktuellerIndex = 0;

  @override
  void initState() {
    super.initState();
    _aktuellerIndex = widget.startIndex;
    _controller = PageController(initialPage: _aktuellerIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView.builder(
        controller: _controller,
        itemCount: widget.bilder.length,
        onPageChanged: (index) => setState(() => _aktuellerIndex = index),
        itemBuilder: (context, index) {
          final pfad = widget.bilder[index];
          final entry = widget.eintraege.firstWhere((e) => e.imagePaths.contains(pfad));

          return Stack(
            children: [
              Center(child: Image.file(File(pfad), fit: BoxFit.contain)),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DayDetailScreen(
                          kategorie: widget.kategorie,
                          eventName: widget.eventName,
                          selectedDate: DateTime.parse(entry.datum),
                        ),
                      ),
                    ).then((changed) {
                      if (changed == true) {
                        Navigator.pop(context, true); // VollbildGalerie meldet Änderung zurück an GalerieScreen
                      }
                    });
                    if (widget.onChanged != null) {
                      await widget.onChanged!(); // Bilder neu laden
                    }
                  },
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}
