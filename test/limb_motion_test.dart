import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/limb_motion.dart';

void main() {
  group('LimbWiggle', () {
    test('settles on its target', () {
      final w = LimbWiggle();
      for (var i = 0; i < 300; i++) {
        w.update(1 / 60, 0.4);
      }
      expect(w.angle, closeTo(0.4, 1e-3));
    });

    test('a kick makes it wobble past rest and back (jiggly)', () {
      final w = LimbWiggle()..kick(5);
      var maxAngle = 0.0;
      var minAngle = 0.0;
      for (var i = 0; i < 120; i++) {
        w.update(1 / 60, 0);
        maxAngle = math.max(maxAngle, w.angle);
        minAngle = math.min(minAngle, w.angle);
      }
      expect(maxAngle, greaterThan(0.1));
      expect(minAngle, lessThan(0)); // overshoots
      expect(w.angle.abs(), lessThan(0.05)); // and calms down
    });

    test('never swings past the max, even on a huge jolt or slow frame', () {
      final w = LimbWiggle()..kick(1000);
      w.update(0.5, 0);
      expect(w.angle.abs(), lessThanOrEqualTo(Tuning.limbMaxAngle));
    });
  });

  test('arms flail in the air, opposite each other, and only sway on the '
      'ground', () {
    var airMax = 0.0;
    var groundMax = 0.0;
    for (var t = 0.0; t < 2; t += 0.01) {
      final left = armTarget(time: t, left: true, inAir: true, spinRate: 0);
      final right = armTarget(time: t, left: false, inAir: true, spinRate: 0);
      expect(left, closeTo(-right, 1e-9));
      airMax = math.max(airMax, left.abs());
      groundMax = math.max(
        groundMax,
        armTarget(time: t, left: true, inAir: false, spinRate: 0).abs(),
      );
    }
    expect(airMax, greaterThan(groundMax * 1.5));
  });

  test('arms trail the spin', () {
    // At a moment with no flail swing (t = 0, left arm), the arm sits
    // against the spin direction.
    final clockwise = armTarget(
      time: 0,
      left: true,
      inAir: true,
      spinRate: Tuning.spinSpeed,
    );
    expect(clockwise, lessThan(0));
  });

  test('legs tuck in the air and reach out straight before touchdown', () {
    final tucked = legTarget(time: 0, left: true, inAir: true);
    final landing = legTarget(
      time: 0,
      left: true,
      inAir: true,
      timeToLanding: 0,
    );
    expect(tucked, closeTo(Tuning.legTuckAngle, 1e-9));
    expect(landing, 0);
    expect(legTarget(time: 0.3, left: true, inAir: false), 0);
  });

  test('worse landings jolt the limbs harder', () {
    expect(
      landingKick(LandingType.crash),
      greaterThan(landingKick(LandingType.oneFoot)),
    );
    expect(
      landingKick(LandingType.oneFoot),
      greaterThan(landingKick(LandingType.clean)),
    );
  });

  test('time to fall: higher and slower-rising takes longer', () {
    expect(timeToFall(0, 5), 0);
    expect(timeToFall(10, 0), greaterThan(timeToFall(2, 0)));
    expect(timeToFall(5, -8), greaterThan(timeToFall(5, 8)));
    // h = ½ g t² from rest.
    expect(timeToFall(Tuning.gravity / 2, 0), closeTo(1, 1e-9));
  });
}
