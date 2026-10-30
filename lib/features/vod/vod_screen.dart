import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tivi/language_catalog.dart';
import '../../data/tivi/live_repository.dart';
import '../../data/tivi/play_request.dart';
import '../../data/tivi/resume_store.dart';
import '../../data/tivi/vod_catalog.dart';
import '../../ui/ui.dart';

/// Élément affichable dans le catalogue (film ou série).
class _Item {
  _Item.movie(VodMovie this.movie)
      : series = null,
        title = movie.title,
        poster = movie.poster,
        group = movie.group;
  _Item.series(VodSeries this.series)
      : movie = null,
        title = series.title,
        poster = series.poster,
        group = series.group;

  final VodMovie? movie;
  final VodSeries? series;
  final String title;
  final String? poster;
  final String? group;

  String get id => movie?.id ?? series!.key;

  String get subtitle {
    if (movie != null) return movie!.year?.toString() ?? '';
    final n = series!.seasons.length;
    return '$n saison${n > 1 ? 's' : ''}';
  }

  /// Épisode à reprendre (série) : le dernier commencé, sinon le premier.
  int get resumeEpisode {
    final eps = series!.allEpisodes;
    for (var i = eps.length - 1; i >= 0; i--) {
      final p = ResumeStore.instance.progress(eps[i].streamUrl);
      if (p != null && p > 0) return i;
    }
    return 0;
  }

  double? get progress {
    if (movie != null) return ResumeStore.instance.progress(movie!.streamUrl);
    final eps = series!.allEpisodes;
    return eps.isEmpty ? null : ResumeStore.instance.progress(eps[resumeEpisode].streamUrl);
  }
}

/// Films ou séries : hero du contenu focus + rangées de posters.
/// Le hero défile avec les rangées (il ne reste pas fixe).
class VodScreen extends ConsumerStatefulWidget {
  const VodScreen({super.key, required this.series});
  final bool series;

