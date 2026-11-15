import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config/tuning.dart';
import 'derby_game.dart';
import 'head_launch.dart';
import 'hill.dart';
import 'landing.dart';
import 'palette.dart';
import 'robot_part.dart';
import 'spin.dart';

/// Converts art pixels (the unit of CLAUDE.md's joint positions) to meters.
double _m(double artPixels) => artPixels / Tuning.artPixelsPerMeter;

double _rad(double degrees) => degrees * math.pi / 180;

/// The player's robot: 6 bodies held together by 5 revolute joints.
///
/// The robot spins clockwise on its own once it has touched the ground.
/// While the player holds a finger down ([holding]), a counter-spin force
/// slows the spin and gradually reverses it (see spin.dart). When it touches the ground after being in
/// the air, the first part that touched and the robot's angle decide the
/// landing type; the robot's velocity changes to match and its limbs take
/// damage (see landing.dart). Limbs at 0 HP break off and become debris.
class Robot extends Component with HasGameReference<DerbyGame> {
  Robot({required HillGeometry hill}) {
    // Drop the robot from high above the slope, tilted to match it and not
    // spinning yet, so the first touch-down is a clean landing.
    final x = Tuning.startX;
    final angle = hill.slopeAngleAt(x);
    startRotation = Rot.fromAngle(angle);
    final groundNormal = Vector2(math.sin(angle), -math.cos(angle));
    final feetBelowTorso =
        leftHipPivot.y +
        _m(Tuning.legLength + Tuning.legRadius + Tuning.footHalfHeight);
    start =
        Vector2(x, hill.heightAt(x)) +
        groundNormal * (feetBelowTorso + Tuning.startDropHeight);
  }

  /// World position of the torso center at the start of the run.
  late final Vector2 start;

  /// Rotation of the whole robot at the start of the run.
  late final Rot startRotation;

  // Joint pivots in torso-local coordinates (meters), from CLAUDE.md.
  static final Vector2 neckPivot = Vector2(_m(0), _m(-72));
  static final Vector2 leftShoulderPivot = Vector2(_m(-56), _m(-42));
  static final Vector2 rightShoulderPivot = Vector2(_m(58), _m(-42));
  static final Vector2 leftHipPivot = Vector2(_m(-24), _m(66));
  static final Vector2 rightHipPivot = Vector2(_m(24), _m(66));

  late final RobotPart torso;
  late final RobotPart head;
  late final RevoluteJoint _neckJoint;
  final List<RobotPart> parts = [];

  /// The four arms and legs (the parts that can break off).
  Iterable<RobotPart> get limbs => parts.where((p) => p.isLimb);

  /// Parts still connected to the robot (not debris).
  Iterable<RobotPart> get attachedParts => parts.where((p) => !p.detached);

  /// How many arms and legs are still attached.
  int get limbsLeft => limbs.where((p) => !p.detached).length;

  /// True once the head has been fired off like a rocket; from then on the
  /// run continues with the head alone until it touches the ground.
  bool headLaunched = false;

  /// True once the launched head has touched the ground: the run is over.
  bool headLanded = false;

  /// Seconds since the head was launched.
  double _headFlightTime = 0;

  /// Seconds of rocket burn left after launch (pushes the head along).
  double rocketBurnLeft = 0;

  /// Direction the rocket burn pushes in (the launch direction).
  Vector2 _rocketDirection = Vector2(0, -1);

  /// Seconds spent on the ground with no limbs left, before the head
  /// launches anyway (see [Tuning.headLaunchGroundDelay]).
  double _noLimbsGroundTime = 0;

  /// True while the player is holding a finger on the screen.
  bool holding = false;

  /// From 1 (full clockwise, the default) to -1 (full counter-clockwise).
  /// See spin.dart.
  double spinControl = 1;

  /// The most recent landing, or null if none yet this run.
  LandingType? lastLanding;

  /// The spin only starts once the robot has touched the ground, so the
  /// opening drop is calm and the first landing is clean.
  bool _hasTouchedDown = false;

  double _airTime = 0;

  /// Spin energy gathered during the current airtime, in turns (0 to
  /// Tuning.spinEnergyMaxTurns). All of it is released into the next
  /// bounce on landing, then it starts again from 0. See landing.dart.
  double spinEnergy = 0;

  /// Number of ground contacts per attached part. Counted per part so
  /// that debris touching the ground doesn't count as the robot touching it.
  final Map<RobotPart, int> _groundContacts = {};

  bool get _isOnGround => _groundContacts.values.any((count) => count > 0);

