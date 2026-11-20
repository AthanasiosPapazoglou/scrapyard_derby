import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import '../profile/page_tour.dart';
import '../profile/player_profile.dart';
import 'autopilot.dart';
import 'background.dart';
import 'camera_framing.dart';
import 'damage.dart';
import 'effects.dart';
import 'hill.dart';
import 'landing.dart';
import 'coach.dart';
import 'landing_sight.dart';
import 'levels.dart';
import 'palette.dart';
import 'robot.dart';
import 'robot_sprites.dart';
import 'run_stats.dart';
import 'scrap_reward.dart';
import 'sound.dart';
import 'race_standings.dart';
import 'races.dart';
import 'rival_look.dart';
import 'racer.dart';
import 'star_flags.dart';

export 'race_standings.dart' show PlaceCallout, RivalMarker, Standing;
export 'racer.dart' show RunEnd;

/// The outcome of a finished run, for the run summary.
@immutable
class RunResult {
  const RunResult({
    required this.end,
    required this.distance,
    required this.isNewBest,
    required this.stats,
    required this.scrap,
    this.level = 1,
    this.starsBefore = 0,
    this.starsAfter = 0,
    this.unlockedLevel,
    this.race,
    this.place,
    this.standings = const [],
    this.isFirstWin = false,
    this.unlockedRace,
  });

  final RunEnd end;

  /// Horizontal meters covered (the score).
  final double distance;
  final bool isNewBest;
  final RunStats stats;

  /// The level played, its stars before and after this run, and the level
  /// this run unlocked (null if none).
  final int level;
  final int starsBefore;
  final int starsAfter;
  final int? unlockedLevel;

  /// The Versus race this was (null = a Survival run).
  final int? race;

  /// Versus: the player's final place (1-4) and every racer's final
  /// line, best first (rivals still racing ahead show their distance at
  /// the race end).
  final int? place;
  final List<Standing> standings;

  /// Versus: this race's first win, and the race it unlocked (null if
  /// none; shown once, the first time).
  final bool isFirstWin;
  final int? unlockedRace;

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
    this.starsPassed = 0,
    this.comboSteps = 0,
    this.comboMax = 0,
    this.coach,
    this.standings = const [],
    this.place,
    this.callout,
    this.markers = const [],
    this.fastForward = 1,
    this.raceHint = false,
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

  /// Horizontal meters covered this run, and the best on this level.
  final double distance;
  final double bestDistance;

  /// Arms and legs still attached (0-4).
  final int limbsLeft;

  /// True once the head has been fired off like a rocket.
  final bool headLaunched;

  /// Each part's remaining HP (0 to 1) for the status panel.
  final Map<RobotSlot, double> partHp;

  /// Star distances of the level passed so far this run (0-3).
  final int starsPassed;

  /// Combo Coil: bonus steps of the current clean streak, and the most it
  /// can reach (0 = no Combo Coil).
  final int comboSteps;
  final int comboMax;

  /// The tutorial card to show (first run only; null = none).
  final CoachCard? coach;

  /// Versus: live standings (best first), the player's place, a place
  /// change callout, markers for rivals off screen, and the fast-forward
  /// speed after the player finished (1 = none).
  final List<Standing> standings;
  final int? place;
  final PlaceCallout? callout;
  final List<RivalMarker> markers;
  final int fastForward;

  /// Show the first race's one-line hint card.
  final bool raceHint;

  /// Set once the run is over.
  final RunResult? result;
}

/// The game: one level's endless hill, the player's robot, a following
/// camera, hold to counter-spin. The run lasts until the robot breaks down
/// or gets stuck.
///
/// Survival: the player's robot alone, with the Workshop's parts. Versus
/// ([race] set): the player and 3 rival robots driven by [Autopilot]s race
/// down the same hill with the race's gear. Robots never touch each other
/// (every part shares one collision group, see robot_part.dart).
class DerbyGame extends Forge2DGame with TapCallbacks {
  DerbyGame({required this.profile, int level = 1, this.race})
    : level = race == null ? level : Races.of(race).level,
      hillGeometry = HillGeometry(
        level: race == null ? level : Races.of(race).level,
      ),
      super(gravity: Vector2(0, Tuning.gravity));

  /// The level being played (1-based, see [Tuning.levels]). In Versus, the
  /// level whose hill the race runs on.
  final int level;

  /// The Versus race being run (1-based, see [Tuning.versusRaces]), or
  /// null for Survival.
  final int? race;

  bool get isVersus => race != null;

  /// Saved player data; the best distance is recorded here at run end.
  final PlayerProfile profile;

