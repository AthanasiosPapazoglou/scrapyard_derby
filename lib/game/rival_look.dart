import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../config/tuning.dart';
import 'palette.dart';
import 'robot.dart';

/// How a Versus rival robot looks: its name and paint colour.
class RivalLook {
  const RivalLook({required this.name, required this.color});

  final String name;
  final Color color;

  /// Paint for drawing a rival part's art into a layer: see-through
  /// ([Tuning.rivalOpacity]), darkened ([Tuning.rivalDarken]) and washed
  /// with the rival's colour ([Tuning.rivalTint]), times [opacity]
  /// (debris fading out).
  Paint layerPaint({double opacity = 1}) => Paint()
    ..color = Palette.outline.withValues(alpha: Tuning.rivalOpacity * opacity)
    ..colorFilter = ColorFilter.matrix(tintMatrix);

  /// Colour matrix: each channel becomes
  /// `art × darken × (1 - tint) + rivalColour × tint`; alpha unchanged.
  List<double> get tintMatrix {
    const t = Tuning.rivalTint;
    const k = Tuning.rivalDarken * (1 - t);
    return [
      k, 0, 0, 0, color.r * 255 * t, //
      0, k, 0, 0, color.g * 255 * t, //
      0, 0, k, 0, color.b * 255 * t, //
      0, 0, 0, 1, 0,
    ];
  }
}

/// A small name tag in the rival's colour, floating above its robot (or
/// its launched head).
class RivalTag extends Component {
  RivalTag(this.robot, this.look) : super(priority: 10);

  final Robot robot;
  final RivalLook look;

  /// Text is laid out at this size, then scaled down to meters.
  static const double _layoutSize = 40;

  late final TextPainter _text = TextPainter(
    text: TextSpan(
      text: look.name.toUpperCase(),
      style: const TextStyle(
        color: Palette.cream,
        fontSize: _layoutSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  late final Paint _pill = Paint()
    ..color = look.color.withValues(alpha: Tuning.rivalOpacity);
  final Paint _edge = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  @override
  void render(Canvas canvas) {
    if (!robot.isLoaded) {
      return;
    }
    final center = robot.drawCenter;
    final scale = Tuning.rivalTagTextSize / _layoutSize;
    final pad = _layoutSize * 0.35;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _text.width + pad * 2,
      height: _text.height + pad * 0.6,
    );
    final pill = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    canvas
      ..save()
      ..translate(center.x, center.y - Tuning.rivalTagHeight * robot.drawScale)
      ..scale(scale)
      ..drawRRect(pill, _pill)
      ..drawRRect(pill, _edge);
    _text.paint(canvas, Offset(-_text.width / 2, -_text.height / 2));
    canvas.restore();
  }
}
