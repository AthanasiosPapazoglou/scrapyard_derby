import 'dart:ui';

import 'autopilot.dart';
import 'robot.dart';

/// Why a run ended.
enum RunEnd {
  headDown('HEAD DOWN'),
  stuck('STUCK');

  const RunEnd(this.label);

  final String label;
}

/// One robot in a run: the player's (Survival has only this one) or a
/// Versus rival driven by an [Autopilot]. Keeps its own finish state, so
/// every racer ends on its own, like a Survival run.
class Racer {
  Racer({
    required this.name,
    required this.color,
    required this.isPlayer,
    this.autopilot,
  });

  /// Shown in the standings and on the rival's name tag.
  final String name;

  /// Paint colour (rivals are tinted with it).
  final Color color;

  /// True for the player's robot (camera, HUD, sound and the finger).
  final bool isPlayer;

  /// The bot that steers this robot; null = the player's finger.
  Autopilot? autopilot;

  /// The robot of the current attempt (replaced on restart).
  late Robot robot;

  /// Seconds (real time) spent slower than [Tuning.stallSpeed].
  double stallTime = 0;

  /// How the run ended, or null while still going.
  RunEnd? end;

  /// Final distance, frozen at the finish (the wreck may keep sliding).
  double? finalDistance;

  /// Seconds (real time) since the finish (finished rivals are cleared
  /// away after a while).
  double finishedFor = 0;

  bool get finished => end != null;

  /// Meters covered: final once finished, else live.
  double get distance => finalDistance ?? (robot.isLoaded ? robot.distance : 0);

  /// Marks the run as over at the current distance.
  void finish(RunEnd how) {
    end = how;
    finalDistance = robot.distance;
  }

  /// Ready for a new attempt with [newRobot].
  void reset(Robot newRobot) {
    robot = newRobot;
    stallTime = 0;
    end = null;
    finalDistance = null;
    finishedFor = 0;
  }
}
