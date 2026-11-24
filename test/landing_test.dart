import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/landing.dart';

double deg(double d) => d * math.pi / 180;

void main() {
  group('classifyLanding', () {
    test('leg landing within the clean tolerance is clean', () {
      expect(classifyLanding(PartKind.leg, deg(10)), LandingType.clean);
      expect(classifyLanding(PartKind.leg, deg(-10)), LandingType.clean);
    });

    test('leg landing between the tolerances is one foot', () {
      final between =
          (Tuning.cleanLandingToleranceDeg + Tuning.oneFootToleranceDeg) / 2;
      expect(classifyLanding(PartKind.leg, deg(between)), LandingType.oneFoot);
    });

    test('leg landing past the one-foot tolerance is a crash', () {
      expect(classifyLanding(PartKind.leg, deg(120)), LandingType.crash);
    });

    test('any non-leg part is a crash even when upright', () {
      for (final kind in [PartKind.torso, PartKind.head, PartKind.arm]) {
        expect(classifyLanding(kind, 0), LandingType.crash);
      }
    });
  });

  group('signedAngleBetween', () {
    test('is zero for the same direction and ±90° for perpendicular', () {
      final up = Vector2(0, -1);
      expect(signedAngleBetween(up, up), closeTo(0, 1e-9));
      expect(
        signedAngleBetween(up, Vector2(1, 0)).abs(),
        closeTo(math.pi / 2, 1e-9),
      );
    });
  });

  group('velocityAfterLanding', () {
    // Flat ground: normal points up (negative y), forward is +x.
    final flatNormal = Vector2(0, -1);

    test('clean landing bounces up and gains forward speed', () {
      final v = velocityAfterLanding(
        LandingType.clean,
        Vector2(10, 5),
        flatNormal,
      );
      // Vector2 stores 32-bit floats, so allow a little rounding.
      expect(v.y, closeTo(-Tuning.cleanBounce, 1e-4));
      expect(v.x, greaterThan(10));
    });

    test('crash loses more speed than one foot', () {
      final start = Vector2(10, 5);
      final oneFoot = velocityAfterLanding(
        LandingType.oneFoot,
        start,
        flatNormal,
      );
      final crash = velocityAfterLanding(LandingType.crash, start, flatNormal);
      expect(oneFoot.x, lessThan(10));
      expect(crash.x, lessThan(oneFoot.x));
      expect(-crash.y, lessThan(-oneFoot.y));
    });

    test('speed along the ground never exceeds the cap', () {
      final v = velocityAfterLanding(
        LandingType.clean,
        Vector2(1000, 0),
        flatNormal,
      );
      expect(v.x, closeTo(Tuning.maxRobotSpeed, 1e-4));
    });
  });

  test(
    'crashes hurt more than one-foot landings, which hurt more than clean',
    () {
      expect(
        landingDamage(LandingType.crash),
        greaterThan(landingDamage(LandingType.oneFoot)),
      );
      expect(
        landingDamage(LandingType.oneFoot),
        greaterThan(landingDamage(LandingType.clean)),
      );
    },
  );

  group('spin energy', () {
    test('spinning gathers energy, in either direction', () {
      var energy = 0.0;
      energy = addSpinEnergy(energy, 0.5); // clockwise
      energy = addSpinEnergy(energy, -0.3); // counter-clockwise
      expect(energy, closeTo(0.8, 1e-9));
    });

    test('counter-clockwise turns gather more than clockwise ones', () {
      const fullTurn = 2 * math.pi;
      // One turn each way in one second (positive = clockwise).
      expect(spinEnergyTurns(fullTurn, 1), closeTo(1, 1e-9));
      expect(
        spinEnergyTurns(-fullTurn, 1),
        closeTo(Tuning.reverseSpinEnergyFactor, 1e-9),
      );
      expect(Tuning.reverseSpinEnergyFactor, greaterThan(1));
    });

    test('energy is capped, so jumps cannot grow forever', () {
      final energy = addSpinEnergy(0, 1000);
      expect(energy, Tuning.spinEnergyMaxTurns);
      expect(
        spinEnergyBounce(energy),
        Tuning.spinEnergyMaxTurns * Tuning.spinEnergyPerTurn,
      );
    });

    test('more gathered energy gives a bigger bounce', () {
      expect(spinEnergyBounce(1.5), greaterThan(spinEnergyBounce(0.5)));
      expect(spinEnergyBounce(0), 0);
    });

    test('a clean landing releases all the energy, sloppy ones less', () {
      final flat = Vector2(0, -1);
      final boost = spinEnergyBounce(1);
      double lift(LandingType type) =>
          -velocityAfterLanding(
            type,
            Vector2(10, 5),
            flat,
            energyBounce: boost,
          ).y -
          -velocityAfterLanding(type, Vector2(10, 5), flat).y;
      expect(lift(LandingType.clean), closeTo(boost, 1e-4));
      expect(
        lift(LandingType.oneFoot),
        closeTo(boost * Tuning.energyReleaseOneFoot, 1e-4),
      );
      expect(
        lift(LandingType.crash),
        closeTo(boost * Tuning.energyReleaseCrash, 1e-4),
      );
    });

    test('released energy also pushes the robot forward', () {
      final flat = Vector2(0, -1);
      final boost = spinEnergyBounce(2);
      final plain = velocityAfterLanding(
        LandingType.clean,
        Vector2(10, 5),
        flat,
      );
      final boosted = velocityAfterLanding(
        LandingType.clean,
        Vector2(10, 5),
        flat,
        energyBounce: boost,
      );
      expect(
        boosted.x - plain.x,
        closeTo(boost * Tuning.energyForwardShare, 1e-4),
      );
    });

    test('a full charge nearly doubles a clean bounce', () {
      final full = spinEnergyBounce(Tuning.spinEnergyMaxTurns);
      expect(full, greaterThan(Tuning.cleanBounce * 0.85));
      expect(isFullCharge(Tuning.spinEnergyMaxTurns), isTrue);
      expect(isFullCharge(Tuning.spinEnergyMaxTurns * 0.5), isFalse);
    });
  });
}
