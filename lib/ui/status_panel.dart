import 'package:flutter/material.dart';

import '../game/damage.dart';
import 'crt.dart';

/// A small retro "robot status" screen: a green CRT-style panel with a robot
/// figure lit per part by its health, and a list of HP bars.
///
/// [partHp] gives each part's remaining HP from 1 (full) to 0 (gone);
/// missing parts count as full.
class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key, required this.partHp});

  final Map<RobotSlot, double> partHp;

  static const Size size = Size(236, 132);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _StatusPainter(partHp),
      // Accessible summary of the same information.
      child: Semantics(
        label: [
          for (final slot in RobotSlot.values)
            '${slot.label} ${((partHp[slot] ?? 1) * 100).round()}%',
        ].join(', '),
        child: SizedBox.fromSize(size: size),
      ),
    );
  }
}

class _StatusPainter extends CustomPainter {
  _StatusPainter(this.partHp);

  final Map<RobotSlot, double> partHp;

  // CRT greens, plus warning colours for damaged parts.
  static const _background = Crt.background;
  static const _green = Crt.green;
  static const _dim = Crt.dim;
  static const _amber = Crt.amber;
  static const _red = Crt.red;

  double _hp(RobotSlot slot) => (partHp[slot] ?? 1).clamp(0.0, 1.0);

  /// Green when healthy, amber when worn, red when about to break, dark
  /// green when gone.
  static Color colorFor(double hp) {
    if (hp <= 0) {
      return _dim;
    }
    if (hp > 0.5) {
      return _green;
    }
    return hp > 0.25 ? _amber : _red;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas
      ..drawRRect(panel, Paint()..color = _background)
      ..save()
      ..clipRRect(panel);

    _paintFigure(canvas);
    _paintBars(canvas);

    // Scanlines for the old-screen look.
    final scan = Paint()..color = const Color(0x1A5CFF9A);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
    canvas
      ..restore()
      ..drawRRect(
        panel,
        Paint()
          ..color = _green.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  /// The robot figure, facing you. Its left side is on the left.
  void _paintFigure(Canvas canvas) {
    const parts = {
      RobotSlot.head: Rect.fromLTWH(34, 8, 28, 22),
      RobotSlot.body: Rect.fromLTWH(30, 34, 36, 44),
      RobotSlot.leftArm: Rect.fromLTWH(15, 36, 11, 42),
      RobotSlot.rightArm: Rect.fromLTWH(70, 36, 11, 42),
      RobotSlot.leftLeg: Rect.fromLTWH(33, 82, 12, 40),
      RobotSlot.rightLeg: Rect.fromLTWH(51, 82, 12, 40),
    };
    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    parts.forEach((slot, rect) {
      final hp = _hp(slot);
      final color = colorFor(hp);
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      // Brighter fill the healthier the part.
      fill.color = color.withValues(alpha: hp <= 0 ? 0.0 : 0.2 + 0.6 * hp);
      edge.color = color;
      canvas
        ..drawRRect(shape, fill)
        ..drawRRect(shape, edge);
      if (hp <= 0) {
        // A cross through parts that are gone.
        canvas
          ..drawLine(rect.topLeft, rect.bottomRight, edge)
          ..drawLine(rect.topRight, rect.bottomLeft, edge);
      }
    });
    // The head's eye, for a bit of character.
    if (_hp(RobotSlot.head) > 0) {
      canvas.drawCircle(
        const Offset(54, 19),
        4,
        Paint()..color = const Color(0xFF0B1A10),
      );
    }
  }

  /// One row per part: label, HP bar and percentage.
  void _paintBars(Canvas canvas) {
    const left = 98.0;
    const top = 9.0;
    const rowHeight = 19.0;
    const barWidth = 66.0;
    final barBack = Paint()..color = _dim;
    final barFill = Paint();
    for (var i = 0; i < destructionOrder.length; i++) {
      final slot = destructionOrder[i];
      final hp = _hp(slot);
      final color = colorFor(hp);
      final y = top + i * rowHeight;
      _text(canvas, slot.label, Offset(left, y), color);
      final bar = Rect.fromLTWH(left + 42, y + 3, barWidth, 7);
      barFill.color = color;
      canvas
        ..drawRect(bar, barBack)
        ..drawRect(
          Rect.fromLTWH(bar.left, bar.top, bar.width * hp, bar.height),
          barFill,
        );
      _text(
        canvas,
        hp <= 0 ? '--' : '${(hp * 100).round()}',
        Offset(bar.right + 5, y),
        color,
      );
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color) {
    TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontFamily: 'Menlo',
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, at);
  }

  @override
  bool shouldRepaint(_StatusPainter oldDelegate) =>
      oldDelegate.partHp != partHp;
}
