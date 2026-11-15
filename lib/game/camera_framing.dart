import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

import '../config/tuning.dart';

/// Where the camera should look and how much of the world it should show.
class CameraFraming {
  const CameraFraming(this.center, this.visibleWidth);

  /// World point at the middle of the screen.
  final Vector2 center;

  /// Meters of world visible across the screen.
  final double visibleWidth;
}

/// Frames the robot and the ground right below it.
///
/// - Near the ground: a close view ([Tuning.cameraBaseWidth], a bit wider
///   when fast), centered on the robot.
/// - High up: zoomed out so that both the robot and the ground below it fit
///   on screen (plus a margin). It zooms back in as the robot comes down.
///
/// [groundBias] sets where the camera centers vertically: 0 = on the robot
/// (used for the launched head), 0.5 = halfway between robot and ground.
/// Whatever the zoom cap, the robot itself always stays on screen, and
/// never behind the HUD at the top ([Tuning.cameraHudReserve]).
///
/// [groundY] is the ground height right below the robot. [screenAspect] is
/// screen height / screen width. y points down.
CameraFraming frameRobotAndGround({
  required Vector2 robotPosition,
  required Vector2 velocity,
  required double groundY,
  required double screenAspect,
  double groundBias = Tuning.cameraGroundBias,
}) {
  const margin = Tuning.cameraGroundMargin;
  final height = math.max(0.0, groundY - robotPosition.y);

  // The camera centers [groundBias] of the way from robot to ground, so it
  // needs this much room above center (for the robot) and below (ground).
  final roomAbove = height * groundBias + margin;
  final roomBelow = height * (1 - groundBias) + margin;
  // The top [hudShare] of the screen is kept clear for the HUD, so only
  // the rest of the upper half is usable for the robot.
  const hudShare = Tuning.cameraHudReserve;
  final usableAbove = 1 - 2 * hudShare;
  final widthForHeight =
      2 * math.max(roomAbove / usableAbove, roomBelow) / screenAspect;
  final widthForSpeed =
      Tuning.cameraBaseWidth + velocity.length * Tuning.cameraZoomPerSpeed;
  final width = math
      .max(widthForHeight, widthForSpeed)
      .clamp(Tuning.cameraBaseWidth, Tuning.cameraMaxWidth);

  // If the zoom is capped, the ground may not fit; never lose the robot:
  // keep it at least [margin] below the HUD area at the top.
  final halfVisibleHeight = width * screenAspect / 2;
  final maxOffset = math.max(0.0, halfVisibleHeight * usableAbove - margin);
  final offset = (height * groundBias).clamp(0.0, maxOffset);

  final center = Vector2(
    robotPosition.x + velocity.x * Tuning.cameraLookAhead,
    robotPosition.y + offset,
  );
  return CameraFraming(center, width);
}
