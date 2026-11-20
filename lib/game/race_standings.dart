import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../config/tuning.dart';

/// One racer's line in the Versus standings.
@immutable
class Standing {
  const Standing({
    required this.name,
    required this.color,
    required this.distance,
    this.isPlayer = false,
    this.finished = false,
  });

  final String name;
  final Color color;

  /// Meters covered: final once [finished], else live.
  final double distance;
  final bool isPlayer;
  final bool finished;
}

/// The race rules for places and the race end (D49, D50), as plain logic
/// on a list of [Standing]s (one per racer, any order).
abstract final class RaceStandings {
  /// Best first. Equal distances keep the given order (the player is
  /// listed first, so a tie counts in the player's favour).
  static List<Standing> order(List<Standing> racers) {
    final indexed = [for (var i = 0; i < racers.length; i++) (i, racers[i])];
    indexed.sort((a, b) {
      final byDistance = b.$2.distance.compareTo(a.$2.distance);
      return byDistance != 0 ? byDistance : a.$1.compareTo(b.$1);
    });
    return [for (final (_, standing) in indexed) standing];
  }

  /// The player's place right now (1 = leading).
  static int placeOf(List<Standing> racers) {
    final player = racers.firstWhere((r) => r.isPlayer);
    return 1 +
        racers.where((r) => !r.isPlayer && r.distance > player.distance).length;
  }

  /// True once the player has finished and their place can't change any
  /// more: every rival still running is already ahead (finished rivals'
  /// distances are final, and running ones only move on downhill).
  static bool placeLocked(List<Standing> racers) {
    final player = racers.firstWhere((r) => r.isPlayer);
    return player.finished &&
        racers.every(
          (r) => r.isPlayer || r.finished || r.distance > player.distance,
        );
  }

  /// The rival who can still pass the finished player and is closest to
  /// doing so: the camera follows it during the fast-forward. Its index
  /// in [racers], or null when nobody behind is still running.
  static int? chaserIndex(List<Standing> racers) {
    final player = racers.firstWhere((r) => r.isPlayer);
    int? best;
    for (var i = 0; i < racers.length; i++) {
      final r = racers[i];
      if (r.isPlayer || r.finished || r.distance > player.distance) {
        continue;
      }
      if (best == null || r.distance > racers[best].distance) {
        best = i;
      }
    }
    return best;
  }
}

/// A marker on the screen edge for a rival out of view (D50).
@immutable
class RivalMarker {
  const RivalMarker({
    required this.name,
    required this.color,
    required this.onRight,
    required this.height,
    required this.gap,
  });

  final String name;
  final Color color;

  /// Which edge: right = further down the hill than the camera.
  final bool onRight;

  /// Where along the edge: 0 = top of the screen, 1 = bottom (kept
  /// clear of the HUD at both ends).
  final double height;

  /// Meters ahead of the player (negative = behind).
  final double gap;

  /// "+132 m" / "-40 m".
  String get gapLabel =>
      '${gap >= 0 ? '+' : '-'}${gap.abs().toStringAsFixed(0)} m';

  /// The marker for a rival [dx], [dy] meters from the camera center
  /// (y down), when the view reaches [halfWidth] and [halfHeight] meters
  /// from the center; null while the rival is on screen.
  static RivalMarker? offScreen({
    required String name,
    required Color color,
    required double dx,
    required double dy,
    required double halfWidth,
    required double halfHeight,
    required double gap,
  }) {
    if (dx.abs() <= halfWidth && dy.abs() <= halfHeight) {
      return null;
    }
    final height = (0.5 + dy / halfHeight / 2).clamp(
      Tuning.raceMarkerTop,
      Tuning.raceMarkerBottom,
    );
    return RivalMarker(
      name: name,
      color: color,
      onRight: dx >= 0,
      height: height,
      gap: gap,
    );
  }
}

/// The player's new place, announced for a moment ("2ND!").
@immutable
class PlaceCallout {
  const PlaceCallout({
    required this.place,
    required this.improved,
    required this.serial,
  });

  final int place;

  /// Moved up (true) or dropped back (false).
  final bool improved;

  /// Counts callouts, so the HUD can replay its pop for each new one.
  final int serial;
}

/// Watches the player's place and announces changes (D50). A new place
/// must hold for [Tuning.raceCalloutDelay] first, so robots swapping back
/// and forth don't flood the screen.
class PlaceWatcher {
  int? _shown;
  int? _pending;
  double _pendingFor = 0;
  double _showLeft = 0;
  int _serial = 0;
  PlaceCallout? _last;

  /// The callout to show right now, or null.
  PlaceCallout? get callout => _showLeft > 0 ? _last : null;

  /// Feeds the current [place]. While not [live] (the opening drop, after
  /// the finish) places are only tracked, never announced.
  void update(double dt, int place, {required bool live}) {
    _showLeft -= dt;
    if (!live || _shown == null) {
      _shown = place;
      _pending = null;
      return;
    }
    if (place == _shown) {
      _pending = null;
      return;
    }
    if (place != _pending) {
      _pending = place;
      _pendingFor = 0;
    }
    _pendingFor += dt;
    if (_pendingFor >= Tuning.raceCalloutDelay) {
      _last = PlaceCallout(
        place: place,
        improved: place < _shown!,
        serial: ++_serial,
      );
      _shown = place;
      _pending = null;
      _showLeft = Tuning.raceCalloutTime;
    }
  }

  void reset() {
    _shown = null;
    _pending = null;
    _showLeft = 0;
    _last = null;
  }
}
