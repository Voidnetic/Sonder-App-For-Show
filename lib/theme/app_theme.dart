import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's colours, in a light and a dark version.
///
/// Screens read `AppTheme.kBackground` etc. as before; the values switch when the theme changes and the
/// app is rebuilt (see [ThemeController]). Dark mode keeps the neo-brutalist look: chunky cream outlines
/// and offset shadows on a deep ink background, with deeper versions of the pastels so cream text stays
/// readable on them.
class AppTheme {
  /// Whether the dark palette is active. Set by [ThemeController]; tests and the light theme leave it false.
  static bool isDark = false;

  static Color _pick(int light, int dark) => Color(isDark ? dark : light);

  // Base colours
  static Color get kBackground => _pick(0xFFFAF9F6, 0xFF14151C); // warm off-white / deep ink
  static Color get kSurface => _pick(0xFFFFFFFF, 0xFF1F2130); // cards, fields and sheets
  static Color get kTextPrimary => _pick(0xFF1C1C1C, 0xFFF3EEE3); // charcoal / cream
  static Color get kTextSecondary => _pick(0xFF6B6B6B, 0xFFA9A9B8);
  static Color get kBorder => _pick(0xFF2D2D2D, 0xFFE9E2D2); // outlines and offset shadows
  /// Text and icons on a [kTextPrimary]-coloured button (dark buttons in light mode, cream buttons in dark).
  static Color get kOnPrimary => kBackground;
  static Color get kDanger => _pick(0xFFB00020, 0xFFFF8A80);

  // Pastels: soft tints in light mode, deep tints in dark mode.
  static Color get kLavender => _pick(0xFFE6E6FA, 0xFF2E2B52);
  static Color get kPaleYellow => _pick(0xFFFFFACD, 0xFF4A4022);
  static Color get kSoftMint => _pick(0xFFE0F8E6, 0xFF1D4234);
  static Color get kPalePeach => _pick(0xFFFFE5B4, 0xFF4D3726);
  static Color get kLightBlue => _pick(0xFFE1F5FE, 0xFF1E3A4A);

  // Stronger accents for the stat tiles and highlights.
  static Color get kPeriwinkle => _pick(0xFFB9C4FF, 0xFF4B56B8);
  static Color get kCoral => _pick(0xFFFF9F80, 0xFFB8462C);
  static Color get kSunshine => _pick(0xFFFFD84D, 0xFFE8B830);

  /// Colours that come from data (a moment's accent, a person's avatar) are light pastels. In dark mode they
  /// keep their hue but become deep and a little richer, like the theme's own pastels, so cream text stays
  /// readable on them.
  static Color tint(Color c) {
    if (!isDark) return c;
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(0.25).withSaturation((hsl.saturation * 0.5 + 0.2).clamp(0.0, 0.75)).toColor();
  }

  /// Chunky rounded display font for big headings ("Hey, Hassan", "Past Vault").
  static const String displayFont = 'Bagel';

  static TextStyle display(double size, {Color? color}) =>
      TextStyle(fontFamily: displayFont, fontSize: size, color: color ?? kTextPrimary, height: 1.1);

  // Matches the theme the original prototype ran with. Don't give bodyMedium a colour in the light theme:
  // it's the default style for every Text, so it would turn all unstyled text grey.
  static ThemeData get theme {
    final dark = isDark;
    return ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: kBackground,
      primaryColor: kTextPrimary,
      fontFamily: 'Bricolage',
      colorScheme: dark
          ? ColorScheme.dark(
              surface: kSurface,
              primary: kTextPrimary,
              onPrimary: kOnPrimary,
              secondary: kSunshine,
              onSurface: kTextPrimary,
            )
          : null,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: displayFont, color: kTextPrimary, fontSize: 34, height: 1.1),
      ),
      snackBarTheme: dark
          ? SnackBarThemeData(
              backgroundColor: kTextPrimary,
              contentTextStyle: TextStyle(color: kOnPrimary),
            )
          : null,
    );
  }

  /// Kept for code that still asks for the light theme by name.
  static ThemeData get lightTheme => theme;

  static SystemUiOverlayStyle get systemBars => isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}

/// The user's choice in Profile → Theme, saved on the phone.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    mode.value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode value) async {
    mode.value = value;
    await (await SharedPreferences.getInstance()).setString(_key, value.name);
  }

  /// Resolves "System" against the phone's current setting.
  bool isDarkFor(Brightness platform) =>
      mode.value == ThemeMode.dark || (mode.value == ThemeMode.system && platform == Brightness.dark);
}
