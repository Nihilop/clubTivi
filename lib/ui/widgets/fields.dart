import 'package:flutter/material.dart';

import '../focus/tv_focusable.dart';
import '../focus/tv_keys.dart';
import '../scale.dart';
import '../tokens.dart';
import '../typography.dart';

/// Champ texte utilisable à la télécommande : ↑/↓ sortent du champ
/// (au lieu de déplacer le curseur), OK ouvre le clavier.
class TiviTextField extends StatefulWidget {
  const TiviTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscure = false,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.clearable = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// Croix pour vider le champ (recherche).
  final bool clearable;

  @override
  State<TiviTextField> createState() => _TiviTextFieldState();
}

class _TiviTextFieldState extends State<TiviTextField> {
  late final FocusNode _node = FocusNode(debugLabel: widget.label, onKeyEvent: _onKey);
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!TvKeys.isPress(e)) return KeyEventResult.ignored;
    if (TvKeys.isUp(e.logicalKey)) return node.focusInDirection(TraversalDirection.up) ? KeyEventResult.handled : KeyEventResult.ignored;
    if (TvKeys.isDown(e.logicalKey)) return node.focusInDirection(TraversalDirection.down) ? KeyEventResult.handled : KeyEventResult.ignored;
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _focused = _node.hasFocus));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = context.compact ? 48.0 : context.px(54);
    return AnimatedContainer(
      duration: TiviMotion.base,
      height: h,
      padding: EdgeInsets.symmetric(horizontal: context.space(4)),
      decoration: BoxDecoration(
        color: _focused ? TiviColors.surfaceFocus : TiviColors.bgDeep,
        borderRadius: const BorderRadius.all(TiviRadius.sm),
        border: Border.all(color: _focused ? TiviColors.white : TiviColors.line, width: _focused ? 2 : 1),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: _focused ? TiviColors.text : TiviColors.text3),
            SizedBox(width: context.space(3)),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _node,
              autofocus: widget.autofocus,
              obscureText: widget.obscure,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              style: TiviText.body(context).copyWith(color: TiviColors.text),
              cursorColor: TiviColors.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.label,
                hintStyle: TiviText.body(context).copyWith(color: TiviColors.text4),
              ),
            ),
          ),
          if (widget.clearable)
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => widget.controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                        widget.onChanged?.call('');
                      },
                      child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close_rounded, size: 20, color: TiviColors.text3)),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Bloc repliable (cartes de réglages, détails) : l'en-tête est focusable,
/// OK ouvre / ferme, le contenu devient atteignable une fois ouvert.
class TiviCollapse extends StatefulWidget {
  const TiviCollapse({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.status,
    this.icon,
    this.initiallyOpen = false,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Pastille d'état sous le titre (ex. « Configurée ✓ »), prioritaire sur [subtitle].
  final Widget? status;
  final IconData? icon;
  final bool initiallyOpen;
  final Widget? trailing;
  final Widget child;

  @override
  State<TiviCollapse> createState() => _TiviCollapseState();
}

class _TiviCollapseState extends State<TiviCollapse> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TiviMotion.base,
      margin: EdgeInsets.only(bottom: context.space(2)),
      decoration: BoxDecoration(
        color: _open ? TiviColors.surfaceRaised : TiviColors.surface,
        border: Border.all(color: TiviColors.line),
        borderRadius: const BorderRadius.all(TiviRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvFocusable(
            onSelect: () => setState(() => _open = !_open),
            semanticLabel: widget.title,
            builder: (context, focused) => AnimatedContainer(
              duration: TiviMotion.fast,
              padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(3)),
              decoration: BoxDecoration(color: focused ? TiviColors.white : Colors.transparent, borderRadius: const BorderRadius.all(TiviRadius.sm)),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 22, color: focused ? TiviColors.ink900 : TiviColors.text2),
                    SizedBox(width: context.space(4)),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: TiviText.weight(TiviText.h3(context).fontSize!, 500, color: focused ? TiviColors.ink900 : TiviColors.text)),
                        if (widget.status != null)
                          widget.status!
                        else if (widget.subtitle != null)
                          Text(widget.subtitle!, style: TiviText.small(context).copyWith(color: focused ? TiviColors.ink400 : TiviColors.text3)),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[widget.trailing!, SizedBox(width: context.space(3))],
                  AnimatedRotation(
                    turns: _open ? .5 : 0,
                    duration: TiviMotion.base,
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: focused ? TiviColors.ink900 : TiviColors.text2),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: TiviMotion.base,
            curve: TiviMotion.ease,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: EdgeInsets.fromLTRB(context.space(4), context.space(1), context.space(4), context.space(4)),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Ligne avec interrupteur (activer une source, une option).
class TiviSwitchRow extends StatelessWidget {
  const TiviSwitchRow({super.key, required this.label, required this.value, required this.onChanged, this.subtitle, this.trailing});

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Actions supplémentaires à droite (rafraîchir, supprimer…).
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TvFocusable(
            onSelect: () => onChanged(!value),
            semanticLabel: label,
            builder: (context, focused) => AnimatedContainer(
              duration: TiviMotion.fast,
              padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(3)),
              decoration: BoxDecoration(color: focused ? TiviColors.white : Colors.transparent, borderRadius: const BorderRadius.all(TiviRadius.sm)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TiviText.weight(TiviText.body(context).fontSize!, 500, color: focused ? TiviColors.ink900 : TiviColors.text)),
                        if (subtitle != null)
                          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TiviText.small(context).copyWith(color: focused ? TiviColors.ink400 : TiviColors.text3)),
                      ],
                    ),
                  ),
                  SizedBox(width: context.space(4)),
                  _SwitchKnob(value: value, onDark: !focused),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[SizedBox(width: context.space(2)), ...trailing!],
      ],
    );
  }
}

class _SwitchKnob extends StatelessWidget {
  const _SwitchKnob({required this.value, required this.onDark});
  final bool value;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TiviMotion.base,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? TiviColors.accent : (onDark ? TiviColors.ink500 : TiviColors.ink200),
        borderRadius: BorderRadius.circular(13),
      ),
      child: AnimatedAlign(
        duration: TiviMotion.base,
        curve: TiviMotion.ease,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      ),
    );
  }
}

/// Bloc de réglages : titre de section + carte.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.children, this.description, this.icon});

  final String title;
  final String? description;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.space(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 20, color: TiviColors.accent), SizedBox(width: context.space(3))],
            Text(title, style: TiviText.h2(context)),
          ]),
          if (description != null) ...[
            SizedBox(height: context.space(1)),
            Text(description!, style: TiviText.small(context)),
          ],
          SizedBox(height: context.space(3)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.space(context.compact ? 3 : 4)),
            decoration: BoxDecoration(
              color: TiviColors.surface,
              border: Border.all(color: TiviColors.line),
              borderRadius: const BorderRadius.all(TiviRadius.sm),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}
