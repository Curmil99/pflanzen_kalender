import 'package:flutter/material.dart';
import '../repositories/day_repo.dart'; 
import 'Screens/kategorie_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // wichtig für async Init vor runApp
  await DayRepo().init(); // Isar initialisieren

  runApp(PflanzenApp());
}

class PflanzenApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pflanzen Kalender',
      theme: ThemeData(primarySwatch: Colors.green),
      home: KategorieListeScreen(),
    );
  }
}
