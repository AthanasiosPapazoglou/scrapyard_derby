import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

import '../config/tuning.dart';
import 'hill.dart';
import 'palette.dart';

/// The kinds of junk lying on the slope (decoration only, no physics).
enum PropKind { tire, barrel, girder, plate }

/// One prop: what it is, where it sits on the ground, and how it's turned.
class PropPlacement {
  const PropPlacement(this.kind, this.position, this.angle, this.size);

  final PropKind kind;

  /// Point on the ground surface the prop rests on (meters).
  final Vector2 position;

  /// Rotation in radians (the slope angle plus a little random tilt).
  final double angle;

  /// Size multiplier (about 0.8 - 1.3).
  final double size;
}

/// The props for one hill chunk.
///
/// Seeded by the chunk index, so the same chunk always gets the same props
/// (they don't change when a chunk is rebuilt).
List<PropPlacement> propsForChunk(HillGeometry hill, int chunkIndex) {
  final random = math.Random(chunkIndex * 7919 + 13);
  final start = HillGeometry.chunkStartX(chunkIndex);
  final end = start + Tuning.hillChunkLength;
  final props = <PropPlacement>[];
  // Leave the start of the hill clear, where the robot is dropped.
  var x = math.max(start, 20.0) + random.nextDouble() * Tuning.propSpacing;
  while (x < end) {
    final kind = PropKind.values[random.nextInt(PropKind.values.length)];
    final tilt = (random.nextDouble() - 0.5) * 0.6;
    props.add(
      PropPlacement(
        kind,
        Vector2(x, hill.heightAt(x)),
        hill.slopeAngleAt(x) + tilt,
        0.8 + random.nextDouble() * 0.5,
      ),
    );
    x += Tuning.propSpacing * (0.5 + random.nextDouble());
  }
  return props;
}

/// Draws scrap props in the cutout style: flat fills, thick dark outline.
class PropPainter {
  final Paint _fill = Paint();
  final Paint _outline = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.08
    ..strokeJoin = StrokeJoin.round;

  void paint(Canvas canvas, PropPlacement prop) {
    canvas
      ..save()
      ..translate(prop.position.x, prop.position.y)
      ..rotate(prop.angle)
      ..scale(prop.size);
    switch (prop.kind) {
      case PropKind.tire:
        // Half sunk into the ground.
        _shape(
          canvas,
          Path()..addOval(
            Rect.fromCircle(center: const Offset(0, -0.25), radius: 0.5),
          ),
          Palette.outline,
        );
        _shape(
          canvas,
          Path()..addOval(
            Rect.fromCircle(center: const Offset(0, -0.25), radius: 0.2),
          ),
          Palette.steelDark,
        );
      case PropKind.barrel:
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-0.35, -1.0, 0.7, 1.05),
          const Radius.circular(0.08),
        );
        _shape(canvas, Path()..addRRect(body), Palette.hazard);
        _fill.color = Palette.hazardShadow;
        canvas
          ..drawRect(const Rect.fromLTWH(-0.35, -0.8, 0.7, 0.1), _fill)
          ..drawRect(const Rect.fromLTWH(-0.35, -0.35, 0.7, 0.1), _fill)
          ..drawRRect(body, _outline);
      case PropKind.girder:
        final beam = Path()
          ..addRect(const Rect.fromLTWH(-1.2, -0.35, 2.4, 0.3));
        _shape(canvas, beam, Palette.rust);
        _fill.color = Palette.outline;
        for (var i = 0; i < 4; i++) {
          canvas.drawCircle(Offset(-0.9 + i * 0.6, -0.2), 0.06, _fill);
        }
      case PropKind.plate:
        final plate = Path()
          ..moveTo(-0.6, 0.05)
          ..lineTo(-0.45, -0.55)
          ..lineTo(0.5, -0.45)
          ..lineTo(0.6, 0.05)
          ..close();
        _shape(canvas, plate, Palette.steelLight);
    }
    canvas.restore();
  }

  void _shape(Canvas canvas, Path path, Color color) {
    _fill.color = color;
    canvas
      ..drawPath(path, _fill)
      ..drawPath(path, _outline);
  }
}
