import 'package:flutter/material.dart';

const Color valencaGreen = Color(0xFF005C20);
const Color valencaLightGreen = Color(0xFF00A63C);
const Color valencaBlue = Color(0xFF00AEEF);
const Color valencaYellow = Color(0xFFFFD733);
const Color valencaRed = Color(0xFFE30613);
const Color valencaInk = Color(0xFF172019);

final ThemeData customTheme = ThemeData(
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: valencaGreen,
    onPrimary: Colors.white,
    secondary: valencaBlue,
    onSecondary: Colors.white,
    tertiary: valencaYellow,
    onTertiary: valencaInk,
    error: valencaRed,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: valencaInk,
  ),
  scaffoldBackgroundColor: const Color(0xFFF6F8F5),
  useMaterial3: true,
  fontFamily: 'Roboto',
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: Color(0xFFD8E0D8)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: valencaGreen, width: 2),
    ),
    labelStyle: TextStyle(color: valencaInk),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: valencaGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: valencaGreen),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: valencaGreen,
    foregroundColor: Colors.white,
    elevation: 2,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
);
