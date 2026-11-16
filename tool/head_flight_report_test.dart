// Head flight report: plays full headless runs and prints how far the
// launched head flies (launch point to touchdown) and the total distance.
// Used to tune the head launch (roadmap V4) and the head tiers (V6). Not
// part of the normal test run; start it with:
//
//   flutter test tool/head_flight_report_test.dart --timeout none
//
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/autopilot.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';

import '../test/support/run_simulator.dart';

const level = 1;
const skills = [0.4, 0.9];
const headTiers = [0, 5];
const seeds = 6;

/// Every other slot's tier.
const otherTier = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('head flight report', () async {
    print('level $level, other slots tier $otherTier');
    print('head skill | flight avg  min  max | total avg');
    for (final headTier in headTiers) {
      for (final skill in skills) {
        final flights = <double>[];
        final totals = <double>[];
        for (var seed = 1; seed <= seeds; seed++) {
          final profile = PlayerProfile(
            upgradeLevels: {
              for (final track in UpgradeTrack.values)
                track.id: track == UpgradeTrack.rocketHead
                    ? headTier
                    : otherTier,
            },
          );
          final run = await simulateRun(
            pilot: Autopilot(skill: skill, seed: seed * 17 + headTier),
            profile: profile,
            level: level,
          );
          final result = run.result;
          if (result == null) {
            continue;
          }
          totals.add(result.distance);
          final flight = result.stats.headFlight;
          if (flight != null) {
            flights.add(flight);
          }
        }
        double avg(List<double> xs) =>
            xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
        String f(double x) => x.toStringAsFixed(0).padLeft(5);
        print(
          '  T$headTier  ${skill.toStringAsFixed(1)} |'
          '${f(avg(flights))}${f(flights.isEmpty ? 0 : flights.reduce((a, b) => a < b ? a : b))}'
          '${f(flights.isEmpty ? 0 : flights.reduce((a, b) => a > b ? a : b))} |'
          '${f(avg(totals))}  (${flights.length} flights)',
        );
      }
    }
  });
}
