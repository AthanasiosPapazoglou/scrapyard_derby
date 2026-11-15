import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import '../profile/player_profile.dart';
import 'autopilot.dart';
import 'background.dart';
import 'camera_framing.dart';
import 'damage.dart';
import 'effects.dart';
import 'hill.dart';
import 'landing.dart';
import 'palette.dart';
import 'robot.dart';
import 'robot_sprites.dart';
import 'run_stats.dart';
import 'scrap_reward.dart';
import 'sound.dart';

/// Why a run ended.
enum RunEnd {
  headDown('HEAD DOWN'),
  stuck('STUCK');

  const RunEnd(this.label);

  final String label;
}

/// The outcome of a finished run, for the run summary.
@immutable
class RunResult {
  const RunResult({
    required this.end,
    required this.distance,
    required this.isNewBest,
    required this.stats,
    required this.scrap,
  });

  final RunEnd end;

  /// Horizontal meters covered (the score).
  final double distance;
  final bool isNewBest;
  final RunStats stats;

  /// Scrap earned, line by line; already added to the profile.
  final List<ScrapLine> scrap;

  int get scrapEarned => scrapTotal(scrap);
}

/// A snapshot of the numbers the Flutter overlays show.
@immutable
class HudInfo {
  const HudInfo({
    this.speed = 0,
    this.spin = 1,
    this.spinEnergy = 0,
    this.spinEnergyMax = Tuning.spinEnergyMaxTurns,
    this.lastLanding,
    this.distance = 0,
    this.bestDistance = 0,
    this.limbsLeft = 4,
    this.headLaunched = false,
    this.partHp = const {},
    this.result,
  });

  /// Robot speed in m/s.
  final double speed;

  /// Spin control: 1 = full clockwise, -1 = full counter-clockwise.
  final double spin;

  /// Stored spin energy in turns (0 to [spinEnergyMax]).
  final double spinEnergy;

  /// The most spin energy the robot can hold (raised by the Energy core).
  final double spinEnergyMax;
  final LandingType? lastLanding;

  /// Horizontal meters covered this run, and the best ever (saved).
  final double distance;
  final double bestDistance;

  /// Arms and legs still attached (0-4).
  final int limbsLeft;

  /// True once the head has been fired off like a rocket.
  final bool headLaunched;

  /// Each part's remaining HP (0 to 1) for the status panel.
  final Map<RobotSlot, double> partHp;

  /// Set once the run is over.
  final RunResult? result;
}

/// The game: an endless hill, one robot, a following camera, hold to
/// counter-spin. The run lasts until the robot breaks down or gets stuck.
class DerbyGame extends Forge2DGame with TapCallbacks {
  DerbyGame({required this.profile})
    : super(gravity: Vector2(0, Tuning.gravity));

  /// Saved player data; the best distance is recorded here at run end.
  final PlayerProfile profile;

  /// When set, a bot plays instead of the player's finger (used by the
  /// balance simulator in `tool/`; could drive AI rivals later).
  Autopilot? autopilot;

  final HillGeometry hillGeometry = HillGeometry();
  late Robot robot;

  /// Updated a few times per second for the Flutter overlays.
  late final ValueNotifier<HudInfo> hud = ValueNotifier(
    HudInfo(bestDistance: profile.bestDistance),
  );

  RunResult? _result;
  double _stallTime = 0;
  double _hudTimer = 0;
  double _visibleWidth = Tuning.cameraBaseWidth;

  /// Robot part artwork, loaded once.
  RobotSprites? _sprites;

  /// Feedback effects (particles, shake, vibration).
  final Effects effects = Effects();

  /// Where the camera is smoothly heading; the shake is added on top.
  Vector2 _cameraCenter = Vector2.zero();

