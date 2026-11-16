import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/damage.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/game/run_stats.dart';
import 'package:scrapyard_derby/game/scrap_reward.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/hud.dart';
import 'package:scrapyard_derby/ui/run_summary.dart';

void main() {
  testWidgets('HUD shows distance, debug info and the run summary', (
    tester,
  ) async {
    // The summary card is wide; use a landscape phone-sized screen.
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // The game is never loaded here, so no physics runs; we only drive the
    // HUD through its ValueNotifier.
    final profile = PlayerProfile(scrap: 120);
    final game = DerbyGame(profile: profile);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Hud(game: game, onMenu: () {}, onPause: () {}),
        ),
      ),
    );

    expect(find.byTooltip('Restart'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    // The distance is outlined text: drawn twice (ink outline + fill).
    expect(find.text('0 m'), findsNWidgets(2));
    // Debug numbers are hidden until Settings turns them on.
    expect(find.textContaining('↻ 100%'), findsNothing);
    profile.showDebugInfo = true;
    await tester.pump();
    expect(find.textContaining('↻ 100%'), findsOneWidget);
    expect(find.textContaining('HEAD DOWN'), findsNothing);

    final stats = RunStats()
      ..addLanding(LandingType.clean)
      ..addLimbLost()
      ..reportHeight(14.26)
      ..headLaunchedAt(370)
      ..headLandedAt(412);
    game.hud.value = HudInfo(
      speed: 12.3,
      spin: -0.4,
      lastLanding: LandingType.clean,
      distance: 412,
      bestDistance: 500,
      limbsLeft: 0,
      partHp: const {RobotSlot.leftArm: 0, RobotSlot.rightArm: 0.5},
      result: RunResult(
        end: RunEnd.headDown,
        distance: 412,
        isNewBest: false,
        stats: stats,
        scrap: const [
          ScrapLine('Distance', 41),
          ScrapLine('Clean landings x1', 2),
        ],
        starsBefore: 0,
        starsAfter: 1,
      ),
    );
    await tester.pump();
    // Let the card fill in (stars, stamp, scrap counting up).
    await tester.pump(RunSummary.revealTime);

    expect(find.textContaining('12.3 m/s'), findsOneWidget);
    expect(find.textContaining('↺ 40%'), findsOneWidget);
    expect(find.textContaining('Both feet'), findsOneWidget);
    expect(find.textContaining('0/4'), findsOneWidget);
    expect(find.textContaining('HEAD DOWN'), findsOneWidget);
    // Top counter (outline + fill) and the summary.
    expect(find.text('412 m'), findsNWidgets(3));
    expect(find.text('Best: 500 m'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Levels'), findsOneWidget);
    // Level and stars; no next level while level 2 is locked.
    expect(find.text('LEVEL 1 · RUST HOLLOW'), findsOneWidget);
    expect(find.bySemanticsLabel('1 of 3 stars'), findsOneWidget);
    expect(find.text('Next level'), findsNothing);
    // Run stats and the scrap breakdown.
    expect(find.text('14.3 m'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('42 m'), findsOneWidget);
    expect(find.text('+41'), findsOneWidget);
    // The total is outlined text (ink outline + fill).
    expect(find.text('+43'), findsNWidgets(2));
    expect(find.text('You have 120'), findsOneWidget);
    // No pause once the run is over.
    expect(find.byTooltip('Pause'), findsNothing);
    // The status panel reports each part's HP.
    expect(
      find.bySemanticsLabel(RegExp('L ARM 0%, R ARM 50%')),
      findsOneWidget,
    );
  });

  testWidgets('HUD shows the next star distance', (tester) async {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final game = DerbyGame(profile: PlayerProfile(), level: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Hud(game: game)),
      ),
    );
    final targets = Levels.of(2).starDistances;
    expect(find.text('next ${targets[0].toStringAsFixed(0)} m'), findsWidgets);
    game.hud.value = const HudInfo(starsPassed: 1);
    await tester.pump();
    expect(find.text('next ${targets[1].toStringAsFixed(0)} m'), findsWidgets);
    game.hud.value = const HudInfo(starsPassed: 3);
    await tester.pump();
    expect(find.text('ALL STARS!'), findsWidgets);
  });

  testWidgets('a run that unlocks a level offers the next level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final goal = Levels.of(1).starDistances.first;
    final game = DerbyGame(profile: PlayerProfile(levelBest: {1: goal}));
    var next = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Hud(game: game, onNextLevel: () => next++),
        ),
      ),
    );
    game.hud.value = HudInfo(
      result: RunResult(
        end: RunEnd.stuck,
        distance: goal,
        isNewBest: true,
        stats: RunStats(),
        scrap: const [ScrapLine('Distance', 40)],
        starsAfter: 1,
        unlockedLevel: 2,
      ),
    );
    await tester.pump();
    expect(find.text('LEVEL 2 UNLOCKED!'), findsOneWidget);
    await tester.tap(find.text('Next level'));
    expect(next, 1);
  });

  for (final MapEntry(key: name, value: size) in const {
    'portrait': Size(390, 844),
    'landscape': Size(844, 390),
  }.entries) {
    testWidgets('$name HUD: buttons never cover the distance counter', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = DerbyGame(profile: PlayerProfile());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Hud(game: game, onPause: () {}),
          ),
        ),
      );
      game.hud.value = const HudInfo(distance: 4321);
      await tester.pump();

      final counter = tester.getRect(find.text('4321 m').first);
      final restart = tester.getRect(find.byTooltip('Restart'));
      final pause = tester.getRect(find.byTooltip('Pause'));
      expect(counter.overlaps(restart), isFalse);
      expect(counter.overlaps(pause), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
