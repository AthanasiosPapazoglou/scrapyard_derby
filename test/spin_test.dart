import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/spin.dart';

/// Runs the spin control for [seconds] in small steps.
double run(double control, {required bool holding, required double seconds}) {
  const dt = 1 / 1000; // small steps, so ramp timing is measured precisely
  for (var t = 0.0; t < seconds; t += dt) {
    control = nextSpinControl(control, holding: holding, dt: dt);
  }
  return control;
}

void main() {
  test('without holding, the robot stays at full clockwise spin', () {
    expect(run(1, holding: false, seconds: 2), 1);
  });

  test('holding slows the spin gradually, not instantly', () {
    final afterOneFrame = nextSpinControl(1, holding: true, dt: 1 / 60);
    expect(afterOneFrame, lessThan(1));
    // One 60 fps frame only goes a small part of the way, never a flip.
    expect(afterOneFrame, greaterThan(0.5));
  });

  test('holding for half the counter-spin time stops the spin', () {
    final c = run(1, holding: true, seconds: Tuning.counterSpinTime / 2);
    expect(c, closeTo(0, 0.05));
  });

  test('holding long enough reaches full counter-clockwise, and no more', () {
    final c = run(1, holding: true, seconds: Tuning.counterSpinTime * 3);
    expect(c, -1);
  });

  test('letting go returns to full clockwise', () {
    final c = run(-1, holding: false, seconds: Tuning.releaseSpinTime * 1.1);
    expect(c, 1);
  });
}
