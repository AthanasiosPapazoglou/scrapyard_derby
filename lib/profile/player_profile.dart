import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import '../game/robot_stats.dart';

/// Everything the game remembers between launches: best distance, scrap,
/// upgrade levels and settings.
///
/// Every change calls [notifyListeners]; the [ProfileStore] listens and
/// saves, so callers never have to remember to save.
class PlayerProfile extends ChangeNotifier {
  PlayerProfile({
    this._bestDistance = 0,
    this._scrap = 0,
    Map<String, int> upgradeLevels = const {},
    this._musicVolume = defaultMusicVolume,
    this._sfxVolume = defaultSfxVolume,
    this._hapticsOn = Tuning.hapticsEnabled,
    this._showDebugInfo = false,
  }) : _upgradeLevels = Map.of(upgradeLevels);

  /// Bump this when the JSON layout changes, and migrate in [fromJson].
  static const int jsonVersion = 1;

  static const double defaultMusicVolume = 0.7;
  static const double defaultSfxVolume = 0.8;

  double _bestDistance;
  int _scrap;
  final Map<String, int> _upgradeLevels;
  double _musicVolume;
  double _sfxVolume;
  bool _hapticsOn;
  bool _showDebugInfo;

  /// Best distance ever, in meters.
  double get bestDistance => _bestDistance;

  /// Currency earned from runs, spent in the Workshop.
  int get scrap => _scrap;

  /// Upgrade level per track name (missing = level 0).
  Map<String, int> get upgradeLevels => Map.unmodifiable(_upgradeLevels);
  int upgradeLevel(String track) => _upgradeLevels[track] ?? 0;

  /// Volumes from 0 (off) to 1 (full).
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  /// Vibrate on landings, limb loss and head launch.
  bool get hapticsOn => _hapticsOn;

  /// Show the developer numbers panel during a run.
  bool get showDebugInfo => _showDebugInfo;

  // ---------------------------------------------------------------- Changes

  /// Records a finished run. Returns true if [distance] is a new best.
  bool recordRun(double distance) {
    if (distance <= _bestDistance) {
      return false;
    }
    _bestDistance = distance;
    notifyListeners();
    return true;
  }

  void addScrap(int amount) {
    if (amount == 0) {
      return;
    }
    _scrap = math.max(0, _scrap + amount);
    notifyListeners();
  }

  /// Can the next level of [track] be bought right now?
  bool canBuy(UpgradeTrack track) {
    final price = track.priceAfter(upgradeLevel(track.id));
    return price != null && price <= _scrap;
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
  RobotStats get robotStats => RobotStats.fromLevelOf(upgradeLevel);

  void setUpgradeLevel(String track, int level) {
    _upgradeLevels[track] = level;
    notifyListeners();
  }

  /// Wipes best distance, scrap and upgrades. Settings are kept.
  void resetProgress() {
    _bestDistance = 0;
    _scrap = 0;
    _upgradeLevels.clear();
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

  // ---------------------------------------------------------------- JSON

  Map<String, Object?> toJson() => {
    'version': jsonVersion,
    'bestDistance': _bestDistance,
    'scrap': _scrap,
    'upgrades': Map.of(_upgradeLevels),
    'settings': {
      'musicVolume': _musicVolume,
      'sfxVolume': _sfxVolume,
      'hapticsOn': _hapticsOn,
      'showDebugInfo': _showDebugInfo,
    },
  };

  /// Reads saved data. Missing, unknown or wrongly typed values fall back to
  /// the defaults instead of throwing, so a damaged save never blocks play.
  factory PlayerProfile.fromJson(Map<String, Object?> json) {
    final settings = json['settings'];
    final s = settings is Map ? settings : const {};
    final upgrades = json['upgrades'];
    return PlayerProfile(
      bestDistance: _double(json['bestDistance'], 0),
      scrap: math.max(0, _int(json['scrap'], 0)),
      upgradeLevels: {
        if (upgrades is Map)
          for (final MapEntry(:key, :value) in upgrades.entries)
            if (key is String && value is int) key: value,
      },
      musicVolume: _double(s['musicVolume'], defaultMusicVolume),
      sfxVolume: _double(s['sfxVolume'], defaultSfxVolume),
      hapticsOn: _bool(s['hapticsOn'], Tuning.hapticsEnabled),
      showDebugInfo: _bool(s['showDebugInfo'], false),
    );
  }

  static double _double(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;
}
