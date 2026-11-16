import 'package:flutter/material.dart';

import '../game/palette.dart';

/// A bolted steel plate: dark steel with an ink outline, a lighter bevel
/// and a rivet in each corner. Wraps [child] with [padding].
class RivetedPlate extends StatelessWidget {
  const RivetedPlate({
    super.key,
    required this.child,
    this.color = Palette.steel,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlatePainter(color: color, radius: radius),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final plate = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas
      ..drawRRect(plate, Paint()..color = color)
      // Bevel: a lighter band along the top.
      ..save()
      ..clipRRect(plate)
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, 5),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      )
      ..restore()
      ..drawRRect(
        plate,
        Paint()
          ..color = Palette.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    const inset = 9.0;
    for (final c in [
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      canvas
        ..drawCircle(c, 4, Paint()..color = Palette.steelLight)
        ..drawCircle(
          c,
          4,
          Paint()
            ..color = Palette.outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        )
        ..drawCircle(
          c + const Offset(-1, -1),
          1.2,
          Paint()..color = Colors.white.withValues(alpha: 0.6),
        );
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.color != color || old.radius != radius;
}

/// Diagonal black-and-yellow hazard stripes filling the area.
class HazardStripesPainter extends CustomPainter {
  const HazardStripesPainter({
    this.stripe = Palette.outline,
    this.background = Palette.hazard,
    this.width = 14,
  });

  final Color stripe;
  final Color background;

  /// Width of one stripe (the gap is the same).
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()..color = stripe;
    final h = size.height;
    for (var x = -h; x < size.width + h; x += width * 2) {
      canvas.drawPath(
        Path()
          ..moveTo(x, h)
          ..lineTo(x + width, h)
          ..lineTo(x + width + h, 0)
          ..lineTo(x + h, 0)
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HazardStripesPainter old) =>
      old.stripe != stripe ||
      old.background != background ||
      old.width != width;
}
