import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/gadgets.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';

import 'support/run_simulator.dart';

/// Gadgets in full headless runs of the real game (kept apart from widget
/// tests, which run on a fake clock).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<double> averageNoInput(Map<String, int> gadgets) async {
    var total = 0.0;
    for (var level = 1; level <= Levels.count; level++) {
      final run = await simulateRun(
        profile: PlayerProfile(gadgetLevels: gadgets),
        level: level,
      );
      total += run.result!.distance;
    }
    return total / Levels.count;
  }

  test('Auto-Gyro carries no-input runs much further', () async {
    final plain = await averageNoInput({});
    final gyro = await averageNoInput({'autoGyro': Tuning.gadgetMaxLevel});
    expect(gyro, greaterThan(plain * 1.5));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a run with every gadget plays through without trouble', () async {
    final run = await simulateRun(
      profile: PlayerProfile(
        gadgetLevels: {
          for (final g in Gadget.values) g.id: Tuning.gadgetMaxLevel,
        },
      ),
      level: Levels.count,
    );
    expect(run.result, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
