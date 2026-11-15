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
  test('on the ground the camera uses the close base view', () {
    expect(frameAt(0).visibleWidth, Tuning.cameraBaseWidth);
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
}
