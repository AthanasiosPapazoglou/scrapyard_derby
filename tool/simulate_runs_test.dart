// Balance report: plays many full runs headless with bots of different
// skill and prints distances, landings and scrap. Not part of the normal
// test run; start it with:
//
//   flutter test tool/simulate_runs_test.dart
//
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/autopilot.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';

import '../test/support/run_simulator.dart';

/// Bots to test: null = no input at all.
const skills = <double?>[null, 0.0, 0.4, 0.7, 0.9, 1.0];
const seedsPerBot = 6;

/// Upgrade levels for the whole report (track id → level), e.g.
/// {'plating': 5, ...} to see a fully upgraded robot.
const upgrades = <String, int>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('balance report', () async {
    print(
      'bot       | dist avg  min   max | clean% 1foot crash | jump  head  | '
      'scrap avg | time s',
    );
    for (final skill in skills) {
      final runs = <SimulatedRun>[];
      final seeds = skill == null ? 1 : seedsPerBot;
      for (var seed = 1; seed <= seeds; seed++) {
        runs.add(
          await simulateRun(
            pilot: skill == null ? null : Autopilot(skill: skill, seed: seed),
            profile: PlayerProfile(upgradeLevels: upgrades),
          ),
        );
      }
      final results = runs.map((r) => r.result).nonNulls.toList();
      final timeouts = runs.length - results.length;
      if (results.isEmpty) {
        print('${_name(skill)} | all ${runs.length} runs hit the time limit');
        continue;
      }
      double avg(Iterable<num> xs) =>
          xs.fold<double>(0, (a, b) => a + b) / xs.length;
      final dist = results.map((r) => r.distance);
      var clean = 0, total = 0, crashes = 0, oneFoot = 0;
      for (final r in results) {
        for (final type in LandingType.values) {
          total += r.stats.landingsOf(type);
        }
        clean += r.stats.landingsOf(LandingType.clean);
        crashes += r.stats.landingsOf(LandingType.crash);
        oneFoot += r.stats.landingsOf(LandingType.oneFoot);
      }
      print(
        '${_name(skill)} | ${_n(avg(dist), 5)} ${_n(dist.reduce(math.min), 5)} '
        '${_n(dist.reduce(math.max), 5)} | '
        '${_n(100 * clean / math.max(1, total), 5)}  ${_n(oneFoot / results.length, 5)} ${_n(crashes / results.length, 4)} | '
        '${_n(avg(results.map((r) => r.stats.highestJump)), 4)}  '
        '${_n(avg(results.map((r) => r.stats.headFlight ?? 0)), 4)}  | '
        '${_n(avg(results.map((r) => r.scrapEarned)), 6)}    | '
        '${_n(avg(runs.map((r) => r.seconds)), 5)}'
        '${timeouts > 0 ? '  ($timeouts timed out)' : ''}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

String _name(double? skill) =>
    skill == null ? 'no input ' : 'skill ${skill.toStringAsFixed(1)}';

String _n(num x, int width) => x.toStringAsFixed(0).padLeft(width);
