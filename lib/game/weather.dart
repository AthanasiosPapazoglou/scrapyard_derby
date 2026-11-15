import 'dart:math' as math;
import 'dart:ui';

import 'palette.dart';

/// Draws a level's [Weather] over the sky, in screen pixels. Every particle
/// is placed by a formula of its index, the time and the scroll, so there
/// is nothing to store or update: the same inputs always draw the same
/// picture. Decoration only.
class WeatherPainter {
  final Paint _paint = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _smog = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

  static const Color _ember = Color(0xFFFF9A3C);
  static const Color _ash = Color(0xFFA09692);
  static const Color _rain = Color(0x66B4C0CB);
  static const Color _smogColor = Color(0xFF8FBF6A);
  static const Color _crimson = Color(0xFFFF2E4A);

  /// Lightning: seconds between strikes, and how long a flash lasts.
  static const double _strikeEvery = 5.5;
  static const double _flashTime = 0.18;

  void paint(
    Canvas canvas,
    Size size,
    Weather weather, {
    required double scroll,
    required double time,
  }) {
    switch (weather) {
      case Weather.none:
        return;
      case Weather.embers:
        _embers(canvas, size, scroll, time, count: 36, color: _ember);
      case Weather.smog:
        _smogBanks(canvas, size, scroll, time);
      case Weather.storm:
        _storm(canvas, size, scroll, time);
      case Weather.ash:
        _ashFall(canvas, size, scroll, time);
        _embers(canvas, size, scroll, time, count: 18, color: _ember);
      case Weather.crimsonSparks:
        _sparks(canvas, size, scroll, time);
    }
  }

  /// Small glowing dots rising and swaying, flickering.
  void _embers(
    Canvas canvas,
    Size size,
    double scroll,
    double time, {
    required int count,
    required Color color,
  }) {
    for (var i = 0; i < count; i++) {
      final rise = 20 + 40 * _hash(i, 3);
      final x =
          _wrap(_hash(i, 1) * size.width - scroll * 1.5, size.width) +
          8 * math.sin(time * 1.3 + i);
      final y = _wrap(_hash(i, 2) * size.height - rise * time, size.height);
      final flicker = 0.5 + 0.5 * math.sin(time * 6 + i * 1.7);
      final r = 1.2 + 2 * _hash(i, 4);
      _paint.color = color.withValues(alpha: 0.18 * flicker);
      canvas.drawCircle(Offset(x, y), r * 3, _paint);
      _paint.color = color.withValues(alpha: 0.5 + 0.5 * flicker);
      canvas.drawCircle(Offset(x, y), r, _paint);
    }
  }

  /// A few big, soft, slow banks of green smog.
  void _smogBanks(Canvas canvas, Size size, double scroll, double time) {
    for (var i = 0; i < 7; i++) {
      final w = size.width * (0.35 + 0.3 * _hash(i, 1));
      final h = size.height * (0.08 + 0.06 * _hash(i, 2));
      final span = size.width + w;
      final x =
          _wrap(
            _hash(i, 3) * span + (10 + 12 * _hash(i, 4)) * time - scroll,
            span,
          ) -
          w / 2;
      final y = size.height * (0.32 + 0.4 * _hash(i, 5));
      _smog.color = _smogColor.withValues(alpha: 0.10 + 0.07 * _hash(i, 6));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        _smog,
      );
    }
  }

  /// Slanted rain, and every few seconds a lightning bolt with a flash.
  void _storm(Canvas canvas, Size size, double scroll, double time) {
    _line
      ..color = _rain
      ..strokeWidth = 1.5;
    const slant = Offset(-0.28, 1);
    for (var i = 0; i < 90; i++) {
      final fall = 900 + 300 * _hash(i, 3);
      final y = _wrap(_hash(i, 2) * size.height + fall * time, size.height);
      final x = _wrap(
        _hash(i, 1) * size.width - scroll * 3 + slant.dx * fall * time,
        size.width,
      );
      final start = Offset(x, y);
      canvas.drawLine(start, start + slant * 18, _line);
    }

    final strike = (time / _strikeEvery).floor();
    final phase = time - strike * _strikeEvery;
    if (time <= 0 || phase > _flashTime) {
      return;
    }
    final fade = 1 - phase / _flashTime;
    _paint.color = const Color(0xFFFFF2E8).withValues(alpha: 0.3 * fade);
    canvas.drawRect(Offset.zero & size, _paint);
    // A jagged bolt from the top of the sky down to the heaps.
    final bolt = Path();
    var x = size.width * (0.15 + 0.7 * _hash(strike, 7));
    var y = 0.0;
    bolt.moveTo(x, y);
    final step = size.height * 0.07;
    for (var k = 0; k < 9; k++) {
      x += (_hash(strike * 13 + k, 8) - 0.5) * step * 1.6;
      y += step;
      bolt.lineTo(x, y);
    }
    _line
      ..color = const Color(0xFFFFF6EE).withValues(alpha: fade)
      ..strokeWidth = 3;
    canvas.drawPath(bolt, _line);
  }

  /// Grey flakes drifting down slowly.
  void _ashFall(Canvas canvas, Size size, double scroll, double time) {
    for (var i = 0; i < 50; i++) {
      final fall = 25 + 30 * _hash(i, 3);
      final x =
          _wrap(
            _hash(i, 1) * size.width - scroll * 1.5 - 15 * time,
            size.width,
          ) +
          10 * math.sin(time * 0.9 + i);
      final y = _wrap(_hash(i, 2) * size.height + fall * time, size.height);
      _paint.color = _ash.withValues(alpha: 0.35 + 0.35 * _hash(i, 4));
      canvas.drawCircle(Offset(x, y), 1.2 + 1.8 * _hash(i, 5), _paint);
    }
  }

  /// Short crimson streaks shooting upward, flickering.
  void _sparks(Canvas canvas, Size size, double scroll, double time) {
    _line.strokeWidth = 2;
    for (var i = 0; i < 40; i++) {
      final rise = 60 + 90 * _hash(i, 3);
      final x = _wrap(_hash(i, 1) * size.width - scroll * 1.5, size.width);
      final y = _wrap(_hash(i, 2) * size.height - rise * time, size.height);
      final flicker = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(time * 9 + i * 2.3));
      _line.color = _crimson.withValues(alpha: flicker);
      canvas.drawLine(Offset(x, y), Offset(x, y + 7), _line);
    }
  }

  /// [value] wrapped into 0..[range].
  static double _wrap(double value, double range) {
    final v = value % range;
    return v < 0 ? v + range : v;
  }

  /// A stable pseudo-random number in 0..1 for particle [i].
  static double _hash(int i, int salt) {
    final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }
}
