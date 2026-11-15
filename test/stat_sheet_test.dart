import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';
import 'package:scrapyard_derby/game/stat_sheet.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/robot_stats_page.dart';

void main() {
  test('a plain robot: now is the base, max is every part at the top', () {
    final lines = statSheet(installed: (_) => 0, maxPartTier: 1);
    final best = RobotStats.fromLevels({
      for (final slot in UpgradeTrack.values) slot: Tuning.upgradeMaxLevel,
    });
    final hp = lines.firstWhere((l) => l.label == 'Part HP');
    expect(hp.now, Tuning.limbMaxHp);
    expect(hp.max, best.limbMaxHp);
    expect(
      hp.reachable,
      RobotStats.fromLevels({UpgradeTrack.plating: 1}).limbMaxHp,
    );
    // Every slot has at least one line, and every line can still improve.
    for (final slot in UpgradeTrack.values) {
      expect(lines.where((l) => l.slot == slot), isNotEmpty, reason: slot.name);
    }
    for (final line in lines) {
      expect(line.now, line.base, reason: line.label);
      expect(line.share(line.now), 0, reason: line.label);
      expect(line.share(line.max), 1, reason: line.label);
      expect(
        line.share(line.reachable),
        greaterThanOrEqualTo(line.share(line.now)),
        reason: line.label,
      );
    }
  });

  test('times are better when lower', () {
    final lines = statSheet(
      installed: (_) => Tuning.upgradeMaxLevel,
      maxPartTier: 5,
    );
    final flip = lines.firstWhere((l) => l.label == 'Flip time');
    expect(flip.lowerIsBetter, isTrue);
    expect(flip.max, lessThan(Tuning.counterSpinTime));
    expect(flip.share(flip.now), 1);
    expect(flip.share(Tuning.counterSpinTime), 0);
    expect(flip.share((flip.base + flip.max) / 2), closeTo(0.5, 1e-6));
  });

  test('parts installed above the sale tier still count as reachable', () {
    final lines = statSheet(installed: (_) => 4, maxPartTier: 1);
    for (final line in lines) {
      expect(line.reachable, line.now, reason: line.label);
    }
  });

  testWidgets('stats page shows each stat and the progress bonuses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final profile = PlayerProfile(
      levelBest: {1: Tuning.levels[0].starDistances[1]},
      upgradeLevels: {'plating': 2},
    );
    await tester.pumpWidget(
      MaterialApp(home: RobotStatsPage(profile: profile)),
    );
    final hp = RobotStats.fromLevels({UpgradeTrack.plating: 2}).limbMaxHp;
    expect(
      find.bySemanticsLabel(
        RegExp('^Part HP ${hp.toStringAsFixed(0)} HP, max'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Racer Chassis'), findsOneWidget);
    expect(find.text('2 / 18'), findsOneWidget);
    expect(find.text('+6% / +54%'), findsOneWidget);
    expect(find.text('tier 2 / 5'), findsOneWidget);
  });
}
