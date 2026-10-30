import 'package:media_kit/media_kit.dart';

/// URL de flux avec en-têtes HTTP éventuels, au format Kodi :
/// `https://exemple/flux.m3u8|Referer=https%3A%2F%2Fsite&User-Agent=Mozilla%2F5.0`.
///
/// Certaines playlists (≈ 14 % d'iptv-org) exigent un Referer ou un User-Agent :
/// sans eux, le serveur refuse le flux.
class StreamUrl {
  const StreamUrl(this.url, this.headers);

  final String url;
  final Map<String, String> headers;

  factory StreamUrl.parse(String raw) {
    final bar = raw.indexOf('|');
    if (bar < 0) return StreamUrl(raw, const {});
    final headers = <String, String>{};
    for (final part in raw.substring(bar + 1).split('&')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      headers[Uri.decodeComponent(part.substring(0, eq))] = Uri.decodeComponent(part.substring(eq + 1));
    }
    return StreamUrl(raw.substring(0, bar), headers);
  }

  /// Construit l'URL encodée (utilisé par le parseur M3U).
  static String encode(String url, Map<String, String> headers) {
    if (headers.isEmpty) return url;
    final query = headers.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    return '$url|$query';
  }

  Media toMedia() => Media(url, httpHeaders: headers.isEmpty ? null : headers);
}
