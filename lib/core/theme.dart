import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF2E7D6B);
  final colorScheme = ColorScheme.fromSeed(seedColor: seed);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF8F5EF),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 18),
      bodyMedium: TextStyle(fontSize: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.symmetric(vertical: 8),
    ),
  );
}
