import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Positions de reprise des films / épisodes (par URL de flux).
class ResumeStore {
  ResumeStore._();
  static final instance = ResumeStore._();

  static const _key = 'tivi.resume';
  Map<String, dynamic> _data = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _data = raw == null ? {} : (jsonDecode(raw) as Map<String, dynamic>);
    _loaded = true;
  }

  /// Fraction vue (0–1) ou null.
  double? progress(String url) {
    final e = _data[url];
    if (e is! Map) return null;
    final dur = (e['d'] as num?)?.toDouble() ?? 0;
    if (dur <= 0) return null;
    return ((e['p'] as num).toDouble() / dur).clamp(0.0, 1.0);
  }

  Duration? position(String url) {
    final e = _data[url];
    if (e is! Map) return null;
    return Duration(seconds: (e['p'] as num).toInt());
  }

  Future<void> save(String url, Duration position, Duration duration) async {
    if (duration.inSeconds <= 0) return;
    // Terminé (>95 %) : on oublie la position
    if (position.inSeconds > duration.inSeconds * .95) {
      _data.remove(url);
    } else if (position.inSeconds > 15) {
      _data[url] = {'p': position.inSeconds, 'd': duration.inSeconds, 't': DateTime.now().millisecondsSinceEpoch};
    }
    // On ne garde que les 200 plus récents
    if (_data.length > 200) {
      final entries = _data.entries.toList()..sort((a, b) => ((b.value as Map)['t'] as int).compareTo((a.value as Map)['t'] as int));
      _data = Map.fromEntries(entries.take(200));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_data));
  }
}
