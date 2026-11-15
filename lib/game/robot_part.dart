import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config/tuning.dart';
import 'damage.dart';
import 'hill.dart';
import 'landing.dart';
import 'palette.dart';
import 'robot.dart';
import 'robot_sprites.dart';

/// One shape of a part plus the colour it is drawn with.
class PartShape {
  const PartShape(this.geometry, this.color);

  final ShapeGeometry geometry;
  final Color color;
}

/// One physics body of the robot (torso, head, an arm or a leg).
///
/// The body origin sits on the part's joint pivot, so rotating the part
/// swings it around the joint, like the cutout art will.
///
/// [Robot] builds the body (so it can connect the joints right away) and
/// hands it over with [attachBody]. Contacts with the hill are forwarded to
/// the robot, which decides what kind of landing happened.
class RobotPart extends BodyComponent with ContactCallbacks {
  RobotPart({
    required this.kind,
    required this.robot,
    required this.shapes,
    required this.density,
    int layer = 0,
  }) : super(priority: layer);

  final PartKind kind;
  final Robot robot;

  /// The part's artwork; when null, the plain placeholder shapes are drawn.
  PartSprite? sprite;

  /// Drawn over [sprite] (the core on the torso's chest).
  PartSprite? overlay;
  final List<PartShape> shapes;
  final double density;

  /// Arms and legs only: the joint holding this limb to the torso and its
  /// pivot in torso-local meters.
  RevoluteJoint? joint;
  Vector2? pivot;

  /// Which part of the status panel this is.
  RobotSlot? slot;

  /// True once the limb has broken off and is just debris.
  bool detached = false;

  /// Seconds since the limb broke off.
  double debrisAge = 0;

  bool get isLimb => kind == PartKind.arm || kind == PartKind.leg;

