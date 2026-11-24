import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF0F172A); // Background color, options: 0xFFF8FAFC(white) or 0xFF0F172A(dark)
  static const card = Color(0xFFF8FAFC); // Card color: 0xFFF8FAFC (white)
  static const accent = Color(0xFF0D9488); // Accent color: 0xFF0D9488 (Teal)
  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(primary: accent),
    useMaterial3: true,
  );
}
