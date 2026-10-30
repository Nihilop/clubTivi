import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/providers/provider_manager.dart';
import '../datasources/local/database.dart' as db;

/// Rappels de programmes (table `epg_reminders` d'origine, jusqu'ici inutilisée).
/// L'état contient les clés des programmes rappelés : `epgChannelId|début`.
class RemindersNotifier extends StateNotifier<Set<String>> {
  RemindersNotifier(this._db) : super(const {}) {
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  final db.AppDatabase _db;
  Timer? _timer;
  final _due = StreamController<db.EpgReminder>.broadcast();

  /// Rappels arrivés à échéance (affichés par l'app).
  Stream<db.EpgReminder> get due => _due.stream;

  static String keyOf(String epgChannelId, DateTime start) => '$epgChannelId|${start.millisecondsSinceEpoch}';

  Future<void> _load() async {
    final active = await _db.getActiveReminders();
    state = {for (final r in active) r.id};
  }

  bool has(db.EpgProgramme p) => state.contains(keyOf(p.epgChannelId, p.start));

  /// Ajoute ou retire le rappel ; renvoie vrai si ajouté.
  Future<bool> toggle(db.EpgProgramme p, {String? channelId}) async {
    final key = keyOf(p.epgChannelId, p.start);
    if (state.contains(key)) {
      state = {...state}..remove(key);
      await _db.deleteReminder(key);
      return false;
    }
    state = {...state, key};
    await _db.addReminder(db.EpgRemindersCompanion.insert(
      id: key,
      epgChannelId: p.epgChannelId,
      channelId: Value(channelId),
      programmeTitle: p.title,
      programmeStart: p.start,
      programmeStop: p.stop,
    ));
    return true;
  }

  Future<void> _check() async {
    final now = DateTime.now();
    for (final r in await _db.getActiveReminders()) {
      final at = r.programmeStart.subtract(Duration(minutes: r.minutesBefore));
      if (now.isBefore(at)) continue;
      await _db.markReminderFired(r.id);
      state = {...state}..remove(r.id);
      // Ne pas rappeler un programme déjà terminé (app fermée entre-temps)
      if (r.programmeStop.isAfter(now)) _due.add(r);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _due.close();
    super.dispose();
  }
}

final remindersProvider = StateNotifierProvider<RemindersNotifier, Set<String>>((ref) => RemindersNotifier(ref.watch(databaseProvider)));
