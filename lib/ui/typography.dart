import 'package:flutter/widgets.dart';

import 'scale.dart';
import 'tokens.dart';

/// Échelle typographique (Rubik variable, embarquée dans assets/fonts).
abstract final class TiviText {
  static const family = 'Rubik';

  /// Rubik est une police variable : on règle l'axe `wght` en plus de fontWeight.
  static TextStyle weight(double size, int weight, {Color color = TiviColors.text, double? height, double? letterSpacing}) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle display(BuildContext c) => weight(c.compact ? 48 : c.px(68), 300, height: 1);
  static TextStyle h1(BuildContext c) => weight(c.compact ? 24 : c.px(30), 500, height: 1.15);
  static TextStyle h2(BuildContext c) => weight(c.compact ? 19 : c.px(22), 500, height: 1.2);
  static TextStyle h3(BuildContext c) => weight(c.compact ? 16 : c.px(17), 500, height: 1.25);
  static TextStyle body(BuildContext c) => weight(c.compact ? 14 : c.px(15), 400, color: TiviColors.text2, height: 1.45);
  static TextStyle small(BuildContext c) => weight(c.compact ? 12.5 : c.px(13), 400, color: TiviColors.text3, height: 1.35);
  static TextStyle micro(BuildContext c) => weight(c.compact ? 11 : c.px(11), 600, color: TiviColors.text3, letterSpacing: .3);

  /// Libellé en capitales espacées (titres de groupe dans les tiroirs).
  static TextStyle eyebrow(BuildContext c) => micro(c).copyWith(letterSpacing: 1.8);
}
