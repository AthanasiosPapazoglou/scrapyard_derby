import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/dusk_scene.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/game/palette.dart';
import 'package:scrapyard_derby/game/weather.dart';

void main() {
  test('one theme per level; level 1 is the style test dusk', () {
    expect(LevelTheme.all, hasLength(Levels.count));
    final first = LevelTheme.of(1);
    expect(first.skyMid, Palette.skyMid);
    expect(first.dirt, Palette.dirt);
    expect(first.weather, Weather.none);
    expect(LevelTheme.of(99), LevelTheme.all.last);
  });

  test('later levels get darker skies', () {
    double brightness(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    final first = brightness(LevelTheme.of(1).skyMid);
    final last = brightness(LevelTheme.of(Levels.count).skyMid);
    expect(last, lessThan(first));
    // Every level after the first has weather, all different.
    final weathers = {for (final t in LevelTheme.all.skip(1)) t.weather};
    expect(weathers, hasLength(Levels.count - 1));
    expect(weathers, isNot(contains(Weather.none)));
  });

  test('every scene and weather paints at any time and scroll', () {
    for (final theme in LevelTheme.all) {
      final scene = DuskScene(theme);
      for (final time in [0.0, 1.7, 5.55, 123.4]) {
        final recorder = PictureRecorder();
        scene.paint(
          Canvas(recorder),
          const Size(900, 400),
          cameraX: time * 13,
          time: time,
        );
        recorder.endRecording().dispose();
      }
    }
    // Negative scroll (camera left of the start) wraps too.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final weather in Weather.values) {
      WeatherPainter().paint(
        canvas,
        const Size(900, 400),
        weather,
        scroll: -500,
        time: 3,
      );
    }
    recorder.endRecording().dispose();
  });
}
