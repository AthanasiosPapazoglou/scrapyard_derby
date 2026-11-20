import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/services.dart';

import '../config/tuning.dart';
import 'derby_game.dart';
import 'landing.dart';
import 'palette.dart';
import 'sound.dart';

/// Feedback ("juice"): sparks, dust, smoke, screen shake, phone vibration
/// and sound effects. None of it affects the physics.
///
/// Particles live in the world, in meters, so they move with the scene.
///
/// A [quiet] instance (Versus rivals) only shows particles, fewer of them
/// ([Tuning.rivalParticleShare]): no sound, vibration or screen shake.
class Effects extends Component with HasGameReference<DerbyGame> {
  Effects({this.quiet = false});

  final bool quiet;

  final math.Random _random = math.Random();

  /// Current screen shake strength in meters; fades out over time.
  double _shake = 0;

  // ---------------------------------------------------------------- Events

  /// A landing at [point] on ground facing [normal] (unit, pointing up).
  void landing(LandingType type, Vector2 point, Vector2 normal) {
    _sound(Sfx.forLanding(type));
    switch (type) {
      case LandingType.clean:
        _burst(
          point,
          normal,
          count: Tuning.sparkCount,
          speed: Tuning.sparkSpeed,
          spreadDeg: 70,
          lifetime: Tuning.sparkLifetime,
          radius: 0.07,
          colors: const [Palette.hazard, Palette.eyeGlow, Palette.rustLight],
          gravity: true,
        );
        _addShake(Tuning.shakeClean);
        _haptic(HapticFeedback.lightImpact);
      case LandingType.oneFoot:
        _dust(point, normal, Tuning.dustCount ~/ 2);
        _addShake(Tuning.shakeOneFoot);
        _haptic(HapticFeedback.mediumImpact);
      case LandingType.crash:
        _dust(point, normal, Tuning.dustCount);
        _burst(
          point,
          normal,
          count: Tuning.sparkCount ~/ 2,
          speed: Tuning.sparkSpeed * 0.7,
          spreadDeg: 80,
          lifetime: Tuning.sparkLifetime,
          radius: 0.06,
          colors: const [Palette.hazard, Palette.rust],
          gravity: true,
        );
        _addShake(Tuning.shakeCrash);
        _haptic(HapticFeedback.heavyImpact);
    }
  }

  /// A limb broke off at [point].
  void limbLost(Vector2 point) {
    _sound(Sfx.limbBreak);
    _burst(
      point,
      Vector2(0, -1),
      count: Tuning.limbBreakBits,
      speed: 5,
      spreadDeg: 120,
      lifetime: 0.6,
      radius: 0.09,
      colors: const [Palette.steel, Palette.rustShadow, Palette.outline],
      gravity: true,
    );
    _addShake(Tuning.shakeLimbLost);
    _haptic(HapticFeedback.heavyImpact);
  }

  /// The head was fired off from [point], flying along [direction].
  void headLaunch(Vector2 point, Vector2 direction) {
    _sound(Sfx.rocketLaunch);
    _burst(
      point,
      -direction,
      count: Tuning.sparkCount * 2,
      speed: Tuning.sparkSpeed,
      spreadDeg: 60,
      lifetime: 0.6,
      radius: 0.1,
      colors: const [Palette.hazard, Palette.rustLight, Palette.eyeGlow],
      gravity: false,
    );
    _dust(point, -direction, Tuning.dustCount);
    _addShake(Tuning.shakeHeadLaunch);
    _haptic(HapticFeedback.heavyImpact);
  }

  /// The spin energy tank just filled up, around [point] (the torso).
  void energyFull(Vector2 point) {
    _sound(Sfx.energyFull);
    _burst(
      point,
      Vector2(0, -1),
      count: 18,
      speed: 4,
      spreadDeg: 180,
      lifetime: 0.45,
      radius: 0.08,
      colors: const [Palette.eyeGlow, Palette.cream],
      gravity: false,
    );
    _haptic(HapticFeedback.selectionClick);
  }

  /// A clean landing with a full tank at [point]: the "super bounce".
  void superBounce(Vector2 point, Vector2 normal) {
    _sound(Sfx.superBounce);
    _burst(
      point,
      normal,
      count: Tuning.sparkCount * 3,
      speed: Tuning.sparkSpeed * 1.7,
      spreadDeg: 50,
      lifetime: 0.6,
      radius: 0.1,
      colors: const [Palette.eyeGlow, Palette.hazard, Palette.cream],
      gravity: true,
    );
    _dust(point, normal, Tuning.dustCount);
    _addShake(Tuning.shakeSuperBounce);
    _haptic(HapticFeedback.heavyImpact);
  }

