import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/tuning.dart';
import 'landing.dart';
import 'palette.dart';
import 'robot.dart';

/// A soft glow behind the robot that grows with its spin energy: amber
/// while charging, pulsing cyan when the tank is full. [flash] makes it
/// flare for a moment (when the tank fills up). Purely visual.
///
/// A child of [Robot] with a negative priority, so it draws behind the
/// robot's parts, in world coordinates (meters).
class EnergyAura extends Component with ParentIsA<Robot> {
  EnergyAura() : super(priority: -1);

  double _time = 0;
  double _flash = 0;
  final Paint _paint = Paint();

  /// Flares the glow (fades over about a third of a second).
  void flash() => _flash = 1;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _flash = math.max(0, _flash - dt * 3);
  }

  @override
  void render(Canvas canvas) {
    final robot = parent;
    if (robot.headLaunched) {
      return;
    }
    final max = robot.stats.spinEnergyMaxTurns;
    final fill = (robot.spinEnergy / max).clamp(0.0, 1.0);
    if (fill < 0.02 && _flash <= 0) {
      return;
    }
    final full = isFullCharge(robot.spinEnergy, stats: robot.stats);
    final pulse = full ? 0.5 + 0.5 * math.sin(_time * 10) : 0.0;
    final radius =
        robot.drawScale *
            Tuning.energyAuraRadius *
            (0.55 + 0.45 * fill) *
            (1 + 0.08 * pulse) +
        _flash * 0.8;
    final strength =
        (Tuning.energyAuraStrength * (0.3 + 0.7 * fill) * (1 + 0.25 * pulse) +
                _flash * 0.4)
            .clamp(0.0, 1.0);
    final color = Color.lerp(Palette.hazard, Palette.eyeGlow, full ? 1 : 0)!;
    final c = robot.torso.body.worldCenterOfMass;
    final center = Offset(c.x, c.y);
    _paint.shader = Gradient.radial(
      center,
      radius,
      [
        color.withValues(alpha: strength),
        color.withValues(alpha: strength * 0.4),
        color.withValues(alpha: 0),
      ],
      [0, 0.55, 1],
    );
    canvas.drawCircle(center, radius, _paint);
  }
}
