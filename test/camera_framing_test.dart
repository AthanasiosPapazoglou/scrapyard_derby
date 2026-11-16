import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/camera_framing.dart';

/// Landscape phone: height / width.
const aspect = 440 / 956;

/// Portrait phone: height / width.
const tall = 956 / 440;

CameraFraming frameAt(
  double heightAboveGround, {
  double screenAspect = aspect,
  double groundBias = Tuning.cameraGroundBias,
}) => frameRobotAndGround(
  robotPosition: Vector2(100, 50 - heightAboveGround),
  velocity: Vector2.zero(),
  groundY: 50,
  screenAspect: screenAspect,
  groundBias: groundBias,
);

/// Screen top and bottom (world y) of a framing.
(double, double) edges(CameraFraming f, double screenAspect) {
  final half = f.visibleWidth * screenAspect / 2;
  return (f.center.y - half, f.center.y + half);
}

void main() {
  for (final (name, a, hud, widthScale) in [
    ('landscape', aspect, Tuning.cameraHudReserve, 1.0),
    (
      'portrait',
      tall,
      Tuning.cameraPortraitHudReserve,
      Tuning.cameraPortraitWidthScale,
    ),
  ]) {
    group(name, () {
      test('on the ground the camera uses the close base view', () {
        expect(
          frameAt(0, screenAspect: a).visibleWidth,
          closeTo(Tuning.cameraBaseWidth * widthScale, 1e-6),
        );
      });

      test('the higher the robot, the further out (up to the cap)', () {
        var last = 0.0;
        for (final h in [0.0, 4, 8, 12, 16, 24, 40, 500]) {
          final width = frameAt(h.toDouble(), screenAspect: a).visibleWidth;
          expect(width, greaterThanOrEqualTo(last), reason: 'height $h');
          last = width;
        }
        expect(last, closeTo(Tuning.cameraMaxWidth * widthScale, 1e-6));
      });

      test('the robot is always on screen and never behind the HUD', () {
        for (final h in [0.0, 3, 8, 15, 30, 60, 500]) {
          final robotY = 50 - h.toDouble();
          final f = frameAt(h.toDouble(), screenAspect: a);
          final (top, bottom) = edges(f, a);
          final hudBottom = top + (bottom - top) * hud;
          expect(robotY, greaterThan(hudBottom), reason: 'height $h');
          expect(robotY, lessThan(bottom), reason: 'height $h');
        }
      });

      test('the ground is in view whenever the zoom allows it', () {
        // Visible height needed: HUD band + robot + drop + ground margin.
        final maxHeight = Tuning.cameraMaxWidth * widthScale * a;
        final fitsUpTo =
            maxHeight * (1 - hud) -
            Tuning.cameraTopMargin -
            Tuning.cameraGroundMargin;
        for (var h = 0.0; h < fitsUpTo; h += 2) {
          final (_, bottom) = edges(frameAt(h, screenAspect: a), a);
          expect(bottom, greaterThanOrEqualTo(50 - 1e-6), reason: 'h $h');
        }
      });
    });
  }

  test('max zoom-out is much tighter than 1.0 (robot stays readable)', () {
    expect(
      Tuning.cameraMaxWidth,
      lessThanOrEqualTo(Tuning.cameraBaseWidth * 3),
    );
  });

  test('centered mode (launched head) puts the robot in the middle', () {
    final f = frameAt(20, groundBias: 0);
    expect(f.center.y, closeTo(30, 1e-4));
    expect(f.visibleWidth, greaterThan(frameAt(0, groundBias: 0).visibleWidth));
  });

  test('portrait: the robot sits above the middle near the ground', () {
    expect(frameAt(0, screenAspect: tall).center.y, greaterThan(50));
  });
}
