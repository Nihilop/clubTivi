import '../../../features/player/stream_url.dart';
import '../../models/channel.dart';

/// Parses M3U and M3U Plus playlist formats.
///
/// Supports:
/// - Standard M3U (#EXTM3U / #EXTINF)
/// - M3U Plus extended attributes (tvg-id, tvg-name, tvg-logo, group-title, etc.)
/// - Xtream Codes style attributes (tvg-chno, tvg-shift)
/// - Multiple URL formats (HTTP, HTTPS, RTMP, RTSP, UDP)
class M3uParser {
  /// Parse M3U content from a string.
  M3uResult parse(String content, {required String providerId}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    final errors = <String>[];

    if (lines.isEmpty || !lines.first.trim().startsWith('#EXTM3U')) {
      errors.add('Missing #EXTM3U header');
    }

    String? currentExtInf;
    // En-têtes HTTP déclarés entre #EXTINF et l'URL (#EXTVLCOPT:http-referrer=…)
    final vlcOpts = <String, String>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty || line == '#EXTM3U') continue;

      // Skip global EXTM3U attributes line
      if (line.startsWith('#EXTM3U ')) continue;

      if (line.startsWith('#EXTINF:')) {
        currentExtInf = line;
        vlcOpts.clear();
        continue;
      }

      if (line.startsWith('#EXTVLCOPT:')) {
        final opt = line.substring('#EXTVLCOPT:'.length);
        final eq = opt.indexOf('=');
        if (eq > 0) vlcOpts[opt.substring(0, eq).trim().toLowerCase()] = opt.substring(eq + 1).trim();
        continue;
      }

      // Skip other directives
      if (line.startsWith('#')) continue;

      // This should be a URL
      if (currentExtInf != null) {
        try {
          final channel = _parseEntry(currentExtInf, line, providerId, vlcOpts);
          if (channel != null) channels.add(channel);
        } catch (e) {
          errors.add('Line $i: $e');
        }
        currentExtInf = null;
      }
    }

    return M3uResult(channels: channels, errors: errors);
  }

  Channel? _parseEntry(String extInf, String rawUrl, String providerId, [Map<String, String> vlcOpts = const {}]) {
    if (rawUrl.isEmpty) return null;

    // Parse #EXTINF:-1 tvg-id="..." tvg-name="..." ... , Channel Name
    final attrs = _parseAttributes(extInf);

    // Referer / User-Agent exigés par certains serveurs → ajoutés à l'URL (format Kodi)
    final referer = attrs['http-referrer'] ?? vlcOpts['http-referrer'];
    final userAgent = attrs['http-user-agent'] ?? vlcOpts['http-user-agent'];
    final url = StreamUrl.encode(rawUrl, {
      if (referer != null && referer.isNotEmpty) 'Referer': referer,
      if (userAgent != null && userAgent.isNotEmpty) 'User-Agent': userAgent,
    });
    final displayName = _parseDisplayName(extInf);

    if (displayName.isEmpty && attrs['tvg-name'] == null) return null;

    final name = displayName.isNotEmpty ? displayName : attrs['tvg-name']!;

    // Generate a stable ID from provider + tvg-id or URL
    final tvgId = attrs['tvg-id'];
    final channelId = tvgId != null && tvgId.isNotEmpty
        ? '${providerId}_$tvgId'
        : '${providerId}_${url.hashCode}';

    // Parse channel number
    int? channelNumber;
    final chnoStr = attrs['tvg-chno'];
    if (chnoStr != null && chnoStr.isNotEmpty) {
      channelNumber = int.tryParse(chnoStr);
    }

    return Channel(
      id: channelId,
      providerId: providerId,
      name: name,
      tvgId: _emptyToNull(attrs['tvg-id']),
      tvgName: _emptyToNull(attrs['tvg-name']),
      tvgLogo: _emptyToNull(attrs['tvg-logo']),
      groupTitle: _emptyToNull(attrs['group-title']),
      channelNumber: channelNumber,
      streamUrl: url,
      streamType: _inferStreamType(attrs, url),
    );
  }

  /// Parse M3U Plus extended attributes from an #EXTINF line.
  /// Example: #EXTINF:-1 tvg-id="ESPN.us" tvg-name="ESPN HD" group-title="Sports",ESPN HD
  Map<String, String> _parseAttributes(String extInf) {
    final attrs = <String, String>{};

    // Match key="value" pairs
    final regex = RegExp(r'([\w-]+)="([^"]*)"');
    for (final match in regex.allMatches(extInf)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    return attrs;
  }

  /// Extract the display name (after the last comma in #EXTINF line).
  String _parseDisplayName(String extInf) {
    final commaIndex = extInf.lastIndexOf(',');
    if (commaIndex == -1) return '';
    return extInf.substring(commaIndex + 1).trim();
  }

  static final _videoFile = RegExp(r'\.(mp4|mkv|avi|mov|m4v|webm|wmv|flv|mpe?g)$');

  StreamType _inferStreamType(Map<String, String> attrs, String url) {
    final path = (Uri.tryParse(StreamUrl.parse(url).url)?.path ?? '').toLowerCase();
    // Xtream Codes URL patterns
    if (path.contains('/movie/')) return StreamType.vod;
    if (path.contains('/series/')) return StreamType.series;
    // Un flux HLS ou sans fichier vidéo est du direct, même rangé dans « Movies » :
    // ce sont des chaînes de films (iptv-org, Pluto…), pas des films à la demande.
    if (!_videoFile.hasMatch(path)) return StreamType.live;
    final groupTitle = (attrs['group-title'] ?? '').toLowerCase();
    if (groupTitle.contains('series') || groupTitle.contains('série') || groupTitle.contains('serie')) {
      return StreamType.series;
    }
    return StreamType.vod;
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

/// Result of parsing an M3U playlist.
class M3uResult {
  final List<Channel> channels;
  final List<String> errors;

  const M3uResult({required this.channels, this.errors = const []});

  bool get hasErrors => errors.isNotEmpty;
  int get channelCount => channels.length;
}
