import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/widgets.dart';

import '../game/robot.dart';
import '../game/robot_sprites.dart';

/// Paints the whole robot from its part sprites, posed like in the game
/// (same joint pivots), for menus. No physics.
class RobotFigurePainter extends CustomPainter {
  RobotFigurePainter({
    required this.look,
    required this.angle,
    this.armSwing = 0,
    this.legSwing = 0,
    this.metersTall = 4.2,
  });

  final RobotLook look;

  /// Rotation of the whole robot (radians, clockwise).
  final double angle;

  /// Extra joint angles (radians) for a little idle motion.
  final double armSwing;
  final double legSwing;

  /// How many meters of robot fit in the painter's height.
  final double metersTall;

  @override
  void paint(Canvas canvas, Size size) {
    final pixelsPerMeter = size.height / metersTall;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(pixelsPerMeter)
      ..rotate(angle);
    // Same draw order as the game: back arm, legs, torso, head, front arm.
    _part(canvas, look.arm, Robot.leftShoulderPivot, -armSwing);
    _part(canvas, look.leg, Robot.leftHipPivot, legSwing);
    _part(canvas, look.leg, Robot.rightHipPivot, -legSwing);
    look.torso.render(canvas);
    look.core.render(canvas);
    _part(canvas, look.head, Robot.neckPivot, 0);
    _part(canvas, look.arm, Robot.rightShoulderPivot, armSwing);
    canvas.restore();
  }

  void _part(Canvas canvas, PartSprite sprite, Vector2 pivot, double turn) {
    canvas
      ..save()
      ..translate(pivot.x, pivot.y)
      ..rotate(turn);
    sprite.render(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RobotFigurePainter old) =>
      old.angle != angle ||
      old.armSwing != armSwing ||
      old.legSwing != legSwing ||
      old.look != look;
}

/// The robot slowly spinning and bobbing in the air, like at the top of a
/// floaty jump. [time] is seconds since the menu opened.
class IdleRobot extends StatelessWidget {
  const IdleRobot({super.key, required this.look, required this.time});

  final RobotLook look;
  final double time;

  /// Seconds per full idle turn.
  static const double turnTime = 7;

  @override
  Widget build(BuildContext context) {
    final bob = math.sin(time * 1.3) * 0.06;
    return FractionalTranslation(
      translation: Offset(0, bob),
      // A CustomPaint without a child is zero-sized; fill the space.
      child: CustomPaint(
        size: Size.infinite,
        painter: RobotFigurePainter(
          look: look,
          angle: time / turnTime * 2 * math.pi,
          armSwing: math.sin(time * 1.7) * 0.35,
          legSwing: math.sin(time * 1.7 + 1) * 0.2,
        ),
      ),
    );
  }
}
