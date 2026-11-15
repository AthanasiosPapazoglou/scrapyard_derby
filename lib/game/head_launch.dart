import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

import '../config/tuning.dart';

/// The velocity the head is fired with, like a rocket, when the robot
/// (down to just its torso and head) lands.
///
/// - Direction: where the robot is facing ([facing], the torso's "up"),
///   bent strongly away from the ground ([Tuning.headLaunchUpBias]) so it
///   always shoots up and never into the slope.
/// - Power: grows with the robot's [speed], and is strongest when the
///   robot lands upright (facing along [groundNormal]).
///
/// [groundNormal] must be a unit vector pointing away from the ground.
Vector2 headLaunchVelocity({
  required Vector2 facing,
  required Vector2 groundNormal,
  required double speed,
}) {
  var direction = facing.normalized() + groundNormal * Tuning.headLaunchUpBias;
  if (direction.length2 < 1e-6) {
    direction = groundNormal.clone();
  }
  direction.normalize();

  // 1 when landing upright, 0 when sideways or upside down.
  final alignment = math.max(0.0, facing.normalized().dot(groundNormal));
  final anglePower =
      Tuning.headLaunchMinAngleFactor +
      (1 - Tuning.headLaunchMinAngleFactor) * alignment;
  final power =
      ((Tuning.headLaunchBaseSpeed + speed * Tuning.headLaunchSpeedFactor) *
              anglePower)
          .clamp(0.0, Tuning.headLaunchMaxSpeed);
  return direction * power;
}
