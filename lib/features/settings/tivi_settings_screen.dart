import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/datasources/local/database.dart' as db;
import '../../data/datasources/remote/tmdb_client.dart';
import '../../data/datasources/remote/trakt_client.dart';
import '../../data/services/epg_refresh_service.dart';
import '../../data/tivi/epg_index.dart';
import '../../data/tivi/language_catalog.dart';
import '../../data/tivi/live_repository.dart';
import '../../data/tivi/vod_catalog.dart';
import '../../ui/ui.dart';
import '../providers/provider_manager.dart';
import '../shows/shows_providers.dart';

final _providersStream = StreamProvider<List<db.Provider>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.select(database.providers).watch();
});

final _epgSourcesStream = StreamProvider<List<db.EpgSource>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.select(database.epgSources).watch();
});

/// Réglages au design system Tivi : langue, playlists, guide TV, clés API.
/// Les réglages avancés d'origine restent accessibles en bas de page.
class TiviSettingsScreen extends ConsumerStatefulWidget {
  const TiviSettingsScreen({super.key});

  @override
  ConsumerState<TiviSettingsScreen> createState() => _TiviSettingsScreenState();
}

class _TiviSettingsScreenState extends ConsumerState<TiviSettingsScreen> {
  final _busy = <String>{};
  String? _confirmDelete;

  String _ago(DateTime? d) {
    if (d == null) return 'jamais mise à jour';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return 'mise à jour il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'mise à jour il y a ${diff.inHours} h';
    return 'mise à jour il y a ${diff.inDays} j';
  }

