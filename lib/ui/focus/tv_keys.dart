import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Touches télécommande / clavier.
///
/// Android TV : le D-pad envoie les flèches et `select` (bouton central).
/// Le bouton Retour passe par la navigation système (PopScope), on ne le
/// mappe donc pas ici pour éviter un double retour.
/// Windows (dev) : flèches, Entrée, Échap = Retour, Espace = lecture/pause.
abstract final class TvKeys {
  static bool isSelect(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  static bool isUp(LogicalKeyboardKey k) => k == LogicalKeyboardKey.arrowUp;
  static bool isDown(LogicalKeyboardKey k) => k == LogicalKeyboardKey.arrowDown;
  static bool isLeft(LogicalKeyboardKey k) => k == LogicalKeyboardKey.arrowLeft;
  static bool isRight(LogicalKeyboardKey k) => k == LogicalKeyboardKey.arrowRight;

  static bool isPlayPause(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.mediaPlayPause || k == LogicalKeyboardKey.space;
  static bool isPlay(LogicalKeyboardKey k) => k == LogicalKeyboardKey.mediaPlay;
  static bool isPause(LogicalKeyboardKey k) => k == LogicalKeyboardKey.mediaPause;
  static bool isChannelUp(LogicalKeyboardKey k) => k == LogicalKeyboardKey.channelUp || k == LogicalKeyboardKey.pageUp;
  static bool isChannelDown(LogicalKeyboardKey k) => k == LogicalKeyboardKey.channelDown || k == LogicalKeyboardKey.pageDown;
  static bool isFastForward(LogicalKeyboardKey k) => k == LogicalKeyboardKey.mediaFastForward;
  static bool isRewind(LogicalKeyboardKey k) => k == LogicalKeyboardKey.mediaRewind;
  static bool isNext(LogicalKeyboardKey k) => k == LogicalKeyboardKey.mediaTrackNext;
  static bool isPrevious(LogicalKeyboardKey k) => k == LogicalKeyboardKey.mediaTrackPrevious;

  /// Appui ou répétition (touche maintenue).
  static bool isPress(KeyEvent e) => e is KeyDownEvent || e is KeyRepeatEvent;
}

/// Retour demandé au clavier (Échap sur Windows).
class BackIntent extends Intent {
  const BackIntent();
}

/// Raccourcis globaux, à passer à `MaterialApp.router(shortcuts: …)`.
Map<ShortcutActivator, Intent> tvShortcuts() => {
      ...WidgetsApp.defaultShortcuts,
      const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
      const SingleActivator(LogicalKeyboardKey.browserBack): const BackIntent(),
    };

/// Échap → même effet que le bouton Retour Android (respecte les PopScope).
Map<Type, Action<Intent>> tvActions(GlobalKey<NavigatorState> navigatorKey) => {
      BackIntent: CallbackAction<BackIntent>(onInvoke: (_) {
        navigatorKey.currentState?.maybePop();
        return null;
      }),
    };
