import 'package:flutter/material.dart';

import '../game/palette.dart';

/// Bold text with a thick ink outline, readable on both the dark sky and
/// the light ground (the cutout art style).
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    required this.fontSize,
    required this.color,
  });

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900);
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize / 6
              ..strokeJoin = StrokeJoin.round
              ..color = Palette.outline,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}