  /// The body the game follows: the torso, or the head once launched.
  Body get _trackedBody => headLaunched ? head.body : torso.body;

  /// Speed of the robot (or launched head) in m/s.
  double get speed => _trackedBody.linearVelocity.length;

  /// Velocity of the robot (or launched head).
  Vector2 get velocity => _trackedBody.linearVelocity;

  /// Position of the robot (or launched head) in the world.
  Vector2 get position => _trackedBody.position;

  /// Horizontal meters travelled since the start.
  double get distance => math.max(0, position.x - start.x);

  @override
  Future<void> onLoad() async {
    final world = game.world;

    torso = _makePart(PartKind.torso, null, Tuning.torsoDensity, [
      PartShape(
        Polygon(_box(Tuning.torsoHalfWidth, Tuning.torsoHalfHeight, 0)),
        Palette.rust,
      ),
    ]);
    head = _makePart(PartKind.head, neckPivot, Tuning.headDensity, [
      PartShape(
        Circle(
          radius: _m(Tuning.headRadius),
          center: Vector2(0, -_m(Tuning.headOffset)),
        ),
        Palette.steelLight,
      ),
    ]);
    _makeArm(leftShoulderPivot);
    _makeArm(rightShoulderPivot);
    _makeLeg(leftHipPivot);
    _makeLeg(rightHipPivot);

    for (final part in parts) {
      final offset = part.pivot ?? Vector2.zero();
      part.attachBody(
        world,
        start + startRotation.rotate(offset),
        startRotation,
      );
    }

    // Arms and legs break off from damage; the neck only "breaks" when the
    // head is launched.
    _neckJoint = _joint(head, neckPivot, Tuning.neckLimitDeg);
    for (final limb in limbs) {
      final limit = limb.kind == PartKind.arm
          ? Tuning.shoulderLimitDeg
          : Tuning.hipLimitDeg;
      limb.joint = _joint(limb, limb.pivot!, limit);
    }

    await addAll(parts);
  }

  RobotPart _makePart(
    PartKind kind,
    Vector2? pivot,
    double density,
    List<PartShape> shapes,
  ) {
    final part = RobotPart(
      kind: kind,
      robot: this,
      shapes: shapes,
      density: density,
    )..pivot = pivot;
    parts.add(part);
    return part;
  }

  void _makeArm(Vector2 pivot) {
    _makePart(PartKind.arm, pivot, Tuning.limbDensity, [
      PartShape(
        Capsule(
          center1: Vector2.zero(),
          center2: Vector2(0, _m(Tuning.armLength)),
          radius: _m(Tuning.armRadius),
        ),
        Palette.steel,
      ),
    ]);
  }

  void _makeLeg(Vector2 pivot) {
    _makePart(PartKind.leg, pivot, Tuning.limbDensity, [
      PartShape(
        Capsule(
          center1: Vector2.zero(),
          center2: Vector2(0, _m(Tuning.legLength)),
          radius: _m(Tuning.legRadius),
        ),
        Palette.steelDark,
      ),
      PartShape(
        Polygon(
          _box(
            Tuning.footHalfWidth,
            Tuning.footHalfHeight,
            Tuning.legLength + Tuning.legRadius,
          ),
        ),
        Palette.hazard,
      ),
    ]);
  }

  /// Corner points of a box (art pixels in, meters out), centered at
  /// (0, [centerY]).
  List<Vector2> _box(double halfWidth, double halfHeight, double centerY) {
    final w = _m(halfWidth);
    final top = _m(centerY - halfHeight);
    final bottom = _m(centerY + halfHeight);
    return [
      Vector2(-w, top),
      Vector2(w, top),
      Vector2(w, bottom),
      Vector2(-w, bottom),
    ];
  }

  /// Connects [part] to the torso at [pivot] with an angle limit and a
  /// spring that pulls it back to its rest pose.
  RevoluteJoint _joint(RobotPart part, Vector2 pivot, double limitDeg) {
    return game.world.physicsWorld.createRevoluteJoint(
      RevoluteJointDef(
        bodyA: torso.body,
        bodyB: part.body,
        localAnchorA: pivot,
        localAnchorB: Vector2.zero(),
        enableLimit: true,
        lowerAngle: -_rad(limitDeg),
        upperAngle: _rad(limitDeg),
        enableSpring: true,
        hertz: Tuning.jointSpringHertz,
        dampingRatio: Tuning.jointSpringDamping,
      ),
    );
  }

  // ---------------------------------------------------------------- Control

