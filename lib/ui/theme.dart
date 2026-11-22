import 'package:material_ui/material_ui.dart';

/// Couleurs tirées du logo validé (vert forêt et or).
class NafaColors {
  static const green = Color(0xFF064A28);
  static const greenLight = Color(0xFFE6F0EA);
  static const gold = Color(0xFFC28E2C);
  static const background = Color(0xFFF6F7F5);
  static const surface = Colors.white;
  static const border = Color(0xFFDDE2DC);
  static const text = Color(0xFF17231B);
  static const textMuted = Color(0xFF5D6B61);

  // Statuts : normal, à surveiller, urgent, terminé.
  static const ok = Color(0xFF1E7A44);
  static const watch = Color(0xFFA86B00);
  static const urgent = Color(0xFFB3261E);
  static const done = Color(0xFF4A5A70);
}

ThemeData buildNafaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NafaColors.green,
    primary: NafaColors.green,
    secondary: NafaColors.gold,
    surface: NafaColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NafaColors.background,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: NafaColors.text,
      displayColor: NafaColors.text,
    ),
    cardTheme: const CardThemeData(
      color: NafaColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: NafaColors.border),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NafaColors.surface,
      foregroundColor: NafaColors.text,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
  );
}
