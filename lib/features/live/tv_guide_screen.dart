import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/local/database.dart' as db;
import '../../data/tivi/epg_index.dart';
import '../../data/tivi/live_repository.dart';
import '../../data/tivi/play_request.dart';
import '../../data/tivi/reminders.dart';
import '../../ui/ui.dart';

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Demain';
  if (diff == -1) return 'Hier';
  return formatDateFr(d);
}

/// Guide TV : chaînes de la langue choisie à gauche, programmes à droite.
/// OK sur le programme en cours → lecture ; sur un programme à venir → rappel.
class TvGuideScreen extends ConsumerStatefulWidget {
  const TvGuideScreen({super.key});

  @override
  ConsumerState<TvGuideScreen> createState() => _TvGuideScreenState();
}

class _TvGuideScreenState extends ConsumerState<TvGuideScreen> {
  final _listCtrl = TvIndexedListController();
  final _listFocus = FocusNode(debugLabel: 'guide-channels');
  final _scheduleFocus = FocusNode(debugLabel: 'guide-schedule');
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Le Retour dépend de la position du focus (programmes → chaînes → sortie)
    _listFocus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _listFocus.removeListener(_onFocus);
    _listCtrl.dispose();
    _listFocus.dispose();
    _scheduleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(filteredLiveChannelsProvider).valueOrNull ?? const <db.Channel>[];
    final index = ref.watch(epgIndexProvider).valueOrNull;
    // Le guide ne liste que les chaînes qui ont des programmes
    final channels = index == null ? const <db.Channel>[] : all.where((c) => index.idFor(c) != null).toList();
    final selected = channels.isEmpty ? null : channels[_index.clamp(0, channels.length - 1)];

    final list = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && TvKeys.isRight(e.logicalKey) && !context.compact) {
          _scheduleFocus.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TvIndexedList(
        controller: _listCtrl,
        focusNode: _listFocus,
        autofocus: true,
        itemCount: channels.length,
        itemExtent: (context.compact ? 64.0 : context.px(78)) + 8,
        centered: !context.compact,
        padding: EdgeInsets.symmetric(vertical: context.space(4), horizontal: context.space(4)),
        onIndexChanged: (i) => setState(() => _index = i),
        onSelect: (i) => setState(() => _index = i),
        itemBuilder: (context, i, focused) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _GuideChannelRow(channel: channels[i], focused: focused, selected: i == _index),
        ),
      ),
    );

    final schedule = selected == null
        ? Center(child: Text(index == null ? 'Chargement du guide…' : 'Aucun programme pour ces chaînes.\nVérifiez le guide TV dans les réglages.', textAlign: TextAlign.center, style: TiviText.body(context)))
        : _Schedule(
            key: ValueKey(selected.id),
            channel: selected,
            epgId: index!.idFor(selected)!,
            firstFocus: _scheduleFocus,
            onPlay: () => context.push('/play', extra: PlayRequest.live(channels: channels, index: _index)),
          );

    return PopScope(
      canPop: _listFocus.hasFocus || context.compact,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _listFocus.requestFocus();
      },
      child: Scaffold(
        backgroundColor: TiviColors.bg,
        body: AdaptiveShell(
          onBack: () => context.pop(),
          destinations: [
            if (context.compact) RailDestination(icon: Icons.home_outlined, label: 'Accueil', onSelect: () => context.go('/')),
            RailDestination(icon: Icons.live_tv_outlined, label: 'Direct', onSelect: () => context.pushReplacement('/live')),
            RailDestination(icon: Icons.calendar_view_day_outlined, label: 'Guide', active: true, onSelect: () {}),
            RailDestination(icon: Icons.search_rounded, label: 'Recherche', onSelect: () => context.push('/search')),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.compact ? context.safeX : context.space(4), context.safeY, context.safeX, 0),
                child: Row(children: [
                  Text('Guide TV', style: TiviText.h1(context)),
                  SizedBox(width: context.space(4)),
                  Text('${channels.length} chaînes', style: TiviText.small(context)),
                  const Spacer(),
                  if (!context.compact) const ClockWeather(),
                ]),
              ),
              Expanded(
                child: context.compact
                    ? Column(children: [SizedBox(height: 220, child: list), const Divider(color: TiviColors.line, height: 1), Expanded(child: schedule)])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: (MediaQuery.sizeOf(context).width * .3).clamp(260.0, 480.0), child: list),
                          Expanded(child: schedule),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideChannelRow extends ConsumerWidget {
  const _GuideChannelRow({required this.channel, required this.focused, required this.selected});
  final db.Channel channel;
  final bool focused;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(channelProgrammesProvider(channel)).where((p) => p.isNow).firstOrNull;
    return AnimatedScale(
      scale: focused ? 1.04 : 1,
      duration: TiviMotion.base,
      curve: TiviMotion.ease,
      child: AnimatedContainer(
        duration: TiviMotion.base,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: focused ? TiviColors.surfaceFocus : (selected ? TiviColors.surfaceRaised : TiviColors.surface),
          border: Border.all(color: focused ? TiviColors.lineStrong : TiviColors.line),
          borderRadius: const BorderRadius.all(TiviRadius.xs),
          boxShadow: focused ? TiviShadow.focus : null,
        ),
        child: Row(children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: const BoxDecoration(color: TiviColors.bg, borderRadius: BorderRadius.all(TiviRadius.xs)),
              child: ChannelLogo(name: channel.name, url: channel.tvgLogo),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.weight(TiviText.body(context).fontSize!, 500)),
                if (now != null) Text(now.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.small(context)),
              ],
            ),
          ),
          if (selected && !focused) const Icon(Icons.chevron_right_rounded, color: TiviColors.text3),
        ]),
      ),
    );
  }
}

