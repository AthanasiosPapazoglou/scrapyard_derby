import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/tuning.dart';
import 'autopilot.dart';
import 'derby_game.dart';
import 'landing.dart';
import 'palette.dart';

/// The Landing Sight gadget: how the robot will touch down if the player
/// keeps doing what they do now (holding or not). Green = clean, amber =
/// one foot, red = crash. Shown only in the last
/// [RobotStats.landingSightTime] seconds.
///
/// Two parts: a gauge next to the robot (always on screen: a dim line for
/// the ground's slope at touchdown and a coloured stick for the robot's
/// "up" then), and a marker on the ground at the touchdown point.
class LandingSight extends Component with HasGameReference<DerbyGame> {
  LandingSight() : super(priority: 6);

  LandingPrediction? _prediction;
  LandingType _type = LandingType.clean;
  double _slope = 0;
  Offset _robotAt = Offset.zero;

  static const double _feetLength = 1.5;
  static const double _stickLength = 1.3;

  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.2
    ..strokeCap = StrokeCap.round;
  final Paint _ink = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.36
    ..strokeCap = StrokeCap.round;

  @override
  void update(double dt) {
    super.update(dt);
    _prediction = null;
    final robot = game.robot;
    final stats = robot.stats;
    if (stats.landingSightTime <= 0 ||
        !robot.isLoaded ||
        !robot.hasTouchedDown ||
        robot.headLaunched ||
        robot.isOnGround ||
        game.hud.value.result != null) {
      return;
    }
    final prediction = predictLanding(
      robot.flightState,
      game.hillGeometry,
      holding: robot.holding,
      stats: stats,
    );
    if (prediction == null || prediction.time > stats.landingSightTime) {
      return;
    }
    _prediction = prediction;
    _slope = game.hillGeometry.slopeAngleAt(prediction.groundPoint.x);
    _robotAt = Offset(robot.position.x, robot.position.y);
    // Judged like a feet-first landing (a foot touches first when it is
    // close to upright; otherwise it is a crash anyway).
    _type = classifyLanding(PartKind.leg, prediction.error, stats: stats);
  }

  @override
  void render(Canvas canvas) {
    final p = _prediction;
    if (p == null) {
      return;
    }
    _line.color = switch (_type) {
      LandingType.clean => Palette.eyeGlow,
      LandingType.oneFoot => Palette.hazard,
      LandingType.crash => Palette.danger,
    };
    _renderGauge(canvas, p);
    // Ground marker: thin lines, the same size at any zoom.
    final scale = game.visibleWidth / Tuning.cameraBaseWidth;
    _line.strokeWidth = 0.2 * scale;
    _ink.strokeWidth = 0.36 * scale;
    // The robot's feet line and "up" stick at touchdown (y points down,
    // angles are clockwise).
    final a = p.angle;
    final along = Offset(math.cos(a), math.sin(a));
    final up = Offset(math.sin(a), -math.cos(a));
    final base = Offset(p.groundPoint.x, p.groundPoint.y) + up * 0.15 * scale;
    final feetA = base - along * (_feetLength / 2 * scale);
    final feetB = base + along * (_feetLength / 2 * scale);
    final top = base + up * _stickLength * scale;
    for (final paint in [_ink, _line]) {
      canvas
        ..drawLine(feetA, feetB, paint)
        ..drawLine(base, top, paint);
    }
    canvas.drawCircle(top, 0.22 * scale, Paint()..color = _line.color);
  }

  final Paint _gaugeFill = Paint()
    ..color = Palette.outline.withValues(alpha: 0.55);
  final Paint _gaugeGround = Paint()
    ..color = Palette.cream.withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// A round gauge ahead of the robot (clear of the HUD and the hill): the ground slope at touchdown
  /// and the robot's up stick at touchdown, sized to stay readable at any
  /// zoom.
  void _renderGauge(Canvas canvas, LandingPrediction p) {
    // Sized by the screen's long side, so it is as big on a portrait
    // screen (narrow view) as in landscape.
    final screen = game.size;
    final longShare = math.max(screen.x, screen.y) / screen.x;
    final r = Tuning.landingSightGaugeSize * game.visibleWidth * longShare;
    final center = _robotAt + Offset(r * 3, r * 1.5);
    final groundDir = Offset(math.cos(_slope), math.sin(_slope));
    final up = Offset(math.sin(p.angle), -math.cos(p.angle));
    _gaugeGround.strokeWidth = r * 0.12;
    _line.strokeWidth = r * 0.2;
    _ink.strokeWidth = r * 0.34;
    canvas
      ..drawCircle(center, r, _gaugeFill)
      ..drawLine(center - groundDir * r, center + groundDir * r, _gaugeGround);
    for (final paint in [_ink, _line]) {
      canvas.drawLine(center, center + up * (r * 0.85), paint);
    }
    canvas.drawCircle(center, r * 0.14, Paint()..color = _line.color);
  }
}
