import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ui/dashboard_screen.dart';

void main() {
  runApp(const MobileHygieneGuardianApp());
}

class MobileHygieneGuardianApp extends StatelessWidget {
  const MobileHygieneGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Hygiene Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('gu', ''), // Gujarati
        Locale('hi', ''), // Hindi
      ],
      home: const DashboardScreen(),
    );
  }
}
