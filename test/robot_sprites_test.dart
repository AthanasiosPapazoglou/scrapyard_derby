import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';

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

void main() {
  // These checks keep the art (art/make_style_test.py → assets/robot) and
  // the collision shapes (Tuning) in step. If one fails, re-export the
  // sprites or update the shape numbers in tuning.dart.

  test('every sprite has its pivot (0, 0) inside its viewBox', () {
    for (final name in ['torso', 'head', 'arm', 'leg']) {
      expect(fits([0, 0, 0, 0], viewBox(name)), isTrue, reason: name);
    }
  });

  test('the torso box fits inside the torso art', () {
    const w = Tuning.torsoHalfWidth;
    const h = Tuning.torsoHalfHeight;
    expect(fits([-w, -h, w, h], viewBox('torso')), isTrue);
  });

  test('the head circle fits inside the head art', () {
    const r = Tuning.headRadius;
    const cy = -Tuning.headOffset;
    expect(fits([-r, cy - r, r, cy + r], viewBox('head')), isTrue);
  });

  test('the arm capsule fits inside the arm art', () {
    const r = Tuning.armRadius;
    expect(fits([-r, -r, r, Tuning.armLength + r], viewBox('arm')), isTrue);
  });

  test('the leg and foot fit inside the leg art', () {
    const fx = Tuning.footCenterX;
    const fy = Tuning.footCenterY;
    const fw = Tuning.footHalfWidth;
    const fh = Tuning.footHalfHeight;
    expect(fits([fx - fw, fy - fh, fx + fw, fy + fh], viewBox('leg')), isTrue);
    const r = Tuning.legRadius;
    expect(fits([-r, -r, r, Tuning.legLength + r], viewBox('leg')), isTrue);
  });
}
