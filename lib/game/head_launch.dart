import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

import '../config/tuning.dart';
import 'robot_stats.dart';

/// The velocity the head is fired with, like a rocket, when the robot
/// (down to just its torso and head) lands.
///
/// - Momentum: the head keeps the robot's [carried] velocity (from just
///   before the landing), minus the part going into the ground, times
///   [Tuning.headLaunchCarry]. A robot racing downhill launches its head
///   onward, downhill, instead of stopping dead.
/// - Rocket kick: on top, a push along where the robot is facing, bent
///   away from the ground ([Tuning.headLaunchUpBias]). It grows with speed
///   and is strongest when the robot lands upright (facing along
///   [groundNormal]).
/// - It always leaves the ground at least [Tuning.headLaunchMinLift] fast,
///   and never faster than [Tuning.headLaunchMaxSpeed].
///
/// [groundNormal] must be a unit vector pointing away from the ground.
/// [stats] scales the kick and the caps (Rocket head upgrade).
Vector2 headLaunchVelocity({
  required Vector2 carried,
  required Vector2 facing,
  required Vector2 groundNormal,
  RobotStats stats = RobotStats.base,
}) {
  final scale = stats.headLaunchScale;

  // Momentum along the ground (and away from it); the part driving into
  // the ground is what the impact takes.
  final intoGround = math.min(0.0, carried.dot(groundNormal));
  final momentum = (carried - groundNormal * intoGround)
    ..scale(Tuning.headLaunchCarry);

  // The rocket kick.
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
  final kick =
      ((Tuning.headLaunchBaseSpeed +
                  carried.length * Tuning.headLaunchSpeedFactor) *
              anglePower *
              scale)
          .clamp(0.0, Tuning.headLaunchMaxKick * scale);

  final velocity = momentum + direction * kick;

  // Always clear of the ground.
  final lift = velocity.dot(groundNormal);
  final minLift = Tuning.headLaunchMinLift * scale;
  if (lift < minLift) {
    velocity.add(groundNormal * (minLift - lift));
  }

  final maxSpeed = Tuning.headLaunchMaxSpeed * scale;
  if (velocity.length > maxSpeed) {
    velocity.scale(maxSpeed / velocity.length);
  }
  return velocity;
}
