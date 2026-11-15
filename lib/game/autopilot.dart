import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

import '../config/tuning.dart';
import 'hill.dart';
import 'robot_stats.dart';
import 'spin.dart';

/// The robot's state, as the autopilot needs it.
class FlightState {
  const FlightState({
    required this.position,
    required this.velocity,
    required this.angle,
    required this.spinControl,
    required this.feetBelowTorso,
  });

  /// Torso center (m) and velocity (m/s), y down.
  final Vector2 position;
  final Vector2 velocity;

  /// Torso angle (radians, clockwise), 0 = upright on flat ground.
  final double angle;

  /// Current spin control (1 = full clockwise, see spin.dart).
  final double spinControl;

  /// Distance from torso center to the soles (m).
  final double feetBelowTorso;
}

/// Wraps an angle into -pi..pi.
double wrapAngle(double a) {
  var x = (a + math.pi) % (2 * math.pi);
  if (x < 0) {
    x += 2 * math.pi;
  }
  return x - math.pi;
}

/// Predicts the landing angle error (radians, signed, like the robot's
/// landing check) if the player keeps [holding] (or not) until touchdown.
/// Returns null if the robot won't land within [horizon] seconds.
///
/// Flight is ballistic and the spin follows the hold/release ramps, which
/// is close to what the physics does in the air.
double? predictLandingError(
  FlightState s,
  HillGeometry hill, {
  required bool holding,
  RobotStats stats = RobotStats.base,
  double horizon = 6,
  double step = 1 / 60,
}) {
  final p = s.position.clone();
  final v = s.velocity.clone();
  var angle = s.angle;
  var control = s.spinControl;
  for (var t = 0.0; t < horizon; t += step) {
    control = nextSpinControl(
      control,
      holding: holding,
      dt: step,
      stats: stats,
    );
    angle += control * Tuning.spinSpeed * step;
    v.y += Tuning.gravity * step;
    p.addScaled(v, step);
    if (hill.heightAt(p.x) - p.y <= s.feetBelowTorso) {
      return wrapAngle(angle - hill.slopeAngleAt(p.x));
    }
  }
  return null;
}

/// A bot that plays like a person: while in the air it holds when holding
/// would land the robot closer to upright than letting go.
///
/// [skill] 1 is near perfect; lower skill adds noise to its judgement and
/// makes it react more slowly. Used by the balance simulator (and could
/// drive AI rivals later).
class Autopilot {
  Autopilot({this.skill = 1, int seed = 1}) : _random = math.Random(seed);

  final double skill;
  final math.Random _random;

  bool _holding = false;
  double _sinceDecision = 0;

  /// Seconds between changes of mind: 0.05 s at skill 1, 0.25 s at 0.
  double get _reaction => 0.05 + 0.2 * (1 - skill);

  /// Spread (radians) of the error in the bot's judgement of the landing.
  double get _noise => (1 - skill) * 35 * math.pi / 180;

  /// Should the finger be down this frame? [dt] is game-world seconds.
  bool decide(
    FlightState state,
    HillGeometry hill, {
    required double dt,
    required bool onGround,
    RobotStats stats = RobotStats.base,
  }) {
    _sinceDecision += dt;
    if (onGround) {
      _holding = false;
      return false;
    }
    if (_sinceDecision < _reaction) {
      return _holding;
    }
    _sinceDecision = 0;
    final hold = predictLandingError(state, hill, holding: true, stats: stats);
    final release = predictLandingError(
      state,
      hill,
      holding: false,
      stats: stats,
    );
    if (hold == null || release == null) {
      return _holding;
    }
    double judge(double error) => (error + _gaussian() * _noise).abs();
    _holding = judge(hold) < judge(release);
    return _holding;
  }

  double _gaussian() {
    final u = 1 - _random.nextDouble();
    final v = _random.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }
}
