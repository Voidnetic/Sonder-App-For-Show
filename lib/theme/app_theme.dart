import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/aurora_sky.dart';

/// Which look the app is in.
enum AppLook {
  /// Cream and pastels with black ink outlines (the original).
  light,

  /// "Pastel Glow": near-black, the same bright pastels with a soft glow, black text on them.
  dark,

  /// "Northern Lights": a starry night sky with green and magenta light streaks, mint buttons.
  aurora,

  /// "Aurora Blossom": a navy-to-teal sky with a pink and orchid glow rising from below, pink buttons.
  blossom,
}

/// The app's colours for each look.
///
/// Screens read `AppTheme.kBackground` etc.; the values switch when the look changes and the app is rebuilt
/// (see [ThemeController]). Every look keeps Sonder's bubbly style: chunky outlined "sticker" cards with
/// offset shadows, the Bagel headings and the bouncy taps. Only the colours change.
///
/// Two kinds of surface:
///   - background and panels ([kBackground], [kSurface]) carry [kTextPrimary] / [kTextSecondary]
///   - pastel cards (stat tiles, moment cards, chips) carry [kInk] / [kInkSoft], which stay dark in every look
class AppTheme {
  static AppLook look = AppLook.light;

  static bool get isDark => look != AppLook.light;

  /// The two aurora looks paint a sky behind every screen (see `AuroraSky`), so screens are see-through.
  static bool get hasSky => look == AppLook.aurora || look == AppLook.blossom;

  /// [northern] and [blossom] fall back to [dark] when not given.
  static Color _pick(int light, int dark, {int? northern, int? blossom}) => Color(switch (look) {
    AppLook.light => light,
    AppLook.dark => dark,
    AppLook.aurora => northern ?? dark,
    AppLook.blossom => blossom ?? dark,
  });

  // Background and panels
  /// Solid background: sheets, dialogs, and the base colour of the aurora skies.
  static Color get kBackground => _pick(0xFFFAF9F6, 0xFF0E0E11, northern: 0xFF05070F, blossom: 0xFF14284A);

  /// Behind whole screens: [kBackground], or see-through in the aurora looks so the sky shows.
  static Color get kCanvas => hasSky ? Colors.transparent : kBackground;

  /// Bars that sit over the screen (bottom tabs, the chat box): frosted over the sky in the aurora looks.
  static Color get kBar => hasSky ? kBackground.withValues(alpha: 0.8) : kBackground;

  /// Lists, fields, other people's chat bubbles. Slightly see-through over the aurora skies.
  static Color get kSurface => _pick(0xFFFFFFFF, 0xFF1E1E25, northern: 0xE6141A2B, blossom: 0xE01A3456);
  static Color get kTextPrimary => _pick(0xFF1C1C1C, 0xFFF5F2EA, northern: 0xFFF2F6FF, blossom: 0xFFFFF4F8);
  static Color get kTextSecondary => _pick(0xFF6B6B6B, 0xFF9C9CA8, northern: 0xFFA3AEC4, blossom: 0xFFB8C8DE);

  /// Outlines around cards and panels.
  static Color get kBorder => _pick(0xFF2D2D2D, 0xFF000000, blossom: 0xFF0A1428);

  /// The solid offset "sticker" shadow under cards.
  static Color get kShadow => _pick(0xFF2D2D2D, 0xFF3A3A47, northern: 0xFF000000, blossom: 0xFF0A1428);

  /// Main buttons, your own chat bubbles, selected tabs: black in light, lime in Pastel Glow, mint in
  /// Northern Lights, pink in Aurora Blossom.
  static Color get kPrimaryFill => _pick(0xFF1C1C1C, 0xFFDDF57A, northern: 0xFF8CF5C9, blossom: 0xFFF9C6DA);

  /// Text and icons on [kPrimaryFill].
  static Color get kOnPrimary => _pick(0xFFFAF9F6, 0xFF111111);

  static Color get kDanger => _pick(0xFFB00020, 0xFFFF8A80);

  /// Text on pastel cards: always dark, in every look.
  static const Color kInk = Color(0xFF1C1C1C);
  static Color get kInkSoft => _pick(0xFF6B6B6B, 0xFF3D3D46);

  // Pastels: soft in light, brighter in the dark looks so they glow against the background.
  // Northern Lights leans green, pink and violet like the aurora; Blossom leans pink, orchid and ice blue.
  static Color get kLavender => _pick(0xFFE6E6FA, 0xFFC9C2FF, northern: 0xFFC3B6FF, blossom: 0xFFE2C8FF);
  static Color get kPaleYellow => _pick(0xFFFFFACD, 0xFFFFE89A, northern: 0xFFE6FF8F, blossom: 0xFFFFE3B8);
  static Color get kSoftMint => _pick(0xFFE0F8E6, 0xFFA8E6D8, northern: 0xFF8CF5C9, blossom: 0xFFB8F0E2);
  static Color get kPalePeach => _pick(0xFFFFE5B4, 0xFFFFC8A8, northern: 0xFFFFC2E6, blossom: 0xFFFFCFC4);
  static Color get kLightBlue => _pick(0xFFE1F5FE, 0xFFA9D8F2, northern: 0xFF9FE6FF, blossom: 0xFFAEE3F5);

