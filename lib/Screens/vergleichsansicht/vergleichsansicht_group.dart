import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/vergleichseintrag.dart';
import 'vergleichsansicht_shared.dart';

class VergleichsansichtGroupContent extends StatelessWidget {
  final List<Vergleichseintrag> vergleichseintraege;
  final Set<int> fixedIDs;
  final VergleichsModus modus;
  final void Function(bool forward, Vergleichseintrag eintrag) onArrowPressed;
  final void Function(Vergleichseintrag eintrag) onMakeEventMain;
  final void Function(int id, String eventName, bool fixed) onToggleFixed;
  final void Function(BuildContext context, List<String> imagePaths, int initialIndex)
      onShowImageViewer;

  const VergleichsansichtGroupContent({
    super.key,
    required this.vergleichseintraege,
    required this.fixedIDs,
    required this.modus,
    required this.onArrowPressed,
    required this.onMakeEventMain,
    required this.onToggleFixed,
    required this.onShowImageViewer,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: vergleichseintraege.length,
      itemBuilder: (_, index) {
        final eintrag = vergleichseintraege[index];
        final isFixed = fixedIDs.contains(eintrag.eintrag.id);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Card(
            elevation: isFixed ? 4 : 2,
            color: isFixed ? Colors.green[50] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isFixed
                  ? BorderSide(color: Colors.green[400]!, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => onMakeEventMain(eintrag),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eintrag.eventName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Tag ${eintrag.tag + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateTime.tryParse(eintrag.eintrag.datum) != null
                                        ? eintrag.eintrag.datum
                                        : '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFixed ? Icons.push_pin : Icons.push_pin_outlined,
                            color: isFixed ? Colors.green[700] : Colors.grey[400],
                            size: 22,
                          ),
                          tooltip: isFixed ? 'Entfernen' : 'Fixieren',
                          onPressed: () => onToggleFixed(
                              eintrag.eintrag.id, eintrag.eventName, !isFixed),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          color: Colors.grey[600],
                          onPressed: () => onArrowPressed(false, eintrag),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        Expanded(
                          child: Text(
                            eintrag.eintrag.title.isNotEmpty
                                ? eintrag.eintrag.title
                                : 'Ohne Titel',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontStyle: eintrag.eintrag.title.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          color: Colors.grey[600],
                          onPressed: () => onArrowPressed(true, eintrag),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ],
                    ),
                    if (eintrag.eintrag.imagePaths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: eintrag.eintrag.imagePaths.length,
                            itemBuilder: (_, imgIndex) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onTap: () => onShowImageViewer(
                                      context, eintrag.eintrag.imagePaths, imgIndex),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      File(eintrag.eintrag.imagePaths[imgIndex]),
                                      width: 100,
                                      height: 90,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
