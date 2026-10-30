import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_info.dart';
import '../data/tivi/reminders.dart';
import '../ui/ui.dart';
import 'router.dart';

class ClubTiviApp extends StatelessWidget {
  const ClubTiviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tivi',
      debugShowCheckedModeBanner: false,
      theme: TiviTheme.dark,
      routerConfig: router,
      // D-pad : OK = activer, Échap = Retour (Windows) — voir ui/focus/tv_keys.dart
      shortcuts: tvShortcuts(),
      actions: {...WidgetsApp.defaultActions, ...tvActions(rootNavigatorKey)},
      builder: (context, child) {
        // Détection TV conservée pour les écrans d'origine
        PlatformInfo.detectFromContext(context);
        return TiviScale.wrap(context, _ReminderListener(child: child ?? const SizedBox.shrink()));
      },
    );
  }
}

/// Affiche les rappels de programmes arrivés à échéance, sur n'importe quel écran.
class _ReminderListener extends ConsumerStatefulWidget {
  const _ReminderListener({required this.child});
  final Widget child;

  @override
  ConsumerState<_ReminderListener> createState() => _ReminderListenerState();
}

class _ReminderListenerState extends ConsumerState<_ReminderListener> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(remindersProvider.notifier).due.listen((r) {
      if (!mounted) return;
      final overlay = rootNavigatorKey.currentState?.overlay;
      if (overlay == null) return;
      final minutes = r.programmeStart.difference(DateTime.now()).inMinutes;
      final when = minutes > 0 ? 'dans $minutes min' : 'maintenant';
      showTiviToast(overlay.context, '« ${r.programmeTitle} » commence $when', icon: Icons.notifications_active_outlined, overlayState: overlay);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
