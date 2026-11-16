import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/head_launch.dart';

void main() {
  // Flat ground: up is -y, forward is +x.
  final up = Vector2(0, -1);

  // A 35° downhill slope (y down): its "away from the ground" normal and
  // the downhill direction along it.
  final slopeAngle = 35 * math.pi / 180;
  final slopeNormal = Vector2(math.sin(slopeAngle), -math.cos(slopeAngle));
  final downhill = Vector2(math.cos(slopeAngle), math.sin(slopeAngle));

  Vector2 launch({
    required Vector2 carried,
    Vector2? facing,
    Vector2? normal,
  }) => headLaunchVelocity(
    carried: carried,
    facing: facing ?? normal ?? up,
    groundNormal: normal ?? up,
  );

  group('momentum', () {
    test('the head keeps the robot racing forward', () {
      // Landing upright at 20 m/s, coming in at an angle.
      final v = launch(carried: Vector2(20, 8));
      expect(v.x, greaterThan(20 * Tuning.headLaunchCarry * 0.95));
    });

    test(
      'racing downhill, the head flies on downhill and up off the slope',
      () {
        final v = launch(carried: downhill * 22, normal: slopeNormal);
        expect(v.dot(downhill), greaterThan(15));
        expect(
          v.dot(slopeNormal),
          greaterThan(Tuning.headLaunchMinLift - 1e-3),
        );
      },
    );

    test('the part of the speed going into the ground is not kept', () {
      // Straight down onto flat ground: no forward speed to keep.
      final v = launch(carried: Vector2(0, 25));
      expect(v.x.abs(), lessThan(1e-3));
      expect(v.y, lessThan(0)); // up
    });

    test('a faster robot launches its head faster', () {
      final slow = launch(carried: downhill * 8, normal: slopeNormal);
      final fast = launch(carried: downhill * 20, normal: slopeNormal);
      expect(fast.length, greaterThan(slow.length + 8));
    });
  });

  group('rocket kick', () {
    test('standing still, an upright landing fires the head straight up', () {
      final v = launch(carried: Vector2.zero());
      expect(v.y, lessThan(-Tuning.headLaunchBaseSpeed * 0.9));
      expect(v.x.abs(), lessThan(1e-4));
    });

    test('landing upright kicks harder than landing sideways', () {
      final upright = launch(carried: Vector2.zero());
      final sideways = launch(carried: Vector2.zero(), facing: Vector2(1, 0));
      expect(upright.length, greaterThan(sideways.length));
    });

    test('the head never fires into the ground, even upside down', () {
      for (final facing in [
        Vector2(0, 1),
        Vector2(0.3, 1)..normalize(),
        Vector2(-1, 0.2)..normalize(),
      ]) {
        final v = launch(carried: Vector2(15, 10), facing: facing);
        expect(
          v.dot(up),
          greaterThanOrEqualTo(Tuning.headLaunchMinLift - 1e-3),
          reason: '$facing',
        );
      }
    });

    test('the launch speed is capped', () {
      final v = launch(carried: Vector2(1000, 0));
      expect(v.length, closeTo(Tuning.headLaunchMaxSpeed, 1e-3));
    });
  });
}
