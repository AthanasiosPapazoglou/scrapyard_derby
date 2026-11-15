import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

import '../config/tuning.dart';
import 'robot_stats.dart';

/// The robot's body parts. Used to decide what kind of landing happened.
enum PartKind { torso, head, arm, leg }

/// The three kinds of landing from the spec.
enum LandingType {
  clean('Both feet'),
  oneFoot('One foot'),
  crash('Crash');

  const LandingType(this.label);

  /// Human-readable name for the debug overlay.
  final String label;
}

/// Signed angle in radians from [from] to [to], in the range -pi..pi.
double signedAngleBetween(Vector2 from, Vector2 to) {
  final cross = from.x * to.y - from.y * to.x;
  final dot = from.dot(to);
  return math.atan2(cross, dot);
}

/// Decides the landing type from which part touched the ground first and
/// how far the robot's "up" was from the ground normal (radians).
/// [stats] gives the clean-landing tolerance (Spring legs upgrade).
LandingType classifyLanding(
  PartKind firstPart,
  double angleError, {
  RobotStats stats = RobotStats.base,
}) {
  if (firstPart != PartKind.leg) {
    return LandingType.crash;
  }
  final errorDeg = angleError.abs() * 180 / math.pi;
  if (errorDeg <= stats.cleanToleranceDeg) {
    return LandingType.clean;
  }
  if (errorDeg <= Tuning.oneFootToleranceDeg) {
    return LandingType.oneFoot;
  }
  return LandingType.crash;
}

/// The velocity the robot should have right after a landing.
///
/// [groundNormal] must be a unit vector pointing away from the ground (up,
/// so its y is negative in our y-down world).
///
/// The velocity is split into two parts:
/// - along the ground (tangent): scaled by the landing's speed multiplier,
///   plus a bonus for clean landings. This is the "speed gain / loss".
/// - away from the ground (normal): replaced with a fixed bounce speed.
///
/// [extraBounce] (m/s) is added to the bounce, e.g. from spin energy.
/// [stats] gives the clean bounce (Spring legs upgrade).
Vector2 velocityAfterLanding(
  LandingType type,
  Vector2 velocity,
  Vector2 groundNormal, {
  double extraBounce = 0,
  RobotStats stats = RobotStats.base,
}) {
  // Tangent pointing "forward" (to the right / downhill) along the ground.
  final tangent = Vector2(-groundNormal.y, groundNormal.x);
  final alongGround = velocity.dot(tangent);

  final (bounce, multiplier, bonus) = switch (type) {
    LandingType.clean => (
      stats.cleanBounce,
      Tuning.cleanSpeedMultiplier,
      Tuning.cleanSpeedBonus,
    ),
    LandingType.oneFoot => (
      Tuning.oneFootBounce,
      Tuning.oneFootSpeedMultiplier,
      0.0,
    ),
    LandingType.crash => (Tuning.crashBounce, Tuning.crashSpeedMultiplier, 0.0),
  };

  final newAlong = (alongGround * multiplier + bonus).clamp(
    -Tuning.maxRobotSpeed,
    Tuning.maxRobotSpeed,
  );
  return tangent * newAlong + groundNormal * (bounce + extraBounce);
}

/// How much damage a landing adds to the robot's shared damage total
/// (see damage.dart). Shock Pads ([RobotStats.landingDamageScale]) soften
/// one-foot landings and crashes.
double landingDamage(LandingType type, {RobotStats stats = RobotStats.base}) =>
    switch (type) {
      LandingType.clean => Tuning.cleanLandingDamage,
      LandingType.oneFoot => Tuning.oneFootDamage * stats.landingDamageScale,
      LandingType.crash => Tuning.crashDamage * stats.landingDamageScale,
    };

// ---------------------------------------------------------------- Spin energy
//
// Energy is measured in turns. Every airtime gathers energy from spinning
// (capped), and ALL of it is released into the next bounce, whatever kind
// of landing it is. Then the next airtime starts gathering from zero.

/// Energy after spinning [turns] more full turns (either direction counts),
/// capped at [RobotStats.spinEnergyMaxTurns] (Energy core upgrade).
double addSpinEnergy(
  double energy,
  double turns, {
  RobotStats stats = RobotStats.base,
}) => math.min(energy + turns.abs(), stats.spinEnergyMaxTurns);

/// Extra bounce (m/s) the gathered [energy] adds to the next jump, never
/// more than [RobotStats.maxEnergyBounce].
double spinEnergyBounce(double energy, {RobotStats stats = RobotStats.base}) =>
    math.min(
      math.min(energy, stats.spinEnergyMaxTurns) * stats.spinEnergyPerTurn,
      stats.maxEnergyBounce,
    );
