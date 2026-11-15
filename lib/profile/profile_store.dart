import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_profile.dart';

/// Loads the [PlayerProfile] from the device and saves it after every change.
class ProfileStore {
  ProfileStore._(this._prefs, this.profile) {
    profile.addListener(_save);
  }

  static const String _key = 'player_profile';

  final SharedPreferences _prefs;

  /// The loaded profile; changes to it are saved automatically.
  final PlayerProfile profile;

  /// Reads the saved profile, or starts a fresh one if there is none (or it
  /// can't be read).
  static Future<ProfileStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ProfileStore._(prefs, _decode(prefs.getString(_key)));
  }

  static PlayerProfile _decode(String? text) {
    if (text == null) {
      return PlayerProfile();
    }
    try {
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) {
        return PlayerProfile.fromJson(json);
      }
    } on FormatException catch (e) {
      debugPrint('Saved profile unreadable, starting fresh: $e');
    }
    return PlayerProfile();
  }

  void _save() =>
      unawaited(_prefs.setString(_key, jsonEncode(profile.toJson())));
}
