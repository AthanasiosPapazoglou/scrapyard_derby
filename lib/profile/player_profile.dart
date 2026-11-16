import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import '../game/gadgets.dart';
import '../game/levels.dart';
import '../game/robot_stats.dart';

/// What a finished run changed on its level (see [PlayerProfile.recordRun]).
@immutable
class RunRecord {
  const RunRecord({
    required this.isNewBest,
    required this.starsBefore,
    required this.starsAfter,
    required this.unlockedLevel,
  });

  final bool isNewBest;

  /// The level's stars before and after this run (0-3).
  final int starsBefore;
  final int starsAfter;

  /// The level this run unlocked (its first star), or null.
  final int? unlockedLevel;

  /// Stars earned for the first time by this run.
  int get newStars => starsAfter - starsBefore;
}

/// Everything the game remembers between launches: best distance per
/// level (stars and unlocks follow from it), scrap, upgrade levels and
/// settings.
///
/// Every change calls [notifyListeners]; the [ProfileStore] listens and
/// saves, so callers never have to remember to save.
class PlayerProfile extends ChangeNotifier {
  PlayerProfile({
    Map<int, double> levelBest = const {},
    this._scrap = 0,
    Map<String, int> upgradeLevels = const {},
    Map<String, int> gadgetLevels = const {},
    this._musicVolume = defaultMusicVolume,
    this._sfxVolume = defaultSfxVolume,
    this._hapticsOn = Tuning.hapticsEnabled,
    this._showDebugInfo = false,
    this._showLandingSight = true,
  }) : _levelBest = Map.of(levelBest),
       _upgradeLevels = Map.of(upgradeLevels),
       _gadgetLevels = Map.of(gadgetLevels);

  /// Bump this when the JSON layout changes, and migrate in [fromJson].
  /// v2: best distance per level (v1 had one best, now level 1's).
  /// v3 (1.1.0): the Landing Sight gadget is built in; saves that bought
  /// it get the scrap back ([Tuning.retiredGadgetPrices]).
  static const int jsonVersion = 3;

  static const double defaultMusicVolume = 0.7;
  static const double defaultSfxVolume = 0.8;

  final Map<int, double> _levelBest;
  int _scrap;
  final Map<String, int> _upgradeLevels;
  final Map<String, int> _gadgetLevels;
  double _musicVolume;
  double _sfxVolume;
  bool _hapticsOn;
  bool _showDebugInfo;
  bool _showLandingSight;

  /// Best distance on [level], in meters (0 = never played).
  double bestOn(int level) => _levelBest[level] ?? 0;

  /// Best distance on any level, in meters.
  double get bestDistance => _levelBest.values.fold(0, math.max);

  /// Stars (0-3) earned on [level], from its best distance.
  int starsOn(int level) => Levels.starsFor(level, bestOn(level));

  /// Stars earned on all levels together.
  int get totalStars =>
      [for (var level = 1; level <= Levels.count; level++) starsOn(level)]
          .fold(0, (a, b) => a + b);

  /// Level 1 is always open; every other level opens with the first star
  /// of the level before it.
  bool isUnlocked(int level) =>
      level == 1 ||
      (level > 1 && level <= Levels.count && starsOn(level - 1) > 0);

  /// The furthest level the player can play.
  int get highestUnlockedLevel {
    var level = 1;
    while (level < Levels.count && isUnlocked(level + 1)) {
      level++;
    }
    return level;
  }

  /// The best part tier the Workshop sells right now (set by the furthest
  /// unlocked level).
  int get maxPartTier => Levels.of(highestUnlockedLevel).partTier;

  /// Extra share of scrap from stars, e.g. 0.12 = +12% (see
  /// [Tuning.scrapBonusPerStar]).
  double get starScrapBonus => totalStars * Tuning.scrapBonusPerStar;

  /// Currency earned from runs, spent in the Workshop.
  int get scrap => _scrap;

  /// Upgrade level per track name (missing = level 0).
  Map<String, int> get upgradeLevels => Map.unmodifiable(_upgradeLevels);
  int upgradeLevel(String track) => _upgradeLevels[track] ?? 0;

