import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/datasources/local/database.dart' as db;
import '../../data/tivi/epg_index.dart';
import '../../data/tivi/language_catalog.dart';
import '../../data/tivi/live_repository.dart';
import '../../data/tivi/play_request.dart';
import '../../data/tivi/reminders.dart';
import '../../data/tivi/resume_store.dart';
import '../../data/tivi/vod_catalog.dart';
import '../../ui/ui.dart';
import 'player_service.dart';

enum _Ui { idle, controls, details, panel }

enum _PanelKind { tracks, settings }

/// Lecteur unique : direct, film, épisode.
///
/// Télécommande :
/// - contrôles masqués : ↓ détails (direct, série), ←/→ ±10 s (VOD), autre touche → contrôles
/// - contrôles : flèches entre boutons, ↑ barre de lecture (VOD), ↓ détails, Retour masque
/// - détails : ↑ en haut referme ; film : pas de panneau
/// - CH+/CH− zappe, ⏯ / Espace pause, ⏩ ⏪ ±30 s
class TiviPlayerScreen extends ConsumerStatefulWidget {
  const TiviPlayerScreen({super.key, required this.request});
  final PlayRequest request;

  @override
  ConsumerState<TiviPlayerScreen> createState() => _TiviPlayerScreenState();
}

class _TiviPlayerScreenState extends ConsumerState<TiviPlayerScreen> {
  late final PlayerService _ps = ref.read(playerServiceProvider);
  late int _chIndex = widget.request.index;
  late int _epIndex = widget.request.episodeIndex;

  _Ui _ui = _Ui.controls;
  _PanelKind? _panel;
  BoxFit _fit = BoxFit.contain;
  double _rate = 1;

  final _position = ValueNotifier(Duration.zero);
  Duration _duration = Duration.zero;

  /// Durée qui augmente en cours de lecture → flux en direct déguisé en VOD.
  int _durationGrowth = 0;
  bool get _streamIsLive => _isLive || _durationGrowth >= 3;
  bool _playing = true;
  bool _buffering = false;
  DateTime _startedAt = DateTime.now();
  (IconData, String)? _osd;

  /// Raison d'un échec de lecture (affichée à la place des contrôles).
  String? _error;
  String? _lastHttpError;
  bool _started = false;
  Timer? _startTimer;
  final _retryFocus = FocusNode(debugLabel: 'retry');
  late final _episodesCtrl = TvIndexedListController(initialIndex: widget.request.episodeIndex);

  final _rootFocus = FocusNode(debugLabel: 'player-root');
  final _playFocus = FocusNode(debugLabel: 'play');
  final _seekFocus = FocusNode(debugLabel: 'seek');
  final _tracksFocus = FocusNode(debugLabel: 'tracks');
  final _settingsFocus = FocusNode(debugLabel: 'settings');
  final _sheetFirstFocus = FocusNode(debugLabel: 'sheet-first');
  final _controlsScope = FocusScopeNode(debugLabel: 'controls');
  final _sheetScope = FocusScopeNode(debugLabel: 'sheet');
  FocusNode? _lastControl;
  FocusNode? _panelReturn;

  Timer? _hideTimer;
  Timer? _osdTimer;
  Timer? _clock;
  Timer? _resumeTimer;
  final _subs = <StreamSubscription>[];

  PlayKind get _kind => widget.request.kind;
  bool get _isLive => _kind == PlayKind.live;
  bool get _isMovie => _kind == PlayKind.movie;
  bool get _isEpisode => _kind == PlayKind.episode;
  bool get _hasDetails => !_isMovie;

  db.Channel? get _channel => _isLive ? widget.request.channels[_chIndex] : null;
  List<VodEpisode> get _episodes => widget.request.series?.allEpisodes ?? const [];
  VodEpisode? get _episode => _isEpisode && _episodes.isNotEmpty ? _episodes[_epIndex] : null;

