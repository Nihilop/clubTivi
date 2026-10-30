import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/local/database.dart' as db;
import '../../data/tivi/epg_index.dart';
import '../../data/tivi/live_repository.dart';
import '../../data/tivi/play_request.dart';
import '../../data/tivi/reminders.dart';
import '../../data/tivi/resume_store.dart';
import '../../data/tivi/vod_catalog.dart';
import '../../ui/ui.dart';
import '../providers/provider_manager.dart';

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Programme trouvé + chaîne qui le diffuse.
class _ProgHit {
  const _ProgHit(this.programme, this.channel);
  final db.EpgProgramme programme;
  final db.Channel channel;
}

/// Recherche : chaînes (langue choisie), programmes à la TV, films, séries.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _q = '';
  List<_ProgHit> _programmes = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(text.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _q = q);
    if (q.length < 2) {
      setState(() => _programmes = const []);
      return;
    }
    // Programmes en cours ou dans les 12 h, sur les chaînes de la langue choisie
    final database = ref.read(databaseProvider);
    final index = ref.read(epgIndexProvider).valueOrNull;
    final channels = ref.read(filteredLiveChannelsProvider).valueOrNull ?? const <db.Channel>[];
    if (index == null) return;
    final byEpg = <String, db.Channel>{};
    for (final c in channels) {
      final id = index.idFor(c);
      if (id != null) byEpg.putIfAbsent(id, () => c);
    }
    final now = DateTime.now();
    final rows = await (database.select(database.epgProgrammes)
          ..where((p) =>
              p.title.like('%$q%') &
              p.stop.isBiggerThanValue(now) &
              p.start.isSmallerThanValue(now.add(const Duration(hours: 12))) &
              p.epgChannelId.isIn(byEpg.keys))
          ..orderBy([(p) => OrderingTerm.asc(p.start)])
          ..limit(40))
        .get();
    if (!mounted || q != _q) return;
    setState(() => _programmes = [for (final p in rows) _ProgHit(p, byEpg[p.epgChannelId]!)]);
  }

  @override
  Widget build(BuildContext context) {
    final q = _norm(_q);
    final channels = ref.watch(filteredLiveChannelsProvider).valueOrNull ?? const <db.Channel>[];
    final catalog = ref.watch(vodCatalogProvider).valueOrNull;
    final hasQuery = q.length >= 2;

    final chanHits = hasQuery ? channels.where((c) => _norm(c.name).contains(q)).take(40).toList() : const <db.Channel>[];
    final movieHits = hasQuery ? (catalog?.movies.where((m) => _norm(m.title).contains(q)).take(40).toList() ?? const []) : const <VodMovie>[];
    final seriesHits = hasQuery ? (catalog?.series.where((s) => _norm(s.title).contains(q)).take(40).toList() ?? const []) : const <VodSeries>[];
    final empty = hasQuery && chanHits.isEmpty && movieHits.isEmpty && seriesHits.isEmpty && _programmes.isEmpty;
    final posterW = PosterCard.widthOf(context);
    final reminders = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: TiviColors.bg,
      body: FocusTraversalGroup(
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.safeX, context.safeY, context.safeX, context.space(8)),
          children: [
            Row(children: [
              TiviIconButton(icon: Icons.chevron_left_rounded, iconScale: .55, tooltip: 'Retour', onPressed: () => context.pop()),
              SizedBox(width: context.space(4)),
              Expanded(
                child: TiviTextField(
                  controller: _query,
                  label: 'Chaînes, programmes, films, séries…',
                  icon: Icons.search_rounded,
                  autofocus: true,
                  clearable: true,
                  onChanged: _onChanged,
                  onSubmitted: (t) => _search(t.trim()),
                ),
              ),
            ]),
            SizedBox(height: context.space(6)),
            if (!hasQuery)
              _Hint(text: 'Tapez au moins 2 lettres. Sur la télécommande, OK ouvre le clavier ; ↓ pour parcourir les résultats.')
            else if (empty)
              _Hint(text: 'Aucun résultat pour « $_q ».'),
            if (chanHits.isNotEmpty)
              _ResultRow(
                title: 'Chaînes',
                count: chanHits.length,
                height: (context.compact ? 84.0 : context.px(118)) + 28,
                itemExtent: (context.compact ? 260.0 : context.px(340)) + context.space(4),
                itemCount: chanHits.length,
                onSelect: (i) => context.push('/play', extra: PlayRequest.live(channels: chanHits, index: i)),
                itemBuilder: (context, i, focused) => Padding(
                  padding: EdgeInsets.only(right: context.space(4)),
                  child: ChannelCard(name: chanHits[i].name, logoUrl: chanHits[i].tvgLogo, subtitle: chanHits[i].groupTitle, focused: focused),
                ),
              ),
            if (_programmes.isNotEmpty)
              _ResultRow(
                title: 'À la TV',
                count: _programmes.length,
                height: (context.compact ? 96.0 : context.px(116)) + 28,
                itemExtent: (context.compact ? 230.0 : context.px(290)) + context.space(4),
                itemCount: _programmes.length,
                onSelect: (i) async {
                  final hit = _programmes[i];
                  if (hit.programme.isNow) {
                    context.push('/play', extra: PlayRequest.live(channels: [hit.channel], index: 0));
                    return;
                  }
                  final added = await ref.read(remindersProvider.notifier).toggle(hit.programme, channelId: hit.channel.id);
                  if (mounted) showTiviToast(this.context, added ? 'Rappel ajouté' : 'Rappel retiré', icon: Icons.notifications_none_rounded);
                },
                itemBuilder: (context, i, focused) {
                  final hit = _programmes[i];
                  final reminded = reminders.contains(RemindersNotifier.keyOf(hit.programme.epgChannelId, hit.programme.start));
                  return Padding(padding: EdgeInsets.only(right: context.space(4)), child: _ProgrammeCard(hit: hit, focused: focused, reminded: reminded));
                },
              ),
            if (movieHits.isNotEmpty)
              _ResultRow(
                title: 'Films',
                count: movieHits.length,
                height: posterW * 1.5 + 40,
                itemExtent: posterW + context.space(4),
                itemCount: movieHits.length,
                onSelect: (i) => context.push('/play', extra: PlayRequest.movie(movieHits[i])),
                itemBuilder: (context, i, focused) => Align(
                  alignment: Alignment.topLeft,
                  child: PosterCard(
                    title: movieHits[i].title,
                    subtitle: movieHits[i].year?.toString(),
                    imageUrl: movieHits[i].poster,
                    progress: ResumeStore.instance.progress(movieHits[i].streamUrl),
                    focused: focused,
                  ),
                ),
              ),
            if (seriesHits.isNotEmpty)
              _ResultRow(
                title: 'Séries',
                count: seriesHits.length,
                height: posterW * 1.5 + 40,
                itemExtent: posterW + context.space(4),
                itemCount: seriesHits.length,
                onSelect: (i) => context.push('/play', extra: PlayRequest.episode(seriesHits[i], 0)),
                itemBuilder: (context, i, focused) => Align(
                  alignment: Alignment.topLeft,
                  child: PosterCard(title: seriesHits[i].title, subtitle: '${seriesHits[i].episodeCount} épisodes', imageUrl: seriesHits[i].poster, focused: focused),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: context.space(5)),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: TiviColors.text3, size: 20),
          SizedBox(width: context.space(3)),
          Expanded(child: Text(text, style: TiviText.body(context))),
        ]),
      );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.title,
    required this.count,
    required this.height,
    required this.itemExtent,
    required this.itemCount,
    required this.itemBuilder,
    required this.onSelect,
  });

  final String title;
  final int count;
  final double height;
  final double itemExtent;
  final int itemCount;
  final Widget Function(BuildContext, int, bool) itemBuilder;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.space(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title, style: TiviText.h3(context).copyWith(color: TiviColors.text2)),
            SizedBox(width: context.space(2)),
            TiviBadge.soft('$count'),
          ]),
          SizedBox(
            height: height,
            child: TvIndexedList(
              axis: Axis.horizontal,
              itemCount: itemCount,
              itemExtent: itemExtent,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              onSelect: onSelect,
              onFocusChange: (f) {
                if (f) Scrollable.ensureVisible(context, alignment: .3, duration: TiviMotion.base, curve: TiviMotion.ease);
              },
              itemBuilder: itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({required this.hit, required this.focused, required this.reminded});
  final _ProgHit hit;
  final bool focused;
  final bool reminded;

  @override
  Widget build(BuildContext context) {
    final p = hit.programme;
    return AnimatedScale(
      scale: focused ? TiviMotion.focusScale : 1,
      duration: TiviMotion.base,
      curve: TiviMotion.ease,
      child: AnimatedContainer(
        duration: TiviMotion.base,
        padding: EdgeInsets.all(context.space(3)),
        decoration: BoxDecoration(
          color: focused ? TiviColors.surfaceFocus : TiviColors.surface,
          border: Border.all(color: focused ? TiviColors.lineStrong : TiviColors.line),
          borderRadius: const BorderRadius.all(TiviRadius.xs),
          boxShadow: focused ? TiviShadow.focus : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (p.isNow) const TiviBadge.live(label: 'En cours') else Text(_hm(p.start), style: TiviText.small(context).copyWith(color: TiviColors.accent)),
              const Spacer(),
              if (reminded) const Icon(Icons.notifications_active_rounded, size: 16, color: TiviColors.accent),
            ]),
            const SizedBox(height: 6),
            Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TiviText.weight(TiviText.body(context).fontSize!, 500)),
            const Spacer(),
            Text(hit.channel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.small(context)),
          ],
        ),
      ),
    );
  }
}