  /// Gadget level per gadget id (missing = not owned).
  Map<String, int> get gadgetLevels => Map.unmodifiable(_gadgetLevels);
  int gadgetLevel(Gadget gadget) => _gadgetLevels[gadget.id] ?? 0;

  /// Is [gadget] for sale yet (its level unlocked)?
  bool isGadgetUnlocked(Gadget gadget) => isUnlocked(gadget.unlockLevel);

  /// Can the next level of [gadget] be bought right now?
  bool canBuyGadget(Gadget gadget) {
    final price = gadget.priceAfter(gadgetLevel(gadget));
    return price != null && isGadgetUnlocked(gadget) && price <= _scrap;
  }

  /// Buys the next level of [gadget]. Returns false (and changes nothing)
  /// if it is maxed, still locked or too expensive.
  bool buyGadget(Gadget gadget) {
    if (!canBuyGadget(gadget)) {
      return false;
    }
    final level = gadgetLevel(gadget);
    _scrap -= gadget.priceAfter(level)!;
    _gadgetLevels[gadget.id] = level + 1;
    notifyListeners();
    return true;
  }

  /// Volumes from 0 (off) to 1 (full).
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  /// Vibrate on landings, limb loss and head launch.
  bool get hapticsOn => _hapticsOn;

  /// Show the developer numbers panel during a run.
  bool get showDebugInfo => _showDebugInfo;

  /// Whether the built-in Landing Sight shows in runs (Settings).
  bool get showLandingSight => _showLandingSight;

  // ---------------------------------------------------------------- Changes

  /// Records a finished run on [level]: keeps the best distance and
  /// reports what it changed (new best, stars, unlocks).
  RunRecord recordRun(int level, double distance) {
    final starsBefore = starsOn(level);
    final wasUnlocked = isUnlocked(level + 1);
    final isNewBest = distance > bestOn(level);
    if (isNewBest) {
      _levelBest[level] = distance;
      notifyListeners();
    }
    final unlocks = !wasUnlocked && isUnlocked(level + 1);
    return RunRecord(
      isNewBest: isNewBest,
      starsBefore: starsBefore,
      starsAfter: starsOn(level),
      unlockedLevel: unlocks ? level + 1 : null,
    );
  }

  void addScrap(int amount) {
    if (amount == 0) {
      return;
    }
    _scrap = math.max(0, _scrap + amount);
    notifyListeners();
  }

  /// Is the next part of [track] for sale yet? Tier N opens with level N
  /// (see [maxPartTier]). False when the slot is maxed.
  bool isNextTierUnlocked(UpgradeTrack track) {
    final next = upgradeLevel(track.id) + 1;
    return next <= Tuning.upgradeMaxLevel && next <= maxPartTier;
  }

  /// Can the next level of [track] be bought right now?
  bool canBuy(UpgradeTrack track) {
    final price = track.priceAfter(upgradeLevel(track.id));
    return price != null && isNextTierUnlocked(track) && price <= _scrap;
  }

  /// Buys the next level of [track]: takes its price in scrap and raises
  /// the level by one. Returns false (and changes nothing) if it is maxed
  /// or the player can't afford it.
  bool buyUpgrade(UpgradeTrack track) {
    if (!canBuy(track)) {
      return false;
    }
    final level = upgradeLevel(track.id);
    _scrap -= track.priceAfter(level)!;
    _upgradeLevels[track.id] = level + 1;
    notifyListeners();
    return true;
  }

  /// The installed part tier in [track]'s slot (0 = the scrap part).
  int tierOf(UpgradeTrack track) => upgradeLevel(track.id);

  /// The robot's numbers with this profile's upgrades.
  RobotStats get robotStats => RobotStats.fromLevelOf(
    upgradeLevel,
    gadgetLevelOf: (id) => _gadgetLevels[id] ?? 0,
  );

  void setUpgradeLevel(String track, int level) {
    _upgradeLevels[track] = level;
    notifyListeners();
  }

