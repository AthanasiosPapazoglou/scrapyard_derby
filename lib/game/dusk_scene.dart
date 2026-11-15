import 'dart:math' as math;
import 'dart:ui';

import '../config/tuning.dart';
import 'palette.dart';

/// The dusk sky and the distant scrap heaps, in the look of the style test
/// scene (art/make_style_test.py). Plain `dart:ui` drawing, so both the
/// game ([Background]) and Flutter widgets (the main menu) can use it.
///
/// Drawn in screen pixels. Each heap layer scrolls sideways at a fraction
/// of the camera's movement ([Tuning.parallaxFactors]): far layers barely
/// move, near ones move more, which gives a sense of depth and speed.
class DuskScene {
  /// Screen pixels each layer moves per meter the camera moves, before the
  /// layer's parallax factor.
  static const double _pixelsPerMeter = 60;

  final Paint _skyPaint = Paint();
  final Paint _sunPaint = Paint()..color = Palette.sun.withValues(alpha: 0.9);
  final Paint _fill = Paint();
  final Path _path = Path();
  Size _skySize = Size.zero;

  /// Heap colours, far to near: the far heaps are lighter (hazier).
  static final List<Color> _layerColors = [
    Palette.heapFar,
    Color.lerp(Palette.heapFar, Palette.heapNear, 0.5)!,
    Palette.heapNear,
  ];

  /// Paints the scene over [size] (screen pixels). [cameraX] is the
  /// camera's world x in meters; it drives the parallax scroll.
  void paint(Canvas canvas, Size size, {required double cameraX}) {
    if (size.width <= 0) {
      return;
    }
    _renderSky(canvas, size);
    for (var i = 0; i < Tuning.parallaxFactors.length; i++) {
      _renderHeaps(
        canvas,
        size,
        layer: i,
        scroll: cameraX * Tuning.parallaxFactors[i] * _pixelsPerMeter,
      );
    }
  }

  void _renderSky(Canvas canvas, Size size) {
    final skySize = size;
    final horizonY = size.height * Tuning.horizonHeight;
    if (skySize != _skySize) {
      _skySize = skySize;
      _skyPaint.shader = Gradient.linear(
        Offset.zero,
        Offset(0, horizonY),
        [Palette.skyTop, Palette.skyMid, Palette.skyHorizon],
        [0, 0.55, 1],
      );
    }
    canvas
      ..drawRect(Offset.zero & skySize, _skyPaint)
      // A big low sun, partly behind the heaps.
      ..drawCircle(
        Offset(size.width * 0.72, horizonY - size.height * 0.04),
        size.height * 0.16,
        _sunPaint,
      );
  }

  /// One row of jagged scrap heaps along the horizon, with junk on top.
  void _renderHeaps(
    Canvas canvas,
    Size size, {
    required int layer,
    required double scroll,
  }) {
    // Nearer layers: bigger heaps, sitting a little lower on screen.
    final scale = 1.0 + layer * 0.6;
    final cellWidth = 170.0 * scale;
    final baseY =
        size.height * Tuning.horizonHeight + layer * size.height * 0.06;
    final maxHeight = size.height * 0.10 * scale;
    final color = _layerColors[layer % _layerColors.length];

    _fill.color = color;
    _path
      ..reset()
      ..moveTo(0, size.height);

    // Which heap cells are on screen.
    final firstCell = ((scroll - cellWidth) / cellWidth).floor();
    final lastCell = ((scroll + size.width + cellWidth) / cellWidth).ceil();
    final junk = <_Junk>[];
    for (var cell = firstCell; cell <= lastCell; cell++) {
      final left = cell * cellWidth - scroll;
      final peak = maxHeight * (0.4 + 0.6 * _random(cell, layer));
      final peakAt = 0.3 + 0.4 * _random(cell, layer + 10);
      final peakX = left + cellWidth * peakAt;
      final peakY = baseY - peak;
      // A lumpy heap: rise, a few jagged bumps, the peak, down again.
      _path
        ..lineTo(left, baseY)
        ..lineTo(left + cellWidth * 0.15, baseY - peak * 0.45)
        ..lineTo(left + cellWidth * 0.22, baseY - peak * 0.38)
        ..lineTo(peakX, peakY)
        ..lineTo(left + cellWidth * (peakAt + 0.08), baseY - peak * 0.86)
        ..lineTo(left + cellWidth * 0.8, baseY - peak * 0.5)
        ..lineTo(left + cellWidth, baseY);
      // Some junk on top of the heap.
      final roll = _random(cell, layer + 20);
      if (roll > 0.35) {
        junk.add(
          _Junk(
            kind: roll > 0.8 ? 2 : (roll > 0.6 ? 1 : 0),
            x: peakX,
            y: peakY,
            size: maxHeight * 0.28,
            tilt: (_random(cell, layer + 30) - 0.5) * 0.8,
          ),
        );
      }
    }
    _path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(_path, _fill);

    for (final j in junk) {
      _renderJunk(canvas, j, color, layer == 0);
    }
  }

  /// A tire, car body or girder sticking out of a heap, as a silhouette.
  void _renderJunk(Canvas canvas, _Junk j, Color color, bool far) {
    _fill.color = color;
    canvas
      ..save()
      ..translate(j.x, j.y)
      ..rotate(j.tilt);
    switch (j.kind) {
      case 0: // tire
        canvas.drawCircle(Offset(0, -j.size * 0.6), j.size, _fill);
        if (far) {
          // The far layer shows the lighter hub, like the style test.
          _fill.color = Palette.heapFarLight;
          canvas.drawCircle(Offset(0, -j.size * 0.6), j.size * 0.42, _fill);
        }
      case 1: // car body, half sunk into the heap
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              -j.size * 1.4,
              -j.size * 0.6,
              j.size * 2.8,
              j.size * 1.4,
            ),
            Radius.circular(j.size * 0.25),
          ),
          _fill,
        );
      default: // girder poking up
        canvas.drawPath(
          Path()
            ..moveTo(-j.size * 0.15, j.size * 0.2)
            ..lineTo(j.size * 0.5, -j.size * 2.4)
            ..lineTo(j.size * 0.8, -j.size * 2.3)
            ..lineTo(j.size * 0.2, j.size * 0.3)
            ..close(),
          _fill,
        );
    }
    canvas.restore();
  }

  /// A stable pseudo-random number in 0..1 for a heap cell, so heaps look
  /// random but don't change between frames.
  static double _random(int cell, int salt) {
    final v = math.sin(cell * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }
}

/// One piece of junk on a background heap.
class _Junk {
  const _Junk({
    required this.kind,
    required this.x,
    required this.y,
    required this.size,
    required this.tilt,
  });

  /// 0 = tire, 1 = car body, 2 = girder.
  final int kind;
  final double x;
  final double y;
  final double size;
  final double tilt;
}
