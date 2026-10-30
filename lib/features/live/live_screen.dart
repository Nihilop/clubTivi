import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/local/database.dart' as db;
import '../../data/tivi/epg_index.dart';
import '../../data/tivi/language_catalog.dart';
import '../../data/tivi/live_repository.dart';
import '../../data/tivi/play_request.dart';
import '../../ui/ui.dart';
import '../providers/provider_manager.dart';

/// TV en direct (maquette image 3) : choix de la langue une seule fois,
/// puis la liste des chaînes avec l'aperçu du programme à droite.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final _listCtrl = TvIndexedListController();
  final _listFocus = FocusNode(debugLabel: 'channel-list');
  final _watchFocus = FocusNode(debugLabel: 'watch');
  _LiveFilter _filter = _LiveFilter.all;
  int _preview = 0;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    // Le comportement du Retour dépend de la position du focus
    _listFocus.addListener(_onListFocus);
  }

  void _onListFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _listFocus.removeListener(_onListFocus);
    _previewTimer?.cancel();
    _listCtrl.dispose();
    _listFocus.dispose();
    _watchFocus.dispose();
    super.dispose();
  }

  List<db.Channel> _visible(List<db.Channel> all, Set<String> favs, EpgIndex? epg) => switch (_filter) {
        _LiveFilter.all => all,
        _LiveFilter.favorites => all.where((c) => favs.contains(c.id)).toList(),
        _LiveFilter.epg => epg == null ? all : all.where((c) => epg.idFor(c) != null).toList(),
        _LiveFilter.hd => all.where((c) => _hdPattern.hasMatch(c.name)).toList(),
      };

  void _schedulePreview(int index, {bool fast = false}) {
    _previewTimer?.cancel();
    // On attend que la télécommande se calme avant de recharger l'aperçu
    _previewTimer = Timer(Duration(milliseconds: fast ? 60 : 160), () {
      if (mounted) setState(() => _preview = index);
    });
  }

  void _play(List<db.Channel> channels, int index) {
    if (channels.isEmpty) return;
    context.push('/play', extra: PlayRequest.live(channels: channels, index: index));
  }

  void _setFilter(_LiveFilter filter) {
    setState(() {
      _filter = filter;
      _preview = 0;
    });
    _listCtrl.select(0);
    _listFocus.requestFocus();
  }

  Future<void> _toggleFavorite(db.Channel c) async {
    final added = await ref.read(channelFavoritesProvider.notifier).toggle(c.id);
    if (mounted) showTiviToast(context, added ? 'Ajoutée aux favoris' : 'Retirée des favoris', icon: Icons.star_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final pref = ref.watch(languagePrefProvider);
    final summary = ref.watch(languageSummaryProvider);
    final channelsAsync = ref.watch(filteredLiveChannelsProvider);

    if (!pref.loaded || channelsAsync.isLoading || summary.isLoading) {
      return const _Scaffold(child: Center(child: CircularProgressIndicator(color: TiviColors.accent)));
    }
    final all = channelsAsync.valueOrNull ?? const <db.Channel>[];
    if (all.isEmpty) return const _Scaffold(child: _NoChannels());

    final s = summary.valueOrNull;
    if (pref.code == null && s != null && s.counts.length >= 2) {
      return _Scaffold(child: _LanguagePicker(summary: s, total: all.length, onChoose: (code) => ref.read(languagePrefProvider.notifier).choose(code)));
    }

    final favs = ref.watch(channelFavoritesProvider);
    final channels = _visible(all, favs, ref.watch(epgIndexProvider).valueOrNull);
    final preview = channels.isEmpty ? null : channels[_preview.clamp(0, channels.length - 1)];
    final lang = (pref.code == null || pref.code == 'all') ? null : languageInfo(pref.code!);

    final list = _ChannelList(
      channels: channels,
      favorites: favs,
      controller: _listCtrl,
      focusNode: _listFocus,
      onIndexChanged: _schedulePreview,
      onSelect: (i) => _play(channels, i),
      onRight: () => _watchFocus.requestFocus(),
    );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(title: _filter == _LiveFilter.favorites ? 'Favoris' : 'TV en direct', lang: lang, count: channels.length),
        SizedBox(height: context.space(3)),
        // Filtres : ↑ depuis le haut de la liste
        FocusTraversalGroup(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(children: [
              for (final f in _LiveFilter.values) ...[
                TiviChip(label: f.label, active: _filter == f, onPressed: () => _setFilter(f)),
                SizedBox(width: context.space(2)),
              ],
            ]),
          ),
        ),
      ],
    );
    final previewPanel = preview == null
        ? const SizedBox.shrink()
        : _Preview(
            channel: preview,
            favorite: favs.contains(preview.id),
            watchFocus: _watchFocus,
            onWatch: () => _play(channels, _preview.clamp(0, channels.length - 1)),
            onFavorite: () => _toggleFavorite(preview),
          );

    final destinations = [
      if (context.compact) RailDestination(icon: Icons.home_outlined, label: 'Accueil', onSelect: () => context.pop()),
      RailDestination(icon: Icons.live_tv_outlined, label: 'Direct', active: true, onSelect: () => _setFilter(_LiveFilter.all)),
      RailDestination(icon: Icons.calendar_view_day_outlined, label: 'Guide', onSelect: () => context.push('/epg')),
      RailDestination(icon: Icons.search_rounded, label: 'Recherche', onSelect: () => context.push('/search')),
    ];

    return PopScope(
      // Retour depuis l'aperçu ou le rail → revient sur la liste ; depuis la liste → accueil
      canPop: _listFocus.hasFocus || context.compact,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _listFocus.requestFocus();
      },
      child: _Scaffold(
        child: AdaptiveShell(
          onBack: () => context.pop(),
          destinations: destinations,
          child: context.compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: MediaQuery.sizeOf(context).height * .34, child: previewPanel),
                    Padding(padding: EdgeInsets.fromLTRB(context.safeX, context.space(3), context.safeX, context.space(2)), child: header),
                    Expanded(child: channels.isEmpty ? _NoResults(favorites: _filter == _LiveFilter.favorites) : list),
                  ],
                )
              : Stack(
                  children: [
                    Positioned(top: 0, bottom: 0, right: 0, width: MediaQuery.sizeOf(context).width * .52, child: previewPanel),
                    SizedBox(
                      width: (context.px(560)).clamp(320.0, MediaQuery.sizeOf(context).width * .45),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: context.safeY),
                          Padding(padding: EdgeInsets.only(left: context.px(26)), child: header),
                          Expanded(child: channels.isEmpty ? _NoResults(favorites: _filter == _LiveFilter.favorites) : list),
                        ],
                      ),
                    ),
                    Positioned(
                      top: context.safeY,
                      right: context.safeX,
                      child: FocusTraversalGroup(
                        child: Row(children: [
                          const ClockWeather(),
                          SizedBox(width: context.space(5)),
                          TiviIconButton(icon: Icons.search_rounded, size: TiviButtonSize.sm, tooltip: 'Rechercher', onPressed: () => context.push('/search')),
                          SizedBox(width: context.space(4)),
                          const TiviAvatar(),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: TiviColors.bg, body: child);
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.count, this.lang});
  final String title;
  final int count;
  final LanguageInfo? lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TiviText.h1(context)),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (lang?.flag != null) ...[
            ClipOval(child: CachedNetworkImage(imageUrl: 'https://flagcdn.com/w40/${lang!.flag!}.png', width: 16, height: 16, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox())),
            const SizedBox(width: 8),
          ],
          Text('${lang != null ? '${lang!.label} · ' : ''}$count chaînes', style: TiviText.small(context)),
        ]),
      ],
    );
  }
}

