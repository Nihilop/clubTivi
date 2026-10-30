import 'package:flutter/widgets.dart';

/// Design tokens — miroir de `design/assets/tokens.css`.
/// Toute valeur visuelle passe par ici.
abstract final class TiviColors {
  // Palette brute
  static const ink950 = Color(0xFF100E16);
  static const ink900 = Color(0xFF16141E);
  static const ink850 = Color(0xFF1D1A27);
  static const ink800 = Color(0xFF25222F);
  static const ink700 = Color(0xFF2F2B3A);
  static const ink600 = Color(0xFF3C3849);
  static const ink500 = Color(0xFF4B4759);
  static const ink400 = Color(0xFF6C6880);
  static const ink300 = Color(0xFF918DA4);
  static const ink200 = Color(0xFFBAB6C8);
  static const ink100 = Color(0xFFE2E0EA);
  static const white = Color(0xFFFFFFFF);

  static const orange500 = Color(0xFFFF7A1F);
  static const red500 = Color(0xFFEF3B52);
  static const red700 = Color(0xFFB3172D);
  static const green500 = Color(0xFF3DD68C);
  static const yellow400 = Color(0xFFFFC94D);

  // Rôles
  static const bg = ink850;
  static const bgDeep = ink900;
  static const surface = ink800;
  static const surfaceRaised = ink700;
  static const surfaceFocus = ink600;

  static const glass = Color(0x663E3A4E);
  static const glassStrong = Color(0x94545066);
  static const glassBorder = Color(0x1AFFFFFF);
  static const line = Color(0x12FFFFFF);
  static const lineStrong = Color(0x38FFFFFF);

  static const text = white;
  static const text2 = ink200;
  static const text3 = ink300;
  static const text4 = ink400;

  static const accent = orange500;
  static const live = red500;
  static const positive = green500;

  static const focusIndicator = white;
  static const focusOnMedia = Color(0x3DFFFFFF);
  static const scrim = Color(0xFF0C0A12);
}

abstract final class TiviMotion {
  static const ease = Cubic(.2, .8, .2, 1);
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const focusScale = 1.06;
}

abstract final class TiviRadius {
  static const xs = Radius.circular(3);
  static const sm = Radius.circular(6);
  static const md = Radius.circular(10);
  static const lg = Radius.circular(16);
}

/// Ombres
abstract final class TiviShadow {
  static const s1 = [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 4))];
  static const focus = [BoxShadow(color: Color(0x80000000), blurRadius: 48, offset: Offset(0, 22))];
}

/// Seuil sous lequel on passe en mise en page mobile (barre d'onglets, grilles 2 colonnes…).
const double kCompactBreakpoint = 760;

/// Largeur logique de référence : à cette largeur, l'échelle vaut 1.
/// Une TV 1080p (960 dp de large) donne ~0,87, un écran PC 1600 px ~1,45.
const double kReferenceWidth = 1100;
