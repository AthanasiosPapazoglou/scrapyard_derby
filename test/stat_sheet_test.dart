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
    final hp = lines.firstWhere((l) => l.label == 'Toughness');
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
    final flip = lines.firstWhere((l) => l.label == 'Flip speed');
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

  test('next shows the slot\'s next part, and nothing at the top', () {
    final lines = statSheet(
      installed: (slot) =>
          slot == UpgradeTrack.plating ? Tuning.upgradeMaxLevel : 1,
      maxPartTier: 5,
    );
    final hp = lines.firstWhere((l) => l.label == 'Toughness');
    expect(hp.next, isNull);
    final jump = lines.firstWhere((l) => l.label == 'Jump');
    expect(
      jump.next,
      RobotStats.fromLevels({UpgradeTrack.springLegs: 2}).cleanBounce,
    );
    expect(jump.next, greaterThan(jump.now));
    for (final line in lines) {
      expect(line.hint, isNotEmpty);
    }
  });

  test('power rank climbs with the installed tiers', () {
    expect(powerShare((_) => 0), 0);
    expect(powerShare((_) => Tuning.upgradeMaxLevel), 1);
    expect(powerRank(0), 'Scrap Rookie');
    expect(powerRank(1), 'Obsidian Legend');
    final ranks = [
      for (var t = 0; t <= 5; t++) powerRank(powerShare((_) => t)),
    ];
    expect(ranks.toSet().length, greaterThanOrEqualTo(5));
  });

  testWidgets('stats page shows the parts, gauges, rank and progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final profile = PlayerProfile(
      levelBest: {1: Tuning.levels[0].starDistances[1]},
      upgradeLevels: {'plating': 2},
      gadgetLevels: {'scrapMagnet': 1},
    );
    await tester.pumpWidget(
      MaterialApp(home: RobotStatsPage(profile: profile)),
    );
    await tester.pump();
    // The cards scroll; bring each thing into view before checking it.
    Future<void> reveal(Finder finder) => tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.text('2 / 18'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Power 8%, Scrap Rookie')),
      findsOneWidget,
    );
    expect(find.text(UpgradeTrack.springLegs.partName(0)), findsOneWidget);
    final hp = RobotStats.fromLevels({UpgradeTrack.plating: 2}).limbMaxHp;
    final toughness = find.bySemanticsLabel(
      RegExp('^Toughness ${hp.toStringAsFixed(0)} HP, max'),
    );
    await reveal(toughness);
    expect(toughness, findsOneWidget);
    expect(find.text('Racer Chassis'), findsOneWidget);
    final magnet = find.bySemanticsLabel(RegExp('^Scrap Magnet level 1 of 3'));
    await reveal(magnet);
    expect(magnet, findsOneWidget);
  });
}
