import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/gadgets.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/profile/profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PlayerProfile', () {
    test('starts with sensible defaults', () {
      final p = PlayerProfile();
      expect(p.bestDistance, 0);
      expect(p.scrap, 0);
      expect(p.upgradeLevel('plating'), 0);
      expect(p.musicVolume, PlayerProfile.defaultMusicVolume);
      expect(p.sfxVolume, PlayerProfile.defaultSfxVolume);
      expect(p.hapticsOn, isTrue);
      expect(p.showDebugInfo, isFalse);
    });

    test('JSON round trip keeps every value', () {
      final p = PlayerProfile(
        levelBest: {1: 1812.5, 2: 300},
        scrap: 340,
        upgradeLevels: {'plating': 2, 'rocketHead': 5},
        musicVolume: 0.2,
        sfxVolume: 0.9,
        hapticsOn: false,
        showDebugInfo: true,
      );
      // Through a real string, like the store does.
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>;
      expect(json['version'], PlayerProfile.jsonVersion);
      final back = PlayerProfile.fromJson(json);
      expect(back.toJson(), p.toJson());
    });

    test('missing, unknown and wrongly typed keys fall back to defaults', () {
      final p = PlayerProfile.fromJson({
        'version': 1,
        'bestDistance': 'far',
        'levelBest': {'2': 50.0, 'x': 3.0, '3': 'far'},
        'scrap': -5,
        'upgrades': {'plating': 3, 'bogus': 'x'},
        'settings': {'sfxVolume': 0.5, 'hapticsOn': 'yes'},
        'somethingNew': true,
      });
      expect(p.bestOn(1), 0);
      expect(p.bestOn(2), 50);
      expect(p.bestOn(3), 0);
      expect(p.scrap, 0);
      expect(p.upgradeLevels, {'plating': 3});
      expect(p.sfxVolume, 0.5);
      expect(p.musicVolume, PlayerProfile.defaultMusicVolume);
      expect(p.hapticsOn, isTrue);
      expect(PlayerProfile.fromJson({}).toJson(), PlayerProfile().toJson());
    });

    test('recordRun only keeps a better distance, per level', () {
      final p = PlayerProfile(levelBest: {1: 100});
      expect(p.recordRun(1, 80).isNewBest, isFalse);
      expect(p.bestOn(1), 100);
      expect(p.recordRun(1, 150).isNewBest, isTrue);
      expect(p.bestOn(1), 150);
      expect(p.bestOn(2), 0);
      expect(p.bestDistance, 150);
    });

    test(
      'stars come from the best distance; the goal unlocks the next level',
      () {
        final stars = Tuning.levels[0].starDistances;
        final p = PlayerProfile();
        expect(p.isUnlocked(1), isTrue);
        expect(p.isUnlocked(2), isFalse);
        expect(p.highestUnlockedLevel, 1);

        var record = p.recordRun(1, stars[0] - 1);
        expect(record.newStars, 0);
        expect(record.unlockedLevel, isNull);

        record = p.recordRun(1, stars[1]);
        expect(record.starsBefore, 0);
        expect(record.starsAfter, 2);
        expect(record.newStars, 2);
        expect(record.unlockedLevel, 2);
        expect(p.isUnlocked(2), isTrue);
        expect(p.highestUnlockedLevel, 2);

        // Beating the best without a new star unlocks nothing new.
        record = p.recordRun(1, stars[1] + 10);
        expect(record.newStars, 0);
        expect(record.unlockedLevel, isNull);

        p.recordRun(1, stars[2] + 1);
        expect(p.starsOn(1), Levels.maxStars);
        expect(p.totalStars, 3);
        expect(p.starScrapBonus, closeTo(3 * Tuning.scrapBonusPerStar, 1e-9));
        expect(p.isUnlocked(Levels.count + 1), isFalse);
      },
    );

    test('part tiers unlock with levels', () {
      final p = PlayerProfile(scrap: 100000);
      expect(p.maxPartTier, 1);
      expect(p.buyUpgrade(UpgradeTrack.plating), isTrue);
      // Tier 2 needs level 2.
      expect(p.isNextTierUnlocked(UpgradeTrack.plating), isFalse);
      expect(p.buyUpgrade(UpgradeTrack.plating), isFalse);
      p.recordRun(1, Tuning.levels[0].starDistances[0]);
      expect(p.maxPartTier, 2);
      expect(p.buyUpgrade(UpgradeTrack.plating), isTrue);
      expect(p.tierOf(UpgradeTrack.plating), 2);
    });

    test('debugUnlockAll maxes everything and opens every level', () {
      final p = PlayerProfile(levelBest: {1: 99999}, scrap: 5);
      p.debugUnlockAll();
      for (final track in UpgradeTrack.values) {
        expect(p.tierOf(track), Tuning.upgradeMaxLevel);
      }
      for (final gadget in Gadget.values) {
        expect(p.gadgetLevel(gadget), Tuning.gadgetMaxLevel);
      }
      expect(p.highestUnlockedLevel, Levels.count);
      expect(p.bestOn(1), 99999); // A better best is kept.
      expect(p.starsOn(2), 1); // Other levels: only the goal.
      expect(p.bestOn(Levels.count), 0);
      expect(p.scrap, 10005);
    });

    test('a version 1 save keeps its best distance as level 1', () {
      final p = PlayerProfile.fromJson({
        'version': 1,
        'bestDistance': 1234.0,
        'scrap': 10,
      });
      expect(p.bestOn(1), 1234);
      expect(p.bestOn(2), 0);
      expect(p.toJson()['version'], PlayerProfile.jsonVersion);
    });

    test('a bought Landing Sight is refunded once (it is built in now)', () {
      final p = PlayerProfile.fromJson({
        'version': 2,
        'scrap': 10,
        'gadgets': {'landingSight': 2, 'scrapMagnet': 1},
      });
      final paid = Tuning.retiredGadgetPrices['landingSight']!;
      expect(p.scrap, 10 + paid[0] + paid[1]);
      expect(p.gadgetLevels.containsKey('landingSight'), isFalse);
      expect(p.gadgetLevels['scrapMagnet'], 1);
      // Saving and loading again doesn't refund twice.
      final again = PlayerProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>,
      );
      expect(again.scrap, p.scrap);
    });

    test('the Landing Sight setting is on by default and saved', () {
      final p = PlayerProfile();
      expect(p.showLandingSight, isTrue);
      p.showLandingSight = false;
      final back = PlayerProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>,
      );
      expect(back.showLandingSight, isFalse);
    });

    test('resetProgress wipes progress and keeps settings', () {
      final p = PlayerProfile(
        levelBest: {1: 3000, 2: 300},
        scrap: 80,
        upgradeLevels: {'plating': 1},
        sfxVolume: 0.3,
        showDebugInfo: true,
      )..resetProgress();
      expect(p.bestDistance, 0);
      expect(p.totalStars, 0);
      expect(p.isUnlocked(2), isFalse);
      expect(p.scrap, 0);
      expect(p.upgradeLevels, isEmpty);
      expect(p.sfxVolume, 0.3);
      expect(p.showDebugInfo, isTrue);
    });

    test('scrap never goes negative and volumes are clamped', () {
      final p = PlayerProfile(scrap: 10)..addScrap(-50);
      expect(p.scrap, 0);
      p.musicVolume = 3;
      p.sfxVolume = -1;
      expect(p.musicVolume, 1);
      expect(p.sfxVolume, 0);
    });
  });

  group('tutorial flag', () {
    test('a new player has not had the guided first run', () {
      expect(PlayerProfile().firstRunCoached, isFalse);
      expect(PlayerProfile.fromJson(const {}).firstRunCoached, isFalse);
    });

    test('it is saved and loaded', () {
      final p = PlayerProfile()..firstRunCoached = true;
      final back = PlayerProfile.fromJson(p.toJson());
      expect(back.firstRunCoached, isTrue);
      back.firstRunCoached = false;
      expect(PlayerProfile.fromJson(back.toJson()).firstRunCoached, isFalse);
    });

    test('older saves that have played count as coached', () {
      expect(
        PlayerProfile.fromJson(const {
          'version': 3,
          'levelBest': {'1': 420.0},
        }).firstRunCoached,
        isTrue,
      );
      expect(
        PlayerProfile.fromJson(const {'version': 1, 'bestDistance': 300.0})
            .firstRunCoached,
        isTrue,
      );
      expect(
        PlayerProfile.fromJson(const {
          'version': 3,
          'levelBest': <String, Object?>{},
        }).firstRunCoached,
        isFalse,
      );
    });
  });

  group('ProfileStore', () {
    test('saves on every change and loads it back', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProfileStore.load();
      store.profile
        ..recordRun(1, 420)
        ..addScrap(25)
        ..hapticsOn = false;
      await Future<void>.delayed(Duration.zero);

      final again = await ProfileStore.load();
      expect(again.profile.bestOn(1), 420);
      expect(again.profile.scrap, 25);
      expect(again.profile.hapticsOn, isFalse);
    });

    test('an unreadable save starts a fresh profile', () async {
      SharedPreferences.setMockInitialValues({'player_profile': '{oops'});
      final store = await ProfileStore.load();
      expect(store.profile.toJson(), PlayerProfile().toJson());
    });
  });
}
