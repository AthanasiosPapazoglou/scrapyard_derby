// Progression balance report: plays full headless runs on every level with
// robots of different part tiers and bots of different skill, and prints
// distances, stars and scrap per run. Not part of the normal test run;
// start it with:
//
//   flutter test tool/progression_report_test.dart
//
// Targets (docs/ROADMAP.md, P7): with every slot at tier N, a skill ~0.4
// bot reaches level N's first star; 3 stars need skill ~0.9 or gadgets.
//
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/autopilot.dart';
import 'package:scrapyard_derby/game/gadgets.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';
import 'package:scrapyard_derby/game/scrap_reward.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';

import '../test/support/run_simulator.dart';

/// Levels to report (1-based).
const levels = [1, 2, 3, 4, 5, 6];

/// Bot skills to try.
const skills = [0.0, 0.4, 0.7, 0.9];

/// Runs per bot (different seeds).
const seedsPerBot = 4;

/// Gadget level for every gadget (0 = none), for a second pass.
const gadgetLevel = 0;

/// The part tier the robot has on level N: the tier that level unlocks.
int tierFor(int level) => Levels.of(level).partTier;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('progression report', () async {
    print('gadgets: level $gadgetLevel');
    print(
      'lvl tier skill | dist avg   min   max | stars avg | '
      'scrap/run | time s',
    );
    for (final level in levels) {
      final targets = Levels.of(level).starDistances;
      // The tier the level unlocks, and one below (does the upgrade matter?).
      for (final tier in {math.max(0, tierFor(level) - 1), tierFor(level)}) {
        for (final skill in skills) {
          final distances = <double>[];
          final scraps = <int>[];
          var time = 0.0;
          for (var seed = 1; seed <= seedsPerBot; seed++) {
            final profile = PlayerProfile(
              upgradeLevels: {
                for (final track in UpgradeTrack.values) track.id: tier,
              },
              gadgetLevels: {
                for (final gadget in Gadget.values) gadget.id: gadgetLevel,
              },
            );
            final run = await simulateRun(
              pilot: Autopilot(skill: skill, seed: seed * 31 + level),
              profile: profile,
              level: level,
              maxSeconds: 1500,
            );
            final result = run.result;
            if (result == null) {
              print('  (timed out)');
              continue;
            }
            distances.add(result.distance);
            time += run.seconds;
            // Scrap of a repeat run: no new best or new stars, with the star
            // bonus of a player who has 2 stars on every earlier level.
            scraps.add(
              scrapTotal(
                scrapReward(
                  result.stats,
                  newBest: false,
                  level: level,
                  starBonus: 2 * (level - 1) * Tuning.scrapBonusPerStar,
                  magnetBonus: profile.robotStats.scrapMagnet,
                ),
              ),
            );
          }
          if (distances.isEmpty) {
            continue;
          }
          double avg(Iterable<num> xs) =>
              xs.fold<double>(0, (a, b) => a + b) / xs.length;
          final stars = avg(
            distances.map((d) => targets.where((t) => d >= t).length),
          );
          print(
            '${'$level'.padLeft(3)} ${'$tier'.padLeft(4)} '
            '${skill.toStringAsFixed(1).padLeft(5)} | '
            '${_n(avg(distances), 8)} ${_n(distances.reduce(math.min), 5)} '
            '${_n(distances.reduce(math.max), 5)} | '
            '${stars.toStringAsFixed(1).padLeft(9)} | '
            '${_n(avg(scraps), 9)} | ${_n(time / distances.length, 6)}',
          );
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}

String _n(num x, int width) => x.toStringAsFixed(0).padLeft(width);
