import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import 'camera_framing.dart';
import 'hill.dart';
import 'landing.dart';
import 'palette.dart';
import 'robot.dart';

/// Why a run ended.
enum RunEnd {
  headDown('HEAD DOWN'),
  stuck('STUCK');

  const RunEnd(this.label);

  final String label;
}

/// A snapshot of the numbers the Flutter overlays show.
@immutable
class HudInfo {
  const HudInfo({
    this.speed = 0,
    this.spin = 1,
    this.spinEnergy = 0,
    this.lastLanding,
    this.distance = 0,
    this.bestDistance = 0,
    this.limbsLeft = 4,
    this.headLaunched = false,
    this.runEnd,
  });

  /// Robot speed in m/s.
  final double speed;

  /// Spin control: 1 = full clockwise, -1 = full counter-clockwise.
  final double spin;

  /// Stored spin energy in turns (0 to Tuning.spinEnergyMaxTurns).
  final double spinEnergy;
  final LandingType? lastLanding;

  /// Horizontal meters covered this run, and the best this session.
  final double distance;
  final double bestDistance;

  /// Arms and legs still attached (0-4).
  final int limbsLeft;

  /// True once the head has been fired off like a rocket.
  final bool headLaunched;

  /// Set once the run is over.
  final RunEnd? runEnd;
}

/// The game: an endless hill, one robot, a following camera, hold to
/// counter-spin. The run lasts until the robot breaks down or gets stuck.
class DerbyGame extends Forge2DGame with TapCallbacks {
  DerbyGame() : super(gravity: Vector2(0, Tuning.gravity));

  final HillGeometry hillGeometry = HillGeometry();
  late Robot robot;

  /// Updated a few times per second for the Flutter overlays.
  final ValueNotifier<HudInfo> hud = ValueNotifier(const HudInfo());

  RunEnd? _runEnd;
  double _finalDistance = 0;
  double _bestDistance = 0;
  double _stallTime = 0;
  double _hudTimer = 0;
  double _visibleWidth = Tuning.cameraBaseWidth;

  @override
  Color backgroundColor() => Palette.sky;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.subStepCount = Tuning.physicsSubSteps;
    _spawnRobot();
    await world.add(Hill(hillGeometry, focusX: _focusX));
  }

  /// Where the hill should be built: around the robot.
  double _focusX() => robot.isLoaded ? robot.position.x : robot.start.x;

  void _spawnRobot() {
    robot = Robot(hill: hillGeometry);
    world.add(robot);
    camera.viewfinder.position = robot.start.clone();
  }

  /// Fingers currently touching the screen. Holding any finger down applies
  /// counter-spin; it stops when the last finger lifts.
  final Set<int> _heldPointers = {};

  @override
  void onTapDown(TapDownEvent event) => _heldPointers.add(event.pointerId);

  @override
  void onTapUp(TapUpEvent event) => _heldPointers.remove(event.pointerId);

  @override
  void onTapCancel(TapCancelEvent event) =>
      _heldPointers.remove(event.pointerId);

  /// Starts a new run with a fresh robot at the top of the hill.
  void restart() {
    robot.removeFromParent();
    _spawnRobot();
    _runEnd = null;
    _stallTime = 0;
    _visibleWidth = Tuning.cameraBaseWidth;
    hud.value = HudInfo(bestDistance: _bestDistance);
  }

  /// Runs the world (physics, robot spin and hold response, hill) at
  /// [Tuning.gameSpeed] speed. This game's own [update] below (camera, HUD,
  /// stuck timer) still gets real time, so the camera stays smooth.
  @override
  void updateTree(double dt) => super.updateTree(dt * Tuning.gameSpeed);

  @override
  void update(double dt) {
    super.update(dt);
    if (!robot.isLoaded) {
      return;
    }
    robot.holding = _runEnd == null && _heldPointers.isNotEmpty;
    if (_runEnd == null) {
      _checkRunEnd(dt);
    }
    _updateCamera(dt);

    _hudTimer += dt;
    if (_hudTimer >= 0.1) {
      _hudTimer = 0;
      _publishHud();
    }
  }

  void _checkRunEnd(double dt) {
    _stallTime = robot.speed < Tuning.stallSpeed ? _stallTime + dt : 0;
    final RunEnd? end;
    if (robot.headLanded) {
      end = RunEnd.headDown;
    } else if (_stallTime >= Tuning.stallTime) {
      end = RunEnd.stuck;
    } else {
      end = null;
    }
    if (end != null) {
      _runEnd = end;
      _finalDistance = robot.distance;
      _bestDistance = math.max(_bestDistance, _finalDistance);
      _publishHud();
    }
  }

  /// Smoothly moves and zooms the camera so both the robot (or launched
  /// head) and the ground below it stay on screen (see camera_framing.dart).
  void _updateCamera(double dt) {
    if (size.x <= 0) {
      return;
    }
    final framing = frameRobotAndGround(
      robotPosition: robot.position,
      velocity: robot.velocity,
      groundY: hillGeometry.heightAt(robot.position.x),
      screenAspect: size.y / size.x,
      // The launched head is centered on screen, like the body before it.
      groundBias: robot.headLaunched ? 0 : Tuning.cameraGroundBias,
    );

    // "1 - e^(-k·dt)" gives the same smoothing at any frame rate.
    final viewfinder = camera.viewfinder;
    final sharpness = robot.headLaunched
        ? Tuning.cameraHeadFollowSharpness
        : Tuning.cameraFollowSharpness;
    final follow = 1 - math.exp(-sharpness * dt);
    viewfinder.position += (framing.center - viewfinder.position) * follow;

    final zoomFollow = 1 - math.exp(-Tuning.cameraZoomSharpness * dt);
    _visibleWidth += (framing.visibleWidth - _visibleWidth) * zoomFollow;

    // Forge2D's zoom of 1 means metersToPixels screen pixels per meter.
    viewfinder.zoom = size.x / _visibleWidth / metersToPixels;
  }

  void _publishHud() {
    hud.value = HudInfo(
      speed: robot.speed,
      spin: robot.spinControl,
      spinEnergy: robot.spinEnergy,
      lastLanding: robot.lastLanding,
      // Frozen once the run is over, even if the wreck keeps sliding.
      distance: _runEnd == null ? robot.distance : _finalDistance,
      bestDistance: _bestDistance,
      limbsLeft: robot.limbsLeft,
      headLaunched: robot.headLaunched,
      runEnd: _runEnd,
    );
  }

  @override
  void onRemove() {
    hud.dispose();
    super.onRemove();
  }
}