  @override
  void update(double dt) {
    super.update(dt);
    _updateDebris(dt);
    if (headLaunched) {
      _updateHead(dt);
      return;
    }
    if (_hasTouchedDown) {
      _updateSpin(dt);
    }
    _capSpeed();
    if (!_isOnGround) {
      _airTime += dt;
      if (_hasTouchedDown) {
        final turns = torso.body.angularVelocity.abs() * dt / (2 * math.pi);
        spinEnergy = addSpinEnergy(spinEnergy, turns);
      }
    }
    // Down to torso + head but just sliding along? Launch the head anyway.
    if (limbsLeft == 0 && _isOnGround) {
      _noLimbsGroundTime += dt;
      if (_noLimbsGroundTime >= Tuning.headLaunchGroundDelay) {
        _launchHead(_groundNormalBelow());
      }
    } else {
      _noLimbsGroundTime = 0;
    }
  }

  /// The head phase: the head flies free. For a short moment after launch
  /// the rocket burn keeps pushing it along its launch direction.
  void _updateHead(double dt) {
    _headFlightTime += dt;
    if (rocketBurnLeft > 0 && !headLanded) {
      final burn = math.min(dt, rocketBurnLeft);
      rocketBurnLeft -= burn;
      head.body.linearVelocity =
          head.body.linearVelocity +
          _rocketDirection * (Tuning.headRocketThrust * burn);
    }
  }

  /// Moves the spin control (hold = counter-spin) and turns the torso
  /// toward the matching spin speed. The limbs follow through their joints.
  void _updateSpin(double dt) {
    spinControl = nextSpinControl(spinControl, holding: holding, dt: dt);
    final target = spinControl * Tuning.spinSpeed;

    final body = torso.body;
    final current = body.angularVelocity;
    final maxChange = Tuning.spinAcceleration * dt;
    final change = (target - current).clamp(-maxChange, maxChange);
    body.angularVelocity = current + change;
  }

  /// Scales the robot's velocity down if it is over the speed cap.
  void _capSpeed() {
    final current = speed;
    if (current <= Tuning.maxRobotSpeed) {
      return;
    }
    final factor = Tuning.maxRobotSpeed / current;
    for (final part in attachedParts) {
      part.body.linearVelocity = part.body.linearVelocity * factor;
    }
  }

  /// Removes broken-off parts after they've lain around for a while.
  void _updateDebris(double dt) {
    for (final part in parts.where((p) => p.detached && p.isMounted)) {
      part.debrisAge += dt;
      if (part.debrisAge >= Tuning.debrisLifetime) {
        part.removeFromParent();
      }
    }
  }

  // ---------------------------------------------------------------- Landings

  /// Called by a part when it starts touching the hill.
  void onGroundContactBegin(RobotPart part, Contact contact) {
    if (part.detached) {
      return; // Debris doesn't count.
    }
    // Head phase: the head's first touch of the ground ends the run (after
    // a short grace, since it launches from right next to the ground).
    if (headLaunched) {
      if (part == head && _headFlightTime >= Tuning.headLandingGrace) {
        _landHead();
      }
      return;
    }
    final wasInAir = !_isOnGround;
    _groundContacts[part] = (_groundContacts[part] ?? 0) + 1;
    _hasTouchedDown = true;
    if (!wasInAir || _airTime < Tuning.minAirTime) {
      return;
    }
    _airTime = 0;

    final normal = _groundNormal(part, contact);
    if (normal == null) {
      return;
    }
    // Only torso and head left: this landing fires the head.
    if (limbsLeft == 0) {
      _launchHead(normal);
      return;
    }
    final up = torso.body.rotation.rotate(Vector2(0, -1));
    final type = classifyLanding(part.kind, signedAngleBetween(up, normal));
    lastLanding = type;

    // Change the velocity of the whole robot by the same amount, so the
    // parts keep moving together.
    final oldVelocity = torso.body.linearVelocity;
    final newVelocity = velocityAfterLanding(
      type,
      oldVelocity,
      normal,
      extraBounce: spinEnergyBounce(spinEnergy),
    );
    // All gathered energy went into this bounce; the next airtime starts
    // gathering from zero.
    spinEnergy = 0;
    final delta = newVelocity - oldVelocity;
    for (final p in attachedParts) {
      p.body.linearVelocity = p.body.linearVelocity + delta;
    }

    _applyLandingDamage(type, part, contact);
  }

  /// Called by a part when it stops touching the hill.
  void onGroundContactEnd(RobotPart part) {
    final count = _groundContacts[part];
    if (count != null) {
      _groundContacts[part] = math.max(0, count - 1);
    }
  }

