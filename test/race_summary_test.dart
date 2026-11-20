import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/game/run_stats.dart';
import 'package:scrapyard_derby/game/scrap_reward.dart';
import 'package:scrapyard_derby/ui/run_summary.dart';

const _c = Color(0xFF3AA7A3);

/// A finished race: 2nd behind a rival still running, race 3 unlocked.
RunResult raceResult({int? unlockedRace = 3, bool firstWin = false}) =>
    RunResult(
      end: RunEnd.headDown,
      distance: 2400,
      isNewBest: false,
      stats: RunStats()..distance = 2400,
      scrap: const [
        ScrapLine('Distance', 240),
        ScrapLine('2nd place +30%', 72),
      ],
      level: 2,
      race: 2,
      place: 2,
      standings: const [
        Standing(name: 'Clank-9', color: _c, distance: 3100),
        Standing(
          name: 'YOU',
          color: _c,
          distance: 2400,
          isPlayer: true,
          finished: true,
        ),
        Standing(name: 'Ember', color: _c, distance: 900, finished: true),
        Standing(name: 'Sprocket', color: _c, distance: 300, finished: true),
      ],
      isFirstWin: firstWin,
      unlockedRace: unlockedRace,
    );

Future<void> pumpCard(
  WidgetTester tester,
  RunResult result, {
  VoidCallback? onNext,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FittedBox(
            child: RunSummary(
              result: result,
              bestDistance: 0,
              totalScrap: 500,
              onPlayAgain: () {},
              onMenu: () {},
              onNextLevel: onNext,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(RunSummary.revealTime);
}

void main() {
  testWidgets('race card: podium, place, unlock stamp, race buttons', (
    tester,
  ) async {
    await pumpCard(tester, raceResult(), onNext: () {});
    expect(find.text('2ND'), findsOneWidget);
    for (final name in ['CLANK-9', 'YOU', 'EMBER', 'SPROCKET']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('RACE 3 UNLOCKED!'), findsOneWidget);
    expect(find.text('2nd place +30%'), findsOneWidget);
    expect(find.text('Ladder'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Next race'), findsOneWidget);
    // Upgrades don't apply to races; no Survival stars or best.
    expect(find.text('Workshop'), findsNothing);
    expect(find.textContaining('Best'), findsNothing);
  });

  testWidgets('a repeat result shows no stamp; no Next race when locked', (
    tester,
  ) async {
    await pumpCard(tester, raceResult(unlockedRace: null));
    expect(find.textContaining('UNLOCKED'), findsNothing);
    expect(find.text('FIRST WIN!'), findsNothing);
    expect(find.text('Next race'), findsNothing);
  });

  testWidgets('the last race\'s first win gets its own stamp', (tester) async {
    await pumpCard(tester, raceResult(unlockedRace: null, firstWin: true));
    expect(find.text('FIRST WIN!'), findsOneWidget);
  });
}