  /// The launched head hit the ground at [point]: the attempt is over.
  void headLanded(Vector2 point) {
    _sound(Sfx.headDown);
    _dust(point, Vector2(0, -1), Tuning.dustCount * 2);
    _addShake(Tuning.shakeCrash);
    _haptic(HapticFeedback.heavyImpact);
  }

  /// One smoke puff behind the flying head.
  void smokePuff(Vector2 point) {
    final drift = Vector2(_spread(0.6), _spread(0.6) - 0.5);
    _spawn(
      point,
      AcceleratedParticle(
        speed: drift,
        lifespan: Tuning.smokeLifetime,
        child: _FadingCircle(
          lifespan: Tuning.smokeLifetime,
          color: Palette.smoke,
          startRadius: 0.25,
          endRadius: 0.9,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Shake

  /// Random camera offset for this frame, fading the shake out.
  Vector2 shakeOffset(double dt) {
    if (_shake <= 0.001) {
      _shake = 0;
      return Vector2.zero();
    }
    final offset = Vector2(_spread(_shake), _spread(_shake));
    _shake *= math.exp(-Tuning.shakeDecay * dt);
    return offset;
  }

  void _addShake(double amount) {
    if (!quiet) {
      _shake = math.max(_shake, amount);
    }
  }

  // ---------------------------------------------------------------- Helpers

  void _sound(Sfx sfx) {
    if (!quiet) {
      Sound.play(sfx);
    }
  }

  void _haptic(Future<void> Function() feedback) {
    if (!quiet && game.profile.hapticsOn) {
      unawaited(feedback());
    }
  }

  /// [count] particles, fewer for a quiet (rival) instance.
  int _scaled(int count) =>
      quiet ? math.max(1, (count * Tuning.rivalParticleShare).round()) : count;

  /// Random value between -[range] and +[range].
  double _spread(double range) => (_random.nextDouble() * 2 - 1) * range;

  /// A burst of small dots flying away from [point] around [direction].
  void _burst(
    Vector2 point,
    Vector2 direction, {
    required int count,
    required double speed,
    required double spreadDeg,
    required double lifetime,
    required double radius,
    required List<Color> colors,
    required bool gravity,
  }) {
    final baseAngle = math.atan2(direction.y, direction.x);
    final spread = spreadDeg * math.pi / 180;
    _spawn(
      point,
      Particle.generate(
        count: _scaled(count),
        lifespan: lifetime,
        generator: (i) {
          final angle = baseAngle + _spread(spread);
          final v = speed * (0.5 + _random.nextDouble() * 0.7);
          return AcceleratedParticle(
            speed: Vector2(math.cos(angle), math.sin(angle)) * v,
            acceleration: gravity ? Vector2(0, Tuning.gravity) : Vector2.zero(),
            child: _FadingCircle(
              lifespan: lifetime,
              color: colors[i % colors.length],
              startRadius: radius,
              endRadius: radius * 0.4,
            ),
          );
        },
      ),
    );
  }

  /// Soft puffs of dust rolling out along the ground at [point].
  void _dust(Vector2 point, Vector2 normal, int count) {
    final along = Vector2(-normal.y, normal.x);
    _spawn(
      point,
      Particle.generate(
        count: _scaled(count),
        lifespan: Tuning.dustLifetime,
        generator: (i) {
          final side = i.isEven ? 1.0 : -1.0;
          final v =
              along * (side * (1 + _random.nextDouble() * 3)) +
              normal * (0.5 + _random.nextDouble());
          return AcceleratedParticle(
            speed: v,
            child: _FadingCircle(
              lifespan: Tuning.dustLifetime,
              color: Palette.steelLight,
              startRadius: 0.2,
              endRadius: 0.6,
            ),
          );
        },
      ),
    );
  }

  void _spawn(Vector2 point, Particle particle) {
    game.world.add(
      ParticleSystemComponent(
        particle: particle,
        position: point.clone(),
        priority: 6, // in front of the robot (5) and hill (1)
      ),
    );
  }
}

/// A circle that grows or shrinks and fades out over the particle's life.
///
/// The lifespan is passed in explicitly: Flame doesn't hand a parent
/// particle's lifespan down to its child.
class _FadingCircle extends Particle {
  _FadingCircle({
    required double lifespan,
    required Color color,
    required this.startRadius,
    required this.endRadius,
  }) : _baseColor = color,
       super(lifespan: lifespan);

  final Color _baseColor;
  final double startRadius;
  final double endRadius;
  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    final t = progress;
    _paint.color = _baseColor.withValues(alpha: 1 - t);
    final radius = startRadius + (endRadius - startRadius) * t;
    canvas.drawCircle(Offset.zero, radius, _paint);
  }
}
