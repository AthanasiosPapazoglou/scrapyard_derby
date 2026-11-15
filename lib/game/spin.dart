import '../config/tuning.dart';

/// The spin "control" value, from 1 (full clockwise, the default) to
/// -1 (full counter-clockwise).
///
/// While the player holds a finger down, it moves steadily toward -1 (the
/// counter-spin force). When they let go, it moves back toward 1. The robot
/// spins at `control × Tuning.spinSpeed`, so holding first slows the spin,
/// stops it, and then builds it up the other way.
double nextSpinControl(
  double control, {
  required bool holding,
  required double dt,
}) {
  if (holding) {
    // Covering the full range (2) takes counterSpinTime seconds.
    final step = 2 * dt / Tuning.counterSpinTime;
    return (control - step).clamp(-1.0, 1.0);
  }
  final step = 2 * dt / Tuning.releaseSpinTime;
  return (control + step).clamp(-1.0, 1.0);
}
