import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/run_stats.dart';
import 'package:scrapyard_derby/game/scrap_reward.dart';

void main() {
  test('full breakdown: distance, clean landings, head flight, new best', () {
    final stats = RunStats()
      ..distance = 415
      ..addLanding(LandingType.clean)
      ..addLanding(LandingType.clean)
      ..addLanding(LandingType.clean)
      ..addLanding(LandingType.crash)
      ..headLaunchedAt(380)
      ..headLandedAt(415);
    final lines = scrapReward(stats, newBest: true);

    final distance = (415 / Tuning.scrapMetersPerScrap).floor();
    final clean = 3 * Tuning.scrapPerCleanLanding;
    final head = (35 / Tuning.scrapHeadFlightMetersPerScrap).floor();
    expect(lines, [
      ScrapLine('Distance', distance),
      ScrapLine('Clean landings x3', clean),
      ScrapLine('Head flight 35 m', head),
      const ScrapLine('New best', Tuning.scrapNewBestBonus),
    ]);
    expect(
      scrapTotal(lines),
      distance + clean + head + Tuning.scrapNewBestBonus,
    );
  });

  test('a backwards head flight earns no bonus', () {
    final stats = RunStats()
      ..distance = 100
      ..headLaunchedAt(120)
      ..headLandedAt(100);
    final lines = scrapReward(stats, newBest: false);
    expect(lines.map((l) => l.label), isNot(contains(startsWith('Head'))));
    expect(scrapTotal(lines), greaterThanOrEqualTo(0));
  });

  test('empty bonuses are left out, distance always shows', () {
    final stats = RunStats()..distance = 3;
    final lines = scrapReward(stats, newBest: false);
    expect(lines, [const ScrapLine('Distance', 0)]);
    expect(scrapTotal(lines), 0);
  });
}
