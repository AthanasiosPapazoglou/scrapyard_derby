import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/run_stats.dart';

void main() {
  test('counts landings per type and limbs lost', () {
    final stats = RunStats()
      ..addLanding(LandingType.clean)
      ..addLanding(LandingType.clean)
      ..addLanding(LandingType.crash)
      ..addLimbLost();
    expect(stats.landingsOf(LandingType.clean), 2);
    expect(stats.landingsOf(LandingType.oneFoot), 0);
    expect(stats.landingsOf(LandingType.crash), 1);
    expect(stats.limbsLost, 1);
  });

  test('keeps the highest jump only', () {
    final stats = RunStats()
      ..reportHeight(3)
      ..reportHeight(12.5)
      ..reportHeight(4);
    expect(stats.highestJump, 12.5);
  });

  test('head flight is measured from launch to landing', () {
    final stats = RunStats();
    expect(stats.headFlight, isNull);
    stats
      ..headLaunchedAt(400)
      ..headLandedAt(437.5);
    expect(stats.headFlight, closeTo(37.5, 1e-9));
  });

  test('a landing without a launch records no head flight', () {
    final stats = RunStats()..headLandedAt(100);
    expect(stats.headFlight, isNull);
  });
}
