import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/providers/provider_manager.dart';
import '../datasources/local/database.dart' as db;
import 'language_catalog.dart';

/// Résout l'identifiant EPG d'une chaîne (même logique que l'écran d'origine,
/// simplifiée) : mapping enregistré → tvg-id → nom normalisé.
class EpgIndex {
  EpgIndex._(this._mapped, this._rawToPrefixed, this._byName);

  final Map<String, String> _mapped;
  final Map<String, String> _rawToPrefixed;
  final Map<String, String> _byName;

  static String normalize(String name) => stripLanguagePrefix(name)
      .toLowerCase()
      .replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '')
      .replaceAll(RegExp(r'\b(hd|fhd|shd|sd|4k|uhd|hevc|h265)\b'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  String? idFor(db.Channel c) {
    final mapped = _mapped[c.id];
    if (mapped != null) return mapped;
    final tvg = c.tvgId;
    if (tvg != null && tvg.isNotEmpty) {
      final lower = tvg.toLowerCase();
      // iptv-org suffixe ses tvg-id par le flux (« 6ter.fr@SD »), pas les guides
      final byTvg = _rawToPrefixed[lower] ?? _rawToPrefixed[lower.split('@').first];
      if (byTvg != null) return byTvg;
    }
    final n = normalize(c.name);
    return n.isEmpty ? null : _byName[n];
  }

  static Future<EpgIndex> build(db.AppDatabase database) async {
    final epgChannels = await database.select(database.epgChannels).get();
    final validIds = <String>{};
    final rawToPrefixed = <String, String>{};
    final byName = <String, String>{};
    final sourceIds = <String>{};
    for (final ch in epgChannels) {
      validIds.add(ch.id);
      sourceIds.add(ch.sourceId);
      rawToPrefixed.putIfAbsent(ch.channelId.toLowerCase(), () => ch.id);
      final n = normalize(ch.displayName);
      if (n.isNotEmpty) byName.putIfAbsent(n, () => ch.id);
    }
    final mapped = <String, String>{};
    for (final m in await database.getAllMappings()) {
      final direct = '${m.epgSourceId}_${m.epgChannelId}';
      if (validIds.contains(direct)) {
        mapped[m.channelId] = direct;
        continue;
      }
      for (final src in sourceIds) {
        final candidate = '${src}_${m.epgChannelId}';
        if (validIds.contains(candidate)) {
          mapped[m.channelId] = candidate;
          break;
        }
      }
    }
    return EpgIndex._(mapped, rawToPrefixed, byName);
  }
}

final epgIndexProvider = FutureProvider<EpgIndex>((ref) => EpgIndex.build(ref.watch(databaseProvider)));

/// Programme en cours + suivants d'une chaîne EPG (vide si pas d'EPG).
final programmesProvider = FutureProvider.autoDispose.family<List<db.EpgProgramme>, String>((ref, epgId) async {
  final database = ref.watch(databaseProvider);
  final now = DateTime.now();
  final list = await database.getProgrammes(
    epgChannelId: epgId,
    start: now.subtract(const Duration(hours: 8)),
    end: now.add(const Duration(hours: 14)),
  );
  return list.where((p) => p.stop.isAfter(now)).take(5).toList();
});

/// Programmes d'une chaîne, résolus via l'index EPG.
final channelProgrammesProvider = Provider.autoDispose.family<List<db.EpgProgramme>, db.Channel>((ref, channel) {
  final index = ref.watch(epgIndexProvider).valueOrNull;
  final id = index?.idFor(channel);
  if (id == null) return const [];
  return ref.watch(programmesProvider(id)).valueOrNull ?? const [];
});

extension ProgrammeX on db.EpgProgramme {
  double get progress {
    final total = stop.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (DateTime.now().difference(start).inSeconds / total).clamp(0.0, 1.0);
  }

  bool get isNow {
    final now = DateTime.now();
    return !start.isAfter(now) && stop.isAfter(now);
  }
}

/// Grille d'une chaîne pour le guide : de -2 h à +30 h.
final scheduleProvider = FutureProvider.autoDispose.family<List<db.EpgProgramme>, String>((ref, epgId) async {
  final database = ref.watch(databaseProvider);
  final now = DateTime.now();
  final list = await database.getProgrammes(
    epgChannelId: epgId,
    start: now.subtract(const Duration(hours: 8)),
    end: now.add(const Duration(hours: 30)),
  );
  return list.where((p) => p.stop.isAfter(now.subtract(const Duration(hours: 2)))).toList();
});
