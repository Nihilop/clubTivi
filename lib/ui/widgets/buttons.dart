import 'package:flutter/material.dart';

import '../focus/tv_focusable.dart';
import '../scale.dart';
import '../tokens.dart';
import '../typography.dart';

enum TiviButtonSize { sm, md, lg }

enum TiviButtonVariant {
  /// Fond verre, focus blanc (menus, barres).
  glass,

  /// Sans fond, focus blanc.
  ghost,

  /// Posé sur la vidéo : focus = voile blanc 24 %.
  media,
}

double tiviButtonSize(BuildContext c, TiviButtonSize size) => switch (size) {
      TiviButtonSize.sm => c.compact ? 40 : c.px(46),
      TiviButtonSize.md => c.compact ? 48 : c.px(58),
      TiviButtonSize.lg => c.compact ? 58 : c.px(76),
    };

/// Bouton rond à icône (rail, barre du haut, lecteur).
class TiviIconButton extends StatelessWidget {
  const TiviIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = TiviButtonSize.md,
    this.variant = TiviButtonVariant.glass,
    this.active = false,
    this.on = false,
    this.disabled = false,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.iconScale = 0.44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final TiviButtonSize size;
  final TiviButtonVariant variant;

  /// Section courante (rail).
  final bool active;

  /// État activé, icône orange (favori, sous-titres…).
  final bool on;
  final bool disabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;
  final double iconScale;

  @override
  Widget build(BuildContext context) {
    final d = tiviButtonSize(context, size);
    final media = variant == TiviButtonVariant.media;
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onSelect: onPressed,
      semanticLabel: tooltip,
      builder: (context, focused) {
        Color bg = switch (variant) {
          TiviButtonVariant.glass => TiviColors.glass,
          _ => Colors.transparent,
        };
        Color fg = media ? TiviColors.white : TiviColors.text2;
        if (active) {
          bg = TiviColors.ink500;
          fg = TiviColors.text;
        }
        if (focused) {
          bg = media ? TiviColors.focusOnMedia : TiviColors.white;
          fg = media ? TiviColors.white : TiviColors.ink900;
        }
        if (on) fg = TiviColors.accent;
        return AnimatedScale(
          scale: focused ? 1.12 : 1,
          duration: TiviMotion.base,
          curve: TiviMotion.ease,
          child: AnimatedOpacity(
            opacity: disabled ? .35 : 1,
            duration: TiviMotion.fast,
            child: AnimatedContainer(
              duration: TiviMotion.base,
              curve: TiviMotion.ease,
              width: d,
              height: d,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: focused && !media ? TiviShadow.focus : null,
              ),
              child: Icon(icon, size: d * iconScale, color: fg),
            ),
          ),
        );
      },
    );
  }
}

/// Bouton pilule texte + icône (« Regarder », « Favori »).
class TiviPillButton extends StatelessWidget {
  const TiviPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.on = false,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool on;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final h = tiviButtonSize(context, TiviButtonSize.sm);
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onSelect: onPressed,
      semanticLabel: label,
      builder: (context, focused) {
        final fg = focused ? TiviColors.ink900 : TiviColors.text;
        return AnimatedScale(
          scale: focused ? TiviMotion.focusScale : 1,
          duration: TiviMotion.base,
          curve: TiviMotion.ease,
          child: AnimatedContainer(
            duration: TiviMotion.base,
            curve: TiviMotion.ease,
            height: h,
            padding: EdgeInsets.only(left: icon != null ? h * .36 : h * .5, right: h * .5),
            decoration: BoxDecoration(
              color: focused ? TiviColors.white : (primary ? const Color(0x29FFFFFF) : TiviColors.glass),
              borderRadius: BorderRadius.circular(h),
              boxShadow: focused ? TiviShadow.focus : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: h * .46, color: on ? TiviColors.accent : fg),
                  SizedBox(width: h * .18),
                ],
                Text(label, style: TiviText.weight(TiviText.body(context).fontSize!, 500, color: fg)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pastille (saisons, filtres).
class TiviChip extends StatelessWidget {
  const TiviChip({super.key, required this.label, this.active = false, this.onPressed, this.focusNode});

  final String label;
  final bool active;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final h = tiviButtonSize(context, TiviButtonSize.sm);
    return TvFocusable(
      focusNode: focusNode,
      onSelect: onPressed,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? TiviMotion.focusScale : 1,
        duration: TiviMotion.base,
        curve: TiviMotion.ease,
        child: AnimatedContainer(
          duration: TiviMotion.base,
          height: h,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: h * .5),
          decoration: BoxDecoration(
            color: focused ? TiviColors.white : (active ? TiviColors.ink500 : TiviColors.glass),
            borderRadius: BorderRadius.circular(h),
          ),
          child: Text(
            label,
            style: TiviText.weight(TiviText.small(context).fontSize!, 500,
                color: focused ? TiviColors.ink900 : (active ? TiviColors.text : TiviColors.text2)),
          ),
        ),
      ),
    );
  }
}
