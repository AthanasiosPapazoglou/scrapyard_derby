import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/race_standings.dart';

const _c = Color(0xFF000000);

Standing _you(double d, {bool finished = false}) => Standing(
  name: 'YOU',
  color: _c,
  distance: d,
  isPlayer: true,
  finished: finished,
);

Standing _rival(String name, double d, {bool finished = false}) =>
    Standing(name: name, color: _c, distance: d, finished: finished);

void main() {
  group('order and place', () {
    test('best first, finished and running mixed', () {
      final racers = [
        _you(300, finished: true),
        _rival('A', 500),
        _rival('B', 100, finished: true),
        _rival('C', 320, finished: true),
      ];
      expect(
        [for (final s in RaceStandings.order(racers)) s.name],
        ['A', 'C', 'YOU', 'B'],
      );
      expect(RaceStandings.placeOf(racers), 3);
    });

    test('a tie counts for the player', () {
      final racers = [_rival('A', 50), _you(50), _rival('B', 50)];
      expect(RaceStandings.placeOf(racers), 1);
      expect(RaceStandings.order(racers).first.name, 'A');
    });
  });

  group('place locked', () {
    test('never while the player is still running', () {
      expect(
        RaceStandings.placeLocked([
          _you(900),
          _rival('A', 10, finished: true),
          _rival('B', 10, finished: true),
          _rival('C', 10, finished: true),
        ]),
        isFalse,
      );
    });

    test('when every rival has finished', () {
      expect(
        RaceStandings.placeLocked([
          _you(300, finished: true),
          _rival('A', 500, finished: true),
          _rival('B', 100, finished: true),
          _rival('C', 200, finished: true),
        ]),
        isTrue,
      );
    });

    test('not while a running rival is behind (it may still pass)', () {
      final racers = [
        _you(300, finished: true),
        _rival('A', 500),
        _rival('B', 250),
        _rival('C', 100, finished: true),
      ];
      expect(RaceStandings.placeLocked(racers), isFalse);
      // The camera follows the rival behind who is closest.
      expect(RaceStandings.chaserIndex(racers), 2);
    });

    test('when every running rival is already ahead', () {
      final racers = [
        _you(300, finished: true),
        _rival('A', 500),
        _rival('B', 301),
        _rival('C', 100, finished: true),
      ];
      expect(RaceStandings.placeLocked(racers), isTrue);
      expect(RaceStandings.chaserIndex(racers), isNull);
      expect(RaceStandings.placeOf(racers), 3);
    });
  });

  group('edge markers', () {
    RivalMarker? marker(double dx, double dy) => RivalMarker.offScreen(
      name: 'A',
      color: _c,
      dx: dx,
      dy: dy,
      halfWidth: 10,
      halfHeight: 20,
      gap: dx,
    );

    test('none while on screen', () {
      expect(marker(5, -15), isNull);
    });

    test('right edge ahead, left edge behind', () {
      final ahead = marker(132.4, 0)!;
      expect(ahead.onRight, isTrue);
      expect(ahead.height, 0.5);
      expect(ahead.gapLabel, '+132 m');
      final behind = marker(-40, 0)!;
      expect(behind.onRight, isFalse);
      expect(behind.gapLabel, '-40 m');
    });

    test('height follows the rival but stays clear of the HUD', () {
      expect(marker(50, -500)!.height, Tuning.raceMarkerTop);
      expect(marker(50, 500)!.height, Tuning.raceMarkerBottom);
      // Straight above, in view sideways: still off screen.
      expect(marker(0, -30), isNotNull);
    });
  });

  group('place callout', () {
    test('quiet before going live, then announces a held change', () {
      final watcher = PlaceWatcher();
      watcher.update(0.1, 3, live: false);
      watcher.update(0.1, 1, live: false);
      expect(watcher.callout, isNull);
      // Live from place 1: dropping to 2nd must hold a moment first.
      watcher.update(0.1, 2, live: true);
      expect(watcher.callout, isNull);
      for (var t = 0.0; t < Tuning.raceCalloutDelay; t += 0.1) {
        watcher.update(0.1, 2, live: true);
      }
      final callout = watcher.callout!;
      expect(callout.place, 2);
      expect(callout.improved, isFalse);
      // It fades after a while.
      for (var t = 0.0; t <= Tuning.raceCalloutTime; t += 0.1) {
        watcher.update(0.1, 2, live: true);
      }
      expect(watcher.callout, isNull);
    });

    test('a callout goes away as soon as the place changes again', () {
      final watcher = PlaceWatcher()..update(0.1, 1, live: true);
      for (var t = 0.0; t <= Tuning.raceCalloutDelay + 0.1; t += 0.1) {
        watcher.update(0.1, 4, live: true);
      }
      expect(watcher.callout!.place, 4);
      watcher.update(0.1, 2, live: true);
      expect(watcher.callout, isNull);
    });

    test('robots swapping back and forth make no callout', () {
      final watcher = PlaceWatcher()..update(0.1, 2, live: true);
      for (var i = 0; i < 20; i++) {
        watcher.update(0.1, i.isEven ? 1 : 2, live: true);
      }
      expect(watcher.callout, isNull);
    });

    test('moving up is an improvement; each callout is new', () {
      final watcher = PlaceWatcher()..update(0.1, 3, live: true);
      for (var t = 0.0; t <= Tuning.raceCalloutDelay; t += 0.1) {
        watcher.update(0.1, 2, live: true);
      }
      final first = watcher.callout!;
      expect(first.improved, isTrue);
      for (var t = 0.0; t <= Tuning.raceCalloutDelay; t += 0.1) {
        watcher.update(0.1, 1, live: true);
      }
      expect(watcher.callout!.place, 1);
      expect(watcher.callout!.serial, greaterThan(first.serial));
    });
  });
}
