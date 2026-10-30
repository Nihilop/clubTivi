import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../focus/tv_focusable.dart';
import '../scale.dart';
import '../tokens.dart';
import '../typography.dart';
import 'buttons.dart';

/// Tiroir latéral (TV / tablette) ou feuille du bas (mobile).
///
/// À placer en haut d'un Stack. Le contenu n'est construit qu'ouvert : la
/// navigation D-pad reste enfermée dedans, l'option `autofocus` reçoit le focus,
/// et le focus revient à l'élément d'origine à la fermeture.
/// Le Retour est géré par l'écran (un seul PopScope par écran).
class TiviSidePanel extends StatelessWidget {
  const TiviSidePanel({super.key, required this.open, required this.onClose, required this.title, required this.child});

  final bool open;
  final VoidCallback onClose;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = context.compact;
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !open,
          child: GestureDetector(
            onTap: onClose,
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: TiviMotion.base,
              child: Container(color: const Color(0x73080710)),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: TiviMotion.slow,
          curve: TiviMotion.ease,
          top: compact ? null : 0,
          bottom: compact ? (open ? 0 : -700) : 0,
          right: compact ? 0 : (open ? 0 : -460 * context.s - 40),
          left: compact ? 0 : null,
          width: compact ? null : (440 * context.s).clamp(320.0, 620.0),
          child: ClipRRect(
            borderRadius: compact ? const BorderRadius.vertical(top: TiviRadius.lg) : BorderRadius.zero,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                constraints: BoxConstraints(maxHeight: compact ? MediaQuery.sizeOf(context).height * .82 : double.infinity),
                padding: EdgeInsets.fromLTRB(context.space(compact ? 4 : 6), context.safeY, context.space(compact ? 4 : 6), context.safeY),
                decoration: BoxDecoration(
                  color: const Color(0xDB16141E),
                  border: compact
                      ? const Border(top: BorderSide(color: TiviColors.glassBorder))
                      : const Border(left: BorderSide(color: TiviColors.glassBorder)),
                ),
                child: open ? _PanelBody(title: title, onClose: onClose, child: child) : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelBody extends StatefulWidget {
  const _PanelBody({required this.title, required this.onClose, required this.child});
  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<_PanelBody> createState() => _PanelBodyState();
}

class _PanelBodyState extends State<_PanelBody> {
  FocusNode? _previous;
  final _scope = FocusScopeNode(debugLabel: 'side-panel');

  @override
  void initState() {
    super.initState();
    _previous = FocusManager.instance.primaryFocus;
  }

  @override
  void dispose() {
    final prev = _previous;
    _scope.dispose();
    if (prev != null && prev.context != null) {
      scheduleMicrotask(() {
        if (prev.context != null) prev.requestFocus();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scope,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: TiviText.h2(context))),
              // Bouton de fermeture : souris / tactile (le Retour ferme aussi)
              GestureDetector(
                onTap: widget.onClose,
                child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.close_rounded, color: TiviColors.text2)),
              ),
            ],
          ),
          SizedBox(height: context.space(5)),
          Flexible(child: SingleChildScrollView(child: widget.child)),
        ],
      ),
    );
  }
}

/// Titre de groupe dans un tiroir (« AUDIO », « SOUS-TITRES »).
class PanelGroupTitle extends StatelessWidget {
  const PanelGroupTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: context.space(4), bottom: context.space(2)),
        child: Text(text.toUpperCase(), style: TiviText.eyebrow(context)),
      );
}

/// Option cochable d'un tiroir.
class OptionTile extends StatelessWidget {
  const OptionTile({super.key, required this.label, this.checked = false, this.onSelect, this.autofocus = false, this.hint, this.icon});

  final String label;
  final bool checked;
  final VoidCallback? onSelect;
  final bool autofocus;
  final String? hint;

  /// Icône de tête à la place de la coche (menus d'actions).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: label,
      builder: (context, focused) {
        final fg = focused ? TiviColors.ink900 : (checked || icon != null ? TiviColors.text : TiviColors.text2);
        return AnimatedScale(
          scale: focused ? 1.03 : 1,
          duration: TiviMotion.base,
          curve: TiviMotion.ease,
          child: AnimatedContainer(
            duration: TiviMotion.fast,
            padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(3)),
            decoration: BoxDecoration(color: focused ? TiviColors.white : Colors.transparent, borderRadius: const BorderRadius.all(TiviRadius.sm)),
            child: Row(
              children: [
                if (icon != null)
                  Icon(icon, size: 20, color: fg)
                else
                  Opacity(opacity: checked ? 1 : 0, child: const Icon(Icons.check_rounded, size: 20, color: TiviColors.accent)),
                SizedBox(width: context.space(3)),
                Expanded(child: Text(label, style: TiviText.body(context).copyWith(color: fg))),
                if (hint != null) Text(hint!, style: TiviText.micro(context).copyWith(color: focused ? TiviColors.ink400 : TiviColors.text4)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Message éphémère en haut de l'écran.
void showTiviToast(BuildContext context, String message, {IconData? icon, OverlayState? overlayState}) {
  final overlay = overlayState ?? Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) => _Toast(message: message, icon: icon, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.onDone, this.icon});
  final String message;
  final IconData? icon;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _visible = true));
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _visible = false);
      Future.delayed(TiviMotion.base, widget.onDone);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: context.safeY,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, -.4),
            duration: TiviMotion.slow,
            curve: TiviMotion.ease,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: TiviMotion.base,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xEB1E1B28),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: TiviColors.glassBorder),
                  boxShadow: TiviShadow.s1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: TiviColors.text), const SizedBox(width: 10)],
                    Text(widget.message, style: TiviText.small(context).copyWith(color: TiviColors.text)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrée du rail / de la barre d'onglets.
class RailDestination {
  const RailDestination({required this.icon, required this.label, required this.onSelect, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onSelect;
  final bool active;
}

/// Coque des écrans de navigation : rail vertical sur TV, barre d'onglets sur mobile.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.destinations, required this.child, this.onBack});

  final List<RailDestination> destinations;
  final Widget child;
  final VoidCallback? onBack;

  static double railWidth(BuildContext c) => (MediaQuery.sizeOf(c).width * .07).clamp(72.0, 150.0);

  @override
  Widget build(BuildContext context) {
    if (context.compact) {
      return Column(
        children: [
          Expanded(child: child),
          _BottomBar(destinations: destinations),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(
          width: railWidth(context),
          child: FocusTraversalGroup(
            child: Column(
              children: [
                SizedBox(height: context.safeY),
                if (onBack != null) TiviIconButton(icon: Icons.chevron_left_rounded, onPressed: onBack, tooltip: 'Retour', iconScale: .55),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final d in destinations) ...[
                          TiviIconButton(icon: d.icon, active: d.active, onPressed: d.onSelect, tooltip: d.label),
                          SizedBox(height: context.space(5)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.destinations});
  final List<RailDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 6, bottom: 6 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(color: Color(0xEB16141E), border: Border(top: BorderSide(color: TiviColors.line))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final d in destinations)
            TvFocusable(
              onSelect: d.onSelect,
              semanticLabel: d.label,
              builder: (context, focused) => Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: focused ? const Color(0x14FFFFFF) : Colors.transparent, borderRadius: const BorderRadius.all(TiviRadius.md)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(d.icon, color: d.active ? TiviColors.accent : TiviColors.text2),
                    const SizedBox(height: 2),
                    Text(d.label, style: TiviText.micro(context).copyWith(color: d.active ? TiviColors.text : TiviColors.text3, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
