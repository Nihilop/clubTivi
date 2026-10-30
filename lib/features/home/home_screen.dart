import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/epg_refresh_service.dart';
import '../../data/tivi/epg_language_sync.dart';
import '../../data/tivi/live_repository.dart';
import '../../data/tivi/resume_store.dart';
import '../../data/tivi/vod_catalog.dart';
import '../../core/weather_service.dart';
import '../../ui/ui.dart';
import '../providers/provider_manager.dart';

/// Accueil (maquette image 2) : quatre tuiles en verre, horloge, réglages.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _startupTasks();
  }

  /// Tâches de fond reprises de l'écran d'origine (EPG, logos, météo).
  Future<void> _startupTasks() async {
    ref.read(weatherProvider);
    ResumeStore.instance.load();
    final providers = ref.read(providerManagerProvider);
    providers.resolveAllMissingLogos().catchError((_) {});
    // Source iptv-org par défaut (ajoutée une fois, rafraîchie chaque jour)
    providers.ensureDefaultProvider().catchError((e) => debugPrint('[Tivi] default source: $e'));
    // Guide TV de la langue choisie, puis les autres sources EPG de l'utilisateur
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('tivi.live.language');
    if (lang != null) await ref.read(epgLanguageSyncProvider).sync(lang).catchError((e) => debugPrint('[EPG] sync: $e'));
    ref.read(epgRefreshServiceProvider).refreshAllSources().catchError((e) => debugPrint('[EPG] refresh failed: $e'));
  }

  String _count(int n, String unit) {
    if (n == 0) return 'Aucun contenu';
    final s = n >= 1000 ? '+${(n / 1000).floor()} ${(n % 1000).toString().padLeft(3, '0')}' : '$n';
    return '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveChannelsProvider).valueOrNull ?? const [];
    final vod = ref.watch(vodCatalogProvider).valueOrNull;
    final noPlaylist = ref.watch(liveChannelsProvider).hasValue && live.isEmpty && (vod?.isEmpty ?? true);

    final tiles = [
      GlassTile(
        autofocus: true,
        icon: Icons.live_tv_outlined,
        title: 'TV en direct',
        meta: noPlaylist ? 'Ajouter une playlist' : _count(live.length, 'chaînes'),
        corner: noPlaylist ? null : const _UpdatedCorner(),
        onSelect: () => context.push(noPlaylist ? '/providers' : '/live'),
      ),
      // Films / Séries n'apparaissent que si une source en contient
      if (vod?.movies.isNotEmpty ?? false)
        GlassTile(icon: Icons.movie_outlined, title: 'Films', meta: _count(vod!.movies.length, 'films'), onSelect: () => context.push('/vod?kind=movies')),
      if (vod?.series.isNotEmpty ?? false)
        GlassTile(
          icon: Icons.video_library_outlined,
          title: 'Séries',
          meta: _count(vod!.series.length, 'séries'),
          onSelect: () => context.push('/vod?kind=series'),
        ),
    ];

    return Scaffold(
      backgroundColor: TiviColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.safeX, context.safeY, context.safeX, 0),
                child: FocusTraversalGroup(
                  child: Row(
                    children: [
                      const TiviBrand(),
                      if (!context.compact) ...[
                        SizedBox(width: context.space(5)),
                        Container(width: 1, height: context.px(34), color: TiviColors.lineStrong),
                        SizedBox(width: context.space(5)),
                      ] else
                        const Spacer(),
                      SearchPill(onSelect: () => context.push('/search')),
                      if (!context.compact) const Spacer(),
                      SizedBox(width: context.space(3)),
                      TiviIconButton(icon: Icons.settings_outlined, size: TiviButtonSize.sm, tooltip: 'Réglages', onPressed: () => context.push('/settings')),
                      SizedBox(width: context.space(4)),
                      const TiviAvatar(),
                    ],
                  ),
                ),
              ),
              Expanded(child: context.compact ? _compactBody(tiles) : _tvBody(tiles)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tvBody(List<Widget> tiles) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.safeX),
            child: LayoutBuilder(
              builder: (context, box) {
                // Les tuiles occupent au plus ~80 % de la largeur, marge du zoom de focus comprise
                final gap = context.px(30);
                final w = ((box.maxWidth * .8 - gap * (tiles.length - 1)) / tiles.length).clamp(120.0, context.px(220));
                return FocusTraversalGroup(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[if (i > 0) SizedBox(width: gap), _SizedTile(tile: tiles[i] as GlassTile, width: w)],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(right: context.safeX, bottom: context.safeY, child: const _BigClock()),
      ],
    );
  }

  Widget _compactBody(List<Widget> tiles) {
    return ListView(
      padding: EdgeInsets.fromLTRB(context.safeX, context.space(6), context.safeX, context.space(6)),
      children: [
        const _BigClock(alignLeft: true),
        SizedBox(height: context.space(5)),
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final t in tiles)
                  SizedBox(
                    width: w,
                    child: _SizedTile(tile: t as GlassTile, width: w, aspectRatio: 1 / 1.05),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Tuile redimensionnée selon l'espace (presque carrée sur mobile).
class _SizedTile extends StatelessWidget {
  const _SizedTile({required this.tile, required this.width, this.aspectRatio = .6});
  final GlassTile tile;
  final double width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => GlassTile(
    icon: tile.icon,
    title: tile.title,
    meta: tile.meta,
    corner: tile.corner,
    onSelect: tile.onSelect,
    autofocus: tile.autofocus,
    width: width,
    aspectRatio: aspectRatio,
  );
}

class _UpdatedCorner extends ConsumerWidget {
  const _UpdatedCorner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sync_rounded, size: context.px(14).clamp(12.0, 20.0), color: TiviColors.text3),
        const SizedBox(width: 4),
        Text('Playlist à jour', style: TiviText.micro(context)),
      ],
    );
  }
}

class _BigClock extends ConsumerWidget {
  const _BigClock({this.alignLeft = false});
  final bool alignLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temp = temperatureLabel(ref.watch(weatherProvider));
    return MinuteTicker(
      builder: (context, now) => Column(
        crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (temp != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_rounded, color: Colors.white, size: context.px(26).clamp(22.0, 40.0)),
                const SizedBox(width: 6),
                Text(temp, style: TiviText.weight(TiviText.h3(context).fontSize!, 400)),
              ],
            ),
          SizedBox(height: context.space(2)),
          Text(formatClock(now), style: TiviText.display(context).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          SizedBox(height: context.space(2)),
          Text(formatDateFr(now), style: TiviText.weight(TiviText.h2(context).fontSize!, 300, color: TiviColors.text2)),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(center: Alignment(.7, -.2), radius: 1.2, colors: [Color(0xFF2E2838), TiviColors.bg]),
    ),
  );
}
