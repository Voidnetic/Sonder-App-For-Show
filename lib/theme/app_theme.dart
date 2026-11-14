import 'package:flutter/material.dart';

class AppTheme {
  // Base Colors
  static const Color kBackground = Color(0xFFFAF9F6); // Warm off-white
  static const Color kTextPrimary = Color(0xFF1C1C1C); // Dark charcoal
  static const Color kTextSecondary = Color(0xFF6B6B6B);
  static const Color kBorder = Color(0xFF2D2D2D);

  // Pastels
  static const Color kLavender = Color(0xFFE6E6FA);
  static const Color kPaleYellow = Color(0xFFFFFACD);
  static const Color kSoftMint = Color(0xFFE0F8E6);
  static const Color kPalePeach = Color(0xFFFFE5B4);
  static const Color kLightBlue = Color(0xFFE1F5FE);

  // Stronger accents for the stat tiles and highlights, still soft enough to sit next to the pastels.
  static const Color kPeriwinkle = Color(0xFFB9C4FF);
  static const Color kCoral = Color(0xFFFF9F80);
  static const Color kSunshine = Color(0xFFFFD84D);

  /// Chunky rounded display font for big headings ("Hey, Hassan", "Past Vault").
  static const String displayFont = 'Bagel';

  static TextStyle display(double size, {Color color = kTextPrimary}) =>
      TextStyle(fontFamily: displayFont, fontSize: size, color: color, height: 1.1);

  // Matches the theme the original prototype ran with. Don't give bodyMedium a colour here:
  // it's the default style for every Text, so it would turn all unstyled text grey.
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: kBackground,
      primaryColor: kTextPrimary,
      fontFamily: 'Bricolage',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: displayFont, color: kTextPrimary, fontSize: 34, height: 1.1),
      ),
    );
  }
}
