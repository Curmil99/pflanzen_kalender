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
  late PageController _aktuellerPageController;
  late PageController _vergleichPageController;

  int _aktuellerImageIndex = 0;
  int _vergleichImageIndex = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _aktuellerPageController = PageController();
    _vergleichPageController = PageController();
  }

  @override
  void dispose() {
    _aktuellerPageController.dispose();
    _vergleichPageController.dispose();
    super.dispose();
  }

    Widget _buildNavigationButtons({
      required VoidCallback onPrevious,
      required VoidCallback onNext,
    }) {
      return Positioned.fill(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Linker Button
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onPrevious,
              child: Container(
                width: 50,
                color: Colors.black26,
                child: Icon(Icons.arrow_left, color: Colors.white, size: 40),
              ),
            ),

            // Rechter Button
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onNext,
              child: Container(
                width: 50,
                color: Colors.black26,
                child: Icon(Icons.arrow_right, color: Colors.white, size: 40),
              ),
            ),
          ],
        ),
      );
    }


  @override
  Widget build(BuildContext context) {
    final Vergleichseintrag vergleichsEintrag = widget.vergleichsEintraege[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Direkter Vergleich')),
      body: Column(
        children: [
          // Oberes Bild
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _aktuellerPageController,
                  itemCount: widget.aktuellerEintrag.eintrag.imagePaths.length,
                  onPageChanged: (index) {
                    setState(() => _aktuellerImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      panEnabled: true,
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image.file(
                        File(widget.aktuellerEintrag.eintrag.imagePaths[index]),
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                _buildNavigationButtons(
                  onPrevious: () {
                    if (_aktuellerImageIndex > 0) {
                      _aktuellerPageController.previousPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  onNext: () {
                    if (_aktuellerImageIndex < widget.aktuellerEintrag.eintrag.imagePaths.length - 1) {
                      _aktuellerPageController.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          Divider(thickness: 2),

          // Unteres Bild
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _vergleichPageController,
                  itemCount: vergleichsEintrag.eintrag.imagePaths.length,
                  onPageChanged: (index) {
                    setState(() => _vergleichImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      panEnabled: true,
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image.file(
                        File(vergleichsEintrag.eintrag.imagePaths[index]),
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                _buildNavigationButtons(
                  onPrevious: () {
                    if (_vergleichImageIndex > 0) {
                      _vergleichPageController.previousPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  onNext: () {
                    if (_vergleichImageIndex < vergleichsEintrag.eintrag.imagePaths.length - 1) {
                      _vergleichPageController.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Button zum Wechseln des Vergleichseintrags (Jahr)
          if (widget.vergleichsEintraege.length > 1)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentIndex > 0)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentIndex--;
                          _vergleichImageIndex = 0;
                          _vergleichPageController.jumpToPage(0);
                        });
                      },
                      icon: Icon(Icons.arrow_left),
                      label: Text(widget.vergleichsEintraege[_currentIndex - 1].eventName),
                    ),
                  const SizedBox(width: 16),
                  if (_currentIndex < widget.vergleichsEintraege.length - 1)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentIndex++;
                          _vergleichImageIndex = 0;
                          _vergleichPageController.jumpToPage(0);
                        });
                      },
                      icon: Icon(Icons.arrow_right),
                      label: Text(widget.vergleichsEintraege[_currentIndex + 1].eventName),
                    ),
                ],
              ),
            )

        ],
      ),
    );
  }
}