  /// Creates this part's body in [world] at [position], turned by [rotation].
  ///
  /// All robot parts share a negative collision group, so they never
  /// collide with each other, only with the ground.
  void attachBody(Forge2DWorld world, Vector2 position, Rot rotation) {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: position,
        rotation: rotation,
        userData: this,
        enableSleep: false,
      ),
    );
    for (final shape in shapes) {
      body.createShape(
        shape.geometry,
        ShapeDef(
          density: density,
          material: SurfaceMaterial(friction: Tuning.robotFriction),
          filter: Filter(groupIndex: -1),
          enableContactEvents: true,
        ),
      );
    }
    // Set right away (not in onLoad) so the robot can connect joints now.
    this.body = body;
  }

  @override
  Body createBody() => body;

  // ---------------------------------------------------------------- Contacts

  @override
  void beginContact(Object other, Contact contact) {
    if (other is HillChunk) {
      robot.onGroundContactBegin(this, contact);
    }
  }

  @override
  void endContact(Object other, Contact contact) {
    if (other is HillChunk) {
      robot.onGroundContactEnd(this);
    }
  }

  // ---------------------------------------------------------------- Drawing

  static const double _outlineWidth = 0.06;

  final Paint _fill = Paint();
  final Paint _outline = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = _outlineWidth
    ..strokeJoin = StrokeJoin.round;
  final Paint _eyePaint = Paint()..color = Palette.eyeGlow;

  @override
  void render(Canvas canvas) {
    // The canvas is already moved and rotated to this body's position.
    // Debris fades out over its lifetime.
    final opacity = detached
        ? (1 - debrisAge / Tuning.debrisLifetime).clamp(0.0, 1.0)
        : 1.0;
    if (kind == PartKind.head && robot.rocketBurnLeft > 0) {
      _renderRocketFlame(canvas);
    }
    final art = sprite;
    if (art != null) {
      _renderSprite(canvas, art, opacity);
      if (Tuning.debugShowPhysicsShapes) {
        _renderShapes(canvas, opacity: 1, outlineOnly: true);
      }
    } else {
      _renderShapes(canvas, opacity: opacity, outlineOnly: false);
    }
  }

  final Paint _fadePaint = Paint();

  void _renderSprite(Canvas canvas, PartSprite art, double opacity) {
    if (opacity >= 1) {
      art.render(canvas);
      overlay?.render(canvas);
      return;
    }
    // Fading debris: draw the sprite into a see-through layer.
    _fadePaint.color = Palette.outline.withValues(alpha: opacity);
    canvas.saveLayer(null, _fadePaint);
    art.render(canvas);
    overlay?.render(canvas);
    canvas.restore();
  }

  /// The plain placeholder shapes (the physics shapes, filled and outlined).
  void _renderShapes(
    Canvas canvas, {
    required double opacity,
    required bool outlineOnly,
  }) {
    _outline.color = outlineOnly
        ? Palette.eyeGlow
        : Palette.outline.withValues(alpha: opacity);
    for (final shape in shapes) {
      final path = _pathFor(shape.geometry);
      if (!outlineOnly) {
        _fill.color = shape.color.withValues(alpha: opacity);
        canvas.drawPath(path, _fill);
      }
      canvas.drawPath(path, _outline);
    }
    if (kind == PartKind.head && !outlineOnly) {
      // An eye on the right side, so you can see which way the head faces.
      const m = Tuning.artPixelsPerMeter;
      final eye = Offset(Tuning.headRadius * 0.45 / m, -Tuning.headOffset / m);
      canvas
        ..drawCircle(eye, 0.1, _eyePaint)
        ..drawCircle(eye, 0.1, _outline);
    }
  }

  final Paint _flameOuter = Paint()..color = Palette.hazard;
  final Paint _flameInner = Paint()..color = Palette.rustLight;

  /// A rocket flame trailing behind the launched head, shrinking as the
  /// burn runs out.
  void _renderRocketFlame(Canvas canvas) {
    _outline.color = Palette.outline;
    final velocity = body.linearVelocity;
    if (velocity.length2 < 1e-4) {
      return;
    }
    // "Backwards" in this body's own (rotated) coordinates.
    final back = body.rotation.inverseRotate(-velocity.normalized());
    final side = Vector2(-back.y, back.x);
    final radius = Tuning.headRadius / Tuning.artPixelsPerMeter;
    final center = Vector2(0, -Tuning.headOffset / Tuning.artPixelsPerMeter);
    final burnShare = robot.rocketBurnLeft / robot.stats.headRocketBurnTime;
    final length = radius * (1.5 + 2.5 * burnShare);

    Path flame(double widthScale, double lengthScale) {
      final base = center + back * (radius * 0.6);
      final tip = base + back * (length * lengthScale);
      final halfWidth = radius * 0.8 * widthScale;
      return Path()
        ..moveTo(base.x + side.x * halfWidth, base.y + side.y * halfWidth)
        ..lineTo(tip.x, tip.y)
        ..lineTo(base.x - side.x * halfWidth, base.y - side.y * halfWidth)
        ..close();
    }

    final outer = flame(1, 1);
    canvas
      ..drawPath(outer, _flameOuter)
      ..drawPath(outer, _outline)
      ..drawPath(flame(0.5, 0.6), _flameInner);
  }

  Path _pathFor(ShapeGeometry geometry) {
    switch (geometry) {
      case Circle(:final center, :final radius):
        return Path()
          ..addOval(Rect.fromCircle(center: center.toOffset(), radius: radius));
      case Capsule(:final center1, :final center2, :final radius):
        // Our capsules are always vertical, so a rounded rect is enough.
        final rect = Rect.fromPoints(
          Offset(center1.x - radius, center1.y - radius),
          Offset(center2.x + radius, center2.y + radius),
        );
        return Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
      case Polygon(:final points?):
        return Path()..addPolygon([for (final p in points) p.toOffset()], true);
      case Polygon() || Segment():
        return Path();
    }
  }
}
