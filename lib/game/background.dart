import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/tuning.dart';
import 'derby_game.dart';
import 'palette.dart';

/// The sky and the distant scrap heaps behind the hill.
///
/// Drawn in screen pixels (it sits in the camera's backdrop, behind the
/// world). Each heap layer scrolls sideways at a fraction of the camera's
/// movement ([Tuning.parallaxFactors]): far layers barely move, near ones
/// move more, which gives a sense of depth and speed.
class Background extends Component with HasGameReference<DerbyGame> {
  /// Screen pixels each layer moves per meter the camera moves, before the
  /// layer's parallax factor.
  static const double _pixelsPerMeter = 60;

  final Paint _skyPaint = Paint();
  final Paint _layerPaint = Paint();
  final Path _path = Path();
  Size _skySize = Size.zero;

  /// Layer colours, far to near: hazy and close to the sky far away,
  /// darker steel up close.
  static final List<Color> _layerColors = [
    Color.lerp(Palette.skyHorizon, Palette.steelLight, 0.45)!,
    Color.lerp(Palette.skyHorizon, Palette.steel, 0.45)!,
    Color.lerp(Palette.skyHorizon, Palette.steelDark, 0.55)!,
  ];

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0) {
      return;
    }
    _renderSky(canvas, size);
    final cameraX = game.camera.viewfinder.position.x;
    for (var i = 0; i < Tuning.parallaxFactors.length; i++) {
      _renderHeaps(
        canvas,
        size,
        layer: i,
        scroll: cameraX * Tuning.parallaxFactors[i] * _pixelsPerMeter,
      );
    }
  }

  void _renderSky(Canvas canvas, Vector2 size) {
    final skySize = Size(size.x, size.y);
    if (skySize != _skySize) {
      _skySize = skySize;
      _skyPaint.shader = Gradient.linear(
        Offset.zero,
        Offset(0, size.y * Tuning.horizonHeight),
        [Palette.skyTop, Palette.skyHorizon],
      );
    }
    canvas.drawRect(Offset.zero & skySize, _skyPaint);
  }

  /// One row of jagged scrap heaps along the horizon.
  void _renderHeaps(
    Canvas canvas,
    Vector2 size, {
    required int layer,
    required double scroll,
  }) {
    // Nearer layers: bigger heaps, sitting a little lower on screen.
    final scale = 1.0 + layer * 0.6;
    final cellWidth = 170.0 * scale;
    final baseY = size.y * Tuning.horizonHeight + layer * size.y * 0.06;
    final maxHeight = size.y * 0.10 * scale;

    _layerPaint.color = _layerColors[layer % _layerColors.length];
    _path
      ..reset()
      ..moveTo(0, size.y);

    // Which heap cells are on screen.
    final firstCell = ((scroll - cellWidth) / cellWidth).floor();
    final lastCell = ((scroll + size.x + cellWidth) / cellWidth).ceil();
    for (var cell = firstCell; cell <= lastCell; cell++) {
      final left = cell * cellWidth - scroll;
      final peak = maxHeight * (0.4 + 0.6 * _random(cell, layer));
      final peakAt = 0.3 + 0.4 * _random(cell, layer + 10);
      final peakX = left + cellWidth * peakAt;
      final peakY = baseY - peak;
      // A lumpy heap: rise, a few jagged bumps, the peak...
      _path
        ..lineTo(left, baseY)
        ..lineTo(left + cellWidth * 0.15, baseY - peak * 0.45)
        ..lineTo(left + cellWidth * 0.22, baseY - peak * 0.38)
        ..lineTo(peakX, peakY);
      // ...now and then a girder sticking up out of it...
      if (_random(cell, layer + 20) > 0.7) {
        final girderTop = peakY - peak * 0.7;
        _path
          ..lineTo(peakX + 2 * scale, girderTop)
          ..lineTo(peakX + 7 * scale, girderTop)
          ..lineTo(peakX + 9 * scale, peakY + 3);
      }
      // ...then down the other side.
      _path
        ..lineTo(left + cellWidth * (peakAt + 0.08), baseY - peak * 0.86)
        ..lineTo(left + cellWidth * 0.8, baseY - peak * 0.5)
        ..lineTo(left + cellWidth, baseY);
    }
    _path
      ..lineTo(size.x, size.y)
      ..close();
    canvas.drawPath(_path, _layerPaint);
  }

  /// A stable pseudo-random number in 0..1 for a heap cell, so heaps look
  /// random but don't change between frames.
  static double _random(int cell, int salt) {
    final v = math.sin(cell * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }
}
