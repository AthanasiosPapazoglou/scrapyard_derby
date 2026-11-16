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

  test('each track moves only its own values', () {
    const base = RobotStats.base;
    final plating = at(UpgradeTrack.plating, 1);
    expect(plating.limbMaxHp, closeTo(Tuning.limbMaxHp * 1.15, 1e-9));
    expect(plating.cleanBounce, base.cleanBounce);

    final spring = at(UpgradeTrack.springLegs, 2);
    expect(spring.cleanBounce, closeTo(Tuning.cleanBounce * 1.12, 1e-9));
    expect(spring.cleanToleranceDeg, Tuning.cleanLandingToleranceDeg + 4);
    expect(spring.limbMaxHp, base.limbMaxHp);

    final gyro = at(UpgradeTrack.gyroArms, 3);
    expect(gyro.counterSpinTime, closeTo(Tuning.counterSpinTime * 0.7, 1e-9));
    expect(gyro.releaseSpinTime, closeTo(Tuning.releaseSpinTime * 0.7, 1e-9));

    final core = at(UpgradeTrack.energyCore, 1);
    expect(
      core.spinEnergyPerTurn,
      closeTo(Tuning.spinEnergyPerTurn * 1.1, 1e-9),
    );
    expect(core.spinEnergyMaxTurns, Tuning.spinEnergyMaxTurns + 0.25);

    final rocket = at(UpgradeTrack.rocketHead, 2);
    expect(rocket.headLaunchScale, closeTo(1.16, 1e-9));
    expect(
      rocket.headRocketBurnTime,
      closeTo(Tuning.headRocketBurnTime + 0.16, 1e-9),
    );
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

  test('caps hold, even for levels past the max', () {
    final maxed = RobotStats.fromLevels({
      for (final track in UpgradeTrack.values) track: 99,
    });
    expect(maxed.limbMaxHp, lessThanOrEqualTo(Tuning.platingHpMax));
    expect(maxed.cleanBounce, lessThanOrEqualTo(Tuning.springBounceMax));
    expect(
      maxed.cleanToleranceDeg,
      lessThanOrEqualTo(Tuning.springToleranceMax),
    );
    // Clean must stay stricter than one-foot.
    expect(maxed.cleanToleranceDeg, lessThan(Tuning.oneFootToleranceDeg));
    expect(
      maxed.counterSpinTime,
      greaterThanOrEqualTo(Tuning.counterSpinTime * Tuning.gyroTimeMinShare),
    );
    expect(
      spinEnergyBounce(100, stats: maxed),
      lessThanOrEqualTo(Tuning.coreMaxExtraBounce),
    );
    expect(
      maxed.headLaunchScale,
      lessThanOrEqualTo(Tuning.rocketSpeedMaxScale),
    );
    expect(maxed.headRocketBurnTime, lessThanOrEqualTo(Tuning.rocketBurnMax));
    // Levels past the max count as the max.
    expect(
      maxed.limbMaxHp,
      at(UpgradeTrack.plating, Tuning.upgradeMaxLevel).limbMaxHp,
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
