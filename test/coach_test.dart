import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/autopilot.dart';
import 'package:scrapyard_derby/game/coach.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/coach_card.dart';
import 'package:scrapyard_derby/ui/hud.dart';
import 'package:scrapyard_derby/ui/status_panel.dart';

/// Runs [coach] for [seconds] (real time) at 60 fps with [input].
void run(Coach coach, CoachInput input, {double seconds = 0.1}) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    coach.update(1 / 60, input);
  }
}

const inAir = CoachInput(hasTouchedDown: true);
const holding = CoachInput(hasTouchedDown: true, playerHolding: true);

/// A coach walked to the "land on both feet" step.
Coach atLand() {
  final coach = Coach();
  run(coach, inAir);
  run(coach, holding, seconds: Tuning.coachHoldTime + 0.1);
  run(coach, inAir);
  return coach;
}

void main() {
  group('steps', () {
    test('it waits for the first bounce before asking for a hold', () {
      final coach = Coach();
      run(coach, const CoachInput(), seconds: 2); // falling
      expect(coach.step, CoachStep.drop);
      expect(coach.card, CoachCard.drop);
      expect(coach.timeScale, 1);
      run(coach, const CoachInput(hasTouchedDown: true, onGround: true));
      expect(coach.step, CoachStep.drop);
      run(coach, inAir);
      expect(coach.step, CoachStep.hold);
    });

    test('the game nearly stops in the air until the player holds', () {
      final coach = Coach();
      run(coach, inAir);
      run(coach, inAir, seconds: 3);
      expect(coach.step, CoachStep.hold);
      expect(coach.card!.finger, isTrue);
      expect(coach.timeScale, closeTo(Tuning.coachHoldSlow, 0.01));
      // Holding brings the speed back and, held long enough, moves on.
      run(coach, holding, seconds: Tuning.coachHoldTime / 2);
      expect(coach.step, CoachStep.hold);
      expect(coach.timeScale, greaterThan(Tuning.coachHoldSlow));
      run(coach, holding, seconds: Tuning.coachHoldTime);
      expect(coach.step, CoachStep.release);
      run(coach, inAir);
      expect(coach.step, CoachStep.land);
    });

    test('a clean landing finishes the landing step', () {
      final coach = atLand();
      run(coach, const CoachInput(hasTouchedDown: true, sightShowing: true));
      expect(coach.timeScale, lessThan(1));
      run(
        coach,
        const CoachInput(hasTouchedDown: true, landings: 1, cleanLandings: 1),
      );
      expect(coach.step, CoachStep.energy);
      expect(coach.card!.pointer, CoachPointer.energyBar);
      run(coach, inAir, seconds: Tuning.coachEnergyTime + 0.2);
      expect(coach.step, CoachStep.free);
      expect(coach.card, isNull);
      expect(coach.timeScale, closeTo(1, 0.01));
    });

    test('no clean landing? it moves on after a few tries', () {
      final coach = atLand();
      run(
        coach,
        const CoachInput(
          hasTouchedDown: true,
          landings: Tuning.coachLandTries,
          badLandings: Tuning.coachLandTries,
        ),
      );
      expect(coach.step, CoachStep.energy);
    });
  });

  group('event cards', () {
    test('the first bad landing points at the status panel', () {
      final coach = atLand();
      run(
        coach,
        const CoachInput(hasTouchedDown: true, landings: 1, badLandings: 1),
      );
      expect(coach.card, CoachCard.damage);
      run(
        coach,
        const CoachInput(hasTouchedDown: true, landings: 1, badLandings: 1),
        seconds: Tuning.coachDamageTime + 0.2,
      );
      expect(coach.card, CoachCard.land);
    });

    test('bad landings before the hold lesson do not interrupt it', () {
      final coach = Coach();
      run(coach, inAir);
      run(coach, const CoachInput(hasTouchedDown: true, badLandings: 1));
      expect(coach.card, CoachCard.hold);
    });

    test('the head launch explains the score', () {
      final coach = atLand();
      run(coach, const CoachInput(hasTouchedDown: true, headLaunched: true));
      expect(coach.card, CoachCard.head);
    });
  });

  test('the run ending or Skip finishes it, once', () {
    var finished = 0;
    final ended = Coach(onFinished: () => finished++);
    run(ended, inAir);
    run(ended, const CoachInput(runOver: true));
    expect(ended.finished, isTrue);
    expect(ended.card, isNull);
    expect(ended.timeScale, 1);
    run(ended, const CoachInput(runOver: true));
    expect(finished, 1);

    final skipped = Coach(onFinished: () => finished++);
    run(skipped, inAir, seconds: 1);
    skipped
      ..skip()
      ..skip();
    expect(skipped.finished, isTrue);
    expect(skipped.timeScale, 1);
    expect(finished, 2);
  });

  group('in the game', () {
    Future<DerbyGame> load(PlayerProfile profile, {int level = 1}) =>
        initializeGame(() => DerbyGame(profile: profile, level: level));

    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('a new player gets the tutorial on level 1 only', () async {
      expect((await load(PlayerProfile())).coach, isNotNull);
      expect((await load(PlayerProfile(), level: 2)).coach, isNull);
      expect((await load(PlayerProfile(firstRunCoached: true))).coach, isNull);
    });

    test('skipping marks it done in the profile', () async {
      final profile = PlayerProfile();
      final game = await load(profile);
      game.skipTutorial();
      expect(profile.firstRunCoached, isTrue);
      expect(game.coach!.finished, isTrue);
    });

    test('bots never slow down for it', () async {
      final game = await load(PlayerProfile())
        ..autopilot = Autopilot(seed: 1);
      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
      }
      expect(game.coach!.step, CoachStep.drop); // never fed
      expect(game.hud.value.coach, isNull);
    });
  });

  group('card placement', () {
    const screens = {
      'phone portrait': Size(390, 844),
      'phone landscape': Size(844, 390),
      'small phone portrait': Size(360, 640),
      'small phone landscape': Size(640, 360),
    };
    const cards = [
      CoachCard.drop,
      CoachCard.hold,
      CoachCard.release,
      CoachCard.land,
      CoachCard.energy,
      CoachCard.damage,
      CoachCard.head,
    ];
    for (final MapEntry(key: name, value: size) in screens.entries) {
      testWidgets('$name: every card fits and covers no HUD', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final game = DerbyGame(profile: PlayerProfile());
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Hud(game: game)),
          ),
        );
        final panel = tester.getRect(find.byType(StatusPanel));
        for (final card in cards) {
          game.hud.value = HudInfo(coach: card);
          await tester.pump();
          final box = tester.getRect(
            find
                .ancestor(
                  of: find.text(card.title),
                  matching: find.byType(Container),
                )
                .first,
          );
          final screen = Offset.zero & size;
          expect(
            screen.contains(box.topLeft) && screen.contains(box.bottomRight),
            isTrue,
            reason: '${card.title}: $box',
          );
          expect(
            box.overlaps(panel.deflate(2)),
            isFalse,
            reason: '${card.title} covers the status panel',
          );
          final skip = tester.getRect(find.text('SKIP TUTORIAL'));
          expect(screen.contains(skip.bottomRight), isTrue);
          expect(skip.overlaps(panel.deflate(2)), isFalse);
          expect(tester.takeException(), isNull);
        }
        await tester.pump(const Duration(milliseconds: 500));
      });
    }
  });

  testWidgets('the HUD shows the card and its Skip button', (tester) async {
    final profile = PlayerProfile();
    final game = DerbyGame(profile: profile);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Hud(game: game)),
      ),
    );
    expect(find.byType(CoachOverlay), findsNothing);
    game.hud.value = const HudInfo(coach: CoachCard.hold);
    await tester.pump();
    expect(find.text('HOLD ANYWHERE'), findsOneWidget);
    expect(find.text('SKIP TUTORIAL'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });
}
