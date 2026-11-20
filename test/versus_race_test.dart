import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/autopilot.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/game/hill.dart';
import 'package:scrapyard_derby/game/races.dart';
import 'package:scrapyard_derby/game/scrap_reward.dart';
import 'package:scrapyard_derby/profile/page_tour.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';

/// Versus races in full headless runs of the real game: 4 robots on one
/// hill, physics and all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const frame = 1 / 60;

  /// Plays until every racer has finished (or [maxSeconds]).
  Future<DerbyGame> race(
    int race, {
    Autopilot? pilot,
    double maxSeconds = 900,
  }) async {
    final game = await initializeGame(
      () => DerbyGame(profile: PlayerProfile(), race: race),
    );
    game.autopilot = pilot;
    await game.ready();
    var t = 0.0;
    while (!game.racers.every((r) => r.finished) && t < maxSeconds) {
      game.update(frame);
      await game.ready();
      t += frame;
    }
    return game;
  }

  test('a race has the player and 3 quiet, tinted rivals', () async {
    final game = await initializeGame(
      () => DerbyGame(profile: PlayerProfile(), race: 2),
    );
    await game.ready();
    expect(game.isVersus, isTrue);
    expect(game.level, Races.of(2).level);
    expect(game.racers, hasLength(Races.racers));
    expect(game.player.isPlayer, isTrue);
    expect(game.robot.isRival, isFalse);
    final names = [for (final r in game.rivals) r.name];
    expect(names, [for (final r in Races.of(2).rivals) r.name]);
    for (final rival in game.rivals) {
      expect(rival.robot.isRival, isTrue);
      expect(rival.autopilot, isNotNull);
      // Drawn behind the player.
      expect(rival.robot.priority, lessThan(game.robot.priority));
      // Everyone has the race's gear, not the Workshop's.
      expect(rival.robot.stats.limbMaxHp, Races.statsOf(2).limbMaxHp);
    }
    expect(game.robot.stats.limbMaxHp, Races.statsOf(2).limbMaxHp);
    expect(game.rivalEffects.quiet, isTrue);
    expect(game.effects.quiet, isFalse);
    // No tutorial in Versus.
    expect(game.coach, isNull);
    game.world.physicsWorld.destroy();
  });

  test('every racer finishes on the hill; nobody falls through', () async {
    final game = await race(3, pilot: Autopilot(skill: 0.7, seed: 4));
    for (final racer in game.racers) {
      expect(racer.finished, isTrue, reason: racer.name);
      // Far enough to have crossed several hill chunks, so the hill was
      // built under every robot, not only the player.
      expect(
        racer.distance,
        greaterThan(Tuning.hillChunkLength * 4),
        reason: racer.name,
      );
    }
    final result = game.hud.value.result!;
    expect(result.race, 3);
    // Versus never records a Survival best.
    expect(game.profile.bestOn(game.level), 0);
    game.world.physicsWorld.destroy();
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
    'robots never touch: 4 robots dropped on one spot stay together',
    () async {
      // All four robots spawn on exactly the same spot. If their parts could
      // collide, Box2D would shove the overlapping bodies apart at once.
      // Instead they fall as one, exactly like a robot dropped alone.
      final versus = await initializeGame(
        () => DerbyGame(profile: PlayerProfile(), race: 1),
      );
      final solo = await initializeGame(
        () => DerbyGame(profile: PlayerProfile(firstRunCoached: true)),
      );
      await versus.ready();
      await solo.ready();
      for (final rival in versus.rivals) {
        expect(rival.robot.start, versus.robot.start);
      }
      final start = versus.robot.position.clone();
      for (var i = 0; i < 60; i++) {
        versus.update(frame);
        solo.update(frame);
        await versus.ready();
        await solo.ready();
      }
      // Still in the opening drop (no ground contact yet), and moved.
      expect(versus.robot.hasTouchedDown, isFalse);
      expect(versus.robot.position.y - start.y, greaterThan(1));
      for (final racer in versus.racers) {
        for (final part in racer.robot.parts) {
          final twin = versus.robot.parts[racer.robot.parts.indexOf(part)];
          expect(
            (part.body.position - twin.body.position).length,
            lessThan(1e-4),
            reason: '${racer.name} ${part.kind}',
          );
        }
      }
      expect(
        (versus.robot.position - solo.robot.position).length,
        lessThan(1e-4),
      );
      versus.world.physicsWorld.destroy();
      solo.world.physicsWorld.destroy();
    },
  );

  test('a player finished behind running rivals: fast-forward, tap to skip, '
      'race ends once the place is settled', () async {
    final game = await initializeGame(
      () => DerbyGame(profile: PlayerProfile(), race: 1),
    );
    await game.ready();
    expect(game.fastForward, 1);
    // The player is out at the very start; the rivals are level with
    // them, so they can still finish behind: not settled yet.
    game.player.finish(RunEnd.stuck);
    expect(game.fastForward, Tuning.raceFastForward);
    game.onTapDown(createTapDownEvents(game: game));
    expect(game.fastForward, Tuning.raceFastForwardSkip);
    var frames = 0;
    while (game.hud.value.result == null && frames < 60 * 120) {
      game.update(frame);
      await game.ready();
      frames++;
    }
    final result = game.hud.value.result!;
    expect(result.race, 1);
    expect(result.place, inInclusiveRange(1, 4));
    expect(result.standings, hasLength(Races.racers));
    expect(result.standings.indexWhere((s) => s.isPlayer) + 1, result.place);
    // Settled: back to normal speed.
    expect(game.fastForward, 1);
    expect(game.hud.value.place, result.place);
    game.world.physicsWorld.destroy();
  });

  /// Plays race [race] until the player's place is settled; the rivals
  /// all drop out at the start, so the player wins.
  Future<RunResult> win(DerbyGame game) async {
    for (final rival in game.rivals) {
      rival.finish(RunEnd.stuck);
    }
    for (var i = 0; i < 60; i++) {
      game.update(frame);
      await game.ready();
    }
    game.player.finish(RunEnd.stuck);
    game.update(frame);
    await game.ready();
    return game.hud.value.result!;
  }

  test(
    'a win is recorded and paid; the first-win bonus and unlock once',
    () async {
      final profile = PlayerProfile();
      final game = await initializeGame(
        () => DerbyGame(profile: profile, race: 1),
      );
      await game.ready();

      final first = await win(game);
      expect(first.place, 1);
      expect(first.isFirstWin, isTrue);
      expect(first.unlockedRace, 2);
      expect(
        first.scrap,
        contains(
          const ScrapLine('First win, race 1', Tuning.versusFirstWinScrap),
        ),
      );
      expect(profile.bestPlaceOn(1), 1);
      expect(profile.isRaceUnlocked(2), isTrue);
      expect(profile.scrap, first.scrapEarned);
      // Never a Survival best.
      expect(profile.bestOn(game.level), 0);

      game.restart();
      await game.ready();
      final second = await win(game);
      expect(second.place, 1);
      expect(second.isFirstWin, isFalse);
      expect(second.unlockedRace, isNull);
      expect(
        second.scrap.map((l) => l.label),
        isNot(contains(startsWith('First'))),
      );
      expect(profile.scrap, first.scrapEarned + second.scrapEarned);
      game.world.physicsWorld.destroy();
    },
  );

  test('standings show from the first touchdown; the hint card only at '
      'the very first race', () async {
    final profile = PlayerProfile();
    final game = await initializeGame(
      () => DerbyGame(profile: profile, race: 1),
    );
    await game.ready();
    // The HUD publishes every 0.1 s.
    for (var i = 0; i < 10; i++) {
      game.update(frame);
    }
    expect(game.hud.value.raceHint, isTrue);
    expect(profile.tourSeen(PageTour.raceHint), isTrue);
    expect(game.hud.value.standings, isEmpty);
    var t = 0.0;
    while (!game.robot.hasTouchedDown && t < 20) {
      game.update(frame);
      await game.ready();
      t += frame;
    }
    // Let the HUD publish.
    for (var i = 0; i < 10; i++) {
      game.update(frame);
      await game.ready();
    }
    expect(game.hud.value.standings, hasLength(Races.racers));
    // A retry has no hint.
    game.restart();
    await game.ready();
    for (var i = 0; i < 10; i++) {
      game.update(frame);
    }
    expect(game.hud.value.raceHint, isFalse);
    game.world.physicsWorld.destroy();
  });

  test('Survival has no standings and never fast-forwards', () async {
    final game = await initializeGame(
      () => DerbyGame(profile: PlayerProfile(firstRunCoached: true)),
    );
    await game.ready();
    game.player.finish(RunEnd.stuck);
    expect(game.fastForward, 1);
    game.update(frame);
    expect(game.hud.value.standings, isEmpty);
    expect(game.hud.value.place, isNull);
    game.world.physicsWorld.destroy();
  });

  test('the hill is built around every focus point', () {
    final chunks = chunksAround([0, Tuning.hillChunkLength * 20]);
    for (final x in [0.0, Tuning.hillChunkLength * 20]) {
      final center = HillGeometry.chunkIndexAt(x);
      for (
        var i = center - Tuning.hillChunksBehind;
        i <= center + Tuning.hillChunksAhead;
        i++
      ) {
        expect(chunks, contains(i));
      }
    }
    // Nothing built in the gap between them.
    expect(chunks, isNot(contains(HillGeometry.chunkIndexAt(0) + 10)));
  });

  test('Survival still has only the player', () async {
    final game = await initializeGame(
      () => DerbyGame(profile: PlayerProfile()),
    );
    await game.ready();
    expect(game.isVersus, isFalse);
    expect(game.racers, hasLength(1));
    expect(game.rivals, isEmpty);
    game.world.physicsWorld.destroy();
  });
}
