import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
        bestDistance: 812.5,
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
        'scrap': -5,
        'upgrades': {'plating': 3, 'bogus': 'x'},
        'settings': {'sfxVolume': 0.5, 'hapticsOn': 'yes'},
        'somethingNew': true,
      });
      expect(p.bestDistance, 0);
      expect(p.scrap, 0);
      expect(p.upgradeLevels, {'plating': 3});
      expect(p.sfxVolume, 0.5);
      expect(p.musicVolume, PlayerProfile.defaultMusicVolume);
      expect(p.hapticsOn, isTrue);
      expect(PlayerProfile.fromJson({}).toJson(), PlayerProfile().toJson());
    });

    test('recordRun only keeps a better distance', () {
      final p = PlayerProfile(bestDistance: 100);
      expect(p.recordRun(80), isFalse);
      expect(p.bestDistance, 100);
      expect(p.recordRun(150), isTrue);
      expect(p.bestDistance, 150);
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

  group('ProfileStore', () {
    test('saves on every change and loads it back', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProfileStore.load();
      store.profile
        ..recordRun(420)
        ..addScrap(25)
        ..hapticsOn = false;
      await Future<void>.delayed(Duration.zero);

      final again = await ProfileStore.load();
      expect(again.profile.bestDistance, 420);
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
