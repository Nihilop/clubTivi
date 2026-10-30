import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/providers/provider_manager.dart';
import '../datasources/local/database.dart' as db;
import 'epg_language_sync.dart';
import 'language_catalog.dart';

/// Chaînes en direct visibles, triées (rafraîchies quand la base change).
final liveChannelsProvider = StreamProvider<List<db.Channel>>((ref) {
  final database = ref.watch(databaseProvider);
  // Seulement les chaînes des sources activées
  final enabled = database.selectOnly(database.providers)
    ..addColumns([database.providers.id])
    ..where(database.providers.enabled.equals(true));
  final q = database.select(database.channels)
    ..where((c) => c.streamType.equals('live') & c.hidden.equals(false) & c.providerId.isInQuery(enabled))
    ..orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.channelNumber),
      (c) => OrderingTerm.asc(c.name),
    ]);
  return q.watch();
});

/// Langue détectée pour chaque chaîne + effectifs par langue.
class LanguageSummary {
  LanguageSummary(this.byChannel, this.counts, this.providersWithLanguage);
  final Map<String, String?> byChannel;

  /// Sources dont au moins une chaîne a une langue reconnue. Les chaînes des
  /// autres sources (aucune info de langue) restent visibles quelle que soit la langue.
  final Set<String> providersWithLanguage;

  /// Trié par nombre de chaînes décroissant.
  final List<MapEntry<String, int>> counts;

  bool get isEmpty => counts.isEmpty;
}

final languageSummaryProvider = Provider<AsyncValue<LanguageSummary>>((ref) {
  return ref.watch(liveChannelsProvider).whenData((channels) {
    final byChannel = <String, String?>{};
    final counts = <String, int>{};
    final providers = <String>{};
    for (final c in channels) {
      final code = c.providerId == kIptvOrgProviderId ? iptvOrgLanguage(c.groupTitle) : detectLanguage(c.groupTitle, c.name);
      byChannel[c.id] = code;
      if (code != null) {
        counts[code] = (counts[code] ?? 0) + 1;
        providers.add(c.providerId);
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return LanguageSummary(byChannel, sorted, providers);
  });
});

/// Langue choisie une seule fois (null = pas encore choisie, `all` = toutes).
class LanguagePref {
  const LanguagePref({required this.loaded, this.code});
  final bool loaded;
  final String? code;
}

class LanguagePrefNotifier extends StateNotifier<LanguagePref> {
  LanguagePrefNotifier(this._ref) : super(const LanguagePref(loaded: false)) {
    _load();
  }

  final Ref _ref;

  static const _key = 'tivi.live.language';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = LanguagePref(loaded: true, code: prefs.getString(_key));
  }

  Future<void> choose(String code) async {
    state = LanguagePref(loaded: true, code: code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    // Le guide TV suit la langue choisie
    _ref.read(epgLanguageSyncProvider).sync(code).catchError((e) => debugPrint('[EPG] sync: $e'));
  }

  Future<void> reset() async {
    state = const LanguagePref(loaded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final languagePrefProvider = StateNotifierProvider<LanguagePrefNotifier, LanguagePref>((ref) => LanguagePrefNotifier(ref));

/// Chaînes de la langue choisie (toutes si aucune langue reconnue ou `all`).
final filteredLiveChannelsProvider = Provider<AsyncValue<List<db.Channel>>>((ref) {
  final pref = ref.watch(languagePrefProvider);
  final summary = ref.watch(languageSummaryProvider);
  return ref.watch(liveChannelsProvider).whenData((channels) {
    final code = pref.code;
    final s = summary.valueOrNull;
    if (code == null || code == 'all' || s == null) return channels;
    final filtered = channels.where((c) => s.byChannel[c.id] == code || !s.providersWithLanguage.contains(c.providerId)).toList();
    return filtered.isEmpty ? channels : filtered;
  });
});

/// Favoris : compatibles avec les listes de favoris de l'app d'origine.
class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier(this._db) : super(const {}) {
    _load();
  }

  final db.AppDatabase _db;

  Future<void> _load() async {
    final inLists = await _db.getAllFavoritedChannelIds();
    final flagged = (await _db.getFavoriteChannels()).map((c) => c.id);
    state = {...inLists, ...flagged};
  }

  bool isFavorite(String id) => state.contains(id);

  Future<bool> toggle(String channelId) async {
    if (state.contains(channelId)) {
      state = {...state}..remove(channelId);
      for (final list in await _db.getListsForChannel(channelId)) {
        await _db.removeChannelFromList(list.id, channelId);
      }
      final flagged = await _db.getChannelsByIds({channelId});
      if (flagged.isNotEmpty && flagged.first.favorite) await _db.toggleFavorite(channelId);
      return false;
    }
    state = {...state, channelId};
    final lists = await _db.getAllFavoriteLists();
    final list = lists.isNotEmpty ? lists.first : await _db.createFavoriteList('Favoris');
    await _db.addChannelToList(list.id, channelId);
    return true;
  }
}

final channelFavoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) => FavoritesNotifier(ref.watch(databaseProvider)));
