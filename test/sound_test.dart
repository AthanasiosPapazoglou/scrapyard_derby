import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/sound.dart';

void main() {
  test('every sound effect has its generated file', () {
    for (final sfx in Sfx.values) {
      final file = File('assets/audio/${sfx.path}');
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
      // A real WAV, not an empty file.
      expect(file.readAsBytesSync().take(4), 'RIFF'.codeUnits);
    }
  });

  test('every sound is made by art/make_sfx.py', () {
    final script = File('art/make_sfx.py').readAsStringSync();
    for (final sfx in Sfx.values) {
      expect(script, contains('"${sfx.file}": '), reason: sfx.file);
    }
  });

  test('each landing type has its own sound', () {
    final sounds = LandingType.values.map(Sfx.forLanding).toSet();
    expect(sounds, hasLength(LandingType.values.length));
  });

  test('playing before setup does nothing (as in tests)', () {
    expect(() => Sound.play(Sfx.uiClick), returnsNormally);
  });
}