/// Liste des chaînes : un seul nœud de focus, l'élément actif reste centré.
class _ChannelList extends ConsumerWidget {
  const _ChannelList({
    required this.channels,
    required this.favorites,
    required this.controller,
    required this.focusNode,
    required this.onIndexChanged,
    required this.onSelect,
    required this.onRight,
  });

  final List<db.Channel> channels;
  final Set<String> favorites;
  final TvIndexedListController controller;
  final FocusNode focusNode;
  final void Function(int index, {bool fast}) onIndexChanged;
  final ValueChanged<int> onSelect;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gap = context.compact ? 8.0 : context.px(18);
    final cardH = ChannelCard.heightOf(context);
    final hPad = context.compact ? context.safeX : context.px(26);
    final listView = TvIndexedList(
      controller: controller,
      focusNode: focusNode,
      autofocus: !context.compact,
      itemCount: channels.length,
      itemExtent: cardH + gap,
      centered: !context.compact,
      padding: context.compact ? EdgeInsets.only(bottom: context.space(4)) : EdgeInsets.symmetric(vertical: context.px(40)),
      onIndexChanged: (i) => onIndexChanged(i),
      onSelect: onSelect,
      itemBuilder: (context, i, focused) {
        final c = channels[i];
        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, gap),
          child: _ChannelTile(channel: c, focused: focused, favorite: favorites.contains(c.id)),
        );
      },
    );
    // Flèche droite → bouton « Regarder » de l'aperçu
    final withRight = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && TvKeys.isRight(e.logicalKey) && !context.compact) {
          onRight();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: listView,
    );
    if (context.compact) return withRight;
    // Fondu haut / bas comme sur la maquette
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
        stops: [0, .1, .88, 1],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: withRight,
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({required this.channel, required this.focused, required this.favorite});
  final db.Channel channel;
  final bool focused;
  final bool favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progs = ref.watch(channelProgrammesProvider(channel));
    final now = progs.where((p) => p.isNow).firstOrNull;
    return ChannelCard(
      name: channel.name,
      logoUrl: channel.tvgLogo,
      // Pour iptv-org le groupe est la langue : inutile de la répéter sous chaque chaîne
      subtitle: now?.title ?? (channel.providerId == kIptvOrgProviderId ? null : stripLanguagePrefix(channel.groupTitle ?? '')),
      badges: channelBadges(channel.name, hasEpg: progs.isNotEmpty),
      number: channel.channelNumber,
      favorite: favorite,
      focused: focused,
    );
  }
}