  @override
  Color backgroundColor() => Palette.sky;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.subStepCount = Tuning.physicsSubSteps;
    camera.backdrop.add(Background());
    _sprites = await RobotSprites.load();
    await world.add(effects);
    _spawnRobot();
    await world.add(Hill(hillGeometry, focusX: _focusX)..priority = 1);
  }

  /// Where the hill should be built: around the robot.
  double _focusX() => robot.isLoaded ? robot.position.x : robot.start.x;

  void _spawnRobot() {
    // Priority 5: drawn in front of the hill (1), behind particles (6).
    // Upgrades bought in the Workshop apply from the next robot on.
    robot = Robot(
      hill: hillGeometry,
      look: _sprites?.look(profile.tierOf),
      stats: profile.robotStats,
    )..priority = 5;
    world.add(robot);
    _cameraCenter = robot.start.clone();
    camera.viewfinder.position = _cameraCenter.clone();
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
    _result = null;
    _stallTime = 0;
    _slowMoLeft = 0;
    _visibleWidth = Tuning.cameraBaseWidth;
    hud.value = HudInfo(bestDistance: profile.bestDistance);
  }

  /// Runs the world (physics, robot spin and hold response, hill) at
  /// [Tuning.gameSpeed] speed. This game's own [update] below (camera, HUD,
  /// stuck timer) still gets real time, so the camera stays smooth.
  @override
  void updateTree(double dt) =>
      super.updateTree(dt * Tuning.gameSpeed * _slowMoFactor);

  /// Slows the game right after the head launch, easing back to normal
  /// (see [Tuning.headLaunchSlowMo]).
  void startHeadLaunchSlowMo() {
    _slowMoLeft = Tuning.headLaunchSlowMoTime;
    Sound.duckMusic(
      Duration(milliseconds: (Tuning.headLaunchSlowMoTime * 1000).round()),
    );
  }

  /// Seconds (real time) of head-launch slow motion left.
  double _slowMoLeft = 0;

  /// 1 = normal speed; lower during the head-launch slow motion.
  double get _slowMoFactor {
    if (_slowMoLeft <= 0) {
      return 1;
    }
    final eased = 1 - _slowMoLeft / Tuning.headLaunchSlowMoTime;
    return Tuning.headLaunchSlowMo + (1 - Tuning.headLaunchSlowMo) * eased;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _slowMoLeft = math.max(0, _slowMoLeft - dt);
    if (!robot.isLoaded) {
      return;
    }
    final pilot = autopilot;
    final bool wantsHold;
    if (pilot == null) {
      wantsHold = _heldPointers.isNotEmpty;
    } else if (robot.headLaunched) {
      // Nothing left to steer (and the torso may already be removed).
      wantsHold = false;
    } else {
      wantsHold = pilot.decide(
        robot.flightState,
        hillGeometry,
        dt: dt * Tuning.gameSpeed * _slowMoFactor,
        onGround: robot.isOnGround,
        stats: robot.stats,
      );
    }
    robot.holding = _result == null && wantsHold;
    if (_result == null) {
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
      _finishRun(end);
    }
  }

  /// Records the run in the profile (best distance, scrap; once per run)
  /// and publishes the result for the run summary.
  void _finishRun(RunEnd end) {
    final stats = robot.runStats..distance = robot.distance;
    final isNewBest = profile.recordRun(stats.distance);
    final scrap = scrapReward(stats, newBest: isNewBest);
    profile.addScrap(scrapTotal(scrap));
    if (isNewBest) {
      // A beat after the landing sound, so the two don't blur together.
      Future<void>.delayed(
        Tuning.newBestSoundDelay,
        () => Sound.play(Sfx.newBest),
      );
    }
    _result = RunResult(
      end: end,
      distance: stats.distance,
      isNewBest: isNewBest,
      stats: stats,
      scrap: scrap,
    );
    _publishHud();
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
    _cameraCenter += (framing.center - _cameraCenter) * follow;
    viewfinder.position = _cameraCenter + effects.shakeOffset(dt);

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
      spinEnergyMax: robot.stats.spinEnergyMaxTurns,
      lastLanding: robot.lastLanding,
      // Frozen once the run is over, even if the wreck keeps sliding.
      distance: _result?.distance ?? robot.distance,
      bestDistance: profile.bestDistance,
      limbsLeft: robot.limbsLeft,
      headLaunched: robot.headLaunched,
      partHp: robot.partHp,
      result: _result,
    );
  }

  @override
  void onRemove() {
    hud.dispose();
    super.onRemove();
  }
}
