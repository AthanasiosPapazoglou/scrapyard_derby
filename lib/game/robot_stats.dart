import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/tuning.dart';

/// The five Workshop upgrade tracks, one per robot part.
enum UpgradeTrack {
  plating(
    id: 'plating',
    name: 'Plating',
    part: 'Body',
    description: 'Tougher parts: more damage before each limb breaks.',
  ),
  springLegs(
    id: 'springLegs',
    name: 'Spring legs',
    part: 'Legs',
    description: 'Bouncier clean landings, and a wider angle counts as clean.',
  ),
  gyroArms(
    id: 'gyroArms',
    name: 'Gyro arms',
    part: 'Arms',
    description: 'Faster spin control when you hold and let go.',
  ),
  energyCore(
    id: 'energyCore',
    name: 'Energy core',
    part: 'Core',
    description: 'More energy per spin, and a bigger energy tank.',
  ),
  rocketHead(
    id: 'rocketHead',
    name: 'Rocket head',
    part: 'Head',
    description: 'A faster head launch and a longer rocket burn.',
  );

  const UpgradeTrack({
    required this.id,
    required this.name,
    required this.part,
    required this.description,
  });

  /// Key in the saved profile. Never change it, or saves lose the level.
  final String id;
  final String name;
  final String part;
  final String description;

  /// Scrap price of the next level after [level], or null when maxed.
  int? priceAfter(int level) =>
      level < Tuning.upgradeMaxLevel ? Tuning.upgradePrices[level] : null;
}

/// The robot's effective numbers: the [Tuning] base values changed by
/// upgrade levels. Robot, damage, spin, landing and head-launch code read
/// the upgradeable values from here instead of from [Tuning] directly.
///
/// [RobotStats.base] (all levels 0) equals the plain robot exactly.
@immutable
class RobotStats {
  const RobotStats({
    this.limbMaxHp = Tuning.limbMaxHp,
    this.cleanBounce = Tuning.cleanBounce,
    this.cleanToleranceDeg = Tuning.cleanLandingToleranceDeg,
    this.counterSpinTime = Tuning.counterSpinTime,
    this.releaseSpinTime = Tuning.releaseSpinTime,
    this.spinEnergyPerTurn = Tuning.spinEnergyPerTurn,
    this.spinEnergyMaxTurns = Tuning.spinEnergyMaxTurns,
    this.maxEnergyBounce = Tuning.coreMaxExtraBounce,
    this.headLaunchScale = 1,
    this.headRocketBurnTime = Tuning.headRocketBurnTime,
  });

  /// The plain robot, no upgrades.
  static const RobotStats base = RobotStats();

  /// Stats for the given upgrade levels (missing tracks = level 0; levels
  /// are clamped to 0..[Tuning.upgradeMaxLevel]).
  factory RobotStats.fromLevels(Map<UpgradeTrack, int> levels) {
    double level(UpgradeTrack track) =>
        (levels[track] ?? 0).clamp(0, Tuning.upgradeMaxLevel).toDouble();

    final plating = level(UpgradeTrack.plating);
    final spring = level(UpgradeTrack.springLegs);
    final gyro = level(UpgradeTrack.gyroArms);
    final core = level(UpgradeTrack.energyCore);
    final rocket = level(UpgradeTrack.rocketHead);

    final gyroShare = math.max(
      Tuning.gyroTimeMinShare,
      1 - Tuning.gyroTimePerLevel * gyro,
    );
    return RobotStats(
      limbMaxHp: math.min(
        Tuning.platingHpMax,
        Tuning.limbMaxHp * (1 + Tuning.platingHpPerLevel * plating),
      ),
      cleanBounce: math.min(
        Tuning.springBounceMax,
        Tuning.cleanBounce * (1 + Tuning.springBouncePerLevel * spring),
      ),
      cleanToleranceDeg: math.min(
        Tuning.springToleranceMax,
        Tuning.cleanLandingToleranceDeg +
            Tuning.springTolerancePerLevel * spring,
      ),
      counterSpinTime: Tuning.counterSpinTime * gyroShare,
      releaseSpinTime: Tuning.releaseSpinTime * gyroShare,
      spinEnergyPerTurn:
          Tuning.spinEnergyPerTurn * (1 + Tuning.corePerTurnPerLevel * core),
      spinEnergyMaxTurns:
          Tuning.spinEnergyMaxTurns + Tuning.coreCapPerLevel * core,
      headLaunchScale: math.min(
        Tuning.rocketSpeedMaxScale,
        1 + Tuning.rocketSpeedPerLevel * rocket,
      ),
      headRocketBurnTime: math.min(
        Tuning.rocketBurnMax,
        Tuning.headRocketBurnTime + Tuning.rocketBurnPerLevel * rocket,
      ),
    );
  }

  /// Stats for a profile's saved levels, looked up by track id.
  factory RobotStats.fromLevelOf(int Function(String trackId) levelOf) =>
      RobotStats.fromLevels({
        for (final track in UpgradeTrack.values) track: levelOf(track.id),
      });

  /// Damage between one part breaking and the next (see damage.dart).
  final double limbMaxHp;

  /// Bounce speed (m/s) of a clean landing.
  final double cleanBounce;

  /// Max angle (deg) that still counts as a clean landing.
  final double cleanToleranceDeg;

  /// Seconds of holding from full clockwise to full counter-clockwise, and
  /// of letting go to come back (see spin.dart).
  final double counterSpinTime;
  final double releaseSpinTime;

  /// Extra bounce (m/s) per turn of spin energy, and the most turns one
  /// airtime can gather.
  final double spinEnergyPerTurn;
  final double spinEnergyMaxTurns;

  /// Hard cap on the extra bounce from spin energy (m/s).
  final double maxEnergyBounce;

  /// Multiplier on the head launch speed (and its cap).
  final double headLaunchScale;

  /// Seconds of rocket burn after the head launch.
  final double headRocketBurnTime;

  /// A short "now" value for the Workshop, e.g. "115 HP".
  String summary(UpgradeTrack track) => switch (track) {
    UpgradeTrack.plating => '${limbMaxHp.round()} HP per part',
    UpgradeTrack.springLegs =>
      '${cleanBounce.toStringAsFixed(1)} m/s, '
          '${cleanToleranceDeg.round()}°',
    UpgradeTrack.gyroArms => '${counterSpinTime.toStringAsFixed(2)} s flip',
    UpgradeTrack.energyCore =>
      '+${spinEnergyPerTurn.toStringAsFixed(1)}/turn, '
          '${spinEnergyMaxTurns.toStringAsFixed(2)} max',
    UpgradeTrack.rocketHead =>
      '×${headLaunchScale.toStringAsFixed(2)}, '
          '${headRocketBurnTime.toStringAsFixed(2)} s burn',
  };
}
