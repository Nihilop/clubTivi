import 'package:clubtivi/data/datasources/parsers/m3u_parser.dart';
import 'package:clubtivi/features/player/stream_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('en-têtes encodés puis relus', () {
    final raw = StreamUrl.encode('https://a.tv/live.m3u8', {'Referer': 'https://site.ma/', 'User-Agent': 'Mozilla/5.0 (X)'});
    final s = StreamUrl.parse(raw);
    expect(s.url, 'https://a.tv/live.m3u8');
    expect(s.headers, {'Referer': 'https://site.ma/', 'User-Agent': 'Mozilla/5.0 (X)'});
    expect(StreamUrl.parse('https://a.tv/x.m3u8').headers, isEmpty);
  });

  test('le parseur M3U garde Referer / User-Agent (attributs et #EXTVLCOPT)', () {
    const m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="A.ma@SD" http-referrer="https://a.ma/" group-title="French",A
https://a.tv/a.m3u8
#EXTINF:-1 tvg-id="B.fr@SD" group-title="French",B
#EXTVLCOPT:http-user-agent=Mozilla/5.0
https://b.tv/b.m3u8
#EXTINF:-1 tvg-id="C.fr@SD" group-title="French",C
https://c.tv/c.m3u8
''';
    final ch = M3uParser().parse(m3u, providerId: 'p').channels;
    expect(StreamUrl.parse(ch[0].streamUrl).headers, {'Referer': 'https://a.ma/'});
    expect(StreamUrl.parse(ch[1].streamUrl).headers, {'User-Agent': 'Mozilla/5.0'});
    expect(ch[2].streamUrl, 'https://c.tv/c.m3u8');
  });

  test('une chaîne « Movies » en HLS reste du direct, un fichier vidéo est un film', () {
    const m3u = '''#EXTM3U
#EXTINF:-1 group-title="Movies",70s Cinema
https://jmp2.uk/plu-5f4d878d3d19b30007d2e782.m3u8
#EXTINF:-1 group-title="VOD Movies",Le Film (2020)
http://host/films/le-film.mkv
#EXTINF:-1 group-title="Series",Show S01E02
http://host/series/user/pass/42.mp4
#EXTINF:-1 group-title="News",Info
http://host/movie/user/pass/7.ts
''';
    final ch = M3uParser().parse(m3u, providerId: 'p').channels;
    expect(ch.map((c) => c.streamType.name), ['live', 'vod', 'series', 'vod']);
  });
}
