import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import 'robot_stats.dart';

/// One gauge of the robot stats screen: a stat's value on the plain robot,
/// now, with the slot's next part, with every part for sale right now, and
/// the most it can ever be.
@immutable
class StatLine {
  const StatLine({
    required this.slot,
    required this.label,
    required this.hint,
    required this.base,
    required this.now,
    required this.next,
    required this.reachable,
    required this.max,
    required this.format,
    this.lowerIsBetter = false,
  });

  /// The Workshop slot whose parts change this stat.
  final UpgradeTrack slot;

  /// Plain words, e.g. "Jump", and what it means, e.g. "Bounce of a clean
  /// landing".
  final String label;
  final String hint;

  /// The plain scrap robot (tier 0 everywhere).
  final double base;

  /// Installed parts / best parts on sale now / best parts in the game.
  final double now;

  /// With the slot's next part installed; null when the slot is maxed.
  final double? next;
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
    String hint,
    double Function(RobotStats s) value,
    String Function(double v) format, {
    bool lowerIsBetter = false,
  }) => StatLine(
    slot: slot,
    label: label,
    hint: hint,
    base: value(RobotStats.base),
    now: value(now),
    next: installed(slot) >= Tuning.upgradeMaxLevel
        ? null
        : value(
            RobotStats.fromLevels({
              for (final s in UpgradeTrack.values)
                s: s == slot ? installed(s) + 1 : installed(s),
            }),
          ),
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
      'Jump',
      'Bounce of a clean landing',
      (s) => s.cleanBounce,
      (v) => fixed(v, 1, ' m/s'),
    ),
    line(
      UpgradeTrack.springLegs,
      'Landing window',
      'How tilted a landing can be and still count as clean',
      (s) => s.cleanToleranceDeg,
      (v) => fixed(v, 0, '°'),
    ),
    line(
      UpgradeTrack.gyroArms,
      'Flip speed',
      'Time to swing the spin around when you hold',
      (s) => s.counterSpinTime,
      (v) => fixed(v, 2, ' s'),
      lowerIsBetter: true,
    ),
    line(
      UpgradeTrack.plating,
      'Toughness',
      'Damage each part takes before it breaks',
      (s) => s.limbMaxHp,
      (v) => fixed(v, 0, ' HP'),
    ),
    line(
      UpgradeTrack.rocketHead,
      'Rocket power',
      'How hard the head is fired off',
      (s) => s.headLaunchScale,
      (v) => '×${v.toStringAsFixed(2)}',
    ),
    line(
      UpgradeTrack.rocketHead,
      'Rocket burn',
      'How long the head keeps thrusting',
      (s) => s.headRocketBurnTime,
      (v) => fixed(v, 2, ' s'),
    ),
    line(
      UpgradeTrack.energyCore,
      'Spin power',
      'Extra bounce from each spin in the air',
      (s) => s.spinEnergyPerTurn,
      (v) => fixed(v, 1, ' m/s'),
    ),
    line(
      UpgradeTrack.energyCore,
      'Energy tank',
      'Most spins one jump can store',
      (s) => s.spinEnergyMaxTurns,
      (v) => fixed(v, 1, ' turns'),
    ),
  ];
}

/// How upgraded the robot is overall, 0 (scrap robot) to 1 (every slot at
/// the top tier).
double powerShare(int Function(UpgradeTrack slot) installed) =>
    UpgradeTrack.values.fold(0, (sum, slot) => sum + installed(slot)) /
    (UpgradeTrack.values.length * Tuning.upgradeMaxLevel);

/// A title for the robot's overall power ([powerShare]).
String powerRank(double share) => switch (share) {
  < 0.15 => 'Scrap Rookie',
  < 0.35 => 'Junk Jumper',
  < 0.55 => 'Rust Racer',
  < 0.75 => 'Iron Flyer',
  < 0.95 => 'Neon Ace',
  _ => 'Obsidian Legend',
};
