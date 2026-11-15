import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';

/// The viewBox (x, y, w, h) of `assets/robot/<name>.svg`, in art pixels.
List<double> viewBox(String name) {
  final svg = File('assets/robot/$name.svg').readAsStringSync();
  final match = RegExp(r'viewBox="([^"]+)"').firstMatch(svg)!;
  return match
      .group(1)!
      .trim()
      .split(RegExp(r'\s+'))
      .map(double.parse)
      .toList();
}

/// True if the box (left, top, right, bottom) fits inside the viewBox.
bool fits(List<double> box, List<double> vb) {
  final (left, top, right, bottom) = (box[0], box[1], box[2], box[3]);
  return left >= vb[0] &&
      top >= vb[1] &&
      right <= vb[0] + vb[2] &&
      bottom <= vb[1] + vb[3];
}

/// Every tier of a slot: `<slot>_0` .. `<slot>_5`.
List<String> tiers(String slot) => [
  for (var t = 0; t <= Tuning.upgradeMaxLevel; t++) '${slot}_$t',
];

void main() {
  // These checks keep the art (art/make_parts.py → assets/robot) and the
  // collision shapes (Tuning) in step, for every part at every tier. If one
  // fails, re-export the sprites or update the shape numbers in tuning.dart.

  test('every slot has a sprite for every tier', () {
    for (final track in UpgradeTrack.values) {
      for (final name in tiers(track.art)) {
        expect(
          File('assets/robot/$name.svg').existsSync(),
          isTrue,
          reason: name,
        );
      }
    }
  });

  test('every sprite has its pivot (0, 0) inside its viewBox', () {
    for (final track in UpgradeTrack.values) {
      for (final name in tiers(track.art)) {
        expect(fits([0, 0, 0, 0], viewBox(name)), isTrue, reason: name);
      }
    }
  });

  test('the torso box fits inside every body', () {
    const w = Tuning.torsoHalfWidth;
    const h = Tuning.torsoHalfHeight;
    for (final name in tiers('body')) {
      expect(fits([-w, -h, w, h], viewBox(name)), isTrue, reason: name);
    }
  });

  test('the head circle fits inside every head', () {
    const r = Tuning.headRadius;
    const cy = -Tuning.headOffset;
    for (final name in tiers('head')) {
      expect(
        fits([-r, cy - r, r, cy + r], viewBox(name)),
        isTrue,
        reason: name,
      );
    }
  });

  test('the arm capsule fits inside every arm', () {
    const r = Tuning.armRadius;
    for (final name in tiers('arms')) {
      expect(
        fits([-r, -r, r, Tuning.armLength + r], viewBox(name)),
        isTrue,
        reason: name,
      );
    }
  });

  test('the leg and foot fit inside every leg', () {
    const fx = Tuning.footCenterX;
    const fy = Tuning.footCenterY;
    const fw = Tuning.footHalfWidth;
    const fh = Tuning.footHalfHeight;
    const r = Tuning.legRadius;
    for (final name in tiers('legs')) {
      final vb = viewBox(name);
      expect(
        fits([fx - fw, fy - fh, fx + fw, fy + fh], vb),
        isTrue,
        reason: name,
      );
      expect(fits([-r, -r, r, Tuning.legLength + r], vb), isTrue, reason: name);
    }
  });

  test('the core fits on the chest of the torso box', () {
    for (final name in tiers('core')) {
      final vb = viewBox(name);
      expect(vb[2], lessThanOrEqualTo(Tuning.torsoHalfWidth * 2), reason: name);
      expect(
        vb[3],
        lessThanOrEqualTo(Tuning.torsoHalfHeight * 2),
        reason: name,
      );
    }
  });

  test('part names in the game match the art script', () {
    final script = File('art/make_parts.py').readAsStringSync();
    for (final track in UpgradeTrack.values) {
      expect(track.partNames, hasLength(Tuning.upgradeMaxLevel + 1));
      for (final name in track.partNames) {
        expect(script, contains('"$name"'), reason: name);
      }
    }
  });
}
