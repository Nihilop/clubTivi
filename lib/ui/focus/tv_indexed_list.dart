import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'tv_keys.dart';

/// Pilote externe d'une [TvIndexedList] (sélection imposée, lecture de l'index).
class TvIndexedListController extends ChangeNotifier {
  TvIndexedListController({int initialIndex = 0}) : _index = initialIndex;
  int _index;
  int get index => _index;

  void select(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}

/// Liste pensée pour le D-pad, utilisée pour les chaînes et les rangées de posters.
///
/// Un seul nœud de focus pour toute la liste : les flèches de l'axe déplacent
/// l'index (même sur des milliers d'éléments non construits), les flèches
/// perpendiculaires laissent Flutter sortir de la liste vers l'élément voisin
/// (rail, bouton, rangée suivante). Arrivé au bout de l'axe, on laisse aussi
/// sortir. L'index est conservé : revenir dans la liste retombe au même endroit.
class TvIndexedList extends StatefulWidget {
  const TvIndexedList({
    super.key,
    required this.itemCount,
    required this.itemExtent,
    required this.itemBuilder,
    this.axis = Axis.vertical,
    this.centered = false,
    this.edgeSpacing = 24,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onIndexChanged,
    this.onSelect,
    this.onFocusChange,
    this.clipBehavior = Clip.hardEdge,
  });

  final int itemCount;

  /// Taille d'un élément sur l'axe, espacement compris.
  final double itemExtent;
  final Widget Function(BuildContext context, int index, bool focused) itemBuilder;
  final Axis axis;

  /// Garde l'élément focus au centre (liste des chaînes) au lieu du défilement minimal.
  final bool centered;

  /// Marge gardée visible avant/après l'élément focus en mode non centré.
  final double edgeSpacing;
  final EdgeInsets padding;
  final TvIndexedListController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<int>? onIndexChanged;
  final ValueChanged<int>? onSelect;
  final ValueChanged<bool>? onFocusChange;
  final Clip clipBehavior;

  @override
  State<TvIndexedList> createState() => _TvIndexedListState();
}

class _TvIndexedListState extends State<TvIndexedList> {
  final _scroll = ScrollController();
  FocusNode? _ownNode;
  TvIndexedListController? _ownController;
  bool _hasFocus = false;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  TvIndexedListController get _ctrl => widget.controller ?? (_ownController ??= TvIndexedListController());
  bool get _vertical => widget.axis == Axis.vertical;

  /// Marge en bout de rangée horizontale : l'élément focus grossit (jusqu'à ×1,1)
  /// et ne doit pas être coupé par le bord de la liste.
  EdgeInsets get _padding => _vertical ? widget.padding : widget.padding + EdgeInsets.symmetric(horizontal: widget.itemExtent * .07);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_ctrl.index, animate: false));
  }

  @override
  void didUpdateWidget(TvIndexedList old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_onControllerChange);
      _ctrl.addListener(_onControllerChange);
    }
    if (_ctrl.index >= widget.itemCount && widget.itemCount > 0) {
      _ctrl.select(widget.itemCount - 1);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChange);
    _scroll.dispose();
    _ownNode?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (!mounted) return;
    setState(() {});
    _scrollTo(_ctrl.index, animate: true);
  }

  void _scrollTo(int index, {required bool animate}) {
    if (!_scroll.hasClients || widget.itemCount == 0) return;
    final pos = _scroll.position;
    final lead = _vertical ? _padding.top : _padding.left;
    final start = lead + index * widget.itemExtent;
    final viewport = pos.viewportDimension;
    double target;
    if (widget.centered) {
      target = start + widget.itemExtent / 2 - viewport / 2;
    } else {
      target = pos.pixels;
      if (start - widget.edgeSpacing < target) {
        target = start - widget.edgeSpacing;
      } else if (start + widget.itemExtent + widget.edgeSpacing > target + viewport) {
        target = start + widget.itemExtent + widget.edgeSpacing - viewport;
      }
    }
    target = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((target - pos.pixels).abs() < 1) return;
    if (animate) {
      _scroll.animateTo(target, duration: TiviMotion.base, curve: TiviMotion.ease);
    } else {
      _scroll.jumpTo(target);
    }
  }

  bool _move(int delta, {required bool repeat}) {
    final next = _ctrl.index + delta;
    if (next < 0 || next >= widget.itemCount) return false;
    _ctrl._index = next; // pas de notify : on gère le défilement ici (instantané si répétition)
    setState(() {});
    widget.onIndexChanged?.call(next);
    _scrollTo(next, animate: !repeat);
    return true;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!TvKeys.isPress(event)) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    final back = _vertical ? TvKeys.isUp(k) : TvKeys.isLeft(k);
    final fwd = _vertical ? TvKeys.isDown(k) : TvKeys.isRight(k);
    if (back || fwd) {
      return _move(fwd ? 1 : -1, repeat: repeat) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (event is KeyDownEvent && TvKeys.isSelect(k) && widget.onSelect != null && widget.itemCount > 0) {
      widget.onSelect!(_ctrl.index);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      canRequestFocus: widget.itemCount > 0,
      onKeyEvent: _onKey,
      onFocusChange: (f) {
        setState(() => _hasFocus = f);
        widget.onFocusChange?.call(f);
        if (f) _scrollTo(_ctrl.index, animate: true);
      },
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: widget.axis,
        padding: _padding,
        itemExtent: widget.itemExtent,
        itemCount: widget.itemCount,
        clipBehavior: widget.clipBehavior,
        itemBuilder: (context, i) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _node.requestFocus();
            if (_ctrl.index != i) {
              _ctrl._index = i;
              setState(() {});
              widget.onIndexChanged?.call(i);
            }
            widget.onSelect?.call(i);
          },
          child: widget.itemBuilder(context, i, _hasFocus && i == _ctrl.index),
        ),
      ),
    );
  }
}
