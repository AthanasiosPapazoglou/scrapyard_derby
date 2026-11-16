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
///   when fast), the robot near the middle.
/// - High up: zoomed out just enough that the robot (below the HUD band at
///   the top, [Tuning.cameraHudReserve], plus [Tuning.cameraTopMargin])
///   and the ground (above the bottom edge, plus
///   [Tuning.cameraGroundMargin]) both fit. It zooms back in as the robot
///   comes down.
/// - Past [Tuning.cameraMaxWidth] the ground drops out of view, but the
///   robot always stays on screen, below the HUD.
///
/// [groundBias] sets where the camera centers vertically when there's
/// room to spare: 0 = on the robot (used for the launched head), 0.5 =
/// halfway between robot and ground.
///
/// On portrait screens ([screenAspect] > 1) the view is narrower
/// ([Tuning.cameraPortraitWidthScale]) and the robot sits a little above
/// the middle ([Tuning.cameraPortraitLead]).
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
  const top = Tuning.cameraTopMargin;
  const bottom = Tuning.cameraGroundMargin;
  final portrait = screenAspect > 1;
  final widthScale = portrait ? Tuning.cameraPortraitWidthScale : 1.0;
  final baseWidth = Tuning.cameraBaseWidth * widthScale;
  final maxWidth = Tuning.cameraMaxWidth * widthScale;
  final hudShare = portrait
      ? Tuning.cameraPortraitHudReserve
      : Tuning.cameraHudReserve;
  final height = math.max(0.0, groundY - robotPosition.y);

  // Visible height needed for HUD band + robot + the drop + ground margin.
  final neededHeight = (height + top + bottom) / (1 - hudShare);
  final widthForHeight = neededHeight / screenAspect;
  final widthForSpeed =
      baseWidth + velocity.length * Tuning.cameraZoomPerSpeed * widthScale;
  final width = math
      .max(widthForHeight, widthForSpeed)
      .clamp(baseWidth, maxWidth);

  // How far below the robot the center sits. Wanted: [groundBias] of the
  // way to the ground (plus the portrait lead), but at least far enough
  // to show the ground, and never so far that the robot goes behind the
  // HUD.
  final visibleHeight = width * screenAspect;
  final half = visibleHeight / 2;
  final maxOffset = math.max(0.0, half - hudShare * visibleHeight - top);
  final double offset;
  if (groundBias <= 0) {
    offset = 0; // Centered on the robot (the launched head).
  } else {
    final lead = portrait ? visibleHeight * Tuning.cameraPortraitLead : 0.0;
    final wanted = height * groundBias + lead;
    final showGround = height + bottom - half;
    offset = math.max(wanted, showGround).clamp(0.0, maxOffset);
  }

  final center = Vector2(
    robotPosition.x + velocity.x * Tuning.cameraLookAhead,
    robotPosition.y + offset,
  );
  return CameraFraming(center, width);
}
