import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import 'robot_stats.dart';

/// One line of the robot stats screen: a stat's value on the plain robot,
/// now, with every part for sale right now, and the most it can ever be.
@immutable
class StatLine {
  const StatLine({
    required this.slot,
    required this.label,
    required this.base,
    required this.now,
    required this.reachable,
    required this.max,
    required this.format,
    this.lowerIsBetter = false,
  });

  /// The Workshop slot whose parts change this stat.
  final UpgradeTrack slot;
  final String label;

  /// The plain scrap robot (tier 0 everywhere).
  final double base;

  /// Installed parts / best parts on sale now / best parts in the game.
  final double now;
  final double reachable;
  final double max;

  /// Shows a value with its unit, e.g. "13.5 m/s".
  final String Function(double value) format;

  /// True for times: less is better (faster control).
  final bool lowerIsBetter;

  /// Upgrade progress of [value] for a bar: 0 = the plain robot, 1 = max.
  /// (Works for times too, where max is the smallest value.)
  double share(double value) =>
      max == base ? 1 : ((value - base) / (max - base)).clamp(0.0, 1.0);
}

/// The robot's stats for the stats screen, grouped by slot in Workshop
/// order. [installed] gives each slot's installed tier; [maxPartTier] is
/// the best tier on sale now (see `PlayerProfile.maxPartTier`).
List<StatLine> statSheet({
  required int Function(UpgradeTrack slot) installed,
  required int maxPartTier,
}) {
  final now = RobotStats.fromLevels({
    for (final slot in UpgradeTrack.values) slot: installed(slot),
  });
  final reachable = RobotStats.fromLevels({
    for (final slot in UpgradeTrack.values)
      slot: math.max(installed(slot), maxPartTier),
  });
  final best = RobotStats.fromLevels({
    for (final slot in UpgradeTrack.values) slot: Tuning.upgradeMaxLevel,
  });

  StatLine line(
    UpgradeTrack slot,
    String label,
    double Function(RobotStats s) value,
    String Function(double v) format, {
    bool lowerIsBetter = false,
  }) => StatLine(
    slot: slot,
    label: label,
    base: value(RobotStats.base),
    now: value(now),
    reachable: value(reachable),
    max: value(best),
    format: format,
    lowerIsBetter: lowerIsBetter,
  );

  String fixed(double v, int decimals, String unit) =>
      '${v.toStringAsFixed(decimals)}$unit';

  return [
    line(
      UpgradeTrack.springLegs,
      'Clean bounce',
      (s) => s.cleanBounce,
      (v) => fixed(v, 1, ' m/s'),
    ),
    line(
      UpgradeTrack.springLegs,
      'Clean angle',
      (s) => s.cleanToleranceDeg,
      (v) => fixed(v, 0, '°'),
    ),
    line(
      UpgradeTrack.gyroArms,
      'Flip time',
      (s) => s.counterSpinTime,
      (v) => fixed(v, 2, ' s'),
      lowerIsBetter: true,
    ),
    line(
      UpgradeTrack.gyroArms,
      'Recover time',
      (s) => s.releaseSpinTime,
      (v) => fixed(v, 2, ' s'),
      lowerIsBetter: true,
    ),
    line(
      UpgradeTrack.plating,
      'Part HP',
      (s) => s.limbMaxHp,
      (v) => fixed(v, 0, ' HP'),
    ),
    line(
      UpgradeTrack.rocketHead,
      'Launch power',
      (s) => s.headLaunchScale,
      (v) => '×${v.toStringAsFixed(2)}',
    ),
    line(
      UpgradeTrack.rocketHead,
      'Rocket burn',
      (s) => s.headRocketBurnTime,
      (v) => fixed(v, 2, ' s'),
    ),
    line(
      UpgradeTrack.energyCore,
      'Energy per turn',
      (s) => s.spinEnergyPerTurn,
      (v) => fixed(v, 1, ' m/s'),
    ),
    line(
      UpgradeTrack.energyCore,
      'Energy tank',
      (s) => s.spinEnergyMaxTurns,
      (v) => fixed(v, 2, ' turns'),
    ),
    line(
      UpgradeTrack.energyCore,
      'Max energy boost',
      (s) => math.min(
        s.spinEnergyPerTurn * s.spinEnergyMaxTurns,
        s.maxEnergyBounce,
      ),
      (v) => fixed(v, 1, ' m/s'),
    ),
  ];
}
