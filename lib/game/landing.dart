import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

import '../config/tuning.dart';

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
LandingType classifyLanding(PartKind firstPart, double angleError) {
  if (firstPart != PartKind.leg) {
    return LandingType.crash;
  }
  final errorDeg = angleError.abs() * 180 / math.pi;
  if (errorDeg <= Tuning.cleanLandingToleranceDeg) {
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
Vector2 velocityAfterLanding(
  LandingType type,
  Vector2 velocity,
  Vector2 groundNormal, {
  double extraBounce = 0,
}) {
  // Tangent pointing "forward" (to the right / downhill) along the ground.
  final tangent = Vector2(-groundNormal.y, groundNormal.x);
  final alongGround = velocity.dot(tangent);

  final (bounce, multiplier, bonus) = switch (type) {
    LandingType.clean => (
      Tuning.cleanBounce,
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
/// (see damage.dart).
double landingDamage(LandingType type) => switch (type) {
  LandingType.clean => Tuning.cleanLandingDamage,
  LandingType.oneFoot => Tuning.oneFootDamage,
  LandingType.crash => Tuning.crashDamage,
};

// ---------------------------------------------------------------- Spin energy
//
// Energy is measured in turns. Every airtime gathers energy from spinning
// (capped), and ALL of it is released into the next bounce, whatever kind
// of landing it is. Then the next airtime starts gathering from zero.

/// Energy after spinning [turns] more full turns (either direction counts),
/// capped at [Tuning.spinEnergyMaxTurns].
double addSpinEnergy(double energy, double turns) =>
    math.min(energy + turns.abs(), Tuning.spinEnergyMaxTurns);

/// Extra bounce (m/s) the gathered [energy] adds to the next jump.
double spinEnergyBounce(double energy) =>
    math.min(energy, Tuning.spinEnergyMaxTurns) * Tuning.spinEnergyPerTurn;
