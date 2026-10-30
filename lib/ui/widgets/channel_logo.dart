import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

const _monoColors = [
  Color(0xFFF2C230), Color(0xFF5FD3F3), Color(0xFFFF7A1F), Color(0xFFEF3B52), Color(0xFF3DD68C),
  Color(0xFFC8A2FF), Color(0xFFFFB347), Color(0xFFFF5FA2), Color(0xFFD9C29A), Color(0xFF7FB2FF),
  Color(0xFF56E0C2), Color(0xFFFFE15F),
];

/// Logo de chaîne : image de la playlist, ou monogramme coloré à défaut.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.name, this.url, this.padding = .14, this.fit = BoxFit.contain});

  final String name;
  final String? url;
  final double padding;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final side = box.biggest.shortestSide.isFinite ? box.biggest.shortestSide : 80.0;
      final mono = Monogram(name: name, size: side);
      if (url == null || url!.isEmpty) return mono;
      return Padding(
        padding: EdgeInsets.all(side * padding),
        child: CachedNetworkImage(
          imageUrl: url!,
          fit: fit,
          fadeInDuration: TiviMotion.fast,
          errorWidget: (_, _, _) => mono,
          placeholder: (_, _) => const SizedBox.shrink(),
        ),
      );
    });
  }
}

/// Monogramme : 2 à 4 lettres du nom, couleur stable par chaîne.
class Monogram extends StatelessWidget {
  const Monogram({super.key, required this.name, required this.size});

  final String name;
  final double size;

  static String initials(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'^\W*[A-Z]{2,3}\s*[|:\-–]\s*'), '')
        .replaceAll(RegExp(r'\b(HD|FHD|UHD|4K|SD|HEVC)\b', caseSensitive: false), '')
        .trim();
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(1, 4)).toUpperCase();
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _monoColors[name.hashCode.abs() % _monoColors.length];
    return Center(
      child: Text(
        initials(name),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TiviText.weight(size * .26, 700, color: color, letterSpacing: -.5, height: .9),
      ),
    );
  }
}
