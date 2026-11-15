import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';

/// Guards the shape of the progression from docs/ROADMAP.md P7. The
/// distances themselves are measured with tool/progression_report_test.dart
/// (full runs take too long for the normal test run).
void main() {
  test('stars get harder within a level and from level to level', () {
    for (var level = 1; level <= Levels.count; level++) {
      final stars = Levels.of(level).starDistances;
      expect(stars, hasLength(Levels.maxStars));
      expect(stars[0], lessThan(stars[1]), reason: 'level $level');
      expect(stars[1], lessThan(stars[2]), reason: 'level $level');
      if (level > 1) {
        final before = Levels.of(level - 1).starDistances;
        for (var i = 0; i < Levels.maxStars; i++) {
          expect(stars[i], greaterThan(before[i]), reason: 'level $level');
        }
      }
    }
  });

  test('later levels are harsher and pay more', () {
    for (var level = 2; level <= Levels.count; level++) {
      final now = Levels.of(level);
      final before = Levels.of(level - 1);
      expect(now.damageScale, greaterThanOrEqualTo(before.damageScale));
      expect(now.scrapMultiplier, greaterThan(before.scrapMultiplier));
      expect(now.bumpScale, greaterThan(before.bumpScale));
    }
  });

  test('the level tier\'s plating keeps up with the level\'s damage', () {
    // Part HP of a robot at the level's tier, per unit of landing damage,
    // stays close to level 1 with tier 1 (tier N clears level N), and
    // never gets easier. Level 6 (tier 5, the last) is meant to be harsher.
    double toughness(int level) {
      final tier = Levels.of(level).partTier;
      final hp = RobotStats.fromLevels({UpgradeTrack.plating: tier}).limbMaxHp;
      return hp / Levels.of(level).damageScale;
    }

    final first = toughness(1);
    for (var level = 2; level < Levels.count; level++) {
      expect(toughness(level), closeTo(first, first * 0.1), reason: '$level');
      expect(toughness(level), lessThanOrEqualTo(first));
    }
    expect(toughness(Levels.count), lessThan(toughness(Levels.count - 1)));
  });

  test('every level unlocks a tier no lower than the one before', () {
    for (var level = 2; level <= Levels.count; level++) {
      expect(
        Levels.of(level).partTier,
        greaterThanOrEqualTo(Levels.of(level - 1).partTier),
      );
    }
    expect(Levels.of(Levels.count).partTier, Tuning.upgradeMaxLevel);
  });
}
