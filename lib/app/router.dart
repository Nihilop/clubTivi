import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../data/models/show.dart';
import '../data/tivi/play_request.dart';
import '../features/epg_mapping/epg_mapping_screen.dart';
import '../features/guide/guide_screen.dart';
import '../features/home/home_screen.dart';
import '../features/live/live_screen.dart';
import '../features/live/tv_guide_screen.dart';
import '../features/search/search_screen.dart';
import '../features/player/player_screen.dart';
import '../features/player/tivi_player_screen.dart';
import '../features/providers/providers_screen.dart';
import '../features/settings/debrid_services_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/tivi_settings_screen.dart';
import '../features/shows/show_detail_screen.dart';
import '../features/shows/shows_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/vod/vod_screen.dart';

/// Navigateur racine : sert aussi au raccourci Échap → Retour (voir tv_keys.dart).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigation : l'accueil est la racine, les autres écrans sont empilés
/// (`context.push`) pour que le bouton Retour de la télécommande y revienne.
GoRouter createRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/live', builder: (context, state) => const LiveScreen()),
      GoRoute(path: '/epg', builder: (context, state) => const TvGuideScreen()),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(
        path: '/vod',
        builder: (context, state) => VodScreen(series: state.uri.queryParameters['kind'] == 'series'),
      ),
      GoRoute(
        path: '/play',
        builder: (context, state) => TiviPlayerScreen(request: state.extra! as PlayRequest),
      ),

      // Écrans d'origine (gestion des playlists, EPG, réglages avancés…)
      GoRoute(path: '/guide', builder: (context, state) => const GuideScreen()),
      GoRoute(path: '/providers', builder: (context, state) => const ProvidersScreen()),
      GoRoute(path: '/epg-mapping', builder: (context, state) => const EpgMappingScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const TiviSettingsScreen()),
      GoRoute(path: '/settings/advanced', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/debrid-services', builder: (context, state) => const DebridServicesScreen()),
      GoRoute(path: '/shows', builder: (context, state) => const ShowsScreen()),
      GoRoute(
        path: '/shows/:id',
        builder: (context, state) {
          final traktId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ShowDetailScreen(traktId: traktId, initialShow: state.extra as Show?);
        },
      ),
      // Ancien lecteur, encore appelé par le guide et les écrans Trakt
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return PlayerScreen(
            streamUrl: extra['streamUrl'] as String? ?? '',
            channelName: extra['channelName'] as String? ?? '',
            channelLogo: extra['channelLogo'] as String?,
            alternativeUrls: (extra['alternativeUrls'] as List<String>?) ?? const [],
            channels: (extra['channels'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [],
            currentIndex: extra['currentIndex'] as int? ?? 0,
          );
        },
      ),
    ],
  );
}

/// Instance globale du routeur.
final GoRouter router = createRouter();
