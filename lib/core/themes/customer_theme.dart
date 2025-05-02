
import 'package:flutter/material.dart';

final ThemeData customTheme = ThemeData(
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1E5631),       // Verde - cor primária
    onPrimary: Colors.white,
    secondary: Color(0xFF00AEEF),     // Azul - cor secundária
    onSecondary: Colors.white,
    error: Color(0xFFE30613),         // Vermelho
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF1A1A1A),
  ),
  scaffoldBackgroundColor: Colors.white,
  useMaterial3: true,
  fontFamily: 'Roboto',
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey[100],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1E5631), width: 2),
    ),
    labelStyle: const TextStyle(color: Color(0xFF1A1A1A)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1E5631),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF00AEEF),
    ),
  ),

  appBarTheme: const AppBarTheme(
  backgroundColor: Color(0xFF1E5631), // Verde principal
  foregroundColor: Colors.white,
  elevation: 4,
  centerTitle: true,
  titleTextStyle: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
  iconTheme: IconThemeData(color: Colors.white),
),

);
