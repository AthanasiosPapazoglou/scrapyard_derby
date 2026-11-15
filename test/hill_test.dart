import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/hill.dart';

void main() {
  final hill = HillGeometry();

  test('the same seed always builds the same hill', () {
    final again = HillGeometry();
    for (var x = -20.0; x < 500; x += 3.7) {
      expect(again.heightAt(x), hill.heightAt(x));
    }
  });

  test('the hill averages the tuned slope angle over a long stretch', () {
    const length = 2000.0;
    final drop = hill.heightAt(length) - hill.heightAt(0);
    final angle = math.atan(drop / length) * 180 / math.pi;
    expect(angle, closeTo(Tuning.hillSlopeDeg, 0.5));
  });

  test('there is no flat start: the hill is already steep at the start', () {
    final angleDeg = hill.slopeAngleAt(Tuning.startX) * 180 / math.pi;
    expect(angleDeg, greaterThan(Tuning.hillSlopeDeg - 10));
  });

  test('the ground always goes downhill, so the robot cannot get stuck', () {
    // Check far down the hill too, since it never ends.
    const step = Tuning.hillPointSpacing;
    for (var x = 0.0; x < 5000; x += step) {
      expect(
        hill.heightAt(x + step),
        greaterThan(hill.heightAt(x)),
        reason: 'at x=$x',
      );
    }
  });

  test('chunk points go left to right so the chain faces upward', () {
    // Box2D chains are one-sided; in our y-down world, left-to-right order
    // makes the solid side face up.
    final points = hill.chunkPoints(3);
    for (var i = 1; i < points.length; i++) {
      expect(points[i].x, greaterThan(points[i - 1].x));
    }
  });

  test('neighbouring chunks join without a gap', () {
    for (var index = -1; index < 5; index++) {
      final a = hill.chunkPoints(index);
      final b = hill.chunkPoints(index + 1);
      // Points are [ghost, first ... last, ghost]. The last real point of a
      // chunk is the first real point of the next one, and each chunk's
      // ghost is its neighbour's real point next to the seam.
      expect(a[a.length - 2], b[1]);
      expect(a.last, b[2]);
      expect(b.first, a[a.length - 3]);
    }
  });
}
