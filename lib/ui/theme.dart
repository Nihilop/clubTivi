import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Thème Material dérivé des tokens. Les écrans Tivi utilisent surtout les
/// composants maison ; ce thème habille les écrans d'origine encore utilisés
/// (réglages, fournisseurs, mapping EPG).
abstract final class TiviTheme {
  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: TiviText.family);
    return base.copyWith(
      scaffoldBackgroundColor: TiviColors.bg,
      canvasColor: TiviColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: TiviColors.accent,
        onPrimary: TiviColors.white,
        secondary: TiviColors.accent,
        surface: TiviColors.surface,
        onSurface: TiviColors.text,
        error: TiviColors.live,
      ),
      focusColor: const Color(0x33FFFFFF),
      hoverColor: const Color(0x14FFFFFF),
      splashFactory: NoSplash.splashFactory,
      cardTheme: const CardThemeData(
        color: TiviColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(TiviRadius.xs)),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: false),
      dialogTheme: const DialogThemeData(backgroundColor: TiviColors.surfaceRaised),
      snackBarTheme: const SnackBarThemeData(backgroundColor: TiviColors.surfaceRaised, contentTextStyle: TextStyle(color: TiviColors.text)),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(TiviRadius.sm)),
        selectedTileColor: Color(0x1FFFFFFF),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: TiviColors.accent),
    );
  }
}
