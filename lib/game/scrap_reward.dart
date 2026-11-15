import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import 'landing.dart';
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
List<ScrapLine> scrapReward(RunStats stats, {required bool newBest}) {
  final clean = stats.landingsOf(LandingType.clean);
  final headFlight = stats.headFlight ?? 0;
  final lines = [
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
  return [lines.first, ...lines.skip(1).where((line) => line.amount > 0)];
}

/// Total of a breakdown from [scrapReward].
int scrapTotal(List<ScrapLine> lines) =>
    lines.fold(0, (sum, line) => sum + line.amount);
