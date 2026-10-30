import '../datasources/local/database.dart' as db;
import 'vod_catalog.dart';

enum PlayKind { live, movie, episode }

/// Ce que le lecteur doit jouer (passé en `extra` à la route `/play`).
class PlayRequest {
  const PlayRequest.live({required this.channels, required this.index})
      : kind = PlayKind.live,
        movie = null,
        series = null,
        episodeIndex = 0;

  const PlayRequest.movie(VodMovie this.movie)
      : kind = PlayKind.movie,
        channels = const [],
        index = 0,
        series = null,
        episodeIndex = 0;

  /// [episodeIndex] : position dans `series.allEpisodes`.
  const PlayRequest.episode(VodSeries this.series, this.episodeIndex)
      : kind = PlayKind.episode,
        channels = const [],
        index = 0,
        movie = null;

  final PlayKind kind;

  /// Liste de zapping (direct).
  final List<db.Channel> channels;
  final int index;
  final VodMovie? movie;
  final VodSeries? series;
  final int episodeIndex;
}
