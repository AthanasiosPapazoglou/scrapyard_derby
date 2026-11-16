import 'dart:math' as math;

import '../config/tuning.dart';
import 'landing.dart';

/// The extra swing a limb is DRAWN with on top of its physics angle, so
/// the robot looks alive (see [Tuning] "Limb motion"). It never touches
/// the physics.
///
/// A damped spring pulls [angle] toward a target pose ([armTarget],
/// [legTarget]); [kick] jolts it (landings, sudden spin changes).
class LimbWiggle {
  /// Current extra angle (radians, + = clockwise on screen).
  double angle = 0;

  /// How fast [angle] is changing (rad/s).
  double velocity = 0;

  /// Jolts the limb with [speed] rad/s.
  void kick(double speed) => velocity += speed;

  /// Moves [angle] toward [target] over [dt] seconds.
  void update(double dt, double target) {
    const omega = 2 * math.pi * Tuning.limbSpringHz;
    const stiffness = omega * omega;
    const damping = 2 * Tuning.limbSpringDamping * omega;
    // Small steps keep the spring stable on slow frames.
    var left = dt;
    while (left > 0) {
      final step = math.min(left, 1 / 120);
      final accel = stiffness * (target - angle) - damping * velocity;
      velocity += accel * step;
      angle += velocity * step;
      left -= step;
    }
    if (angle.abs() > Tuning.limbMaxAngle) {
      angle = angle.sign * Tuning.limbMaxAngle;
      velocity = 0;
    }
  }
}

/// Where an arm wants to be: flailing in the air (harder the faster the
/// robot spins), trailing the spin ([spinRate], rad/s), or swaying gently
/// on the ground. [time] (s) drives the swing; the two arms ([left]) swing
/// opposite.
double armTarget({
  required double time,
  required bool left,
  required bool inAir,
  required double spinRate,
}) {
  final phase = left ? 0.0 : math.pi;
  final swing = math.sin(time * Tuning.armFlailHz * 2 * math.pi + phase);
  if (!inAir) {
    return swing * Tuning.armGroundSway;
  }
  final spinShare = (spinRate.abs() / Tuning.spinSpeed).clamp(0.0, 1.0);
  final flail = swing * Tuning.armFlailAngle * (0.4 + 0.6 * spinShare);
  return flail - spinRate * Tuning.armSpinLag;
}

/// Where a leg wants to be: tucked up and kicking in the air, reaching out
/// straight as touchdown nears ([timeToLanding], s; null = unknown), and
/// straight on the ground.
double legTarget({
  required double time,
  required bool left,
  required bool inAir,
  double? timeToLanding,
}) {
  if (!inAir) {
    return 0;
  }
  final reach = timeToLanding == null
      ? 1.0
      : (timeToLanding / Tuning.legReachTime).clamp(0.0, 1.0);
  final phase = left ? 0.0 : math.pi;
  final kick =
      math.sin(time * Tuning.legKickHz * 2 * math.pi + phase) *
      Tuning.legKickAngle;
  return (Tuning.legTuckAngle + kick) * reach;
}

/// How hard a landing of [type] jolts the limbs (rad/s).
double landingKick(LandingType type) => switch (type) {
  LandingType.clean => Tuning.limbKickClean,
  LandingType.oneFoot => Tuning.limbKickOneFoot,
  LandingType.crash => Tuning.limbKickCrash,
};

/// Seconds until something at [height] m above the ground, falling at
/// [fallSpeed] m/s (+ = down), lands under gravity. A rough guess (flat
/// ground), good enough for the legs to reach out in time.
double timeToFall(double height, double fallSpeed) {
  if (height <= 0) {
    return 0;
  }
  const g = Tuning.gravity;
  // height = fallSpeed × t + ½ g t², solved for t.
  return (-fallSpeed + math.sqrt(fallSpeed * fallSpeed + 2 * g * height)) / g;
}
