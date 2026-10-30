import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../focus/tv_focusable.dart';
import '../scale.dart';
import '../tokens.dart';
import '../typography.dart';
import 'channel_logo.dart';
import 'progress.dart';

/// Barre blanche qui signale l'élément focus (sous une tuile, à gauche d'une carte de liste).
class FocusBar extends StatelessWidget {
  const FocusBar({super.key, required this.visible, this.vertical = false, this.glow = false, this.length = 40});

  final bool visible;
  final bool vertical;
  final bool glow;
  final double length;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : .3,
      duration: TiviMotion.slow,
      curve: TiviMotion.ease,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: TiviMotion.base,
        child: Container(
          width: vertical ? 4 : length,
          height: vertical ? length : 4,
          decoration: BoxDecoration(
            color: TiviColors.focusIndicator,
            borderRadius: BorderRadius.circular(2),
            boxShadow: glow ? const [BoxShadow(color: Color(0x73FFFFFF), blurRadius: 22, spreadRadius: 6)] : null,
          ),
        ),
      ),
    );
  }
}

/// Tuile en verre dépoli de l'accueil (image 2).
class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    required this.icon,
    required this.title,
    required this.meta,
    this.corner,
    this.mediaUrl,
    this.onSelect,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.aspectRatio = .6,
  });

  final IconData icon;
  final String title;
  final String meta;
  final Widget? corner;
  final String? mediaUrl;
  final VoidCallback? onSelect;
  final bool autofocus;
  final FocusNode? focusNode;
  final double? width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final w = width ?? context.px(220);
    final pad = context.compact ? 14.0 : context.px(22);
    return TvFocusable(
      autofocus: autofocus,
      focusNode: focusNode,
      onSelect: onSelect,
      semanticLabel: title,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? (context.compact ? 1.02 : 1.12) : 1,
        duration: TiviMotion.slow,
        curve: TiviMotion.ease,
        child: SizedBox(
          width: w,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: TiviMotion.base,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(TiviRadius.xs),
                      boxShadow: focused ? TiviShadow.focus : null,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(TiviRadius.xs),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: AnimatedContainer(
                          duration: TiviMotion.base,
                          decoration: BoxDecoration(
                            color: focused ? TiviColors.glassStrong : TiviColors.glass,
                            border: Border.all(color: focused ? TiviColors.lineStrong : TiviColors.glassBorder),
                            borderRadius: const BorderRadius.all(TiviRadius.xs),
                          ),
                          child: mediaUrl == null
                              ? null
                              : ShaderMask(
                                  shaderCallback: (r) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black, Colors.transparent],
                                    stops: [.3, .85],
                                  ).createShader(r),
                                  blendMode: BlendMode.dstIn,
                                  child: Opacity(
                                    opacity: .28,
                                    child: CachedNetworkImage(imageUrl: mediaUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (corner != null) Positioned(top: pad * .6, left: pad * .6, right: pad * .6, child: Align(alignment: Alignment.centerRight, child: corner)),
                Positioned(
                  left: pad,
                  right: pad,
                  bottom: pad,
                  top: pad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 5),
                      Icon(icon, size: context.compact ? 34 : context.px(46), color: focused ? TiviColors.text : TiviColors.text2),
                      const Spacer(flex: 4),
                      Text(title, maxLines: 2, style: TiviText.weight(TiviText.h2(context).fontSize!, 400)),
                      SizedBox(height: context.space(1)),
                      Text(meta, style: TiviText.small(context)),
                    ],
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: -2, child: Center(child: FocusBar(visible: focused, glow: true, length: w * .34))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte de chaîne (image 3). Purement visuelle : l'état focus vient de la liste.
class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
    required this.name,
    required this.focused,
    this.logoUrl,
    this.subtitle,
    this.badges = const [],
    this.number,
    this.favorite = false,
  });

  final String name;
  final bool focused;
  final String? logoUrl;
  final String? subtitle;
  final List<Widget> badges;
  final int? number;
  final bool favorite;

  /// Hauteur d'une carte (hors espacement).
  static double heightOf(BuildContext c) => c.compact ? 84 : c.px(118);

  @override
  Widget build(BuildContext context) {
    final h = heightOf(context);
    final pad = context.compact ? 10.0 : context.px(13);
    return AnimatedScale(
      scale: focused ? (context.compact ? 1.02 : 1.07) : 1,
      duration: TiviMotion.base,
      curve: TiviMotion.ease,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: TiviMotion.base,
            height: h,
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: focused ? TiviColors.surfaceFocus : TiviColors.surface,
              border: Border.all(color: focused ? TiviColors.lineStrong : TiviColors.line),
              borderRadius: const BorderRadius.all(TiviRadius.xs),
              boxShadow: focused ? TiviShadow.focus : null,
            ),
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: const BoxDecoration(color: TiviColors.bg, borderRadius: BorderRadius.all(TiviRadius.xs)),
                    child: ChannelLogo(name: name, url: logoUrl),
                  ),
                ),
                SizedBox(width: context.compact ? 12 : context.px(20)),
                Expanded(
                  // Sous-titre et badges cèdent la place si le texte grossit
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.h3(context)),
                      if (subtitle != null)
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.only(top: context.space(1)),
                            child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TiviText.small(context)),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          ...badges.expand((b) => [b, const SizedBox(width: 6)]),
                          const Spacer(),
                          AnimatedOpacity(
                            opacity: favorite ? 1 : 0,
                            duration: TiviMotion.base,
                            child: Icon(Icons.star_rounded, color: TiviColors.accent, size: context.compact ? 18 : context.px(22)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (number != null && !context.compact)
            Positioned(top: 8, right: 12, child: Text(number!.toString().padLeft(3, '0'), style: TiviText.micro(context).copyWith(color: TiviColors.text4))),
          Positioned(left: context.compact ? -8 : -context.px(14), top: h * .3, child: FocusBar(visible: focused, vertical: true, length: h * .4)),
        ],
      ),
    );
  }
}

