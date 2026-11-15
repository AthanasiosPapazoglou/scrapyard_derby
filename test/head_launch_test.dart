import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/head_launch.dart';

void main() {
  // Flat ground: up is -y.
  final up = Vector2(0, -1);

  group('headLaunchVelocity', () {
    test('an upright landing fires the head straight up off the ground', () {
      final v = headLaunchVelocity(facing: up, groundNormal: up, speed: 10);
      expect(v.y, lessThan(0)); // upward
      expect(v.x.abs(), lessThan(1e-4));
    });

    test('the head never fires into the ground, even when upside down', () {
      final v = headLaunchVelocity(
        facing: Vector2(0.3, 1)..normalize(), // facing mostly downward
        groundNormal: up,
        speed: 10,
      );
      expect(v.dot(up), greaterThan(0));
    });

    test('faster robots launch the head harder, up to the cap', () {
      final slow = headLaunchVelocity(facing: up, groundNormal: up, speed: 2);
      final fast = headLaunchVelocity(facing: up, groundNormal: up, speed: 20);
      final huge = headLaunchVelocity(
        facing: up,
        groundNormal: up,
        speed: 1000,
      );
      expect(fast.length, greaterThan(slow.length));
      expect(huge.length, closeTo(Tuning.headLaunchMaxSpeed, 1e-3));
    });

    test('landing upright launches harder than landing sideways', () {
      final upright = headLaunchVelocity(
        facing: up,
        groundNormal: up,
        speed: 10,
      );
      final sideways = headLaunchVelocity(
        facing: Vector2(1, 0),
        groundNormal: up,
        speed: 10,
      );
      expect(upright.length, greaterThan(sideways.length));
    });
  });

  test('the launch is rocket-strong: much faster than a clean bounce', () {
    final v = headLaunchVelocity(facing: up, groundNormal: up, speed: 15);
    expect(v.length, greaterThan(Tuning.cleanBounce));
  });

  test('a sideways robot still fires the head mostly upward', () {
    final v = headLaunchVelocity(
      facing: Vector2(1, 0),
      groundNormal: up,
      speed: 10,
    );
    // More up than sideways.
    expect(-v.y, greaterThan(v.x.abs()));
  });
}