  /// When set, a bot plays instead of the player's finger (used by the
  /// balance simulator in `tool/`).
  Autopilot? get autopilot => player.autopilot;
  set autopilot(Autopilot? pilot) => player.autopilot = pilot;

  final HillGeometry hillGeometry;

  /// Everyone on the hill: the player first, then the rivals (Versus).
  late final List<Racer> racers = [
    Racer(name: 'YOU', color: Palette.rust, isPlayer: true),
    if (race case final race?)
      for (final rival in Races.of(race).rivals)
        Racer(
          name: rival.name,
          color: Color(rival.color),
          isPlayer: false,
          autopilot: Autopilot(
            skill: rival.skill,
            seed: _seeds.nextInt(1 << 30),
          ),
        ),
  ];

  /// New seeds for the rivals' judgement every attempt, so rematches
  /// differ.
  final math.Random _seeds = math.Random();

  /// The player's racer.
  Racer get player => racers.first;

  /// The rival racers (empty in Survival).
  Iterable<Racer> get rivals => racers.skip(1);

  /// The player's robot.
  Robot get robot => player.robot;

  /// Updated a few times per second for the Flutter overlays.
  late final ValueNotifier<HudInfo> hud = ValueNotifier(
    HudInfo(bestDistance: profile.bestOn(level)),
  );

  /// Meters of world visible across the screen right now (zoom).
  double get visibleWidth => _visibleWidth;

  RunResult? _result;
  int _starsPassed = 0;
  double _hudTimer = 0;
  double _visibleWidth = Tuning.cameraBaseWidth;

  /// Robot part artwork, loaded once.
  RobotSprites? _sprites;

  /// Feedback effects (particles, shake, vibration).
  final Effects effects = Effects();

  /// Where the camera is smoothly heading; the shake is added on top.
  Vector2 _cameraCenter = Vector2.zero();

  @override
  Color backgroundColor() => theme.skyMid;

