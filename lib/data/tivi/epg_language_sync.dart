import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/providers/provider_manager.dart';
import '../datasources/local/database.dart' as db;
import '../services/epg_refresh_service.dart';
import 'epg_index.dart';

/// Guides par pays d'iptv-epg.org : mêmes identifiants que les playlists
/// iptv-org (`6ter.fr` ↔ tvg-id `6ter.fr@SD`).
const _guideUrl = 'https://iptv-epg.org/files/epg-{cc}.xml.gz';
const _sourcePrefix = 'iptv-epg-';

/// Pays dont on charge le guide pour chaque langue (les plus gros d'abord).
const kEpgCountriesByLanguage = <String, List<String>>{
  'fr': ['fr', 'be', 'ch', 'ca'],
  'en': ['gb', 'us', 'ca', 'au'],
  'us': ['us'],
  'ca': ['ca'],
  'de': ['de', 'at', 'ch'],
  'es': ['es', 'mx', 'ar', 'co'],
  'mx': ['mx'],
  'it': ['it', 'ch'],
  'pt': ['pt', 'br'],
  'br': ['br'],
  'nl': ['nl', 'be'],
  'be': ['be'],
  'ch': ['ch'],
  'ar': ['sa', 'ae', 'eg'],
  'tr': ['tr'],
  'pl': ['pl'],
  'ro': ['ro'],
  'gr': ['gr', 'cy'],
  'ru': ['ru'],
  'ua': ['ua'],
  'hi': ['in'],
  'in': ['in'],
  'al': ['al'],
  'se': ['se'],
  'no': ['no'],
  'dk': ['dk'],
  'fi': ['fi'],
  'cz': ['cz'],
  'hu': ['hu'],
  'bg': ['bg'],
  'zh': ['cn', 'hk', 'tw'],
  'id': ['id'],
  'ko': ['kr'],
  'ja': ['jp'],
  'vi': ['vn'],
  'th': ['th'],
  'hr': ['hr'],
  'sr': ['rs'],
  'sk': ['sk'],
  'sl': ['si'],
  'he': ['il'],
  'ms': ['my'],
  'tl': ['ph'],
};

/// Active le guide TV correspondant à la langue choisie et désactive les autres.
class EpgLanguageSync {
  EpgLanguageSync(this._ref);
  final Ref _ref;

  Future<void> sync(String? language) async {
    final database = _ref.read(databaseProvider);
    final epg = _ref.read(epgRefreshServiceProvider);
    final countries = kEpgCountriesByLanguage[language] ?? const <String>[];
    final wanted = {for (final cc in countries) '$_sourcePrefix$cc': cc};

    final existing = await database.getAllEpgSources();
    for (final s in existing.where((s) => s.id.startsWith(_sourcePrefix))) {
      if (!wanted.containsKey(s.id) && s.enabled) {
        await database.upsertEpgSource(db.EpgSourcesCompanion(
          id: Value(s.id),
          name: Value(s.name),
          url: Value(s.url),
          enabled: const Value(false),
        ));
      }
    }

    final now = DateTime.now();
    var refreshed = false;
    for (final entry in wanted.entries) {
      final current = existing.where((s) => s.id == entry.key).firstOrNull;
      await database.upsertEpgSource(db.EpgSourcesCompanion.insert(
        id: entry.key,
        name: 'Guide TV ${entry.value.toUpperCase()} (iptv-epg.org)',
        url: _guideUrl.replaceAll('{cc}', entry.value),
        enabled: const Value(true),
        lastRefresh: Value(current?.lastRefresh),
      ));
      final last = current?.lastRefresh;
      if (last != null && now.difference(last).inHours < 12) continue;
      try {
        await epg.refreshSource(entry.key);
        refreshed = true;
        // Rend chaque pays disponible dès qu'il est chargé
        _ref.invalidate(epgIndexProvider);
      } catch (e) {
        debugPrint('[EPG] ${entry.key} : $e');
      }
    }
    if (refreshed) _ref.invalidate(programmesProvider);
  }
}

final epgLanguageSyncProvider = Provider<EpgLanguageSync>((ref) => EpgLanguageSync(ref));