/// Aperçu à droite : visuel, programme en cours, progression, suivant, actions.
class _Preview extends ConsumerWidget {
  const _Preview({required this.channel, required this.favorite, required this.watchFocus, required this.onWatch, required this.onFavorite});

  final db.Channel channel;
  final bool favorite;
  final FocusNode watchFocus;
  final VoidCallback onWatch;
  final VoidCallback onFavorite;

  String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progs = ref.watch(channelProgrammesProvider(channel));
    final now = progs.where((p) => p.isNow).firstOrNull;
    final next = progs.where((p) => !p.isNow).firstOrNull;
    final compact = context.compact;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Visuel : le logo de la chaîne, flouté en fond et net par-dessus
        AnimatedSwitcher(
          duration: TiviMotion.slow,
          child: _PreviewArt(key: ValueKey(channel.id), channel: channel),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: compact
                ? const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [TiviColors.bg, Color(0x661D1A27), Color(0x331D1A27)])
                : const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xF21D1A27), Color(0x801D1A27), Color(0x1A1D1A27)], stops: [0, .45, .75]),
          ),
        ),
        if (!compact)
          const DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [TiviColors.bg, Color(0x001D1A27)], stops: [0, .4])),
          ),
        Positioned(
          left: compact ? context.safeX : null,
          right: context.safeX,
          bottom: compact ? context.space(2) : context.safeY,
          width: compact ? null : MediaQuery.sizeOf(context).width * .52 * .64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(now != null ? 'En cours…' : (channel.providerId == kIptvOrgProviderId ? 'En direct' : stripLanguagePrefix(channel.groupTitle ?? 'En direct')), style: TiviText.small(context).copyWith(color: TiviColors.text2)),
              SizedBox(height: context.space(2)),
              Text(now?.title ?? channel.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TiviText.weight(TiviText.h1(context).fontSize!, 600)),
              if (!compact && now?.description != null) ...[
                SizedBox(height: context.space(3)),
                Text(now!.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TiviText.body(context)),
              ],
              if (now != null) ...[
                SizedBox(height: context.space(4)),
                TiviProgress(value: now.progress),
                SizedBox(height: context.space(2)),
                Row(children: [
                  Text(_hm(now.start), style: TiviText.small(context).copyWith(color: TiviColors.text2)),
                  const Spacer(),
                  Text(_hm(now.stop), style: TiviText.small(context).copyWith(color: TiviColors.text2)),
                ]),
              ],
              if (!compact && next != null) ...[
                SizedBox(height: context.space(3)),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: TiviColors.text3),
                  const SizedBox(width: 8),
                  Flexible(child: Text('À suivre · ${_hm(next.start)}  ${next.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.small(context))),
                ]),
              ],
              SizedBox(height: context.space(compact ? 3 : 5)),
              FocusTraversalGroup(
                child: Row(children: [
                  TiviPillButton(label: 'Regarder', icon: Icons.play_arrow_rounded, primary: true, focusNode: watchFocus, onPressed: onWatch),
                  SizedBox(width: context.space(3)),
                  TiviPillButton(label: favorite ? 'Retirer' : 'Favori', icon: Icons.star_rounded, on: favorite, onPressed: onFavorite),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewArt extends StatelessWidget {
  const _PreviewArt({super.key, required this.channel});
  final db.Channel channel;

  @override
  Widget build(BuildContext context) {
    final logo = channel.tvgLogo;
    final mask = context.compact
        ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.transparent], stops: [.5, 1])
        : const LinearGradient(colors: [Colors.transparent, Colors.black], stops: [0, .42]);
    return ShaderMask(
      shaderCallback: mask.createShader,
      blendMode: BlendMode.dstIn,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: TiviColors.surfaceRaised),
          if (logo != null && logo.isNotEmpty)
            // ClipRect : sans lui le flou déborde du cadre, hors du masque de fondu
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40, tileMode: TileMode.decal),
                child: Opacity(opacity: .45, child: CachedNetworkImage(imageUrl: logo, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox())),
              ),
            ),
          Align(
            alignment: context.compact ? const Alignment(0, -.3) : const Alignment(.25, -.35),
            child: SizedBox.square(
              dimension: context.compact ? 110 : context.px(220),
              child: Opacity(opacity: .9, child: ChannelLogo(name: channel.name, url: logo, padding: 0)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choix de la langue, affiché une seule fois.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.summary, required this.total, required this.onChoose});
  final LanguageSummary summary;
  final int total;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final entries = summary.counts;
    final cols = context.compact ? 1 : 4;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.safeX, context.safeY, context.safeX, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            TiviIconButton(icon: Icons.chevron_left_rounded, iconScale: .55, tooltip: 'Retour', onPressed: () => context.pop()),
            SizedBox(width: context.space(5)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Quelle langue pour vos chaînes ?', style: TiviText.h1(context)),
                const SizedBox(height: 6),
                Text('On ne vous le demandera qu\'une fois. Modifiable dans les réglages.', style: TiviText.body(context)),
              ]),
            ),
          ]),
          SizedBox(height: context.space(6)),
          Expanded(
            child: FocusTraversalGroup(
              child: GridView.builder(
                padding: EdgeInsets.only(bottom: context.space(7), top: 8, left: 8, right: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: context.compact ? 72 : context.px(84),
                  crossAxisSpacing: context.space(5),
                  mainAxisSpacing: context.space(3),
                ),
                itemCount: entries.length + 1,
                itemBuilder: (context, i) {
                  if (i == entries.length) {
                    return LanguageTile(label: 'Toutes les chaînes', count: total, onSelect: () => onChoose('all'));
                  }
                  final e = entries[i];
                  final info = languageInfo(e.key);
                  return LanguageTile(autofocus: i == 0, label: info.label, count: e.value, flagCode: info.flag, onSelect: () => onChoose(e.key));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoChannels extends StatelessWidget {
  const _NoChannels();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.live_tv_outlined, size: context.px(56), color: TiviColors.text3),
        SizedBox(height: context.space(4)),
        Text('Aucune chaîne pour l\'instant', style: TiviText.h2(context)),
        SizedBox(height: context.space(2)),
        Text('Ajoutez une playlist M3U ou Xtream pour commencer.', style: TiviText.body(context)),
        SizedBox(height: context.space(5)),
        TiviPillButton(label: 'Ajouter une playlist', icon: Icons.add_rounded, primary: true, autofocus: true, onPressed: () => context.push('/providers')),
      ]),
    );
  }
}

enum _LiveFilter {
  all('Toutes'),
  favorites('Favoris'),
  epg('Avec guide TV'),
  hd('HD / 4K');

  const _LiveFilter(this.label);
  final String label;
}

final _hdPattern = RegExp(r'\b(4K|UHD|FHD|HD|1080[pi]?|720p)\b', caseSensitive: false);

class _NoResults extends StatelessWidget {
  const _NoResults({required this.favorites});
  final bool favorites;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(context.space(6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.star_outline_rounded, size: context.px(40), color: TiviColors.text3),
          SizedBox(height: context.space(3)),
          Text(favorites ? 'Aucun favori pour l\'instant.' : 'Aucune chaîne pour ce filtre.', style: TiviText.body(context)),
          if (favorites) Text('Sur une chaîne : flèche droite → « Favori ».', style: TiviText.small(context)),
        ]),
      );
}
