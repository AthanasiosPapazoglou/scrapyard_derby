import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/camera_framing.dart';

/// Landscape phone: height / width.
const aspect = 440 / 956;

CameraFraming frameAt(double heightAboveGround) => frameRobotAndGround(
  robotPosition: Vector2(100, 50 - heightAboveGround),
  velocity: Vector2.zero(),
  groundY: 50,
  screenAspect: aspect,
);

void main() {
  test('on the ground the camera uses a close view', () {
    // The base view, or slightly wider to keep room for the HUD.
    final width = frameAt(0).visibleWidth;
    expect(width, greaterThanOrEqualTo(Tuning.cameraBaseWidth));
    expect(width, lessThan(Tuning.cameraBaseWidth * 1.15));
  });

  test('the higher the robot, the further the camera zooms out', () {
    final low = frameAt(5).visibleWidth;
    final mid = frameAt(15).visibleWidth;
    final high = frameAt(25).visibleWidth;
    expect(mid, greaterThan(low));
    expect(high, greaterThan(mid));
  });

  test('coming back down zooms back in', () {
    expect(frameAt(2).visibleWidth, lessThan(frameAt(20).visibleWidth));
  });

  test('both the robot and the ground stay on screen when high up', () {
    const height = 20.0;
    final framing = frameAt(height);
    final halfVisibleHeight = framing.visibleWidth * aspect / 2;
    final top = framing.center.y - halfVisibleHeight;
    final bottom = framing.center.y + halfVisibleHeight;
    const robotY = 50 - height;
    const groundY = 50.0;
    expect(top, lessThan(robotY));
    expect(bottom, greaterThan(groundY));
  });

  test('zoom out is capped', () {
    expect(frameAt(10000).visibleWidth, Tuning.cameraMaxWidth);
  });

  test('centered mode (launched head) puts the robot in the middle', () {
    final framing = frameRobotAndGround(
      robotPosition: Vector2(100, 30),
      velocity: Vector2.zero(),
      groundY: 50,
      screenAspect: aspect,
      groundBias: 0,
    );
    expect(framing.center.y, closeTo(30, 1e-4));
  });

  test('centered mode still zooms out with height', () {
    double widthAt(double h) => frameRobotAndGround(
      robotPosition: Vector2(100, 50 - h),
      velocity: Vector2.zero(),
      groundY: 50,
      screenAspect: aspect,
      groundBias: 0,
    ).visibleWidth;
    expect(widthAt(15), greaterThan(widthAt(5)));
  });

  test('even far above the zoom cap, the robot stays on screen', () {
    const robotY = 50 - 500.0; // 500 m up
    final framing = frameRobotAndGround(
      robotPosition: Vector2(100, robotY),
      velocity: Vector2.zero(),
      groundY: 50,
      screenAspect: aspect,
    );
    final halfVisibleHeight = framing.visibleWidth * aspect / 2;
    expect(framing.visibleWidth, Tuning.cameraMaxWidth);
    expect(robotY, greaterThan(framing.center.y - halfVisibleHeight));
    expect(robotY, lessThan(framing.center.y + halfVisibleHeight));
  });

  test('the robot is never framed behind the HUD at the top', () {
    for (final height in [0.0, 5.0, 20.0, 60.0, 500.0]) {
      final robotY = 50 - height;
      final framing = frameRobotAndGround(
        robotPosition: Vector2(100, robotY),
        velocity: Vector2.zero(),
        groundY: 50,
        screenAspect: aspect,
      );
      final visibleHeight = framing.visibleWidth * aspect;
      final top = framing.center.y - visibleHeight / 2;
      final hudBottom = top + visibleHeight * Tuning.cameraHudReserve;
      expect(robotY, greaterThan(hudBottom), reason: 'height $height');
    }
  });

  group('portrait', () {
    /// Portrait phone: height / width.
    const tall = 956 / 440;

    CameraFraming frameTall(double heightAboveGround) => frameRobotAndGround(
      robotPosition: Vector2(100, 50 - heightAboveGround),
      velocity: Vector2.zero(),
      groundY: 50,
      screenAspect: tall,
    );

    test('the view is narrower, so the robot stays a good size', () {
      final width = frameTall(0).visibleWidth;
      expect(
        width,
        closeTo(Tuning.cameraBaseWidth * Tuning.cameraPortraitWidthScale, 1),
      );
      // Pixels per meter on a 440 px wide portrait screen vs a 956 px wide
      // landscape one: within 30% of each other.
      final portraitPpm = 440 / width;
      final landscapePpm = 956 / frameAt(0).visibleWidth;
      expect(portraitPpm / landscapePpm, greaterThan(0.7));
    });

    test('on the ground the robot sits above the middle', () {
      final framing = frameTall(0);
      expect(framing.center.y, greaterThan(50));
    });

    test('robot and ground both fit, and the robot stays below the HUD', () {
      for (final height in [0.0, 5.0, 20.0, 60.0, 500.0]) {
        final robotY = 50 - height;
        final framing = frameTall(height);
        final visibleHeight = framing.visibleWidth * tall;
        final top = framing.center.y - visibleHeight / 2;
        final hudBottom = top + visibleHeight * Tuning.cameraPortraitHudReserve;
        expect(robotY, greaterThan(hudBottom), reason: 'height $height');
        if (height <= 60) {
          expect(
            top + visibleHeight,
            greaterThan(50),
            reason: 'ground $height',
          );
        }
      }
    });

    test('zoom out is capped at the portrait max', () {
      expect(
        frameTall(10000).visibleWidth,
        closeTo(Tuning.cameraMaxWidth * Tuning.cameraPortraitWidthScale, 1e-4),
      );
    });
  });
}