class _Schedule extends ConsumerWidget {
  const _Schedule({super.key, required this.channel, required this.epgId, required this.firstFocus, required this.onPlay});
  final db.Channel channel;
  final String epgId;
  final FocusNode firstFocus;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progs = ref.watch(scheduleProvider(epgId)).valueOrNull;
    final reminders = ref.watch(remindersProvider);
    if (progs == null) return const Center(child: CircularProgressIndicator(color: TiviColors.accent));
    if (progs.isEmpty) return Center(child: Text('Pas de programme prévu.', style: TiviText.body(context)));
    final current = progs.indexWhere((p) => p.isNow);
    final focusAt = current >= 0 ? current : 0;

    final rows = <Widget>[];
    String? lastDay;
    for (var i = 0; i < progs.length; i++) {
      final p = progs[i];
      final day = _dayLabel(p.start);
      if (day != lastDay) {
        rows.add(Padding(
          padding: EdgeInsets.only(top: context.space(rows.isEmpty ? 0 : 5), bottom: context.space(2)),
          child: Text(day.toUpperCase(), style: TiviText.eyebrow(context)),
        ));
        lastDay = day;
      }
      final reminded = reminders.contains(RemindersNotifier.keyOf(p.epgChannelId, p.start));
      rows.add(_ProgrammeRow(
        programme: p,
        focusNode: i == focusAt ? firstFocus : null,
        reminded: reminded,
        onSelect: () async {
          if (p.isNow) return onPlay();
          if (p.stop.isBefore(DateTime.now())) return showTiviToast(context, 'Programme terminé');
          final added = await ref.read(remindersProvider.notifier).toggle(p, channelId: channel.id);
          if (context.mounted) showTiviToast(context, added ? 'Rappel : « ${p.title} » à ${_hm(p.start)}' : 'Rappel retiré', icon: Icons.notifications_none_rounded);
        },
      ));
    }

    return FocusTraversalGroup(
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.space(5), context.space(4), context.safeX, context.space(8)),
        children: rows,
      ),
    );
  }
}

class _ProgrammeRow extends StatelessWidget {
  const _ProgrammeRow({required this.programme, required this.onSelect, required this.reminded, this.focusNode});
  final db.EpgProgramme programme;
  final VoidCallback onSelect;
  final bool reminded;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    final past = p.stop.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TvFocusable(
        focusNode: focusNode,
        onSelect: onSelect,
        centerOnFocus: true,
        builder: (context, focused) => AnimatedContainer(
          duration: TiviMotion.base,
          padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(3)),
          decoration: BoxDecoration(
            color: focused ? TiviColors.surfaceFocus : (p.isNow ? TiviColors.surfaceRaised : Colors.transparent),
            border: Border.all(color: focused ? TiviColors.lineStrong : Colors.transparent),
            borderRadius: const BorderRadius.all(TiviRadius.xs),
          ),
          child: Opacity(
            opacity: past ? .5 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: context.compact ? 54 : context.px(70),
                  child: Text(_hm(p.start), style: TiviText.weight(TiviText.body(context).fontSize!, 500, color: p.isNow ? TiviColors.accent : TiviColors.text2)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.weight(TiviText.body(context).fontSize!, 500))),
                        if (p.isNow) ...[const SizedBox(width: 10), const TiviBadge.live(label: 'En cours')],
                        if (reminded) ...[const SizedBox(width: 10), const Icon(Icons.notifications_active_rounded, size: 16, color: TiviColors.accent)],
                      ]),
                      if (p.isNow) ...[const SizedBox(height: 8), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: TiviProgress(value: p.progress, height: 3))],
                      // La description s'ouvre sur le programme focus
                      AnimatedSize(
                        duration: TiviMotion.base,
                        alignment: Alignment.topLeft,
                        child: focused && (p.description ?? '').isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(p.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TiviText.small(context).copyWith(color: TiviColors.text2)),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      if (focused)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            p.isNow ? 'OK : regarder' : (past ? 'Terminé' : (reminded ? 'OK : retirer le rappel' : 'OK : me le rappeler')),
                            style: TiviText.micro(context).copyWith(color: TiviColors.text3),
                          ),
                        ),
                    ],
                  ),
                ),
                Text('${_hm(p.start)} – ${_hm(p.stop)}', style: TiviText.small(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
