import 'dart:math' as math;

import 'landing.dart';

/// Numbers collected during one run, shown on the run summary and used for
/// the scrap reward. Pure Dart: the robot reports events, nothing else.
class RunStats {
  /// Landings per type (clean, one foot, crash).
  final Map<LandingType, int> landings = {
    for (final type in LandingType.values) type: 0,
  };

  /// Highest jump: the robot's feet above the ground (m).
  double highestJump = 0;

  /// Arms and legs broken off (0-4).
  int limbsLost = 0;

  /// Horizontal meters the launched head flew, or null if the head was
  /// never launched (or hasn't landed yet). Negative when it was fired
  /// backwards (the robot faced uphill at the launch).
  double? headFlight;

  /// Horizontal meters covered (the score), set when the run ends.
  double distance = 0;

  double? _headLaunchX;

  int landingsOf(LandingType type) => landings[type]!;

  void addLanding(LandingType type) => landings[type] = landingsOf(type) + 1;

  /// Reports the robot's current height above the ground (m).
  void reportHeight(double height) =>
      highestJump = math.max(highestJump, height);

  void addLimbLost() => limbsLost++;

  /// The head was fired off at world x [x].
  void headLaunchedAt(double x) => _headLaunchX = x;

  /// The launched head touched the ground at world x [x].
  void headLandedAt(double x) {
    final from = _headLaunchX;
    if (from != null) {
      headFlight = x - from;
    }
  }
}
