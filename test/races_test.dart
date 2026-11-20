import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/gadgets.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/game/races.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';

void main() {
  test('one race per level hill, in order', () {
    expect(Races.count, Levels.count);
    for (var race = 1; race <= Races.count; race++) {
      expect(Races.of(race).level, race);
    }
  });

  test('every race has 3 rivals, distinct names and colours', () {
    final names = <String>{};
    for (var race = 1; race <= Races.count; race++) {
      final rivals = Races.of(race).rivals;
      expect(rivals, hasLength(Races.racers - 1));
      expect(rivals.map((r) => r.color).toSet(), hasLength(rivals.length));
      for (final rival in rivals) {
        expect(names.add(rival.name), isTrue, reason: rival.name);
        expect(rival.skill, inInclusiveRange(0, 1));
      }
    }
  });

  test('gear never gets worse and rivals get harder up the ladder', () {
    double average(int race) =>
        Races.of(race).rivals.map((r) => r.skill).reduce((a, b) => a + b) / 3;
    for (var race = 2; race <= Races.count; race++) {
      expect(
        Races.of(race).partTier,
        greaterThanOrEqualTo(Races.of(race - 1).partTier),
      );
      expect(
        Races.of(race).partTier,
        lessThanOrEqualTo(Tuning.upgradeMaxLevel),
      );
      expect(average(race), greaterThan(average(race - 1)));
    }
  });

  test('race gear builds the stats from its tiers and gadgets', () {
    final last = Races.count;
    final tier = Races.of(last).partTier;
    final stats = Races.statsOf(last);
    expect(stats.limbMaxHp, Tuning.platingHp[tier]);
    expect(stats.headRocketThrust, Tuning.rocketThrust[tier]);
    for (final MapEntry(key: id, value: level) in Races.of(
      last,
    ).gadgets.entries) {
      final gadget = Gadget.values.firstWhere((g) => g.id == id);
      expect(Races.gadgetsOf(last)[gadget], level);
      expect(level, inInclusiveRange(1, Tuning.gadgetMaxLevel));
    }
    // Race 1 has no gadgets.
    expect(Races.gadgetsOf(1), isEmpty);
    expect(Races.statsOf(1).comboCoilSteps, 0);
    expect(Races.tierOf(1, UpgradeTrack.springLegs), Races.of(1).partTier);
  });

  test('place labels', () {
    expect([1, 2, 3, 4].map(Races.placeLabel), ['1st', '2nd', '3rd', '4th']);
  });

  test('place bonus has one entry per place', () {
    expect(Tuning.versusPlaceBonus, hasLength(Races.racers));
  });
}
