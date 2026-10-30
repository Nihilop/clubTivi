import 'package:flutter/material.dart';

import '../tokens.dart';

/// Barre de progression fine (programme en cours, reprise).
class TiviProgress extends StatelessWidget {
  const TiviProgress({super.key, required this.value, this.height = 4, this.thumb = false});

  final double value;
  final double height;
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return SizedBox(
        height: thumb ? 22 : height,
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: TiviMotion.base,
              height: height,
              decoration: BoxDecoration(color: const Color(0x38FFFFFF), borderRadius: BorderRadius.circular(height)),
            ),
            AnimatedContainer(
              duration: TiviMotion.fast,
              width: w * v,
              height: height,
              decoration: BoxDecoration(color: TiviColors.white, borderRadius: BorderRadius.circular(height)),
            ),
            Positioned(
              left: w * v - 9,
              child: AnimatedScale(
                scale: thumb ? 1 : 0,
                duration: TiviMotion.base,
                curve: TiviMotion.ease,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: TiviColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x2EFFFFFF), spreadRadius: 6)],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