  /// Developer shortcut (Settings, debug builds only): every part at the
  /// top tier, every gadget maxed, every level open (each level before the
  /// last gets at least its first-star distance, so the other stars are
  /// still to earn) and [extraScrap] more scrap. Better bests are kept.
  void debugUnlockAll({int extraScrap = 10000}) {
    for (final track in UpgradeTrack.values) {
      _upgradeLevels[track.id] = Tuning.upgradeMaxLevel;
    }
    for (final gadget in Gadget.values) {
      _gadgetLevels[gadget.id] = Tuning.gadgetMaxLevel;
    }
    for (var level = 1; level < Levels.count; level++) {
      final goal = Levels.of(level).starDistances.first;
      _levelBest[level] = math.max(bestOn(level), goal);
    }
    _scrap += extraScrap;
    notifyListeners();
  }

  /// Wipes best distances (so stars and unlocks), scrap, upgrades and
  /// gadgets.
  /// Settings are kept.
  void resetProgress() {
    _levelBest.clear();
    _scrap = 0;
    _upgradeLevels.clear();
    _gadgetLevels.clear();
    notifyListeners();
  }

  set musicVolume(double value) {
    _musicVolume = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  set sfxVolume(double value) {
    _sfxVolume = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  set hapticsOn(bool value) {
    _hapticsOn = value;
    notifyListeners();
  }

  set showDebugInfo(bool value) {
    _showDebugInfo = value;
    notifyListeners();
  }

  set showLandingSight(bool value) {
    _showLandingSight = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------- JSON

  Map<String, Object?> toJson() => {
    'version': jsonVersion,
    'levelBest': {
      for (final MapEntry(:key, :value) in _levelBest.entries) '$key': value,
    },
    'scrap': _scrap,
    'upgrades': Map.of(_upgradeLevels),
    'gadgets': Map.of(_gadgetLevels),
    'settings': {
      'musicVolume': _musicVolume,
      'sfxVolume': _sfxVolume,
      'hapticsOn': _hapticsOn,
      'showDebugInfo': _showDebugInfo,
      'showLandingSight': _showLandingSight,
    },
  };

  /// Reads saved data. Missing, unknown or wrongly typed values fall back to
  /// the defaults instead of throwing, so a damaged save never blocks play.
  factory PlayerProfile.fromJson(Map<String, Object?> json) {
    final settings = json['settings'];
    final s = settings is Map ? settings : const {};
    final upgrades = json['upgrades'];
    final levelBest = json['levelBest'];
    final gadgets = json['gadgets'];
    final gadgetLevels = <String, int>{
      if (gadgets is Map)
        for (final MapEntry(:key, :value) in gadgets.entries)
          if (key is String && value is int) key: value,
    };
    // Gadgets taken out of the shop are refunded (once: they are dropped
    // from the save here).
    var refund = 0;
    for (final MapEntry(key: id, value: prices)
        in Tuning.retiredGadgetPrices.entries) {
      final owned = (gadgetLevels.remove(id) ?? 0).clamp(0, prices.length);
      refund += prices.take(owned).fold(0, (sum, price) => sum + price);
    }
    return PlayerProfile(
      levelBest: {
        // v1 saves had one best distance: it was played on level 1.
        if (json['bestDistance'] case final num v1Best when v1Best > 0)
          1: v1Best.toDouble(),
        if (levelBest is Map)
          for (final MapEntry(:key, :value) in levelBest.entries)
            if (key is String && int.tryParse(key) != null && value is num)
              int.parse(key): value.toDouble(),
      },
      scrap: math.max(0, _int(json['scrap'], 0)) + refund,
      upgradeLevels: {
        if (upgrades is Map)
          for (final MapEntry(:key, :value) in upgrades.entries)
            if (key is String && value is int) key: value,
      },
      gadgetLevels: gadgetLevels,
      musicVolume: _double(s['musicVolume'], defaultMusicVolume),
      sfxVolume: _double(s['sfxVolume'], defaultSfxVolume),
      hapticsOn: _bool(s['hapticsOn'], Tuning.hapticsEnabled),
      showDebugInfo: _bool(s['showDebugInfo'], false),
      showLandingSight: _bool(s['showLandingSight'], true),
    );
  }

  static double _double(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;
}