  /// The level's colours and weather.
  late final LevelTheme theme = LevelTheme.of(level);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.subStepCount = Tuning.physicsSubSteps;
    camera.backdrop.add(Background(theme));
    _sprites = await RobotSprites.load();
    await world.add(effects);
    await world.add(rivalEffects);
    _spawnRobots();
    await world.add(
      Hill(hillGeometry, focusXs: _focusXs, theme: theme)..priority = 1,
    );
    await world.add(_sight);
    _coach = _newCoach();
    if (isVersus) {
      _startRace();
      return;
    }
    // A flag at each star distance (distance is measured from the start).
    final targets = Levels.of(level).starDistances;
    for (var i = 0; i < targets.length; i++) {
      await world.add(
        StarFlag(
          stars: i + 1,
          x: robot.start.x + targets[i],
          hill: hillGeometry,
        ),
      );
    }
  }

  final LandingSight _sight = LandingSight();

  /// The guided first run (level 1, until played once; never for bots).
  Coach? _coach;
  Coach? get coach => _coach;

  Coach? _newCoach() => !isVersus && level == 1 && !profile.firstRunCoached
      ? Coach(onFinished: () => profile.firstRunCoached = true)
      : null;

  /// Ends the tutorial (its Skip button).
  void skipTutorial() {
    _coach?.skip();
    _publishHud();
  }

  /// The coach's slow-down, when it is running for a person.
  double get _coachFactor {
    final coach = _coach;
    return coach == null || autopilot != null ? 1 : coach.timeScale;
  }

  /// Where the hill should be built: around the player and every rival
  /// still on the hill.
  Iterable<double> _focusXs() sync* {
    for (final racer in racers) {
      if (!racer.isPlayer && racer.finishedFor > Tuning.rivalLingerTime) {
        continue;
      }
      final robot = racer.robot;
      yield robot.isLoaded ? robot.position.x : robot.start.x;
    }
  }

  /// Effects for rival robots: particles only, smaller, no sound,
  /// vibration or screen shake.
  final Effects rivalEffects = Effects(quiet: true);

  void _spawnRobots() {
    for (final racer in racers) {
      racer.reset(_newRobot(racer));
      world.add(racer.robot);
    }
    _cameraCenter = robot.start.clone();
    camera.viewfinder.position = _cameraCenter.clone();
  }

  Robot _newRobot(Racer racer) {
    final race = this.race;
    // Survival: the Workshop's parts (upgrades apply from the next robot
    // on). Versus: everyone gets the race's gear.
    final look = race == null
        ? _sprites?.look(profile.tierOf)
        : _sprites?.look((track) => Races.tierOf(race, track));
    final stats = race == null ? profile.robotStats : Races.statsOf(race);
    if (racer.isPlayer) {
      // Priority 5: drawn in front of the hill (1) and the rivals (4),
      // behind particles (6).
      return Robot(hill: hillGeometry, look: look, stats: stats)..priority = 5;
    }
    racer.autopilot = Autopilot(
      skill: racer.autopilot?.skill ?? 0.5,
      seed: _seeds.nextInt(1 << 30),
    );
    return Robot(
      hill: hillGeometry,
      look: look,
      stats: stats,
      rival: RivalLook(
        name: racer.name,
        color: racer.color,
        index: racers.indexOf(racer) - 1,
      ),
    )..priority = 4;
  }

  /// Fingers currently touching the screen. Holding any finger down applies
  /// counter-spin; it stops when the last finger lifts.
  final Set<int> _heldPointers = {};

  @override
  void onTapDown(TapDownEvent event) {
    _heldPointers.add(event.pointerId);
    // A tap during the race fast-forward skips faster.
    if (fastForward > 1 && !_skipFastForward) {
      _skipFastForward = true;
      _publishHud();
    }
  }

  @override
  void onTapUp(TapUpEvent event) => _heldPointers.remove(event.pointerId);

  @override
  void onTapCancel(TapCancelEvent event) =>
      _heldPointers.remove(event.pointerId);

  /// Starts a new run with a fresh robot at the top of the hill.
  void restart() {
    for (final racer in racers) {
      if (racer.robot.isMounted || racer.robot.isLoading) {
        racer.robot.removeFromParent();
      }
    }
    _spawnRobots();
    _result = null;
    _starsPassed = 0;
    _slowMoLeft = 0;
    _skipFastForward = false;
    _places.reset();
    _raceHintLeft = 0;
    if (isVersus) {
      _startRace();
    }
    _visibleWidth = Tuning.cameraBaseWidth;
    // A fresh run starts the tutorial over, unless it was finished.
    if (_coach != null && !_coach!.finished) {
      _coach = _newCoach();
    }
    hud.value = HudInfo(bestDistance: profile.bestOn(level));
  }

  /// Runs the world (physics, robot spin and hold response, hill) at
  /// [Tuning.gameSpeed] speed. This game's own [update] below (camera, HUD,
  /// stuck timer) still gets real time, so the camera stays smooth.
  @override
  void updateTree(double dt) =>
      super.updateTree(dt * Tuning.gameSpeed * _slowMoFactor * _coachFactor);

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

  /// Versus: game frames run per screen frame. Above 1 while the player
  /// has finished but their place isn't settled yet (D49).
  int get fastForward {
    if (!isVersus || !player.finished || _result != null) {
      return 1;
    }
    return _skipFastForward
        ? Tuning.raceFastForwardSkip
        : Tuning.raceFastForward;
  }

  bool _skipFastForward = false;

  /// Seconds (real time) the first race's hint card has left.
  double _raceHintLeft = 0;

  /// A race (or a retry) begins: the start sting, and the hint card the
  /// very first time (D53).
  void _startRace() {
    Sound.play(Sfx.raceStart);
    if (autopilot == null && !profile.tourSeen(PageTour.raceHint)) {
      profile.markTourSeen(PageTour.raceHint);
      _raceHintLeft = Tuning.raceHintTime;
    }
  }

  /// Announces the player's place changes.
  final PlaceWatcher _places = PlaceWatcher();

  /// Everyone's standing right now, in [racers] order.
  List<Standing> get _standingsNow => [for (final r in racers) r.standing];

  @override
  void update(double dt) {
    // Fast-forward runs whole game frames back to back, so the race plays
    // out exactly as it would at normal speed, only quicker.
    final frames = fastForward;
    for (var i = 0; i < frames; i++) {
      super.update(dt);
      _slowMoLeft = math.max(0, _slowMoLeft - dt);
      if (!robot.isLoaded) {
        return;
      }
      _updateRacers(dt);
      if (fastForward == 1) {
        break;
      }
    }
    // The camera keeps pace with a fast-forwarded race.
    _updateCamera(dt * frames);
    if (_raceHintLeft > 0) {
      _raceHintLeft -= dt;
      if (_raceHintLeft <= 0) {
        _publishHud();
      }
    }

    _hudTimer += dt;
    if (_hudTimer >= 0.1) {
      _hudTimer = 0;
      _publishHud();
    }
  }

  /// One game frame for everyone on the hill: steering, star distances,
  /// finishes, the tutorial, places.
  void _updateRacers(double dt) {
    // Game-world seconds this frame, for the bots' reaction times.
    final worldDt = dt * Tuning.gameSpeed * _slowMoFactor * _coachFactor;
    var playerHolds = false;
    for (final racer in racers) {
      final holds = _steer(racer, dt, worldDt);
      if (racer.isPlayer) {
        playerHolds = holds;
      }
    }
    if (_result == null) {
      _checkStarsPassed();
    }
    for (final racer in racers) {
      _checkRacerEnd(racer, dt);
    }
    _updateCoach(dt, playerHolds);
    if (isVersus) {
      _updateRace(dt);
    }
  }

  /// Versus: tracks the player's place and ends the race once that place
  /// can't change any more.
  void _updateRace(double dt) {
    final standings = _standingsNow;
    final before = _places.callout;
    _places.update(
      dt,
      RaceStandings.placeOf(standings),
      live: robot.hasTouchedDown && !player.finished,
    );
    if (_places.callout != before) {
      _publishHud();
    }
    if (_result == null && RaceStandings.placeLocked(standings)) {
      _finishRace(standings);
    }
  }

  /// Sets [racer]'s hold for this frame (finger or bot, plus the
  /// Auto-Gyro gadget). Returns whether the player (or bot) itself holds.
  bool _steer(Racer racer, double dt, double worldDt) {
    final robot = racer.robot;
    if (!robot.isLoaded || !robot.isMounted) {
      return false;
    }
    final pilot = racer.autopilot;
    final bool holds;
    if (racer.finished || robot.headLaunched) {
      // Nothing left to steer (and the torso may already be removed).
      holds = false;
    } else if (pilot == null) {
      holds = _heldPointers.isNotEmpty;
    } else {
      holds = pilot.decide(
        robot.flightState,
        hillGeometry,
        dt: worldDt,
        onGround: robot.isOnGround,
        stats: robot.stats,
      );
    }
    // Auto-Gyro gadget: helps whoever plays when they aren't holding.
    final wantsHold =
        holds ||
        (!robot.headLaunched &&
            !robot.isOnGround &&
            autoGyroWantsHold(
              robot.flightState,
              hillGeometry,
              stats: robot.stats,
            ));
    robot.holding = !racer.finished && wantsHold;
    return holds;
  }

  /// Feeds the tutorial what happened this frame; republishes the HUD when
  /// its card changes.
  void _updateCoach(double dt, bool playerHolds) {
    final coach = _coach;
    if (coach == null || coach.finished || autopilot != null) {
      return;
    }
    final before = coach.card;
    final stats = robot.runStats;
    final clean = stats.landingsOf(LandingType.clean);
    final bad =
        stats.landingsOf(LandingType.oneFoot) +
        stats.landingsOf(LandingType.crash);
    coach.update(
      dt,
      CoachInput(
        hasTouchedDown: robot.hasTouchedDown,
        onGround: robot.isOnGround,
        playerHolding: playerHolds,
        landings: clean + bad,
        cleanLandings: clean,
        badLandings: bad,
        sightShowing: _sight.showing,
        headLaunched: robot.headLaunched,
        runOver: _result != null,
      ),
    );
    if (coach.card != before) {
      _publishHud();
    }
  }

  /// Plays the jingle each time the robot passes one of the level's star
  /// distances during a run.
  void _checkStarsPassed() {
    final targets = Levels.of(level).starDistances;
    if (_starsPassed < targets.length &&
        robot.distance >= targets[_starsPassed]) {
      _starsPassed++;
      Sound.play(Sfx.newBest);
      _publishHud();
    }
  }

  /// Finishes [racer]'s run when its head lands or it gets stuck; clears
  /// finished rivals away after a while.
  void _checkRacerEnd(Racer racer, double dt) {
    final robot = racer.robot;
    if (racer.finished) {
      racer.finishedFor += dt;
      if (!racer.isPlayer &&
          racer.finishedFor > Tuning.rivalLingerTime &&
          robot.isMounted) {
        robot.removeFromParent();
      }
      return;
    }
    if (!robot.isLoaded || !robot.isMounted) {
      return;
    }
    racer.stallTime = robot.speed < Tuning.stallSpeed
        ? racer.stallTime + dt
        : 0;
    final RunEnd? end;
    if (robot.headLanded) {
      end = RunEnd.headDown;
    } else if (racer.stallTime >= Tuning.stallTime) {
      end = RunEnd.stuck;
    } else {
      end = null;
    }
    if (end == null) {
      return;
    }
    racer.finish(end);
    if (racer.isPlayer) {
      _finishRun(end);
    }
  }

  /// Records the run in the profile (best distance, stars, scrap; once per
  /// run) and publishes the result for the run summary.
  void _finishRun(RunEnd end) {
    final stats = robot.runStats..distance = player.distance;
    if (isVersus) {
      // The race goes on (fast-forward) until the player's place is
      // settled; see _updateRace.
      _publishHud();
      return;
    }
    // The star bonus counts the stars held before this run.
    final starBonus = profile.starScrapBonus;
    final record = profile.recordRun(level, stats.distance);
    final isNewBest = record.isNewBest;
    final scrap = scrapReward(
      stats,
      newBest: isNewBest,
      level: level,
      starBonus: starBonus,
      newStars: record.newStars,
      magnetBonus: robot.stats.scrapMagnet,
    );
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
      level: level,
      starsBefore: record.starsBefore,
      starsAfter: record.starsAfter,
      unlockedLevel: record.unlockedLevel,
    );
    _publishHud();
  }

  /// Versus: the race is over for the player. Records the place (never a
  /// Survival best: the gear was the race's, not the Workshop's) and pays
  /// scrap (D51): the Survival formula on the distance, plus the place
  /// bonus and the first-win bonus. Scrap Magnet doesn't apply.
  void _finishRace(List<Standing> standings) {
    final race = this.race!;
    final stats = robot.runStats..distance = player.distance;
    final place = RaceStandings.placeOf(standings);
    final starBonus = profile.starScrapBonus;
    final record = profile.recordRace(race, place);
    final scrap = scrapReward(
      stats,
      newBest: false,
      level: level,
      starBonus: starBonus,
      place: place,
      firstWinRace: record.isFirstWin ? race : null,
    );
    profile.addScrap(scrapTotal(scrap));
    if (place == 1) {
      Future<void>.delayed(
        Tuning.newBestSoundDelay,
        () => Sound.play(Sfx.newBest),
      );
    }
    _result = RunResult(
      end: player.end!,
      distance: stats.distance,
      isNewBest: false,
      stats: stats,
      scrap: scrap,
      level: level,
      race: race,
      place: place,
      standings: RaceStandings.order(standings),
      isFirstWin: record.isFirstWin,
      unlockedRace: record.unlockedRace,
    );
    _publishHud();
  }

  /// What the camera follows: the player's robot, or during the race
  /// fast-forward the rival who can still pass the player.
  Robot get _cameraRobot {
    if (fastForward > 1) {
      final chaser = RaceStandings.chaserIndex(_standingsNow);
      if (chaser != null && racers[chaser].robot.isLoaded) {
        return racers[chaser].robot;
      }
    }
    return robot;
  }

  /// Edge markers for running rivals out of view.
  List<RivalMarker> _markers() {
    if (!isVersus || size.x <= 0) {
      return const [];
    }
    final followed = _cameraRobot;
    final halfWidth = _visibleWidth / 2;
    final halfHeight = halfWidth * size.y / size.x;
    return [
      for (final rival in rivals)
        if (!rival.finished &&
            rival.robot.isLoaded &&
            !identical(rival.robot, followed))
          ?RivalMarker.offScreen(
            name: rival.name,
            color: rival.color,
            dx: rival.robot.position.x - _cameraCenter.x,
            dy: rival.robot.position.y - _cameraCenter.y,
            halfWidth: halfWidth,
            halfHeight: halfHeight,
            gap: rival.distance - player.distance,
          ),
    ];
  }

  /// Smoothly moves and zooms the camera so both the robot (or launched
  /// head) and the ground below it stay on screen (see camera_framing.dart).
  void _updateCamera(double dt) {
    if (size.x <= 0) {
      return;
    }
    final robot = _cameraRobot;
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
      bestDistance: profile.bestOn(level),
      limbsLeft: robot.limbsLeft,
      headLaunched: robot.headLaunched,
      partHp: robot.partHp,
      starsPassed: _starsPassed,
      comboSteps: robot.comboSteps,
      comboMax: robot.stats.comboCoilSteps,
      coach: autopilot == null ? _coach?.card : null,
      // From the player's first touchdown on: during the opening drop
      // everyone is level, and the panel would cover the rivals' tags.
      standings: isVersus && robot.hasTouchedDown
          ? RaceStandings.order(_standingsNow)
          : const <Standing>[],
      place: isVersus ? RaceStandings.placeOf(_standingsNow) : null,
      callout: _places.callout,
      markers: _markers(),
      fastForward: fastForward,
      raceHint: _raceHintLeft > 0,
      result: _result,
    );
  }

  @override
  void onRemove() {
    hud.dispose();
    super.onRemove();
  }
}
