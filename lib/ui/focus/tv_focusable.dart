import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'tv_keys.dart';

/// Brique de base de tout élément atteignable à la télécommande.
///
/// - OK / Entrée / clic / tap → [onSelect]
/// - le survol souris donne le focus (un seul élément actif, comme sur TV)
/// - [builder] reçoit l'état `focused` pour dessiner l'élévation du focus
/// - [centerOnFocus] centre l'élément dans son conteneur défilant
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.builder,
    this.onSelect,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.onKeyEvent,
    this.centerOnFocus = false,
    this.hoverFocus = true,
    this.canRequestFocus = true,
    this.semanticLabel,
  });

  final Widget Function(BuildContext context, bool focused) builder;
  final VoidCallback? onSelect;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final FocusOnKeyEventCallback? onKeyEvent;
  final bool centerOnFocus;
  final bool hoverFocus;
  final bool canRequestFocus;
  final String? semanticLabel;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _own;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final custom = widget.onKeyEvent?.call(node, event);
    if (custom != null && custom != KeyEventResult.ignored) return custom;
    if (event is KeyDownEvent && TvKeys.isSelect(event.logicalKey) && widget.onSelect != null) {
      widget.onSelect!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFocus(bool focused) {
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
    if (focused && widget.centerOnFocus) {
      Scrollable.ensureVisible(context, alignment: .5, duration: TiviMotion.base, curve: TiviMotion.ease);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onSelect != null,
      label: widget.semanticLabel,
      child: Focus(
        focusNode: _node,
        autofocus: widget.autofocus,
        canRequestFocus: widget.canRequestFocus,
        onFocusChange: _onFocus,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: widget.onSelect != null ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) {
            if (widget.hoverFocus && widget.canRequestFocus && !_node.hasFocus) _node.requestFocus();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSelect == null
                ? null
                : () {
                    _node.requestFocus();
                    widget.onSelect!();
                  },
            child: widget.builder(context, _focused),
          ),
        ),
      ),
    );
  }
}
