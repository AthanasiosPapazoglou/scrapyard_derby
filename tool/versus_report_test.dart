// Versus balance report (roadmap R6): plays full headless Versus races of
// the real game (4 robots, physics and all) and prints how often a
// player-bot of a given skill wins each race. Not part of the normal test
// run; start it with:
//
//   flutter test tool/versus_report_test.dart --timeout none
//
// Two parts:
// 1. Samples: races where all 4 robots are bots at skills from [grid]
//    (with the race's gear), giving finishing distances per race and
//    skill. From these, the win chance of any player skill against any
//    rival skills is worked out (robots never touch, so each finish is
//    independent): the share of player distances that beat a distance
//    drawn for every rival. Cheap to re-run for new rival skills.
// 2. Check: real races with the rivals at their Tuning skills and the
//    player-bot at [playerSkills], counting actual wins.
//
// Targets: skill 0.6 wins race 1 in ~2 of 3 tries and race 6 in ~1 of 4;
// skill 0.8 wins every race most of the time; skill 0.4 can still win
// races 1-2.
//
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/autopilot.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/game/races.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';

/// Bot skills sampled in part 1 (4 per race, so keep a multiple of 4).
const grid = [
  0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, //
  0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9,
];

/// Rounds of the whole grid per race in part 1.
const sampleRounds = 20;

/// Part 1's samples are also written here (JSON: race → skill →
/// distances), for trying rival skills offline.
const samplesFile = 'build/versus_samples.json';

/// `--dart-define=SAMPLES_ONLY=true` skips part 2.
const samplesOnly = bool.fromEnvironment('SAMPLES_ONLY');

/// `--dart-define=CHECK_ONLY=true` skips part 1.
const checkOnly = bool.fromEnvironment('CHECK_ONLY');

/// Player-bot skills for the report and the check.
const playerSkills = [0.4, 0.6, 0.8];

/// Real races per race and player skill in part 2.
const checkRaces = 24;

const frame = 1 / 60;

/// Plays race [race] with every robot driven by a bot ([skills]: player
/// first, then the 3 rivals) until all have finished. Their distances.
Future<List<double>> playRace(
  int race,
  List<double> skills, {
  required int seed,
}) async {
  final game = await initializeGame(
    // The tour and hint flags are set so no hint card is involved.
    () => DerbyGame(profile: PlayerProfile(), race: race),
  );
  await game.ready();
  for (var i = 0; i < game.racers.length; i++) {
    game.racers[i].autopilot = Autopilot(
      skill: skills[i],
      seed: seed * 31 + i * 7 + race,
    );
  }
  var t = 0.0;
  while (!game.racers.every((r) => r.finished) && t < 1200) {
    game.update(frame);
    await game.ready();
    t += frame;
  }
  final distances = [for (final r in game.racers) r.distance];
  game.world.physicsWorld.destroy();
  return distances;
}

/// Win chance of a player with [player] distances against rivals with
/// these distance samples: average over player finishes of the chance
/// that every rival finishes no further (a tie counts for the player).
double winChance(List<double> player, List<List<double>> rivals) {
  var total = 0.0;
  for (final d in player) {
    var p = 1.0;
    for (final samples in rivals) {
      p *= samples.where((x) => x <= d).length / samples.length;
    }
    total += p;
  }
  return total / player.length;
}

String pct(double x) => '${(x * 100).round()}%'.padLeft(5);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('versus report', () async {
    final clock = Stopwatch()..start();
    if (checkOnly) {
      await check(clock);
      return;
    }
    // samples[race][skill] = finishing distances.
    final samples = <int, Map<double, List<double>>>{};
    for (var race = 1; race <= Races.count; race++) {
      final bySkill = samples[race] = {for (final s in grid) s: <double>[]};
      for (var round = 0; round < sampleRounds; round++) {
        for (var i = 0; i < grid.length; i += 4) {
          // Rotate who sits in the player's seat, so no skill always
          // gets the same slot.
          final skills = [
            for (var k = 0; k < 4; k++) grid[i + (k + round) % 4],
          ];
          final distances = await playRace(race, skills, seed: round + 1);
          for (var k = 0; k < 4; k++) {
            bySkill[skills[k]]!.add(distances[k]);
          }
        }
      }
      String med(double s) {
        final xs = [...bySkill[s]!]..sort();
        return xs[xs.length ~/ 2].toStringAsFixed(0).padLeft(6);
      }

      print(
        'race $race median m by skill '
        '${[for (final s in grid) '$s:${med(s)}'].join(' ')}'
        '  (${clock.elapsed.inSeconds} s)',
      );
    }

    File(samplesFile)
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          for (final MapEntry(key: race, value: bySkill) in samples.entries)
            '$race': {
              for (final MapEntry(key: skill, value: d) in bySkill.entries)
                '$skill': d,
            },
        }),
      );

    print('\nwin chance from samples, rivals at their Tuning skills');
    print(
      'race | rivals          | ${[for (final p in playerSkills) 'p$p'].join('   ')}',
    );
    for (var race = 1; race <= Races.count; race++) {
      final rivals = [for (final r in Races.of(race).rivals) r.skill];
      List<double> nearest(double s) {
        final key = grid.reduce(
          (a, b) => (a - s).abs() <= (b - s).abs() ? a : b,
        );
        return samples[race]![key]!;
      }

      print(
        '  $race  | ${rivals.join(', ').padRight(15)} |'
        '${[
          for (final p in playerSkills) pct(winChance(nearest(p), [for (final r in rivals) nearest(r)])),
        ].join(' ')}',
      );
    }

    if (!samplesOnly) {
      await check(clock);
    }
  });
}

/// Part 2: real races at the Tuning rival skills.
Future<void> check(Stopwatch clock) async {
  print('\nreal races, rivals at their Tuning skills: wins / $checkRaces');
  for (var race = 1; race <= Races.count; race++) {
    final rivals = [for (final r in Races.of(race).rivals) r.skill];
    final line = <String>[];
    for (final p in playerSkills) {
      var wins = 0;
      for (var n = 0; n < checkRaces; n++) {
        final d = await playRace(race, [p, ...rivals], seed: 300 + n);
        if (d.skip(1).every((x) => x <= d.first)) {
          wins++;
        }
      }
      line.add('p$p ${'$wins'.padLeft(2)}');
    }
    print('  race $race  ${line.join('   ')}  (${clock.elapsed.inSeconds} s)');
  }
}
