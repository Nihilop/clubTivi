import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/weather_service.dart';
import '../focus/tv_focusable.dart';
import '../scale.dart';
import '../tokens.dart';
import '../typography.dart';
import 'buttons.dart';

const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

String formatClock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String formatDateFr(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// Reconstruit son enfant chaque minute (horloges).
class MinuteTicker extends StatefulWidget {
  const MinuteTicker({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends State<MinuteTicker> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

/// Température en °C (le service d'origine stocke des °F).
String? temperatureLabel(WeatherData? w) => w == null ? null : '${((w.tempF - 32) * 5 / 9).round()}°';

/// « 12:51  ☁ 24° » de la barre du haut.
class ClockWeather extends ConsumerWidget {
  const ClockWeather({super.key, this.style});
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temp = temperatureLabel(ref.watch(weatherProvider));
    final st = style ?? TiviText.weight(TiviText.h3(context).fontSize!, 400);
    return MinuteTicker(
      builder: (context, now) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatClock(now), style: st.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          if (temp != null) ...[
            SizedBox(width: st.fontSize! * .8),
            Icon(Icons.cloud_rounded, size: st.fontSize! * 1.3, color: TiviColors.white),
            const SizedBox(width: 6),
            Text(temp, style: st),
          ],
        ],
      ),
    );
  }
}

/// Logo provisoire « tivi. ».
class TiviBrand extends StatelessWidget {
  const TiviBrand({super.key, this.showName = true});
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final size = context.compact ? 24.0 : context.px(32);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'tivi'),
            TextSpan(text: '.', style: TextStyle(color: TiviColors.accent)),
          ]),
          style: TiviText.weight(size, 700, letterSpacing: -1.5, height: 1),
        ),
        if (showName && !context.compact) ...[
          SizedBox(width: context.space(4)),
          Text('IPTV', style: TiviText.micro(context).copyWith(letterSpacing: 2, color: TiviColors.text2)),
        ],
      ],
    );
  }
}

/// Avatar rond (initiales).
class TiviAvatar extends StatelessWidget {
  const TiviAvatar({super.key, this.initials = 'TV', this.onSelect});
  final String initials;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final d = tiviButtonSize(context, TiviButtonSize.md);
    return TvFocusable(
      onSelect: onSelect,
      semanticLabel: 'Profil',
      builder: (context, focused) => AnimatedScale(
        scale: focused ? 1.12 : 1,
        duration: TiviMotion.base,
        curve: TiviMotion.ease,
        child: AnimatedContainer(
          duration: TiviMotion.base,
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [TiviColors.red500, TiviColors.red700], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: focused ? [const BoxShadow(color: Colors.white, spreadRadius: 3), ...TiviShadow.focus] : null,
          ),
          child: Text(initials, style: TiviText.weight(TiviText.small(context).fontSize!, 600)),
        ),
      ),
    );
  }
}

/// Champ « Rechercher » avec micro (barre du haut de l'accueil).
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, this.onSelect});
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final d = tiviButtonSize(context, TiviButtonSize.sm);
    return TvFocusable(
      onSelect: onSelect,
      semanticLabel: 'Rechercher',
      builder: (context, focused) => AnimatedContainer(
        duration: TiviMotion.base,
        padding: EdgeInsets.only(right: context.compact ? 0 : context.space(6)),
        decoration: BoxDecoration(color: focused ? const Color(0x1AFFFFFF) : Colors.transparent, borderRadius: BorderRadius.circular(d)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: TiviMotion.base,
              width: d,
              height: d,
              decoration: BoxDecoration(color: focused ? TiviColors.white : TiviColors.glass, shape: BoxShape.circle),
              child: Icon(Icons.mic_none_rounded, size: d * .46, color: focused ? TiviColors.ink900 : TiviColors.text2),
            ),
            if (!context.compact) ...[
              SizedBox(width: context.space(4)),
              Text('Rechercher', style: TiviText.body(context).copyWith(color: focused ? TiviColors.text : TiviColors.text3)),
            ],
          ],
        ),
      ),
    );
  }
}
