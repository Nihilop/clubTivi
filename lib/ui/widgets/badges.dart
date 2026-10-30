import 'package:flutter/material.dart';

import '../scale.dart';
import '../tokens.dart';
import '../typography.dart';

enum _BadgeKind { live, fresh, tag, tagDim, soft, glass }

/// Badges compacts (Live, Nouveau, HD/4K/EPG…).
class TiviBadge extends StatelessWidget {
  const TiviBadge._(this.label, this._kind, {this.icon});

  final String label;
  final _BadgeKind _kind;
  final IconData? icon;

  const TiviBadge.live({String label = 'Live'}) : this._(label, _BadgeKind.live);
  const TiviBadge.fresh({String label = 'Nouveau'}) : this._(label, _BadgeKind.fresh);

  /// Format en italique gras (HD, 4K…) ; [dim] pour EPG, $.
  const TiviBadge.tag(String label, {bool dim = false}) : this._(label, dim ? _BadgeKind.tagDim : _BadgeKind.tag);
  const TiviBadge.soft(String label) : this._(label, _BadgeKind.soft);
  const TiviBadge.glass(String label, {IconData? icon}) : this._(label, _BadgeKind.glass, icon: icon);

  @override
  Widget build(BuildContext context) {
    final live = _kind == _BadgeKind.live;
    final h = live ? context.px(24).clamp(20.0, 34.0) : context.px(20).clamp(18.0, 30.0);
    final (bg, fg) = switch (_kind) {
      _BadgeKind.live => (TiviColors.live, TiviColors.white),
      _BadgeKind.fresh => (TiviColors.accent, TiviColors.white),
      _BadgeKind.tag => (TiviColors.ink100, TiviColors.ink800),
      _BadgeKind.tagDim => (TiviColors.ink500, TiviColors.ink200),
      _BadgeKind.soft => (const Color(0x1FFFFFFF), TiviColors.text2),
      _BadgeKind.glass => (const Color(0x99100E16), TiviColors.text),
    };
    final isTag = _kind == _BadgeKind.tag || _kind == _BadgeKind.tagDim;
    final style = TiviText.weight(live ? TiviText.small(context).fontSize! : TiviText.micro(context).fontSize!, isTag ? 700 : (live ? 500 : 600),
            color: fg, letterSpacing: isTag ? -.2 : null)
        .copyWith(fontStyle: isTag ? FontStyle.italic : null, height: 1);
    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: live ? h * .42 : h * .3),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.all(TiviRadius.xs)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[const _LiveDot(), SizedBox(width: h * .22)],
          if (icon != null) ...[Icon(icon, size: h * .62, color: fg), SizedBox(width: h * .18)],
          Text(label, style: style),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 1.0, end: .3).animate(_c),
        child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      );
}

/// Badges déduits du nom d'une chaîne (4K, HD…) + EPG si disponible.
List<Widget> channelBadges(String name, {bool hasEpg = false}) {
  final upper = name.toUpperCase();
  final out = <Widget>[];
  if (RegExp(r'\b(4K|UHD)\b').hasMatch(upper)) {
    out.add(const TiviBadge.tag('4K'));
  } else if (RegExp(r'\b(FHD|HD|1080P?|720P?)\b').hasMatch(upper)) {
    out.add(const TiviBadge.tag('HD'));
  }
  if (hasEpg) out.add(const TiviBadge.tag('EPG', dim: true));
  return out;
}
