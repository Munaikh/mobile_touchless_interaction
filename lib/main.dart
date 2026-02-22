import 'package:flutter/material.dart';
import 'package:mobile_touchless_interaction/screens/home_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Avenir',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF256B6A),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Avenir',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF256B6A),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}
