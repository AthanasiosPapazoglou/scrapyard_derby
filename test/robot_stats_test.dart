import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/damage.dart';
import 'package:scrapyard_derby/game/head_launch.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';
import 'package:scrapyard_derby/game/spin.dart';

RobotStats at(UpgradeTrack track, int level) =>
    RobotStats.fromLevels({track: level});

void main() {
  test('level 0 equals the plain Tuning values', () {
    final s = RobotStats.fromLevels(const {});
    expect(s.limbMaxHp, Tuning.limbMaxHp);
    expect(s.cleanBounce, Tuning.cleanBounce);
    expect(s.cleanToleranceDeg, Tuning.cleanLandingToleranceDeg);
    expect(s.counterSpinTime, Tuning.counterSpinTime);
    expect(s.releaseSpinTime, Tuning.releaseSpinTime);
    expect(s.spinEnergyPerTurn, Tuning.spinEnergyPerTurn);
    expect(s.spinEnergyMaxTurns, Tuning.spinEnergyMaxTurns);
    expect(s.headLaunchScale, 1);
    expect(s.headRocketBurnTime, Tuning.headRocketBurnTime);
    // The energy cap never limits the plain robot.
    expect(
      Tuning.spinEnergyMaxTurns * Tuning.spinEnergyPerTurn,
      lessThanOrEqualTo(s.maxEnergyBounce),
    );
  });

  test('tier 0 of every table is the plain robot', () {
    expect(Tuning.platingHp.first, Tuning.limbMaxHp);
    expect(Tuning.springBounceScale.first, 1);
    expect(Tuning.springToleranceDeg.first, Tuning.cleanLandingToleranceDeg);
    expect(Tuning.gyroTimeShare.first, 1);
    expect(Tuning.corePerTurnScale.first, 1);
    expect(Tuning.coreTankTurns.first, Tuning.spinEnergyMaxTurns);
    expect(Tuning.rocketSpeedScale.first, 1);
    expect(Tuning.rocketBurnTime.first, Tuning.headRocketBurnTime);
    expect(Tuning.rocketThrust.first, Tuning.headRocketThrust);
    for (final table in _tables) {
      expect(table, hasLength(Tuning.upgradeMaxLevel + 1));
    }
  });

  test('each track moves only its own values', () {
    const base = RobotStats.base;
    final plating = at(UpgradeTrack.plating, 1);
    expect(plating.limbMaxHp, Tuning.platingHp[1]);
    expect(plating.cleanBounce, base.cleanBounce);

    final spring = at(UpgradeTrack.springLegs, 2);
    expect(
      spring.cleanBounce,
      closeTo(Tuning.cleanBounce * Tuning.springBounceScale[2], 1e-9),
    );
    expect(spring.cleanToleranceDeg, Tuning.springToleranceDeg[2]);
    expect(spring.limbMaxHp, base.limbMaxHp);

    final gyro = at(UpgradeTrack.gyroArms, 3);
    expect(
      gyro.counterSpinTime,
      closeTo(Tuning.counterSpinTime * Tuning.gyroTimeShare[3], 1e-9),
    );
    expect(
      gyro.releaseSpinTime,
      closeTo(Tuning.releaseSpinTime * Tuning.gyroTimeShare[3], 1e-9),
    );

    final core = at(UpgradeTrack.energyCore, 1);
    expect(
      core.spinEnergyPerTurn,
      closeTo(Tuning.spinEnergyPerTurn * Tuning.corePerTurnScale[1], 1e-9),
    );
    expect(core.spinEnergyMaxTurns, Tuning.coreTankTurns[1]);

    final rocket = at(UpgradeTrack.rocketHead, 2);
    expect(rocket.headLaunchScale, Tuning.rocketSpeedScale[2]);
    expect(rocket.headRocketBurnTime, Tuning.rocketBurnTime[2]);
    expect(rocket.headRocketThrust, Tuning.rocketThrust[2]);
  });

  test('more levels never make a value worse', () {
    for (final track in UpgradeTrack.values) {
      for (var level = 1; level <= Tuning.upgradeMaxLevel; level++) {
        final before = at(track, level - 1);
        final after = at(track, level);
        expect(after.limbMaxHp, greaterThanOrEqualTo(before.limbMaxHp));
        expect(after.cleanBounce, greaterThanOrEqualTo(before.cleanBounce));
        expect(
          after.counterSpinTime,
          lessThanOrEqualTo(before.counterSpinTime),
        );
        expect(
          spinEnergyBounce(after.spinEnergyMaxTurns, stats: after),
          greaterThanOrEqualTo(
            spinEnergyBounce(before.spinEnergyMaxTurns, stats: before),
          ),
        );
        expect(
          after.headLaunchScale,
          greaterThanOrEqualTo(before.headLaunchScale),
        );
      }
    }
  });

  test('every tier is a real step: the top tier is far above tier 0', () {
    RobotStats top(UpgradeTrack track) => at(track, Tuning.upgradeMaxLevel);
    const base = RobotStats.base;
    expect(top(UpgradeTrack.plating).limbMaxHp / base.limbMaxHp, 2.4);
    expect(
      top(UpgradeTrack.springLegs).cleanBounce / base.cleanBounce,
      greaterThanOrEqualTo(1.3), // 1.1.1 (D33): was ≥ 1.4
    );
    expect(
      top(UpgradeTrack.gyroArms).counterSpinTime / base.counterSpinTime,
      lessThanOrEqualTo(0.5),
    );
    expect(
      top(UpgradeTrack.energyCore).spinEnergyPerTurn / base.spinEnergyPerTurn,
      greaterThanOrEqualTo(1.8),
    );
    // Steps grow (or stay) from tier to tier, so later tiers feel bigger.
    for (final table in _tables) {
      final rising = table.last > table.first;
      for (var i = 2; i < table.length; i++) {
        final step = (table[i] - table[i - 1]) * (rising ? 1 : -1);
        final before = (table[i - 1] - table[i - 2]) * (rising ? 1 : -1);
        expect(step, greaterThan(0), reason: '$table');
        expect(step, greaterThanOrEqualTo(before - 1e-9), reason: '$table');
      }
    }
  });

  test('the top head flies at least twice as far as the first one', () {
    final first = _headFlight(RobotStats.base);
    final top = _headFlight(
      at(UpgradeTrack.rocketHead, Tuning.upgradeMaxLevel),
    );
    expect(top, greaterThanOrEqualTo(2 * first));
    // Every head flies further than the one before.
    for (var tier = 1; tier <= Tuning.upgradeMaxLevel; tier++) {
      expect(
        _headFlight(at(UpgradeTrack.rocketHead, tier)),
        greaterThan(_headFlight(at(UpgradeTrack.rocketHead, tier - 1))),
      );
    }
  });

  test('levels past the max count as the max', () {
    final maxed = RobotStats.fromLevels({
      for (final track in UpgradeTrack.values) track: 99,
    });
    expect(
      maxed.limbMaxHp,
      at(UpgradeTrack.plating, Tuning.upgradeMaxLevel).limbMaxHp,
    );
    // Clean must stay stricter than one-foot.
    expect(maxed.cleanToleranceDeg, lessThan(Tuning.oneFootToleranceDeg));
    expect(
      spinEnergyBounce(100, stats: maxed),
      lessThanOrEqualTo(Tuning.coreMaxExtraBounce),
    );
  });

  test('the game logic uses the upgraded values', () {
    // Plating: the first arm survives a hit that breaks it at level 0.
    final tough = RobotDamage(limbMaxHp: at(UpgradeTrack.plating, 2).limbMaxHp);
    expect(tough.add(Tuning.limbMaxHp + 1), isEmpty);
    expect(RobotDamage().add(Tuning.limbMaxHp + 1), [RobotSlot.leftArm]);

    // Spring legs: an angle just past the plain tolerance is now clean.
    final angle = (Tuning.cleanLandingToleranceDeg + 1) * 3.14159265 / 180;
    expect(classifyLanding(PartKind.leg, angle), LandingType.oneFoot);
    expect(
      classifyLanding(
        PartKind.leg,
        angle,
        stats: at(UpgradeTrack.springLegs, 1),
      ),
      LandingType.clean,
    );

    // Gyro arms: one frame of holding moves the control further.
    final plain = nextSpinControl(1, holding: true, dt: 0.05);
    final gyro = nextSpinControl(
      1,
      holding: true,
      dt: 0.05,
      stats: at(UpgradeTrack.gyroArms, 5),
    );
    expect(gyro, lessThan(plain));

    // Rocket head: a faster launch.
    final up = Vector2(0, -1);
    final carried = Vector2(10, 0);
    final slow = headLaunchVelocity(
      carried: carried,
      facing: up,
      groundNormal: up,
    );
    final fast = headLaunchVelocity(
      carried: carried,
      facing: up,
      groundNormal: up,
      stats: at(UpgradeTrack.rocketHead, 3),
    );
    expect(fast.length, greaterThan(slow.length));
  });

  test('prices rise per level and stop at the max', () {
    for (final track in UpgradeTrack.values) {
      int? last;
      for (var level = 0; level < Tuning.upgradeMaxLevel; level++) {
        final price = track.priceAfter(level)!;
        if (last != null) {
          expect(price, greaterThan(last));
        }
        last = price;
      }
      expect(track.priceAfter(Tuning.upgradeMaxLevel), isNull);
    }
  });
}

