import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/hill.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/game/scrap_props.dart';

void main() {
  final hill = HillGeometry();

  test('the same seed always builds the same hill', () {
    final again = HillGeometry();
    for (var x = -20.0; x < 500; x += 3.7) {
      expect(again.heightAt(x), hill.heightAt(x));
    }
  });

  for (var level = 1; level <= Levels.count; level++) {
    final levelHill = HillGeometry(level: level);
    final slopeDeg = Levels.of(level).slopeDeg;

    test('level $level averages its slope angle over a long stretch', () {
      const length = 2000.0;
      final drop = levelHill.heightAt(length) - levelHill.heightAt(0);
      final angle = math.atan(drop / length) * 180 / math.pi;
      expect(angle, closeTo(slopeDeg, 0.5));
    });

    test('level $level has no flat start', () {
      final angleDeg = levelHill.slopeAngleAt(Tuning.startX) * 180 / math.pi;
      expect(angleDeg, greaterThan(slopeDeg - 10));
    });

    test(
      'level $level always goes downhill, so the robot cannot get stuck',
      () {
        // Check far down the hill too, since it never ends.
        const step = Tuning.hillPointSpacing;
        for (var x = 0.0; x < 5000; x += step) {
          expect(
            levelHill.heightAt(x + step),
            greaterThan(levelHill.heightAt(x)),
            reason: 'at x=$x',
          );
        }
      },
    );
  }

  test('later levels are rougher: landing angles vary more', () {
    double spreadDeg(HillGeometry h) {
      var lo = double.infinity, hi = -double.infinity;
      for (var x = 20.0; x < 2000; x += 0.5) {
        final a = h.slopeAngleAt(x) * 180 / math.pi;
        lo = math.min(lo, a);
        hi = math.max(hi, a);
      }
      return hi - lo;
    }

    final first = spreadDeg(HillGeometry());
    final last = spreadDeg(HillGeometry(level: Levels.count));
    expect(last, greaterThan(first + 10));
  });

  test('every level has its own hill', () {
    final a =
        HillGeometry(level: 1).heightAt(100) -
        100 * math.tan(35 * math.pi / 180);
    final b =
        HillGeometry(level: 2).heightAt(100) -
        100 * math.tan(36 * math.pi / 180);
    expect(a, isNot(closeTo(b, 1e-3)));
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

  test('props are placed on the ground and stay the same per chunk', () {
    final a = propsForChunk(hill, 4);
    final b = propsForChunk(hill, 4);
    expect(a, isNotEmpty);
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].position, b[i].position);
      expect(a[i].position.y, closeTo(hill.heightAt(a[i].position.x), 1e-3));
    }
  });

  test('no props near the drop zone at the start', () {
    final props = propsForChunk(hill, 0);
    expect(props.every((p) => p.position.x >= 20), isTrue);
  });
}
