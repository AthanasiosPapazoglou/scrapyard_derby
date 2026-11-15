import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/damage.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/run_stats.dart';
import 'package:scrapyard_derby/game/scrap_reward.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/hud.dart';

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
    final game = DerbyGame(profile: PlayerProfile(scrap: 120));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Hud(game: game, onMenu: () {}, onPause: () {}),
        ),
      ),
    );

    expect(find.text('Restart'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    // The distance is outlined text: drawn twice (ink outline + fill).
    expect(find.text('0 m'), findsNWidgets(2));
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
      ),
    );
    await tester.pump();

    expect(find.textContaining('12.3 m/s'), findsOneWidget);
    expect(find.textContaining('↺ 40%'), findsOneWidget);
    expect(find.textContaining('Both feet'), findsOneWidget);
    expect(find.textContaining('0/4'), findsOneWidget);
    expect(find.textContaining('HEAD DOWN'), findsOneWidget);
    // Top counter (outline + fill) and the summary.
    expect(find.text('412 m'), findsNWidgets(3));
    expect(find.text('Best: 500 m'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    // Run stats and the scrap breakdown.
    expect(find.text('14.3 m'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('42 m'), findsOneWidget);
    expect(find.text('+41'), findsOneWidget);
    expect(find.text('+43'), findsOneWidget);
    expect(find.text('You have 120'), findsOneWidget);
    // No pause once the run is over.
    expect(find.byTooltip('Pause'), findsNothing);
    // The status panel reports each part's HP.
    expect(
      find.bySemanticsLabel(RegExp('L ARM 0%, R ARM 50%')),
      findsOneWidget,
    );
  });
}
