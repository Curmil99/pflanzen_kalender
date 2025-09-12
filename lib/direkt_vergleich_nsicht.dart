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
  late PageController _topPageController;
  late PageController _bottomPageController; // <-- hier
  int _topImageIndex = 0;
  int _bottomImageIndex = 0;

  late Vergleichseintrag _topEntry;
  late Vergleichseintrag _bottomEntry;

  @override
  void initState() {
    super.initState();
    _topEntry = widget.aktuellerEintrag;
    _bottomEntry = widget.vergleichsEintraege.first;

    _topPageController = PageController();
    _bottomPageController = PageController(); // <-- hier
  }

  @override
  void dispose() {
    _topPageController.dispose();
    _bottomPageController.dispose(); // <-- hier
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final alleEintraege = [widget.aktuellerEintrag, ...widget.vergleichsEintraege];
    
    return Scaffold(
      appBar: AppBar(title: Text('Direkter Vergleich')),
      body: Column(
        children: [
          // Oberes Bild + Dropdown
          Expanded(
            child: Column(
              children: [
                // Oberes Dropdown
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: SizedBox(
                      width: 200,
                      child: DropdownButton<Vergleichseintrag>(
                        value: _topEntry,
                        isExpanded: true,
                        items: alleEintraege.map((e) {
                          String label = e.eventName;
                          if (e == _bottomEntry) label += " (unten)";
                          return DropdownMenuItem(
                            value: e,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (Vergleichseintrag? newEntry) {
                          if (newEntry != null) {
                            setState(() {
                              _topEntry = newEntry;
                              _topImageIndex = 0;
                              _topPageController.jumpToPage(0);
                            });
                          }
                        },
                      ),
                  ),
                ),
                ),

                // PageView oben
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _topPageController,
                        itemCount: _topEntry.eintrag.imagePaths.length,
                        onPageChanged: (index) {
                          setState(() => _topImageIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return InteractiveViewer(
                            panEnabled: true,
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.file(
                              File(_topEntry.eintrag.imagePaths[index]),
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                      if (_topImageIndex > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {
                              _topPageController.previousPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
                            },
                            child: Container(
                              width: 50,
                              color: Colors.black26,
                              child: Icon(Icons.arrow_left, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                      // Rechter Pfeil nur sichtbar, wenn nicht letztes Bild
                      if (_topImageIndex < _topEntry.eintrag.imagePaths.length - 1)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {
                              _topPageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
                            },
                            child: Container(
                              width: 50,
                              color: Colors.black26,
                              child: Icon(Icons.arrow_right, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(thickness: 2),

          // Unteres Bild + Dropdown
          Expanded(
            child: Column(
              children: [
                // Unteres Dropdown
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: SizedBox(
                      width: 200,
                      child: DropdownButton<Vergleichseintrag>(
                        value: _bottomEntry,
                        isExpanded: true,
                        items: alleEintraege.map((e) {
                          String label = e.eventName;
                          if (e == _topEntry) label += " (oben)";
                          return DropdownMenuItem(
                            value: e,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (Vergleichseintrag? newEntry) {
                          if (newEntry != null) {
                            setState(() {
                              _bottomEntry = newEntry;
                              _bottomImageIndex = 0;
                              _bottomPageController.jumpToPage(0);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),

                // PageView unten
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _bottomPageController,
                        itemCount: _bottomEntry.eintrag.imagePaths.length,
                        onPageChanged: (index) {
                          setState(() => _bottomImageIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return InteractiveViewer(
                            panEnabled: true,
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.file(
                              File(_bottomEntry.eintrag.imagePaths[index]),
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                      if (_bottomImageIndex > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {
                              _bottomPageController.previousPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
                            },
                            child: Container(
                              width: 50,
                              color: Colors.black26,
                              child: Icon(Icons.arrow_left, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                      // Rechter Pfeil nur sichtbar, wenn nicht letztes Bild
                      if (_bottomImageIndex < _topEntry.eintrag.imagePaths.length - 1)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {
                              _bottomPageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
                            },
                            child: Container(
                              width: 50,
                              color: Colors.black26,
                              child: Icon(Icons.arrow_right, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
