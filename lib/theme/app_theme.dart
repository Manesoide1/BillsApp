import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF0F172A); // Background color, options: 0xFFF8FAFC(white) or 0xFF0F172A(dark)
  static const card = Color(0xFFF8FAFC); // Card color, options: (0xFF0F172A or 0xFF1E293B) = (Azul Marinho Profundo)
  static const accent = Color(0xFF0D9488); // Accent color, options: 0xFF0D9488 (Teal) or 0xFF14B8A6 (Menta Saturado)
  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(primary: accent),
    useMaterial3: true,
  );
}
