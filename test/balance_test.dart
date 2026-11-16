import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/autopilot.dart';

import 'support/run_simulator.dart';

/// Guards the balance targets from docs/ROADMAP.md step 6 with real,
/// headless runs. The full report is `flutter test tool/simulate_runs_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wrapAngle keeps angles in -pi..pi', () {
    expect(wrapAngle(0), 0);
    expect(wrapAngle(2 * math.pi + 0.5), closeTo(0.5, 1e-9));
    expect(wrapAngle(-2 * math.pi - 0.5), closeTo(-0.5, 1e-9));
    expect(wrapAngle(math.pi + 0.1), closeTo(-math.pi + 0.1, 1e-9));
  });

  test('a run with no input ends early', () async {
    final run = await simulateRun();
    final result = run.result!;
    expect(result.distance, lessThan(700));
    // Little scrap for not playing (new-best bonus aside).
    final bonus = result.isNewBest ? Tuning.scrapNewBestBonus : 0;
    expect(result.scrapEarned - bonus, lessThan(30));
  });

  test('skill goes much further than no input', () async {
    final idle = (await simulateRun()).result!;
    final skilled = (await simulateRun(pilot: Autopilot())).result!;
    expect(skilled.distance, greaterThan(idle.distance * 4));
    // But a perfect run still ends in reasonable time (game seconds).
    expect(skilled.distance, lessThan(5000));
  });
}