  String get _url => _channel?.streamUrl ?? widget.request.movie?.streamUrl ?? _episode!.streamUrl;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _subs
      ..add(_ps.positionStream.listen((p) {
        _position.value = p;
        if (!_started && p > Duration.zero) _markStarted();
      }))
      ..add(_ps.player.stream.log.listen((l) {
        final m = RegExp(r'HTTP error (\d{3})', caseSensitive: false).firstMatch(l.text);
        if (m != null) _lastHttpError = m.group(1);
      }))
      ..add(_ps.durationStream.listen((d) {
        if (!mounted) return;
        setState(() {
          if (_duration > Duration.zero && d > _duration && _started) _durationGrowth++;
          _duration = d;
        });
      }))
      ..add(_ps.playingStream.listen((p) {
        if (mounted) setState(() => _playing = p);
      }))
      ..add(_ps.bufferingStream.listen((b) {
        if (mounted) setState(() => _buffering = b);
      }))
      ..add(_ps.player.stream.error.listen((e) {
        if (mounted && e.isNotEmpty && !_started) _fail(e);
      }));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isLive) setState(() {});
    });
    if (!_isLive) _resumeTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveResume());
    _open();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showControls());
  }

  @override
  void dispose() {
    _saveResume();
    for (final s in _subs) {
      s.cancel();
    }
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    _startTimer?.cancel();
    _retryFocus.dispose();
    _clock?.cancel();
    _resumeTimer?.cancel();
    _ps.stop();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    for (final n in [_rootFocus, _playFocus, _seekFocus, _tracksFocus, _settingsFocus, _sheetFirstFocus]) {
      n.dispose();
    }
    _controlsScope.dispose();
    _episodesCtrl.dispose();
    _sheetScope.dispose();
    _position.dispose();
    super.dispose();
  }

  /* ---------- Lecture ---------- */

  Future<void> _open() async {
    _startedAt = DateTime.now();
    _position.value = Duration.zero;
    _started = false;
    _durationGrowth = 0;
    _lastHttpError = null;
    if (_error != null) setState(() => _error = null);
    // Pas d'image au bout de 25 s : on considère le flux comme injoignable
    _startTimer?.cancel();
    _startTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && !_started) _fail('timeout');
    });
    final ch = _channel;
    if (ch != null) {
      final epgId = ref.read(epgIndexProvider).valueOrNull?.idFor(ch);
      await _ps.play(ch.streamUrl, channelId: ch.id, epgChannelId: epgId, tvgId: ch.tvgId, channelName: ch.name);
      return;
    }
    final url = _url;
    await _ps.play(url);
    if (_rate != 1) await _ps.player.setRate(_rate);
    final resume = ResumeStore.instance.position(url);
    if (resume != null) {
      try {
        await _ps.durationStream.firstWhere((d) => d > Duration.zero).timeout(const Duration(seconds: 15));
        await _ps.player.seek(resume);
        if (mounted) showTiviToast(context, 'Reprise à ${_fmt(resume)}', icon: Icons.history_rounded);
      } catch (_) {}
    }
  }

  void _markStarted() {
    _started = true;
    _startTimer?.cancel();
    if (_error != null && mounted) setState(() => _error = null);
  }

  /// Traduit l'erreur du lecteur en explication lisible.
  String _explain(String raw) {
    final m = raw.toLowerCase();
    final code = _lastHttpError ?? RegExp(r'\b(40[0-9]|41[0-9]|5\d\d)\b').firstMatch(m)?.group(1);
    return switch (code) {
      '403' => 'Accès refusé par le serveur (403). La chaîne est souvent réservée à son pays d\'origine.',
      '404' || '410' => 'Flux introuvable (404). La chaîne a probablement changé d\'adresse ou fermé.',
      '401' => 'Le serveur demande une authentification (401).',
      final c? when c.startsWith('5') => 'Le serveur de la chaîne est en panne ($c).',
      _ => m == 'timeout' || m.contains('timed out') || m.contains('timeout')
          ? 'Le flux ne répond pas (délai dépassé). Serveur hors ligne ou trop lent.'
          : m.contains('tls') || m.contains('ssl') || m.contains('certificate')
              ? 'Connexion sécurisée impossible (certificat du serveur invalide).'
              : m.contains('unrecognized') || m.contains('no streams') || m.contains('format')
                  ? 'Format de flux non pris en charge.'
                  : 'Impossible d\'ouvrir le flux : serveur hors ligne ou adresse invalide.',
    };
  }

  void _fail(String raw) {
    _startTimer?.cancel();
    final reason = _explain(raw);
    debugPrint('[Player] Échec : $raw → $reason');
    _hideTimer?.cancel();
    setState(() {
      _error = reason;
      _ui = _Ui.controls;
      _panel = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _retryFocus.requestFocus());
  }

  void _saveResume() {
    if (_streamIsLive || _duration == Duration.zero) return;
    ResumeStore.instance.save(_url, _position.value, _duration);
  }

  void _togglePlay([bool? play]) {
    final next = play ?? !_playing;
    next ? _ps.resume() : _ps.pause();
    setState(() => _playing = next);
    if (_ui == _Ui.idle) _flash(next ? Icons.play_arrow_rounded : Icons.pause_rounded, '');
    _restartHide();
  }

  void _seek(int seconds) {
    if (_streamIsLive || _duration == Duration.zero) return;
    var t = _position.value + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (t > _duration) t = _duration - const Duration(seconds: 1);
    _ps.player.seek(t);
    _position.value = t;
    _flash(seconds < 0 ? Icons.replay_10_rounded : Icons.forward_10_rounded, '${seconds < 0 ? '−' : '+'}${seconds.abs()} s · ${_fmt(t)}');
  }

  void _zap(int dir) {
    if (!_isLive) return;
    final n = widget.request.channels.length;
    setState(() => _chIndex = (_chIndex + dir + n) % n);
    _open();
    if (_ui == _Ui.idle) _showControls();
  }

  void _stepEpisode(int dir) {
    final next = _epIndex + dir;
    if (next < 0 || next >= _episodes.length) {
      showTiviToast(context, dir < 0 ? 'Premier épisode' : 'Dernier épisode');
      return;
    }
    _playEpisode(next);
  }

  void _playEpisode(int index) {
    _saveResume();
    setState(() => _epIndex = index);
    _episodesCtrl.select(index);
    _open();
    showTiviToast(context, '${_episode!.code} — ${_episode!.title}', icon: Icons.play_arrow_rounded);
  }

  void _prev() => _isLive ? _zap(-1) : (_isMovie ? _seek(-10) : _stepEpisode(-1));
  void _next() => _isLive ? _zap(1) : (_isMovie ? _seek(10) : _stepEpisode(1));

  /* ---------- États de l'interface ---------- */

  void _restartHide() {
    _hideTimer?.cancel();
    if (_playing && _ui == _Ui.controls) _hideTimer = Timer(const Duration(seconds: 5), _hideControls);
  }

  void _showControls({FocusNode? focus}) {
    setState(() {
      _ui = _Ui.controls;
      _panel = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = focus ?? _lastControl;
      (target != null && target.context != null ? target : _playFocus).requestFocus();
    });
    _restartHide();
  }

  void _hideControls() {
    if (_ui != _Ui.controls) return;
    final f = FocusManager.instance.primaryFocus;
    if (f != null && _controlsScope.traversalDescendants.contains(f)) _lastControl = f;
    setState(() => _ui = _Ui.idle);
    _rootFocus.requestFocus();
  }

  void _openDetails() {
    if (!_hasDetails) return;
    if (_ui == _Ui.controls) {
      final f = FocusManager.instance.primaryFocus;
      if (f != null && _controlsScope.traversalDescendants.contains(f)) _lastControl = f;
    }
    _hideTimer?.cancel();
    setState(() => _ui = _Ui.details);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sheetFirstFocus.requestFocus());
  }

  void _openPanel(_PanelKind kind) {
    _panelReturn = FocusManager.instance.primaryFocus;
    _hideTimer?.cancel();
    setState(() {
      _ui = _Ui.panel;
      _panel = kind;
    });
  }

  void _closePanel() => _showControls(focus: _panelReturn);

  void _flash(IconData icon, String text) {
    setState(() => _osd = (icon, text));
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _osd = null);
    });
  }

  /* ---------- Télécommande ---------- */

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!TvKeys.isPress(e)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final repeat = e is KeyRepeatEvent;

    // Écran d'erreur : navigation normale entre ses boutons, CH+/CH− zappent
    if (_error != null) {
      if (TvKeys.isChannelUp(k)) return _done(() => _zap(1));
      if (TvKeys.isChannelDown(k)) return _done(() => _zap(-1));
      return KeyEventResult.ignored;
    }

    if (TvKeys.isPlayPause(k) && e is KeyDownEvent) return _done(() => _togglePlay());
    if (TvKeys.isPlay(k)) return _done(() => _togglePlay(true));
    if (TvKeys.isPause(k)) return _done(() => _togglePlay(false));
    if (TvKeys.isChannelUp(k)) return _done(() => _zap(1));
    if (TvKeys.isChannelDown(k)) return _done(() => _zap(-1));
    if (TvKeys.isFastForward(k)) return _done(() => _seek(30));
    if (TvKeys.isRewind(k)) return _done(() => _seek(-30));
    if (TvKeys.isNext(k)) return _done(_next);
    if (TvKeys.isPrevious(k)) return _done(_prev);

    switch (_ui) {
      case _Ui.idle:
        if (TvKeys.isDown(k)) return _done(() => _hasDetails ? _openDetails() : _showControls());
        if (!_isLive && (TvKeys.isLeft(k) || TvKeys.isRight(k))) return _done(() => _seek((TvKeys.isLeft(k) ? -1 : 1) * (repeat ? 30 : 10)));
        if (TvKeys.isUp(k) || TvKeys.isSelect(k) || TvKeys.isLeft(k) || TvKeys.isRight(k)) return _done(_showControls);
        return KeyEventResult.ignored; // Échap / Retour → PopScope

      case _Ui.controls:
        _restartHide();
        final focus = FocusManager.instance.primaryFocus;
        if (focus == _seekFocus && (TvKeys.isLeft(k) || TvKeys.isRight(k))) {
          return _done(() => _seek((TvKeys.isLeft(k) ? -1 : 1) * (repeat ? 30 : 10)));
        }
        if (TvKeys.isDown(k)) {
          return _done(() {
            if (!(focus?.focusInDirection(TraversalDirection.down) ?? false) && _hasDetails) _openDetails();
          });
        }
        if (TvKeys.isUp(k)) {
          return _done(() {
            if (!(focus?.focusInDirection(TraversalDirection.up) ?? false)) _hideControls();
          });
        }
        return KeyEventResult.ignored;

      case _Ui.details:
        if (TvKeys.isUp(k)) {
          final focus = FocusManager.instance.primaryFocus;
          return _done(() {
            if (!(focus?.focusInDirection(TraversalDirection.up) ?? false)) _showControls();
          });
        }
        return KeyEventResult.ignored;

      case _Ui.panel:
        if (TvKeys.isLeft(k) && !context.compact) return _done(_closePanel);
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _done(VoidCallback f) {
    f();
    return KeyEventResult.handled;
  }

  void _onBack() {
    switch (_ui) {
      case _Ui.controls:
        _hideControls();
      case _Ui.details:
        _showControls();
      case _Ui.panel:
        _closePanel();
      case _Ui.idle:
        break;
    }
  }

  /* ---------- Rendu ---------- */

  static String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ch = _channel;
    final progs = ch == null ? const <db.EpgProgramme>[] : ref.watch(channelProgrammesProvider(ch));
    final now = progs.where((p) => p.isNow).firstOrNull;
    final favs = ref.watch(channelFavoritesProvider);
    final showChrome = _ui != _Ui.idle;

    final String title;
    final String subtitle;
    final Widget badge;
    if (ch != null) {
      title = now?.title ?? ch.name;
      subtitle = '${ch.channelNumber != null ? '${ch.channelNumber.toString().padLeft(3, '0')} · ' : ''}${ch.name}';
      badge = const TiviBadge.live();
    } else if (_isMovie) {
      final m = widget.request.movie!;
      title = m.title;
      subtitle = [if (m.year != null) '${m.year}', if (m.group != null) stripLanguagePrefix(m.group!)].join(' · ');
      badge = _streamIsLive ? const TiviBadge.live() : const TiviBadge.soft('Film');
    } else {
      title = _episode!.title;
      subtitle = widget.request.series!.title;
      badge = TiviBadge.soft(_episode!.code);
    }

    return PopScope(
      canPop: _ui == _Ui.idle || _error != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: MouseRegion(
            onHover: (_) {
              if (_ui == _Ui.idle) {
                _showControls();
              } else if (_ui == _Ui.controls) {
                _restartHide();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(controller: _ps.videoController, controls: NoVideoControls, fit: _fit, fill: Colors.black),
                // Zone tactile : tap = contrôles, glisser vers le haut = détails
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => switch (_ui) {
                    _Ui.idle => _showControls(),
                    _Ui.controls => _hideControls(),
                    _Ui.details => _showControls(),
                    _Ui.panel => _closePanel(),
                  },
                  onVerticalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v < -300 && _hasDetails) _openDetails();
                    if (v > 300 && _ui == _Ui.details) _showControls();
                  },
                ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: showChrome ? 1 : 0,
                    duration: TiviMotion.slow,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xB30C0A12), Color(0x000C0A12), Color(0x000C0A12), Color(0x8C0C0A12), Color(0xEB0C0A12)],
                          stops: [0, .28, .45, .72, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_buffering && _error == null) const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5)),
                _topBar(ch, showChrome),
                _osdView(),
                if (_error == null) _controls(title, subtitle, badge, now, favs) else _errorView(title, subtitle),
                if (_hasDetails) _sheet(ch, progs, now),
                TiviSidePanel(
                  open: _ui == _Ui.panel,
                  onClose: _closePanel,
                  title: _panel == _PanelKind.tracks ? 'Langues & sous-titres' : 'Réglages',
                  child: _panel == _PanelKind.tracks ? _tracksPanel() : _settingsPanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(String title, String subtitle) {
    final host = Uri.tryParse(_url.split('|').first)?.host ?? '';
    return Positioned.fill(
      child: Container(
        color: const Color(0xCC0C0A12),
        alignment: Alignment.center,
        padding: EdgeInsets.all(context.safeX),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.px(620).clamp(300.0, 720.0)),
          child: FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.portable_wifi_off_rounded, size: context.compact ? 44 : context.px(56), color: TiviColors.text3),
                SizedBox(height: context.space(4)),
                Text('Lecture impossible', style: TiviText.h1(context)),
                SizedBox(height: context.space(2)),
                Text('$title · $subtitle', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.small(context)),
                SizedBox(height: context.space(4)),
                Text(_error!, textAlign: TextAlign.center, style: TiviText.body(context)),
                if (host.isNotEmpty) ...[
                  SizedBox(height: context.space(2)),
                  Text('Serveur : $host', style: TiviText.micro(context).copyWith(fontWeight: FontWeight.w400)),
                ],
                SizedBox(height: context.space(6)),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: context.space(3),
                  runSpacing: context.space(2),
                  children: [
                    TiviPillButton(label: 'Réessayer', icon: Icons.refresh_rounded, primary: true, focusNode: _retryFocus, onPressed: _open),
                    if (_isLive && widget.request.channels.length > 1)
                      TiviPillButton(label: 'Chaîne suivante', icon: Icons.skip_next_rounded, onPressed: () => _zap(1)),
                    if (_isEpisode && _epIndex < _episodes.length - 1)
                      TiviPillButton(label: 'Épisode suivant', icon: Icons.skip_next_rounded, onPressed: () => _stepEpisode(1)),
                    TiviPillButton(label: 'Retour', icon: Icons.arrow_back_rounded, onPressed: () => Navigator.of(context).maybePop()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(db.Channel? ch, bool visible) {
    return Positioned(
      top: context.safeY,
      left: context.safeX,
      right: context.safeX,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: TiviMotion.slow,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ch != null)
                SizedBox(width: context.compact ? 64 : context.px(110), height: context.compact ? 40 : context.px(64), child: ChannelLogo(name: ch.name, url: ch.tvgLogo, padding: 0))
              else
                const TiviBrand(showName: false),
              const Spacer(),
              const ClockWeather(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _osdView() {
    final osd = _osd;
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: osd == null ? 0 : 1,
          duration: TiviMotion.base,
          child: osd == null
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  decoration: BoxDecoration(color: const Color(0x99100E16), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(osd.$1, color: Colors.white, size: 30),
                    if (osd.$2.isNotEmpty) ...[const SizedBox(width: 10), Text(osd.$2, style: TiviText.h3(context))],
                  ]),
                ),
        ),
      ),
    );
  }

  Widget _controls(String title, String subtitle, Widget badge, db.EpgProgramme? now, Set<String> favs) {
    final visible = _ui == _Ui.controls;
    final ch = _channel;
    final fav = ch != null && favs.contains(ch.id);
    final compact = context.compact;

    final time = ValueListenableBuilder<Duration>(
      valueListenable: _position,
      builder: (context, pos, _) {
        final style = TiviText.weight(compact ? 14 : TiviText.h2(context).fontSize!, 300).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
        if (_streamIsLive) {
          final elapsed = DateTime.now().difference(now?.start ?? _startedAt);
          return Text(_fmt(elapsed), style: style);
        }
        return Text.rich(TextSpan(children: [
          TextSpan(text: _fmt(pos)),
          TextSpan(text: '  /  ${_fmt(_duration)}', style: style.copyWith(fontSize: style.fontSize! * .6, color: TiviColors.text3)),
        ]), style: style);
      },
    );

    final transport = Row(mainAxisSize: MainAxisSize.min, children: [
      TiviIconButton(
        icon: _isMovie ? Icons.replay_10_rounded : Icons.skip_previous_rounded,
        variant: TiviButtonVariant.media,
        size: TiviButtonSize.sm,
        tooltip: _isLive ? 'Chaîne précédente' : (_isMovie ? 'Reculer de 10 s' : 'Épisode précédent'),
        disabled: _isEpisode && _epIndex == 0,
        onPressed: _prev,
        iconScale: .52,
      ),
      SizedBox(width: compact ? 18 : context.px(32)),
      _PlayButton(focusNode: _playFocus, playing: _playing, onPressed: () => _togglePlay()),
      SizedBox(width: compact ? 18 : context.px(32)),
      TiviIconButton(
        icon: _isMovie ? Icons.forward_10_rounded : Icons.skip_next_rounded,
        variant: TiviButtonVariant.media,
        size: TiviButtonSize.sm,
        tooltip: _isLive ? 'Chaîne suivante' : (_isMovie ? 'Avancer de 10 s' : 'Épisode suivant'),
        disabled: _isEpisode && _epIndex >= _episodes.length - 1,
        onPressed: _next,
        iconScale: .52,
      ),
    ]);

    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      TiviIconButton(
        focusNode: _tracksFocus,
        icon: _isLive ? Icons.closed_caption_outlined : Icons.translate_rounded,
        variant: TiviButtonVariant.media,
        size: TiviButtonSize.sm,
        tooltip: _isLive ? 'Sous-titres' : 'Langues et sous-titres',
        on: _isLive && _ps.player.state.track.subtitle.id != 'no' && _ps.player.state.track.subtitle.id != 'auto',
        onPressed: _isLive ? _toggleLiveSubtitles : () => _openPanel(_PanelKind.tracks),
      ),
      SizedBox(width: compact ? 4 : context.px(18)),
      TiviIconButton(
        icon: Icons.star_rounded,
        variant: TiviButtonVariant.media,
        size: TiviButtonSize.sm,
        tooltip: 'Favori',
        on: fav,
        onPressed: () async {
          if (ch == null) {
            showTiviToast(context, 'Ma liste : bientôt', icon: Icons.star_rounded);
            return;
          }
          final added = await ref.read(channelFavoritesProvider.notifier).toggle(ch.id);
          if (mounted) showTiviToast(context, added ? 'Ajoutée aux favoris' : 'Retirée des favoris', icon: Icons.star_rounded);
        },
      ),
      SizedBox(width: compact ? 4 : context.px(18)),
      TiviIconButton(
        focusNode: _settingsFocus,
        icon: Icons.settings_outlined,
        variant: TiviButtonVariant.media,
        size: TiviButtonSize.sm,
        tooltip: 'Réglages',
        onPressed: () => _openPanel(_PanelKind.settings),
      ),
    ]);

    return Positioned(
      left: context.safeX,
      right: context.safeX,
      bottom: compact ? 12 + MediaQuery.paddingOf(context).bottom : context.safeY * .6,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : Offset(0, _ui == _Ui.details ? -.15 : .08),
          duration: TiviMotion.slow,
          curve: TiviMotion.ease,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: TiviMotion.slow,
            child: ExcludeFocus(
              excluding: !visible,
              child: FocusScope(
                node: _controlsScope,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    badge,
                    SizedBox(height: context.space(2)),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TiviText.weight(TiviText.h2(context).fontSize!, 600)),
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.small(context).copyWith(color: TiviColors.text2)),
                    if (!_streamIsLive) ...[SizedBox(height: context.space(3)), _seekBar()],
                    SizedBox(height: context.space(3)),
                    if (compact) ...[
                      Center(child: transport),
                      const SizedBox(height: 8),
                      Row(children: [time, const Spacer(), actions]),
                    ] else
                      Row(children: [
                        Expanded(child: Align(alignment: Alignment.centerLeft, child: time)),
                        transport,
                        Expanded(child: Align(alignment: Alignment.centerRight, child: actions)),
                      ]),
                    if (_hasDetails)
                      Center(
                        child: GestureDetector(
                          onTap: _openDetails,
                          child: const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.keyboard_arrow_down_rounded, color: TiviColors.text2)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seekBar() {
    return LayoutBuilder(builder: (context, box) {
      return TvFocusable(
        focusNode: _seekFocus,
        hoverFocus: false,
        builder: (context, focused) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            if (_duration == Duration.zero) return;
            final t = _duration * (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
            _ps.player.seek(t);
            _position.value = t;
            _restartHide();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ValueListenableBuilder<Duration>(
              valueListenable: _position,
              builder: (context, pos, _) => TiviProgress(
                value: _duration.inMilliseconds == 0 ? 0 : pos.inMilliseconds / _duration.inMilliseconds,
                height: focused ? 8 : 4,
                thumb: focused,
              ),
            ),
          ),
        ),
      );
    });
  }

  /* ---------- Panneau détails ---------- */

  Widget _sheet(db.Channel? ch, List<db.EpgProgramme> progs, db.EpgProgramme? now) {
    final open = _ui == _Ui.details;
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: open ? Offset.zero : const Offset(0, 1.05),
        duration: TiviMotion.slow,
        curve: TiviMotion.ease,
        child: ExcludeFocus(
          excluding: !open,
          child: FocusScope(
            node: _sheetScope,
            child: Container(
              constraints: BoxConstraints(maxHeight: size.height * .78),
              padding: EdgeInsets.fromLTRB(context.safeX, context.space(8), context.safeX, context.safeY),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xF70E0C14), Color(0xEB0E0C14), Color(0x000E0C14)],
                  stops: [0, .7, 1],
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: TiviColors.text3),
                      const SizedBox(width: 6),
                      Text('Revenir au lecteur', style: TiviText.small(context)),
                      const Spacer(),
                      GestureDetector(onTap: _showControls, child: const Icon(Icons.close_rounded, color: TiviColors.text2)),
                    ]),
                    SizedBox(height: context.space(5)),
                    if (ch != null) ..._liveDetails(ch, progs, now) else ..._seriesDetails(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  List<Widget> _liveDetails(db.Channel ch, List<db.EpgProgramme> progs, db.EpgProgramme? now) {
    final upcoming = progs.where((p) => !p.isNow).toList();
    final logoSize = context.compact ? 72.0 : context.px(130);
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: const BoxDecoration(color: TiviColors.surface, borderRadius: BorderRadius.all(TiviRadius.xs)),
            child: ChannelLogo(name: ch.name, url: ch.tvgLogo),
          ),
          SizedBox(width: context.space(6)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  const TiviBadge.live(),
                  Text('${ch.channelNumber != null ? '${ch.channelNumber.toString().padLeft(3, '0')} · ' : ''}${ch.name}', style: TiviText.small(context).copyWith(color: TiviColors.text2)),
                  ...channelBadges(ch.name, hasEpg: progs.isNotEmpty),
                ]),
                SizedBox(height: context.space(3)),
                Text(now?.title ?? ch.name, style: TiviText.h1(context)),
                if (now != null) ...[
                  SizedBox(height: context.space(2)),
                  Text('${_hm(now.start)} – ${_hm(now.stop)} · reste ${now.stop.difference(DateTime.now()).inMinutes} min', style: TiviText.small(context)),
                  SizedBox(height: context.space(3)),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: TiviProgress(value: now.progress)),
                ],
                if (now?.description != null) ...[
                  SizedBox(height: context.space(3)),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Text(now!.description!, maxLines: 4, overflow: TextOverflow.ellipsis, style: TiviText.body(context))),
                ],
                if (progs.isEmpty) ...[
                  SizedBox(height: context.space(2)),
                  Text('Pas de guide des programmes pour cette chaîne.', style: TiviText.small(context)),
                ],
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: context.space(6)),
      Text('À SUIVRE SUR ${ch.name.toUpperCase()}', style: TiviText.eyebrow(context)),
      SizedBox(height: context.space(2)),
      SizedBox(
        height: context.compact ? 96 : context.px(112),
        child: upcoming.isEmpty
            // Toujours un élément focusable pour que ↑ referme le panneau
            ? TvFocusable(
                focusNode: _sheetFirstFocus,
                builder: (context, f) => Align(alignment: Alignment.centerLeft, child: Text('Rien de prévu dans le guide.', style: TiviText.small(context).copyWith(color: f ? TiviColors.text : null))),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: upcoming.length,
                separatorBuilder: (_, _) => SizedBox(width: context.space(4)),
                itemBuilder: (context, i) => _EpgCard(
                  focusNode: i == 0 ? _sheetFirstFocus : null,
                  time: _hm(upcoming[i].start),
                  title: upcoming[i].title,
                  reminded: ref.watch(remindersProvider).contains(RemindersNotifier.keyOf(upcoming[i].epgChannelId, upcoming[i].start)),
                  onSelect: () async {
                    final added = await ref.read(remindersProvider.notifier).toggle(upcoming[i], channelId: ch.id);
                    if (mounted) showTiviToast(this.context, added ? 'Rappel ajouté' : 'Rappel retiré', icon: Icons.notifications_none_rounded);
                  },
                ),
              ),
      ),
    ];
  }

  List<Widget> _seriesDetails() {
    final series = widget.request.series!;
    final ep = _episode!;
    final w = context.compact ? 200.0 : context.px(250);
    final eps = _episodes;
    return [
      Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(series.title, style: TiviText.small(context).copyWith(color: TiviColors.text2)),
        TiviBadge.soft(ep.code),
      ]),
      SizedBox(height: context.space(2)),
      Text(ep.title, style: TiviText.h1(context)),
      SizedBox(height: context.space(5)),
      Text('ÉPISODES · ${series.seasons.length > 1 ? '${series.seasons.length} SAISONS' : 'SAISON ${ep.season}'}', style: TiviText.eyebrow(context)),
      SizedBox(
        height: w * 9 / 16 + context.px(70) + 30,
        child: TvIndexedList(
          axis: Axis.horizontal,
          controller: _episodesCtrl,
          focusNode: _sheetFirstFocus,
          itemCount: eps.length,
          itemExtent: w + context.space(4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          onSelect: (i) {
            _playEpisode(i);
            _showControls();
          },
          itemBuilder: (context, i, focused) => _EpisodeCard(
            episode: eps[i],
            width: w,
            focused: focused,
            current: i == _epIndex,
            progress: i == _epIndex ? null : ResumeStore.instance.progress(eps[i].streamUrl),
          ),
        ),
      ),
    ];
  }

  /* ---------- Tiroirs ---------- */

  String _trackLabel(String? title, String? language, int i) {
    final parts = [if (title != null && title.isNotEmpty) title, if (language != null && language.isNotEmpty) language.toUpperCase()];
    return parts.isEmpty ? 'Piste ${i + 1}' : parts.join(' · ');
  }

  void _toggleLiveSubtitles() {
    final subs = _ps.player.state.tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final current = _ps.player.state.track.subtitle;
    if (current.id != 'no' && current.id != 'auto') {
      _ps.player.setSubtitleTrack(SubtitleTrack.no());
      showTiviToast(context, 'Sous-titres désactivés', icon: Icons.closed_caption_disabled_outlined);
    } else if (subs.isEmpty) {
      showTiviToast(context, 'Aucun sous-titre sur cette chaîne', icon: Icons.closed_caption_outlined);
    } else {
      _ps.player.setSubtitleTrack(subs.first);
      showTiviToast(context, 'Sous-titres activés', icon: Icons.closed_caption_outlined);
    }
    setState(() {});
  }

  Widget _tracksPanel() {
    final tracks = _ps.player.state.tracks;
    final current = _ps.player.state.track;
    final audio = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final subs = tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final subsOff = current.subtitle.id == 'no' || current.subtitle.id == 'auto';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelGroupTitle('Audio'),
        if (audio.isEmpty) const OptionTile(label: 'Piste par défaut', checked: true, autofocus: true),
        for (var i = 0; i < audio.length; i++)
          OptionTile(
            label: _trackLabel(audio[i].title, audio[i].language, i),
            checked: audio[i].id == current.audio.id,
            autofocus: audio[i].id == current.audio.id || (i == 0 && !audio.any((a) => a.id == current.audio.id)),
            onSelect: () {
              _ps.player.setAudioTrack(audio[i]);
              setState(() {});
            },
          ),
        const PanelGroupTitle('Sous-titres'),
        OptionTile(label: 'Désactivés', checked: subsOff, onSelect: () {
          _ps.player.setSubtitleTrack(SubtitleTrack.no());
          setState(() {});
        }),
        for (var i = 0; i < subs.length; i++)
          OptionTile(
            label: _trackLabel(subs[i].title, subs[i].language, i),
            checked: subs[i].id == current.subtitle.id,
            onSelect: () {
              _ps.player.setSubtitleTrack(subs[i]);
              setState(() {});
            },
          ),
      ],
    );
  }

  Widget _settingsPanel() {
    const fits = [(BoxFit.contain, 'Adapter'), (BoxFit.cover, 'Remplir'), (BoxFit.fill, 'Étirer')];
    const rates = [0.75, 1.0, 1.25, 1.5, 2.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelGroupTitle('Format d\'image'),
        for (final (fit, label) in fits)
          OptionTile(label: label, checked: _fit == fit, autofocus: _fit == fit, onSelect: () => setState(() => _fit = fit)),
        if (!_isLive) ...[
          const PanelGroupTitle('Vitesse'),
          for (final r in rates)
            OptionTile(
              label: '${r.toString().replaceAll('.', ',').replaceAll(RegExp(r',0$'), '')}×',
              checked: _rate == r,
              onSelect: () {
                setState(() => _rate = r);
                _ps.player.setRate(r);
              },
            ),
        ],
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.focusNode, required this.playing, required this.onPressed});
  final FocusNode focusNode;
  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final d = tiviButtonSize(context, TiviButtonSize.lg);
    return TvFocusable(
      focusNode: focusNode,
      onSelect: onPressed,
      semanticLabel: playing ? 'Pause' : 'Lecture',
      builder: (context, focused) => AnimatedScale(
        scale: focused ? 1.1 : 1,
        duration: TiviMotion.base,
        curve: TiviMotion.ease,
        child: AnimatedContainer(
          duration: TiviMotion.base,
          width: d,
          height: d,
          decoration: BoxDecoration(shape: BoxShape.circle, color: focused ? const Color(0x47FFFFFF) : const Color(0x29FFFFFF)),
          child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: d * .5),
        ),
      ),
    );
  }
}

