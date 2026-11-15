import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import 'landing.dart';
import 'levels.dart';
import 'run_stats.dart';

/// One line of the scrap breakdown on the run summary, e.g. "Distance +41".
@immutable
class ScrapLine {
  const ScrapLine(this.label, this.amount);

  final String label;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is ScrapLine && other.label == label && other.amount == amount;

  @override
  int get hashCode => Object.hash(label, amount);

  @override
  String toString() => '$label +$amount';
}

/// The scrap a finished run earns, line by line (numbers in [Tuning]).
/// Lines worth nothing are left out, except distance, which always shows.
///
/// On top of the run's own lines: the [level]'s multiplier and the
/// permanent [starBonus] (share, e.g. 0.12) and the Scrap Magnet gadget's
/// [magnetBonus] each add a share of that subtotal, and every star earned for the first time ([newStars]) pays a
/// flat bonus.
List<ScrapLine> scrapReward(
  RunStats stats, {
  required bool newBest,
  int level = 1,
  double starBonus = 0,
  int newStars = 0,
  double magnetBonus = 0,
}) {
  final clean = stats.landingsOf(LandingType.clean);
  // A backwards head launch earns nothing (but costs nothing either).
  final headFlight = math.max(0.0, stats.headFlight ?? 0);
  final runLines = [
    ScrapLine(
      'Distance',
      (stats.distance / Tuning.scrapMetersPerScrap).floor(),
    ),
    ScrapLine('Clean landings x$clean', clean * Tuning.scrapPerCleanLanding),
    ScrapLine(
      'Head flight ${headFlight.toStringAsFixed(0)} m',
      (headFlight / Tuning.scrapHeadFlightMetersPerScrap).floor(),
    ),
    ScrapLine('New best', newBest ? Tuning.scrapNewBestBonus : 0),
  ];
  final subtotal = scrapTotal(runLines);
  final multiplier = Levels.of(level).scrapMultiplier;
  final lines = [
    ...runLines,
    ScrapLine(
      'Level $level x${multiplier.toStringAsFixed(1)}',
      (subtotal * (multiplier - 1)).round(),
    ),
    ScrapLine(
      'Stars +${(starBonus * 100).round()}%',
      (subtotal * starBonus).round(),
    ),
    ScrapLine(
      'Scrap Magnet +${(magnetBonus * 100).round()}%',
      (subtotal * magnetBonus).round(),
    ),
    ScrapLine('New star x$newStars', newStars * Tuning.scrapPerNewStar),
  ];
  return [lines.first, ...lines.skip(1).where((line) => line.amount > 0)];
}

/// Total of a breakdown from [scrapReward].
int scrapTotal(List<ScrapLine> lines) =>
    lines.fold(0, (sum, line) => sum + line.amount);
