import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/damage.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/ui/hud.dart';

void main() {
  testWidgets('HUD shows distance, debug info and the run-over banner', (
    tester,
  ) async {
    // The game is never loaded here, so no physics runs; we only drive the
    // HUD through its ValueNotifier.
    final game = DerbyGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Hud(game: game)),
      ),
    );

    expect(find.text('Restart'), findsOneWidget);
    // The distance is outlined text: drawn twice (ink outline + fill).
    expect(find.text('0 m'), findsNWidgets(2));
    expect(find.textContaining('↻ 100%'), findsOneWidget);
    expect(find.textContaining('HEAD DOWN'), findsNothing);

    game.hud.value = const HudInfo(
      speed: 12.3,
      spin: -0.4,
      lastLanding: LandingType.clean,
      distance: 412,
      bestDistance: 500,
      limbsLeft: 0,
      runEnd: RunEnd.headDown,
      partHp: {RobotSlot.leftArm: 0, RobotSlot.rightArm: 0.5},
    );
    await tester.pump();

    expect(find.textContaining('12.3 m/s'), findsOneWidget);
    expect(find.textContaining('↺ 40%'), findsOneWidget);
    expect(find.textContaining('Both feet'), findsOneWidget);
    expect(find.textContaining('0/4'), findsOneWidget);
    expect(find.textContaining('HEAD DOWN'), findsOneWidget);
    // Top counter (outline + fill) and the banner.
    expect(find.text('412 m'), findsNWidgets(3));
    expect(find.text('Best: 500 m'), findsOneWidget);
    expect(find.text('Go again'), findsOneWidget);
    // The status panel reports each part's HP.
    expect(
      find.bySemanticsLabel(RegExp('L ARM 0%, R ARM 50%')),
      findsOneWidget,
    );
  });
}