  void _applyLandingDamage(LandingType type, RobotPart part, Contact contact) {
    final damage = landingDamage(type);
    switch (type) {
      case LandingType.clean:
        for (final leg in limbs.where(
          (p) => p.kind == PartKind.leg && !p.detached,
        )) {
          _damage(leg, damage);
        }
      case LandingType.oneFoot:
        _damage(part, damage);
      case LandingType.crash:
        final points = contact.points;
        final impact = (points != null && points.isNotEmpty)
            ? points.first.point
            : part.body.position;
        final nearest = _nearestAttachedLimb(impact);
        if (nearest != null) {
          _damage(nearest, damage);
        }
    }
  }

  void _damage(RobotPart limb, double amount) {
    if (!limb.isLimb || limb.detached) {
      return;
    }
    limb.hp = math.max(0, limb.hp - amount);
    if (limb.hp == 0) {
      _breakOff(limb);
    }
  }

  /// The attached arm or leg whose joint is closest to [worldPoint].
  RobotPart? _nearestAttachedLimb(Vector2 worldPoint) {
    RobotPart? nearest;
    var bestDistance = double.infinity;
    final torsoTransform = torso.body.transform;
    for (final limb in limbs.where((p) => !p.detached)) {
      final jointWorld = torsoTransform.apply(limb.pivot!);
      final d = jointWorld.distanceTo(worldPoint);
      if (d < bestDistance) {
        bestDistance = d;
        nearest = limb;
      }
    }
    return nearest;
  }

  /// Destroys the limb's joint and flings it away from the torso, so it
  /// clearly tumbles off as debris.
  void _breakOff(RobotPart limb) {
    limb.joint?.destroy();
    limb.joint = null;
    _makeDebris(limb);
  }

  /// Marks [part] as debris and pushes it away from the torso.
  void _makeDebris(RobotPart part) {
    part.detached = true;
    _groundContacts.remove(part);
    var away = part.body.worldCenterOfMass - torso.body.worldCenterOfMass;
    if (away.length2 < 1e-6) {
      away = Vector2(0, -1);
    }
    away.normalize();
    part.body.linearVelocity =
        part.body.linearVelocity + away * Tuning.debrisKick;
    part.body.angularVelocity = part.body.angularVelocity + 6 * away.x.sign;
  }

  /// Fires the head off like a rocket. The torso is left behind as debris
  /// and the run continues with the head until it touches the ground
  /// (see head_launch.dart).
  void _launchHead(Vector2 groundNormal) {
    if (headLaunched) {
      return;
    }
    final facing = torso.body.rotation.rotate(Vector2(0, -1));
    final launch = headLaunchVelocity(
      facing: facing,
      groundNormal: groundNormal,
      speed: torso.body.linearVelocity.length,
    );
    _neckJoint.destroy();
    headLaunched = true;
    spinEnergy = 0;
    _airTime = 0;
    torso.detached = true;
    _groundContacts.remove(torso);
    head.body.linearVelocity = launch;
    head.body.angularVelocity = 8;
    _rocketDirection = launch.normalized();
    rocketBurnLeft = Tuning.headRocketBurnTime;
    _headFlightTime = 0;
    // Leave the torso where it is; it slows and fades like other debris.
  }

  /// The launched head has touched the ground: the attempt is finished.
  /// It stops right there, so the distance is measured at this point.
  void _landHead() {
    if (headLanded) {
      return;
    }
    headLanded = true;
    rocketBurnLeft = 0;
    head.body
      ..linearVelocity = Vector2.zero()
      ..angularVelocity = 0
      ..type = BodyType.static;
  }

  /// Ground normal right below the torso, from the hill's shape (for when
  /// there is no contact to read it from).
  Vector2 _groundNormalBelow() {
    final angle = game.hillGeometry.slopeAngleAt(torso.body.position.x);
    return Vector2(math.sin(angle), -math.cos(angle));
  }

  /// The ground normal from a contact, pointing up away from the ground.
  ///
  /// Box2D's normal points from shape A to shape B, and either one could be
  /// the robot part, so it is flipped when needed.
  Vector2? _groundNormal(RobotPart part, Contact contact) {
    final raw = contact.normal;
    if (raw == null) {
      return null;
    }
    final normal = contact.bodyA == part.body ? -raw : raw.clone();
    // The ground never faces downward; if it seems to, the sign is off.
    if (normal.y > 0) {
      normal.negate();
    }
    return normal..normalize();
  }
}
