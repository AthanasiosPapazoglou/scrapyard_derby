import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/tuning.dart';
import 'hill.dart';
import 'palette.dart';

/// A flag planted on the hill at one star distance of the level: the goal
/// (1 star), then 2 and 3 stars. Decoration only, no physics.
class StarFlag extends PositionComponent {
  StarFlag({required this.stars, required double x, required HillGeometry hill})
    : super(position: Vector2(x, hill.heightAt(x)), priority: 2);

  /// How many stars this flag stands for (1-3).
  final int stars;

  /// Cloth colour per star count: goal yellow, then rust, then glow.
  static const List<Color> _clothColors = [
    Palette.hazard,
    Palette.rustLight,
    Palette.eyeGlow,
  ];

  static final Paint _ink = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = Tuning.starFlagOutline
    ..strokeJoin = StrokeJoin.round;
  static final Paint _pole = Paint()..color = Palette.steelLight;
  static final Paint _starFill = Paint()..color = Palette.outline;
  final Paint _cloth = Paint();

  @override
  void render(Canvas canvas) {
    const h = Tuning.starFlagHeight;
    const w = Tuning.starFlagClothWidth;
    const ch = Tuning.starFlagClothHeight;
    // Pole: straight up (y down), sunk a little into the ground.
    final pole = Rect.fromLTWH(-0.09, -h, 0.18, h + 0.4);
    canvas
      ..drawRect(pole, _pole)
      ..drawRect(pole, _ink);
    // Cloth with a slight wave, hanging from the top of the pole.
    final cloth = Path()
      ..moveTo(0, -h)
      ..quadraticBezierTo(w * 0.5, -h - 0.3, w, -h + 0.1)
      ..lineTo(w, -h + ch + 0.1)
      ..quadraticBezierTo(w * 0.5, -h + ch - 0.3, 0, -h + ch)
      ..close();
    _cloth.color = _clothColors[(stars - 1).clamp(0, 2)];
    canvas
      ..drawPath(cloth, _cloth)
      ..drawPath(cloth, _ink);
    // One small star per star of the flag.
    final spacing = w / (stars + 1);
    for (var i = 1; i <= stars; i++) {
      canvas.drawPath(
        starPath(Offset(spacing * i, -h + ch * 0.5), ch * 0.3),
        _starFill,
      );
    }
  }
}

/// A five-pointed star around [center] with outer radius [radius].
Path starPath(Offset center, double radius) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? radius : radius * 0.45;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}