/// Every per-tier table.
const List<List<double>> _tables = [
  Tuning.platingHp,
  Tuning.springBounceScale,
  Tuning.springToleranceDeg,
  Tuning.gyroTimeShare,
  Tuning.corePerTurnScale,
  Tuning.coreTankTurns,
  Tuning.rocketSpeedScale,
  Tuning.rocketBurnTime,
  Tuning.rocketThrust,
];

/// Meters a head flies along a straight 35° downhill slope after a robot
/// lands upright at 20 m/s: launch, rocket burn, gravity, until it drops
/// back onto the slope. (Real hills have bumps; this compares heads.)
double _headFlight(RobotStats stats) {
  final slope = 35 * math.pi / 180;
  final normal = Vector2(math.sin(slope), -math.cos(slope));
  final downhill = Vector2(math.cos(slope), math.sin(slope));
  final v = headLaunchVelocity(
    carried: downhill * 20,
    facing: normal,
    groundNormal: normal,
    stats: stats,
  );
  final rocket = v.normalized();
  final p = Vector2(0, -0.3);
  const dt = 1 / 240;
  for (var t = 0.0; t < 60; t += dt) {
    if (t < stats.headRocketBurnTime) {
      v.add(rocket * (stats.headRocketThrust * dt));
    }
    v.y += Tuning.gravity * dt;
    p.add(v * dt);
    if (t > 0.3 && p.y > p.x * math.tan(slope)) {
      return p.x;
    }
  }
  return p.x;
}
