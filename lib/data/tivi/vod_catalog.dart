import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/providers/provider_manager.dart';
import 'language_catalog.dart';

/// Film issu de la playlist (stream_type `vod`).
class VodMovie {
  const VodMovie({required this.id, required this.title, required this.streamUrl, this.year, this.poster, this.group, this.language});
  final String id;
  final String title;
  final String streamUrl;
  final int? year;
  final String? poster;
  final String? group;
  final String? language;
}

class VodEpisode {
  const VodEpisode({required this.id, required this.season, required this.episode, required this.title, required this.streamUrl, this.poster});
  final String id;
  final int season;
  final int episode;
  final String title;
  final String streamUrl;
  final String? poster;

  String get code => 'S$season · É$episode';
}

/// Série regroupée à partir des épisodes de la playlist (stream_type `series`).
class VodSeries {
  VodSeries({required this.key, required this.title, this.poster, this.group, this.language});
  final String key;
  final String title;
  final String? poster;
  final String? group;
  final String? language;
  final Map<int, List<VodEpisode>> seasons = {};

  List<int> get seasonNumbers => seasons.keys.toList()..sort();
  int get episodeCount => seasons.values.fold(0, (n, l) => n + l.length);

  /// Épisodes à plat, dans l'ordre (pour précédent / suivant).
  List<VodEpisode> get allEpisodes => [for (final s in seasonNumbers) ...seasons[s]!];
}

class VodCatalog {
  const VodCatalog(this.movies, this.series);
  final List<VodMovie> movies;
  final List<VodSeries> series;

  bool get isEmpty => movies.isEmpty && series.isEmpty;

  /// Rangées par groupe de playlist, les plus fournis d'abord.
  static List<MapEntry<String, List<T>>> rows<T>(List<T> items, String? Function(T) groupOf, {int max = 12}) {
    final groups = <String, List<T>>{};
    for (final it in items) {
      final g = stripLanguagePrefix(groupOf(it) ?? '').trim();
      (groups[g.isEmpty ? 'Autres' : g] ??= []).add(it);
    }
    final sorted = groups.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return sorted.take(max).toList();
  }
}

final _year = RegExp(r'[\(\[\s\-]((?:19|20)\d{2})[\)\]]?\s*$');
final _episode = RegExp(r'^(.*?)[\s._\-]*S(\d{1,2})[\s._\-]*E(\d{1,3})(.*)$', caseSensitive: false);
final _quality = RegExp(r'\b(4K|UHD|FHD|HD|SD|HEVC|H265|MULTI|VOSTFR|VF|VO)\b', caseSensitive: false);

String _clean(String s) => stripLanguagePrefix(s).replaceAll(_quality, '').replaceAll(RegExp(r'\s{2,}'), ' ').replaceAll(RegExp(r'[\s\-|:]+$'), '').trim();

typedef _Row = ({String id, String name, String? group, String? logo, String url, String type});

VodCatalog _build(List<_Row> rows) {
  final movies = <VodMovie>[];
  final series = <String, VodSeries>{};
  for (final r in rows) {
    if (r.type == 'vod') {
      var title = _clean(r.name);
      int? year;
      final y = _year.firstMatch(title);
      if (y != null) {
        year = int.parse(y.group(1)!);
        title = title.substring(0, y.start).trim();
      }
      movies.add(VodMovie(id: r.id, title: title.isEmpty ? r.name : title, streamUrl: r.url, year: year, poster: r.logo, group: r.group, language: detectLanguage(r.group, r.name)));
    } else {
      final m = _episode.firstMatch(_clean(r.name));
      final showTitle = m != null ? m.group(1)!.trim() : _clean(r.name);
      final key = showTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
      final s = series.putIfAbsent(key, () => VodSeries(key: key, title: showTitle, poster: r.logo, group: r.group, language: detectLanguage(r.group, r.name)));
      final season = m != null ? int.parse(m.group(2)!) : 1;
      final ep = m != null ? int.parse(m.group(3)!) : (s.seasons[1]?.length ?? 0) + 1;
      final rest = m != null ? m.group(4)!.replaceAll(RegExp(r'^[\s\-:.]+'), '').trim() : '';
      (s.seasons[season] ??= []).add(VodEpisode(id: r.id, season: season, episode: ep, title: rest.isEmpty ? 'Épisode $ep' : rest, streamUrl: r.url, poster: r.logo));
    }
  }
  for (final s in series.values) {
    for (final eps in s.seasons.values) {
      eps.sort((a, b) => a.episode.compareTo(b.episode));
    }
  }
  movies.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
  return VodCatalog(movies, series.values.toList()..sort((a, b) => a.title.compareTo(b.title)));
}

/// Catalogue films / séries construit hors du thread UI (playlists volumineuses).
final vodCatalogProvider = FutureProvider<VodCatalog>((ref) async {
  final database = ref.watch(databaseProvider);
  // Seulement les sources existantes et activées
  final enabled = database.selectOnly(database.providers)
    ..addColumns([database.providers.id])
    ..where(database.providers.enabled.equals(true));
  final q = database.select(database.channels)
    ..where((c) => c.streamType.isIn(const ['vod', 'series']) & c.hidden.equals(false) & c.providerId.isInQuery(enabled));
  final channels = await q.get();
  final rows = [
    for (final c in channels) (id: c.id, name: c.name, group: c.groupTitle, logo: c.tvgLogo, url: c.streamUrl, type: c.streamType),
  ];
  return Isolate.run(() => _build(rows));
});
