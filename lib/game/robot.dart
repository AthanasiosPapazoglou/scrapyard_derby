import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config/tuning.dart';
import 'damage.dart';
import 'derby_game.dart';
import 'head_launch.dart';
import 'hill.dart';
import 'landing.dart';
import 'palette.dart';
import 'robot_part.dart';
import 'robot_sprites.dart';
import 'robot_stats.dart';
import 'run_stats.dart';
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
  Robot({
    required HillGeometry hill,
    this.sprites,
    this.stats = RobotStats.base,
  }) {
    // Drop the robot from high above the slope, tilted to match it and not
    // spinning yet, so the first touch-down is a clean landing.
    final x = Tuning.startX;
    final angle = hill.slopeAngleAt(x);
    startRotation = Rot.fromAngle(angle);
    final groundNormal = Vector2(math.sin(angle), -math.cos(angle));
    final feetBelowTorso =
        leftHipPivot.y + _m(Tuning.footCenterY + Tuning.footHalfHeight);
    _feetBelowTorso = feetBelowTorso;
    start =
        Vector2(x, hill.heightAt(x)) +
        groundNormal * (feetBelowTorso + Tuning.startDropHeight);
  }

  /// Artwork for the parts; null draws the plain placeholder shapes.
  final RobotSprites? sprites;

  /// Effective numbers after Workshop upgrades.
  final RobotStats stats;

  /// World position of the torso center at the start of the run.
  late final Vector2 start;

  /// Rotation of the whole robot at the start of the run.
  late final Rot startRotation;

  /// Distance from the torso center down to the soles (m), standing up.
  late final double _feetBelowTorso;

  /// Landings, highest jump, limbs lost and head flight for this run.
  final RunStats runStats = RunStats();

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

  /// Shared damage that decides which part breaks next (see damage.dart).
  late final RobotDamage damage = RobotDamage(limbMaxHp: stats.limbMaxHp);

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

  /// Seconds since the last smoke puff behind the flying head.
  double _smokeTimer = 0;

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
  /// stats.spinEnergyMaxTurns). All of it is released into the next
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

    // Draw layers follow the art: back arm and legs behind the torso, then
    // the head, then the front arm on top.
    torso = _makePart(PartKind.torso, null, Tuning.torsoDensity, 2, [
      PartShape(
        Polygon(_box(Tuning.torsoHalfWidth, Tuning.torsoHalfHeight, 0)),
        Palette.rust,
      ),
    ]);
    head = _makePart(PartKind.head, neckPivot, Tuning.headDensity, 3, [
      PartShape(
        Circle(
          radius: _m(Tuning.headRadius),
          center: Vector2(0, -_m(Tuning.headOffset)),
        ),
        Palette.steelLight,
      ),
    ]);
    _makeArm(leftShoulderPivot, RobotSlot.leftArm, layer: 0); // back arm
    _makeArm(rightShoulderPivot, RobotSlot.rightArm, layer: 4); // front
    _makeLeg(leftHipPivot, RobotSlot.leftLeg);
    _makeLeg(rightHipPivot, RobotSlot.rightLeg);
    torso.slot = RobotSlot.body;
    head.slot = RobotSlot.head;

    final art = sprites;
    if (art != null) {
      for (final part in parts) {
        part.sprite = switch (part.kind) {
          PartKind.torso => art.torso,
          PartKind.head => art.head,
          PartKind.arm => art.arm,
          PartKind.leg => art.leg,
        };
      }
    }

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
    int layer,
    List<PartShape> shapes, {
    RobotSlot? slot,
  }) {
    final part =
        RobotPart(
            kind: kind,
            robot: this,
            shapes: shapes,
            density: density,
            layer: layer,
          )
          ..pivot = pivot
          ..slot = slot;
    parts.add(part);
    return part;
  }

  void _makeArm(Vector2 pivot, RobotSlot slot, {required int layer}) {
    _makePart(PartKind.arm, pivot, Tuning.limbDensity, layer, slot: slot, [
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

  void _makeLeg(Vector2 pivot, RobotSlot slot) {
    _makePart(PartKind.leg, pivot, Tuning.limbDensity, 1, slot: slot, [
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
            Tuning.footCenterY,
            centerX: Tuning.footCenterX,
          ),
        ),
        Palette.hazard,
      ),
    ]);
  }

  /// Corner points of a box (art pixels in, meters out), centered at
  /// ([centerX], [centerY]).
  List<Vector2> _box(
    double halfWidth,
    double halfHeight,
    double centerY, {
    double centerX = 0,
  }) {
    final left = _m(centerX - halfWidth);
    final right = _m(centerX + halfWidth);
    final top = _m(centerY - halfHeight);
    final bottom = _m(centerY + halfHeight);
    return [
      Vector2(left, top),
      Vector2(right, top),
      Vector2(right, bottom),
      Vector2(left, bottom),
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
        _reportJumpHeight();
        final turns = torso.body.angularVelocity.abs() * dt / (2 * math.pi);
        spinEnergy = addSpinEnergy(spinEnergy, turns, stats: stats);
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

  /// Tells [runStats] how high the feet are above the ground right now.
  void _reportJumpHeight() {
    final torsoPosition = torso.body.position;
    final groundY = game.hillGeometry.heightAt(torsoPosition.x);
    // y points down: ground y - torso y is the torso's height.
    runStats.reportHeight(groundY - torsoPosition.y - _feetBelowTorso);
  }

  /// The head phase: the head flies free. For a short moment after launch
  /// the rocket burn keeps pushing it along its launch direction.
  void _updateHead(double dt) {
    _headFlightTime += dt;
    if (!headLanded) {
      _smokeTimer += dt;
      final interval = rocketBurnLeft > 0
          ? Tuning.smokeIntervalBurn
          : Tuning.smokeIntervalCoast;
      if (_smokeTimer >= interval) {
        _smokeTimer = 0;
        game.effects.smokePuff(head.body.worldCenterOfMass);
      }
    }
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
    spinControl = nextSpinControl(
      spinControl,
      holding: holding,
      dt: dt,
      stats: stats,
    );
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
    final type = classifyLanding(
      part.kind,
      signedAngleBetween(up, normal),
      stats: stats,
    );
    lastLanding = type;
    runStats.addLanding(type);
    final points = contact.points;
    final contactPoint = (points != null && points.isNotEmpty)
        ? points.first.point
        : part.body.worldCenterOfMass;
    game.effects.landing(type, contactPoint, normal);

    // Change the velocity of the whole robot by the same amount, so the
    // parts keep moving together.
    final oldVelocity = torso.body.linearVelocity;
    final newVelocity = velocityAfterLanding(
      type,
      oldVelocity,
      normal,
      extraBounce: spinEnergyBounce(spinEnergy, stats: stats),
      stats: stats,
    );
    // All gathered energy went into this bounce; the next airtime starts
    // gathering from zero.
    spinEnergy = 0;
    final delta = newVelocity - oldVelocity;
    for (final p in attachedParts) {
      p.body.linearVelocity = p.body.linearVelocity + delta;
    }

    _applyLandingDamage(type);
  }

  /// Called by a part when it stops touching the hill.
  void onGroundContactEnd(RobotPart part) {
    final count = _groundContacts[part];
    if (count != null) {
      _groundContacts[part] = math.max(0, count - 1);
    }
  }

  /// Adds this landing's damage to the shared total and breaks off the
  /// limbs whose turn it is (arms first, then legs; see damage.dart).
  void _applyLandingDamage(LandingType type) {
    for (final slot in damage.add(landingDamage(type))) {
      _breakOff(_partFor(slot));
    }
  }

  /// The part shown as [slot] in the status panel.
  RobotPart _partFor(RobotSlot slot) =>
      parts.firstWhere((part) => part.slot == slot);

  /// Each part's remaining HP (0 to 1) for the status panel. The body is
  /// gone once the head is launched, the head once it has landed.
  Map<RobotSlot, double> get partHp => {
    for (final slot in RobotSlot.values)
      slot: switch (slot) {
        RobotSlot.body when headLaunched => 0.0,
        RobotSlot.head when headLanded => 0.0,
        _ => damage.hpOf(slot),
      },
  };

  /// Destroys the limb's joint and flings it away from the torso, so it
  /// clearly tumbles off as debris.
  void _breakOff(RobotPart limb) {
    limb.joint?.destroy();
    limb.joint = null;
    runStats.addLimbLost();
    game.effects.limbLost(limb.body.worldCenterOfMass);
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
      stats: stats,
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
    rocketBurnLeft = stats.headRocketBurnTime;
    _headFlightTime = 0;
    runStats.headLaunchedAt(head.body.position.x);
    game.effects.headLaunch(head.body.worldCenterOfMass, _rocketDirection);
    game.startHeadLaunchSlowMo();
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
    runStats.headLandedAt(head.body.position.x);
    game.effects.headLanded(head.body.worldCenterOfMass);
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