/// Poster de film / série (2:3). Purement visuel.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.focused,
    this.imageUrl,
    this.subtitle,
    this.isNew = false,
    this.progress,
    this.width,
  });

  final String title;
  final bool focused;
  final String? imageUrl;
  final String? subtitle;
  final bool isNew;
  final double? progress;
  final double? width;

  static double widthOf(BuildContext c) => c.compact ? 116 : c.px(150);

  @override
  Widget build(BuildContext context) {
    final w = width ?? widthOf(context);
    return AnimatedScale(
      scale: focused ? (context.compact ? 1.03 : 1.1) : 1,
      duration: TiviMotion.base,
      curve: TiviMotion.ease,
      child: SizedBox(
        width: w,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: AnimatedContainer(
                duration: TiviMotion.base,
                decoration: BoxDecoration(
                  color: TiviColors.surface,
                  borderRadius: const BorderRadius.all(TiviRadius.xs),
                  boxShadow: focused ? TiviShadow.focus : TiviShadow.s1,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover, errorWidget: (_, _, _) => Monogram(name: title, size: w))
                    else
                      Monogram(name: title, size: w),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(10, w * .22, 10, progress != null ? 14 : 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xEB0C0A12), Color(0x000C0A12)]),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TiviText.weight(TiviText.small(context).fontSize!, 500)),
                            if (subtitle != null) Text(subtitle!, maxLines: 1, style: TiviText.micro(context).copyWith(fontWeight: FontWeight.w400)),
                          ],
                        ),
                      ),
                    ),
                    if (isNew) const Positioned(top: 8, left: 8, child: _NewBadge()),
                    if (progress != null)
                      Positioned(left: 10, right: 10, bottom: 6, child: TiviProgress(value: progress!, height: 3)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FocusBar(visible: focused, length: w * .4),
          ],
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: const BoxDecoration(color: TiviColors.accent, borderRadius: BorderRadius.all(TiviRadius.xs)),
        child: Text('Nouveau', style: TiviText.micro(context).copyWith(color: Colors.white)),
      );
}

/// Ligne d'un choix de langue (cercle drapeau + nom + nombre de chaînes).
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key, required this.label, required this.count, this.flagCode, this.onSelect, this.autofocus = false});

  final String label;
  final int count;
  final String? flagCode;
  final VoidCallback? onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final f = context.compact ? 44.0 : context.px(56);
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: label,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? 1.05 : 1,
        duration: TiviMotion.base,
        curve: TiviMotion.ease,
        child: AnimatedContainer(
          duration: TiviMotion.base,
          padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(3)),
          decoration: BoxDecoration(color: focused ? const Color(0x0FFFFFFF) : Colors.transparent, borderRadius: BorderRadius.circular(999)),
          child: Row(
            children: [
              AnimatedContainer(
                duration: TiviMotion.base,
                width: f,
                height: f,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TiviColors.surfaceRaised,
                  boxShadow: focused ? const [BoxShadow(color: Colors.white, spreadRadius: 4)] : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: flagCode == null
                    ? Icon(Icons.public, color: TiviColors.text2, size: f * .5)
                    : CachedNetworkImage(
                        imageUrl: 'https://flagcdn.com/w160/$flagCode.png',
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Center(child: Text(flagCode!.toUpperCase(), style: TiviText.micro(context))),
                      ),
              ),
              SizedBox(width: context.space(4)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TiviText.weight(TiviText.h3(context).fontSize!, focused ? 500 : 400, color: focused ? TiviColors.text : TiviColors.text3)),
                    Text('$count chaînes', style: TiviText.small(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