  // Stronger accents for the stat tiles and highlights.
  static Color get kPeriwinkle => _pick(0xFFB9C4FF, 0xFFB7ABFF, northern: 0xFFB59CFF, blossom: 0xFFE7A6FF);
  static Color get kCoral => _pick(0xFFFF9F80, 0xFFFF9E85, northern: 0xFFFF8FD6, blossom: 0xFFF7A8C8);
  static Color get kSunshine => _pick(0xFFFFD84D, 0xFFFFD24D, northern: 0xFFDDFF6E, blossom: 0xFFFFD86B);

  /// Colours that come from data (a moment's accent, a person's avatar). They're pastels already, so every
  /// look shows them as they are, with [kInk] text on top.
  static Color tint(Color c) => c;

  /// The "Pastel Glow" fill for a pastel card: lighter at the top, deeper at the bottom. Null in light,
  /// where cards stay flat.
  static Gradient? glow(Color c) => isDark
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c, Colors.white, 0.45)!, c, Color.lerp(c, const Color(0xFF6A4CFF), 0.12)!],
          stops: const [0, 0.55, 1],
        )
      : null;

  /// The offset shadow for a sticker filled with [fill]: black in light; in the dark looks a deeper shade of
  /// the fill's own colour (pink card, deep-pink shadow), or slate under dark panels.
  static Color shadowFor(Color fill) {
    if (!isDark) return kShadow;
    if (fill.computeLuminance() < 0.15) return kShadow;
    final hsl = HSLColor.fromColor(fill);
    return hsl
        .withLightness((hsl.lightness * 0.62).clamp(0.28, 0.55))
        .withSaturation((hsl.saturation * 1.05 + 0.1).clamp(0.0, 1.0))
        .toColor();
  }

  /// Sonder's "sticker": a chunky outline and a solid offset shadow. In the dark looks pastel stickers also
  /// glow (see [glow]) and their shadow takes the card's own colour (see [shadowFor]).
  static BoxDecoration sticker(
    Color fill, {
    double radius = 24,
    double border = 2,
    double offset = 4,
    bool circle = false,
  }) {
    final pastel = fill.computeLuminance() >= 0.15;
    return BoxDecoration(
      color: fill,
      gradient: pastel ? glow(fill) : null,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
      border: Border.all(color: kBorder, width: isDark ? border + 0.5 : border),
      boxShadow: offset == 0 ? null : [BoxShadow(color: shadowFor(fill), offset: Offset(offset, offset))],
    );
  }

  /// Background of screens that used to take a moment's colour (the moment, its gallery, the reveal):
  /// that colour in light, the plain background in the dark looks (the sky in the aurora looks).
  static Color screenTint(Color accent) => isDark ? kCanvas : accent;

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
      scaffoldBackgroundColor: kCanvas,
      // In the aurora looks every page carries the sky (see SkyPageTransitionsBuilder) and is see-through.
      pageTransitionsTheme: hasSky
          ? PageTransitionsTheme(
              builders: {
                for (final platform in TargetPlatform.values)
                  platform: SkyPageTransitionsBuilder(
                    ios: platform == TargetPlatform.iOS || platform == TargetPlatform.macOS,
                  ),
              },
            )
          : null,
      appBarTheme: hasSky
          ? const AppBarTheme(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
            )
          : null,
      primaryColor: kTextPrimary,
      fontFamily: 'Bricolage',
      colorScheme: dark
          ? ColorScheme.dark(
              surface: kSurface,
              primary: kPrimaryFill,
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
              backgroundColor: kPrimaryFill,
              contentTextStyle: TextStyle(color: kOnPrimary),
            )
          : null,
    );
  }

  /// Kept for code that still asks for the light theme by name.
  static ThemeData get lightTheme => theme;

  static SystemUiOverlayStyle get systemBars => isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}

/// The person's choice in Profile → Theme, saved on the phone.
/// `aurora` is Northern Lights (that name is what's saved on the phone).
enum ThemeChoice { light, dark, aurora, blossom, system }

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';

  /// Light unless the person picks something else in Profile → Theme (even when the phone is in dark mode).
  final ValueNotifier<ThemeChoice> mode = ValueNotifier(ThemeChoice.light);

  Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    mode.value = ThemeChoice.values.firstWhere((m) => m.name == saved, orElse: () => ThemeChoice.light);
  }

  Future<void> set(ThemeChoice value) async {
    mode.value = value;
    await (await SharedPreferences.getInstance()).setString(_key, value.name);
  }

  /// Resolves "System" against the phone's current setting (dark means Pastel Glow).
  AppLook lookFor(Brightness platform) => switch (mode.value) {
    ThemeChoice.light => AppLook.light,
    ThemeChoice.dark => AppLook.dark,
    ThemeChoice.aurora => AppLook.aurora,
    ThemeChoice.blossom => AppLook.blossom,
    ThemeChoice.system => platform == Brightness.dark ? AppLook.dark : AppLook.light,
  };
}