  @override
  ConsumerState<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends ConsumerState<VodScreen> {
  final _scroll = ScrollController();
  final _playFocus = FocusNode(debugLabel: 'hero-play');
  _Item? _hero;

  /// Genre (groupe de playlist) choisi dans les filtres, null = tout.
  String? _genre;
  List<String> _genres = const [];
  Timer? _heroTimer;

  @override
  void dispose() {
    _heroTimer?.cancel();
    _scroll.dispose();
    _playFocus.dispose();
    super.dispose();
  }

  void _showHero(_Item item) {
    _heroTimer?.cancel();
    _heroTimer = Timer(const Duration(milliseconds: 140), () {
      if (mounted && _hero?.id != item.id) setState(() => _hero = item);
    });
  }

  void _play(_Item item) {
    if (item.movie != null) {
      context.push('/play', extra: PlayRequest.movie(item.movie!));
    } else if (item.series!.episodeCount > 0) {
      context.push('/play', extra: PlayRequest.episode(item.series!, item.resumeEpisode));
    }
  }

  List<MapEntry<String, List<_Item>>> _rows(VodCatalog catalog, String? lang) {
    var items = widget.series ? catalog.series.map(_Item.series).toList() : catalog.movies.map(_Item.movie).toList();
    // Même langue que les chaînes si on en trouve
    if (lang != null && lang != 'all') {
      final filtered = items.where((i) => (i.movie?.language ?? i.series?.language) == lang).toList();
      if (filtered.isNotEmpty) items = filtered;
    }
    final groups = VodCatalog.rows(items, (i) => i.group, max: 40);
    _genres = groups.take(10).map((e) => e.key).toList();
    final genre = _genre;
    if (genre != null) {
      // Un genre : tous ses titres, par rangées de 20 (A → Z)
      final list = (groups.where((e) => e.key == genre).firstOrNull?.value ?? const <_Item>[]).toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return [
        for (var i = 0; i < list.length; i += 20)
          MapEntry(i == 0 ? genre : '$genre (${i ~/ 20 + 1})', list.sublist(i, (i + 20).clamp(0, list.length))),
      ];
    }
    final resume = items.where((i) => (i.progress ?? 0) > 0).toList();
    return [
      if (resume.isNotEmpty) MapEntry('Reprendre', resume),
      if (!widget.series) MapEntry('Récents', items.take(30).toList()),
      ...groups.take(12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(vodCatalogProvider);
    final lang = ref.watch(languagePrefProvider).code;
    final title = widget.series ? 'Séries' : 'Films';

    final destinations = [
      if (context.compact) RailDestination(icon: Icons.home_outlined, label: 'Accueil', onSelect: () => context.go('/')),
      RailDestination(icon: Icons.live_tv_outlined, label: 'Direct', onSelect: () => context.pushReplacement('/live')),
      RailDestination(icon: Icons.movie_outlined, label: 'Films', active: !widget.series, onSelect: () => context.pushReplacement('/vod?kind=movies')),
      RailDestination(icon: Icons.video_library_outlined, label: 'Séries', active: widget.series, onSelect: () => context.pushReplacement('/vod?kind=series')),
    ];

    Widget body;
    if (catalog.isLoading) {
      body = const Center(child: CircularProgressIndicator(color: TiviColors.accent));
    } else {
      final rows = _rows(catalog.valueOrNull ?? const VodCatalog([], []), lang);
      if (rows.isEmpty) {
        body = _Empty(series: widget.series);
      } else {
        _hero ??= rows.first.value.first;
        body = SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.only(bottom: context.space(context.compact ? 9 : 7)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(item: _hero!, title: title, playFocus: _playFocus, onPlay: () => _play(_hero!)),
              if (_genres.length > 1)
                Padding(
                  padding: EdgeInsets.only(left: context.compact ? context.safeX : 6, top: context.space(2)),
                  child: FocusTraversalGroup(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: EdgeInsets.only(right: context.safeX),
                      child: Row(children: [
                        for (final g in [null, ..._genres]) ...[
                          TiviChip(
                            label: g == null ? 'Tout' : stripLanguagePrefix(g),
                            active: _genre == g,
                            onPressed: () => setState(() {
                              _genre = g;
                              _hero = null;
                            }),
                          ),
                          SizedBox(width: context.space(2)),
                        ],
                      ]),
                    ),
                  ),
                ),
              for (var r = 0; r < rows.length; r++)
                _PosterRow(
                  key: ValueKey('${rows[r].key}-$r'),
                  title: rows[r].key,
                  items: rows[r].value,
                  autofocus: r == 0,
                  onFocusItem: _showHero,
                  onSelect: _play,
                  onRowFocused: (rowContext) {
                    if (r == 0) {
                      _scroll.animateTo(0, duration: TiviMotion.base, curve: TiviMotion.ease);
                    } else {
                      Scrollable.ensureVisible(rowContext, alignment: .35, duration: TiviMotion.base, curve: TiviMotion.ease);
                    }
                  },
                ),
            ],
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: TiviColors.bg,
      body: AdaptiveShell(onBack: () => context.pop(), destinations: destinations, child: body),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.item, required this.title, required this.playFocus, required this.onPlay});
  final _Item item;
  final String title;
  final FocusNode playFocus;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = context.compact;
    final playLabel = item.series != null
        ? (item.progress != null ? 'Reprendre ${item.series!.allEpisodes[item.resumeEpisode].code}' : 'Lecture S1 · É1')
        : (item.progress != null ? 'Reprendre' : 'Lecture');
    return SizedBox(
      height: compact ? size.height * .52 : size.height * .56,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(duration: TiviMotion.slow, child: _HeroArt(key: ValueKey(item.id), url: item.poster)),
          Positioned(
            top: context.safeY,
            left: compact ? context.safeX : 0,
            right: context.safeX,
            child: FocusTraversalGroup(
              child: Row(children: [
                Text(title, style: TiviText.h1(context)),
                const Spacer(),
                if (!compact) ...[const ClockWeather(), SizedBox(width: context.space(5))],
                TiviIconButton(icon: Icons.search_rounded, size: TiviButtonSize.sm, tooltip: 'Rechercher', onPressed: () => context.push('/search')),
                SizedBox(width: context.space(4)),
                const TiviAvatar(),
              ]),
            ),
          ),
          Positioned(
            left: compact ? context.safeX : 0,
            right: compact ? context.safeX : null,
            bottom: context.space(4),
            width: compact ? null : size.width * .42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TiviText.weight(compact ? 30 : context.px(46), 600, height: 1.05)),
                SizedBox(height: context.space(3)),
                Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (item.subtitle.isNotEmpty) Text(item.subtitle, style: TiviText.small(context).copyWith(color: TiviColors.text2)),
                  if (item.series != null) Text('${item.series!.episodeCount} épisodes', style: TiviText.small(context).copyWith(color: TiviColors.text2)),
                  if ((item.group ?? '').isNotEmpty) Text(stripLanguagePrefix(item.group!), style: TiviText.small(context).copyWith(color: TiviColors.text2)),
                ]),
                SizedBox(height: context.space(4)),
                FocusTraversalGroup(
                  child: Row(children: [
                    TiviPillButton(label: playLabel, icon: Icons.play_arrow_rounded, primary: true, focusNode: playFocus, onPressed: onPlay),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt({super.key, this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const SizedBox.expand();
    final mask = context.compact
        ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.transparent], stops: [.45, 1])
        : const LinearGradient(colors: [Colors.transparent, Colors.black], stops: [.28, .62]);
    return ShaderMask(
      shaderCallback: mask.createShader,
      blendMode: BlendMode.dstIn,
      child: ShaderMask(
        shaderCallback: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.transparent, Colors.black], stops: [0, .4]).createShader,
        blendMode: BlendMode.dstIn,
        child: Stack(fit: StackFit.expand, children: [
          // Posters verticaux : fond flouté + affiche nette à droite
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30, tileMode: TileMode.decal),
              child: Opacity(opacity: .55, child: CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox())),
            ),
          ),
          if (!context.compact)
            Align(
              alignment: const Alignment(.82, 0),
              child: FractionallySizedBox(
                heightFactor: .86,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox()),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _PosterRow extends StatelessWidget {
  const _PosterRow({
    super.key,
    required this.title,
    required this.items,
    required this.onFocusItem,
    required this.onSelect,
    required this.onRowFocused,
    this.autofocus = false,
  });

  final String title;
  final List<_Item> items;
  final ValueChanged<_Item> onFocusItem;
  final ValueChanged<_Item> onSelect;
  final ValueChanged<BuildContext> onRowFocused;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final w = PosterCard.widthOf(context);
    final gap = context.compact ? 12.0 : context.px(20);
    final vPad = context.compact ? 10.0 : context.px(20);
    final rowH = w * 1.5 + 12 + vPad * 2;
    return Padding(
      padding: EdgeInsets.only(top: context.space(3), left: context.compact ? context.safeX : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TiviText.h3(context).copyWith(color: TiviColors.text2)),
          SizedBox(
            height: rowH,
            child: TvIndexedList(
              axis: Axis.horizontal,
              autofocus: autofocus,
              itemCount: items.length,
              itemExtent: w + gap,
              edgeSpacing: context.px(30),
              padding: EdgeInsets.fromLTRB(context.compact ? 0 : 6, vPad, context.safeX, vPad),
              onIndexChanged: (i) => onFocusItem(items[i]),
              onFocusChange: (f) {
                if (f) onRowFocused(context);
              },
              onSelect: (i) => onSelect(items[i]),
              itemBuilder: (context, i, focused) {
                if (focused) onFocusItem(items[i]);
                final it = items[i];
                return Align(
                  alignment: Alignment.topLeft,
                  child: PosterCard(title: it.title, subtitle: it.subtitle, imageUrl: it.poster, progress: it.progress, focused: focused, width: w),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.series});
  final bool series;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(series ? Icons.video_library_outlined : Icons.movie_outlined, size: context.px(56), color: TiviColors.text3),
        SizedBox(height: context.space(4)),
        Text(series ? 'Aucune série dans vos playlists' : 'Aucun film dans vos playlists', style: TiviText.h2(context)),
        SizedBox(height: context.space(2)),
        Text('Les contenus VOD de vos playlists M3U apparaîtront ici.', style: TiviText.body(context)),
        SizedBox(height: context.space(5)),
        TiviPillButton(label: 'Gérer les playlists', icon: Icons.playlist_add_rounded, primary: true, autofocus: true, onPressed: () => context.push('/providers')),
      ]),
    );
  }
}