class _EpgCard extends StatelessWidget {
  const _EpgCard({required this.time, required this.title, this.onSelect, this.focusNode, this.reminded = false});
  final String time;
  final String title;
  final bool reminded;
  final VoidCallback? onSelect;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onSelect: onSelect,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? TiviMotion.focusScale : 1,
        duration: TiviMotion.base,
        curve: TiviMotion.ease,
        child: AnimatedContainer(
          duration: TiviMotion.base,
          width: context.compact ? 200 : context.px(250),
          padding: EdgeInsets.all(context.space(4)),
          decoration: BoxDecoration(
            color: focused ? TiviColors.surfaceFocus : TiviColors.surface,
            border: Border.all(color: TiviColors.line),
            borderRadius: const BorderRadius.all(TiviRadius.xs),
            boxShadow: focused ? TiviShadow.focus : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(time, style: TiviText.small(context).copyWith(color: TiviColors.accent)),
              const SizedBox(height: 6),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TiviText.weight(TiviText.body(context).fontSize!, 500)),
              const Spacer(),
              Row(children: [
                Icon(reminded ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 14, color: reminded ? TiviColors.accent : TiviColors.text3),
                const SizedBox(width: 4),
                Text(reminded ? 'Rappel activé' : 'Me le rappeler', style: TiviText.micro(context).copyWith(fontWeight: FontWeight.w400, color: reminded ? TiviColors.accent : null)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode, required this.width, required this.focused, required this.current, this.progress});
  final VodEpisode episode;
  final double width;
  final bool focused;
  final bool current;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: focused ? TiviMotion.focusScale : 1,
      duration: TiviMotion.base,
      curve: TiviMotion.ease,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AnimatedContainer(
                duration: TiviMotion.base,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: TiviColors.surface,
                  borderRadius: const BorderRadius.all(TiviRadius.xs),
                  border: current ? Border.all(color: TiviColors.accent, width: 2) : null,
                  boxShadow: focused ? TiviShadow.focus : TiviShadow.s1,
                ),
                child: Stack(fit: StackFit.expand, children: [
                  if (episode.poster != null) ChannelLogo(name: episode.title, url: episode.poster, padding: 0, fit: BoxFit.cover),
                  if (current) const Positioned(top: 8, left: 8, child: TiviBadge.fresh(label: 'En cours')),
                  if (progress != null) Positioned(left: 10, right: 10, bottom: 8, child: TiviProgress(value: progress!, height: 3)),
                  Positioned(left: 0, right: 0, bottom: 0, child: Center(child: FocusBar(visible: focused, length: width * .4))),
                ]),
              ),
            ),
            SizedBox(height: context.space(3)),
            Text('É${episode.episode} · ${episode.title}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TiviText.weight(TiviText.body(context).fontSize!, 500, color: focused ? TiviColors.text : TiviColors.text2)),
            Text('Saison ${episode.season}', style: TiviText.small(context)),
          ],
        ),
      ),
    );
  }
}
