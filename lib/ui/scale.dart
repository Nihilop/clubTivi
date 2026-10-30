import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Échelle de l'interface, calculée une fois à la racine de l'app.
///
/// Sur TV / desktop, toutes les dimensions sont proportionnelles à la largeur
/// (comme les `clamp()` du design system HTML). Sur mobile (`compact`), l'échelle
/// reste à 1 et les écrans passent en mise en page mobile.
class TiviScale extends InheritedWidget {
  final double s;
  final bool compact;
  final Size size;

  const TiviScale({
    super.key,
    required this.s,
    required this.compact,
    required this.size,
    required super.child,
  });

  static TiviScale of(BuildContext context) {
    final scale = context.dependOnInheritedWidgetOfExactType<TiviScale>();
    assert(scale != null, 'TiviScale manquant : enveloppez l\'app avec TiviScale.wrap');
    return scale!;
  }

  /// Enveloppe l'app : à placer dans `MaterialApp.builder`.
  static Widget wrap(BuildContext context, Widget child) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < kCompactBreakpoint;
    final s = compact ? 1.0 : (size.width / kReferenceWidth).clamp(0.8, 2.2);
    // Les tailles suivent déjà l'écran : on plafonne la taille de texte système
    // pour ne pas faire déborder les cartes de hauteur fixe.
    final textScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: TiviScale(s: s, compact: compact, size: size, child: child),
    );
  }

  @override
  bool updateShouldNotify(TiviScale old) => old.s != s || old.compact != compact || old.size != size;
}

extension TiviContext on BuildContext {
  TiviScale get _scale => TiviScale.of(this);

  /// Facteur d'échelle courant.
  double get s => _scale.s;

  /// Vrai sous 760 dp : mise en page mobile.
  bool get compact => _scale.compact;

  /// Valeur du design (en px à l'échelle 1) convertie à l'écran.
  double px(double v) => v * _scale.s;

  /// Espacements : s1…s9 = 4, 8, 12, 16, 24, 32, 48, 64, 96.
  double space(int step) => px(const [0.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0, 64.0, 96.0][step]);

  /// Zone de sécurité TV (overscan) : 5 % de la largeur, 16 px sur mobile.
  double get safeX => compact ? 16 : (_scale.size.width * 0.05).clamp(16.0, 110.0);
  double get safeY => compact ? 16 : (_scale.size.height * 0.055).clamp(16.0, 72.0);
}
