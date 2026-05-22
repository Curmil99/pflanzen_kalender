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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Color(0xFF2E7D32),
          secondary: Color(0xFF8BC34A),
          surface: Color(0xFFF4F9F2),
        ),
        scaffoldBackgroundColor: Color(0xFFF4F9F2),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF558B2F),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: Size(100, 44),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFE8F5E9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        textTheme: TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
          bodyLarge: TextStyle(color: Color(0xFF2E7D32)),
          bodyMedium: TextStyle(color: Color(0xFF4E7D38)),
        ),
      ),
      home: KategorieListeScreen(),
    );
  }
}