  Future<void> _run(String key, Future<void> Function() job, String done) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await job();
      if (mounted) showTiviToast(context, done, icon: Icons.check_rounded);
    } catch (e) {
      if (mounted) showTiviToast(context, 'Échec : $e', icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _setProviderEnabled(db.Provider p, bool v) async {
    final database = ref.read(databaseProvider);
    await (database.update(database.providers)..where((t) => t.id.equals(p.id))).write(db.ProvidersCompanion(enabled: Value(v)));
    ref.invalidate(vodCatalogProvider);
  }

  Future<void> _setEpgEnabled(db.EpgSource s, bool v) async {
    final database = ref.read(databaseProvider);
    await (database.update(database.epgSources)..where((t) => t.id.equals(s.id))).write(db.EpgSourcesCompanion(enabled: Value(v)));
    ref.invalidate(epgIndexProvider);
  }

  void _deleteProvider(db.Provider p) {
    if (_confirmDelete != p.id) {
      setState(() => _confirmDelete = p.id);
      showTiviToast(context, 'Appuyez encore pour supprimer « ${p.name} »', icon: Icons.delete_outline_rounded);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _confirmDelete == p.id) setState(() => _confirmDelete = null);
      });
      return;
    }
    setState(() => _confirmDelete = null);
    _run('del-${p.id}', () async {
      await ref.read(providerManagerProvider).deleteProvider(p.id);
      ref.invalidate(vodCatalogProvider);
    }, 'Playlist supprimée');
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(_providersStream).valueOrNull ?? const [];
    final epgSources = ref.watch(_epgSourcesStream).valueOrNull ?? const [];
    final pref = ref.watch(languagePrefProvider);
    final langLabel = switch (pref.code) {
      null => 'Pas encore choisie',
      'all' => 'Toutes les langues',
      final c => languageInfo(c).label,
    };

    return Scaffold(
      backgroundColor: TiviColors.bg,
      body: FocusTraversalGroup(
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.safeX, context.safeY, context.safeX, context.space(8)),
          children: [
            Row(children: [
              TiviIconButton(icon: Icons.chevron_left_rounded, iconScale: .55, tooltip: 'Retour', onPressed: () => context.pop()),
              SizedBox(width: context.space(5)),
              Text('Réglages', style: TiviText.h1(context)),
            ]),
            SizedBox(height: context.space(6)),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.px(860)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsSection(
                      title: 'Langue des chaînes',
                      icon: Icons.public,
                      description: 'Seules les chaînes de cette langue sont affichées, avec le guide TV correspondant.',
                      children: [
                        OptionTile(
                          autofocus: true,
                          icon: Icons.translate_rounded,
                          label: langLabel,
                          hint: 'Changer',
                          onSelect: () async {
                            await ref.read(languagePrefProvider.notifier).reset();
                            if (context.mounted) context.push('/live');
                          },
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Playlists',
                      icon: Icons.playlist_play_rounded,
                      description: 'Sources de chaînes, films et séries (M3U, Xtream).',
                      children: [
                        for (final p in providers)
                          TiviSwitchRow(
                            label: p.name,
                            subtitle: '${p.type.toUpperCase()} · ${_busy.contains('ref-${p.id}') ? 'mise à jour…' : _ago(p.lastRefresh)}',
                            value: p.enabled,
                            onChanged: (v) => _setProviderEnabled(p, v),
                            trailing: [
                              TiviIconButton(
                                icon: Icons.sync_rounded,
                                size: TiviButtonSize.sm,
                                tooltip: 'Mettre à jour',
                                onPressed: () => _run('ref-${p.id}', () async {
                                  await ref.read(providerManagerProvider).refreshProvider(p.id);
                                  ref.invalidate(vodCatalogProvider);
                                }, '« ${p.name} » mise à jour'),
                              ),
                              SizedBox(width: context.space(2)),
                              TiviIconButton(
                                icon: Icons.delete_outline_rounded,
                                size: TiviButtonSize.sm,
                                on: _confirmDelete == p.id,
                                tooltip: 'Supprimer',
                                onPressed: () => _deleteProvider(p),
                              ),
                            ],
                          ),
                        if (providers.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('Aucune playlist.', style: TiviText.small(context))),
                        SizedBox(height: context.space(2)),
                        OptionTile(icon: Icons.add_rounded, label: 'Ajouter une playlist', onSelect: () => context.push('/providers')),
                      ],
                    ),
                    SettingsSection(
                      title: 'Guide TV',
                      icon: Icons.calendar_view_day_outlined,
                      description: 'Programmes (XMLTV). Les guides iptv-epg.org suivent la langue choisie.',
                      children: [
                        for (final s in epgSources)
                          TiviSwitchRow(
                            label: s.name,
                            subtitle: _busy.contains('epg-${s.id}') ? 'mise à jour…' : _ago(s.lastRefresh),
                            value: s.enabled,
                            onChanged: (v) => _setEpgEnabled(s, v),
                            trailing: [
                              TiviIconButton(
                                icon: Icons.sync_rounded,
                                size: TiviButtonSize.sm,
                                tooltip: 'Mettre à jour',
                                onPressed: () => _run('epg-${s.id}', () async {
                                  await ref.read(epgRefreshServiceProvider).refreshSource(s.id);
                                  ref.invalidate(epgIndexProvider);
                                  ref.invalidate(programmesProvider);
                                }, 'Guide mis à jour'),
                              ),
                            ],
                          ),
                        if (epgSources.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('Aucun guide.', style: TiviText.small(context))),
                        SizedBox(height: context.space(2)),
                        OptionTile(icon: Icons.link_rounded, label: 'Associer les chaînes au guide', onSelect: () => context.push('/epg-mapping')),
                        OptionTile(icon: Icons.grid_view_rounded, label: 'Voir le guide complet', onSelect: () => context.push('/epg')),
                      ],
                    ),
                    const SettingsSection(
                      title: 'Films & séries',
                      icon: Icons.movie_filter_outlined,
                      description: 'Clés pour les fiches, affiches et recommandations (Trakt, TMDB).',
                      children: [_ApiKeys()],
                    ),
                    SettingsSection(
                      title: 'Plus',
                      icon: Icons.tune_rounded,
                      children: [
                        OptionTile(icon: Icons.cloud_download_outlined, label: 'Services debrid', onSelect: () => context.push('/debrid-services')),
                        OptionTile(icon: Icons.settings_suggest_outlined, label: 'Réglages avancés', onSelect: () => context.push('/settings/advanced')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartes Trakt / TMDB (remplace la section « Shows & Movies » d'origine).
class _ApiKeys extends ConsumerStatefulWidget {
  const _ApiKeys();

  @override
  ConsumerState<_ApiKeys> createState() => _ApiKeysState();
}

class _ApiKeysState extends ConsumerState<_ApiKeys> {
  final _trakt = TextEditingController();
  final _tmdb = TextEditingController();
  bool _loaded = false;
  bool? _traktOk;
  bool? _tmdbOk;
  bool _checking = false;

  @override
  void dispose() {
    _trakt.dispose();
    _tmdb.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final keys = ref.read(showsApiKeysProvider);
    await ref.read(showsApiKeysProvider.notifier).save(
          traktClientId: _trakt.text.trim(),
          tmdbApiKey: _tmdb.text.trim(),
          debridTokens: keys.debridTokens,
        );
    if (mounted) showTiviToast(context, 'Clés enregistrées', icon: Icons.check_rounded);
  }

  Future<void> _verify() async {
    setState(() {
      _checking = true;
      _traktOk = null;
      _tmdbOk = null;
    });
    Future<bool?> check(String key, Future<List> Function() call) async {
      if (key.isEmpty) return null;
      try {
        return (await call()).isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    final trakt = await check(_trakt.text.trim(), () => TraktClient(clientId: _trakt.text.trim()).getTrendingShows(limit: 1));
    final tmdb = await check(_tmdb.text.trim(), () => TmdbClient(apiKey: _tmdb.text.trim()).getTrendingTv());
    if (!mounted) return;
    setState(() {
      _checking = false;
      _traktOk = trakt;
      _tmdbOk = tmdb;
    });
  }

  Widget _status(BuildContext context, bool configured, bool? verified) {
    final (text, color, icon) = switch (verified) {
      true => ('Clé valide', TiviColors.positive, Icons.check_circle_rounded),
      false => ('Clé refusée', TiviColors.live, Icons.error_rounded),
      null => configured ? ('Configurée', TiviColors.positive, Icons.check_rounded) : ('Non configurée', TiviColors.text3, Icons.remove_circle_outline_rounded),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(text, style: TiviText.small(context).copyWith(color: color)),
    ]);
  }

  Widget _keyBlock(BuildContext context,
      {required String name, required IconData icon, required String help, required String fieldLabel, required String url, required TextEditingController ctrl, required bool configured, required bool? verified}) {
    return TiviCollapse(
      title: name,
      icon: icon,
      status: _status(context, configured, verified),
      initiallyOpen: !configured,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(help, style: TiviText.small(context)),
          SizedBox(height: context.space(3)),
          TiviTextField(controller: ctrl, label: fieldLabel, icon: Icons.key_rounded, onSubmitted: (_) => _save()),
          SizedBox(height: context.space(3)),
          Wrap(spacing: context.space(3), runSpacing: context.space(2), children: [
            TiviPillButton(label: 'Enregistrer', icon: Icons.save_outlined, primary: true, onPressed: _save),
            TiviPillButton(label: _checking ? 'Vérification…' : 'Vérifier', icon: Icons.verified_outlined, onPressed: _checking ? null : _verify),
            TiviPillButton(label: 'Obtenir une clé', icon: Icons.open_in_new_rounded, onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
            if (configured)
              TiviPillButton(
                label: 'Supprimer',
                icon: Icons.delete_outline_rounded,
                onPressed: () {
                  ctrl.clear();
                  _save();
                },
              ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(showsApiKeysProvider);
    if (!_loaded && (keys.traktClientId.isNotEmpty || keys.tmdbApiKey.isNotEmpty)) {
      _trakt.text = keys.traktClientId;
      _tmdb.text = keys.tmdbApiKey;
      _loaded = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _keyBlock(context,
            name: 'Trakt',
            icon: Icons.tv_rounded,
            help: 'Tendances, listes et suivi des séries. Créez une application sur trakt.tv puis copiez son Client ID.',
            fieldLabel: 'Client ID',
            url: 'https://trakt.tv/oauth/applications',
            ctrl: _trakt,
            configured: keys.hasTraktKey,
            verified: _traktOk),
        _keyBlock(context,
            name: 'TMDB',
            icon: Icons.image_outlined,
            help: 'Affiches, résumés et casting. Clé API (v3) ou jeton de lecture (v4).',
            fieldLabel: 'Clé API ou jeton',
            url: 'https://www.themoviedb.org/settings/api',
            ctrl: _tmdb,
            configured: keys.hasTmdbKey,
            verified: _tmdbOk),
      ],
    );
  }
}
