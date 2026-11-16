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

/// One stat a Workshop slot changes: its plain-word label, what it means,
/// how to read it from [RobotStats] and how to show it.
@immutable
class StatDef {
  const StatDef(
    this.slot,
    this.label,
    this.hint,
    this.value,
    this.format, {
    this.lowerIsBetter = false,
  });

  final UpgradeTrack slot;
  final String label;
  final String hint;
  final double Function(RobotStats s) value;
  final String Function(double v) format;

  /// True for times: less is better (faster control).
  final bool lowerIsBetter;
}

String _fixed(double v, int decimals, String unit) =>
    '${v.toStringAsFixed(decimals)}$unit';
String _percent(double v) => '${(v * 100).round()}%';

/// Every stat the Workshop slots change, in Workshop order (stats screen
/// gauges and the Workshop readout).
final List<StatDef> statDefs = [
  StatDef(
    UpgradeTrack.springLegs,
    'Jump',
    'Bounce of a clean landing',
    (s) => s.cleanBounce,
    (v) => _fixed(v, 1, ' m/s'),
  ),
  StatDef(
    UpgradeTrack.springLegs,
    'Landing window',
    'How tilted a landing can be and still count as clean',
    (s) => s.cleanToleranceDeg,
    (v) => _fixed(v, 0, '°'),
  ),
  StatDef(
    UpgradeTrack.springLegs,
    'Grip',
    'Speed kept on a one-foot landing',
    (s) => s.oneFootSpeedKept,
    _percent,
  ),
  StatDef(
    UpgradeTrack.gyroArms,
    'Flip speed',
    'Time to swing the spin around when you hold',
    (s) => s.counterSpinTime,
    (v) => _fixed(v, 2, ' s'),
    lowerIsBetter: true,
  ),
  StatDef(
    UpgradeTrack.gyroArms,
    'Recovery',
    'Time to spin back to normal when you let go',
    (s) => s.releaseSpinTime,
    (v) => _fixed(v, 2, ' s'),
    lowerIsBetter: true,
  ),
  StatDef(
    UpgradeTrack.plating,
    'Toughness',
    'Damage each part takes before it breaks',
    (s) => s.limbMaxHp,
    (v) => _fixed(v, 0, ' HP'),
  ),
  StatDef(
    UpgradeTrack.plating,
    'Crash armor',
    'Speed kept when you crash',
    (s) => s.crashSpeedKept,
    _percent,
  ),
  StatDef(
    UpgradeTrack.rocketHead,
    'Rocket power',
    'How hard the head is fired off',
    (s) => s.headLaunchScale,
    (v) => '×${v.toStringAsFixed(2)}',
  ),
  StatDef(
    UpgradeTrack.rocketHead,
    'Rocket burn',
    'How long the head keeps thrusting',
    (s) => s.headRocketBurnTime,
    (v) => _fixed(v, 2, ' s'),
  ),
  StatDef(
    UpgradeTrack.rocketHead,
    'Thrust',
    'How hard the rocket pushes during the burn',
    (s) => s.headRocketThrust,
    (v) => _fixed(v, 1, ' m/s²'),
  ),
  StatDef(
    UpgradeTrack.energyCore,
    'Spin power',
    'Extra bounce from each spin in the air',
    (s) => s.spinEnergyPerTurn,
    (v) => _fixed(v, 1, ' m/s'),
  ),
  StatDef(
    UpgradeTrack.energyCore,
    'Energy tank',
    'Most spins one jump can store',
    (s) => s.spinEnergyMaxTurns,
    (v) => _fixed(v, 1, ' turns'),
  ),
  StatDef(
    UpgradeTrack.energyCore,
    'Overdrive',
    'Share of the spin energy that also pushes you forward',
    (s) => s.energyForwardShare,
    _percent,
  ),
];

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
  RobotStats withNext(UpgradeTrack slot) => RobotStats.fromLevels({
    for (final s in UpgradeTrack.values)
      s: s == slot ? installed(s) + 1 : installed(s),
  });

  return [
    for (final def in statDefs)
      StatLine(
        slot: def.slot,
        label: def.label,
        hint: def.hint,
        base: def.value(RobotStats.base),
        now: def.value(now),
        next: installed(def.slot) >= Tuning.upgradeMaxLevel
            ? null
            : def.value(withNext(def.slot)),
        reachable: def.value(reachable),
        max: def.value(best),
        format: def.format,
        lowerIsBetter: def.lowerIsBetter,
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
