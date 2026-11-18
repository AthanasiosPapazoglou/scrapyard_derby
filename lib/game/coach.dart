import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/tuning.dart';

/// The guided first run: short cards that teach the controls at the
/// moment they matter, slowing the game while the player tries them.
/// Played on level 1 until finished or skipped once
/// (`PlayerProfile.firstRunCoached`).
///
/// Steps, in order (each waits for the player to do the thing):
/// 1. [CoachStep.drop]: the robot falls and spins on its own.
/// 2. [CoachStep.hold]: after the first bounce the game nearly stops until
///    the player holds anywhere (counter-spin).
/// 3. [CoachStep.release]: let go and the spin comes back.
/// 4. [CoachStep.land]: land on both feet; the game slows while the
///    Landing Sight shows how the landing will go.
/// 5. [CoachStep.energy]: spins charge energy for higher jumps.
///
/// Two cards come up when they happen: the first bad landing (the damage
/// panel) and the head launch (how the score is decided). The run's end
/// finishes the tutorial.
///
/// Plain logic, no Flame: the game feeds it a [CoachInput] every frame
/// and reads [card] and [timeScale].
class Coach {
  Coach({this.onFinished});

  /// Called once, when the run ends with the tutorial on, or on [skip].
  final VoidCallback? onFinished;

  CoachStep step = CoachStep.drop;
  bool get finished => step == CoachStep.done;

  /// The card to show now (null = none).
  CoachCard? get card => _card;
  CoachCard? _card;

  /// Multiplier on the game speed (1 = normal); eases towards the target.
  double get timeScale => _timeScale;
  double _timeScale = 1;

  double _holdTime = 0;
  double _stepTime = 0;
  int _landingsAtStep = 0;
  int _cleanAtStep = 0;

  /// An event card (damage, head launch) and how long it stays up.
  CoachCard? _event;
  double _eventLeft = 0;
  bool _damageShown = false;
  bool _headShown = false;

  /// Ends the tutorial now (the Skip button).
  void skip() => _finish();

  /// Advances the tutorial. [dt] is real time (seconds), not game time.
  void update(double dt, CoachInput input) {
    if (finished) {
      return;
    }
    if (input.runOver) {
      _finish();
      return;
    }
    _stepTime += dt;
    var slow = 1.0;

    switch (step) {
      case CoachStep.drop:
        if (input.hasTouchedDown && !input.onGround) {
          _next(CoachStep.hold, input);
        }
      case CoachStep.hold:
        if (input.playerHolding) {
          _holdTime += dt;
          if (_holdTime >= Tuning.coachHoldTime) {
            _next(CoachStep.release, input);
          }
        } else if (!input.onGround) {
          slow = Tuning.coachHoldSlow;
        }
      case CoachStep.release:
        if (!input.playerHolding) {
          _next(CoachStep.land, input);
        }
      case CoachStep.land:
        if (input.cleanLandings > _cleanAtStep ||
            input.landings - _landingsAtStep >= Tuning.coachLandTries) {
          _next(CoachStep.energy, input);
        } else if (input.sightShowing) {
          slow = Tuning.coachSightSlow;
        }
      case CoachStep.energy:
        if (_stepTime >= Tuning.coachEnergyTime) {
          _next(CoachStep.free, input);
        }
      case CoachStep.free:
      case CoachStep.done:
        break;
    }

    // Event cards: the first bad landing (once the basics are shown) and
    // the head launch.
    if (!_damageShown &&
        input.badLandings > 0 &&
        step.index >= CoachStep.land.index) {
      _damageShown = true;
      _event = CoachCard.damage;
      _eventLeft = Tuning.coachDamageTime;
    }
    if (!_headShown && input.headLaunched) {
      _headShown = true;
      _event = CoachCard.head;
      _eventLeft = double.infinity;
    }
    _eventLeft -= dt;
    if (_eventLeft <= 0) {
      _event = null;
    }

    // Until the first hold-and-release is done, the step's card wins.
    final waiting = step.index <= CoachStep.release.index;
    _card = waiting ? step.card : (_event ?? step.card);
    final ease = 1 - math.exp(-Tuning.coachSlowEase * dt);
    _timeScale += (slow - _timeScale) * ease;
    if ((_timeScale - slow).abs() < 0.01) {
      _timeScale = slow;
    }
  }

  void _next(CoachStep next, CoachInput input) {
    step = next;
    _stepTime = 0;
    _holdTime = 0;
    _landingsAtStep = input.landings;
    _cleanAtStep = input.cleanLandings;
  }

  void _finish() {
    if (finished) {
      return;
    }
    step = CoachStep.done;
    _card = null;
    _timeScale = 1;
    onFinished?.call();
  }
}

enum CoachStep {
  drop(CoachCard.drop),
  hold(CoachCard.hold),
  release(CoachCard.release),
  land(CoachCard.land),
  energy(CoachCard.energy),

  /// The basics are done; only event cards from here on.
  free(null),
  done(null);

  const CoachStep(this.card);

  final CoachCard? card;
}

/// What the coach needs to know about the run, each frame.
@immutable
class CoachInput {
  const CoachInput({
    this.hasTouchedDown = false,
    this.onGround = false,
    this.playerHolding = false,
    this.landings = 0,
    this.cleanLandings = 0,
    this.badLandings = 0,
    this.sightShowing = false,
    this.headLaunched = false,
    this.runOver = false,
  });

  final bool hasTouchedDown;
  final bool onGround;

  /// The player's own finger (not the Auto-Gyro).
  final bool playerHolding;

  /// Landings this run: all, clean, and one-foot or crash.
  final int landings;
  final int cleanLandings;
  final int badLandings;

  final bool sightShowing;
  final bool headLaunched;
  final bool runOver;
}

/// What a card points at on screen.
enum CoachPointer { none, energyBar, statusPanel }

/// One coach card: a short title and line, what it points at, and
/// whether to show the "hold anywhere" finger.
@immutable
class CoachCard {
  const CoachCard(
    this.title,
    this.text, {
    this.pointer = CoachPointer.none,
    this.finger = false,
  });

  final String title;
  final String text;
  final CoachPointer pointer;
  final bool finger;

  static const drop = CoachCard(
    'HERE GOES!',
    'Your robot spins on its own. Land on your feet to bounce.',
  );
  static const hold = CoachCard(
    'HOLD ANYWHERE',
    'Holding spins the robot the other way. Try it now!',
    finger: true,
  );
  static const release = CoachCard(
    'NOW LET GO',
    'The spin comes back on its own. Keep the feet pointing down.',
  );
  static const land = CoachCard(
    'LAND ON BOTH FEET',
    'Watch the marker: green means both feet, for a big bounce.',
  );
  static const energy = CoachCard(
    'SPIN = ENERGY',
    'Turns in the air charge this bar. More spins, higher jumps!',
    pointer: CoachPointer.energyBar,
  );
  static const damage = CoachCard(
    'OUCH!',
    'Bad landings wear your parts down. At zero, a limb breaks off.',
    pointer: CoachPointer.statusPanel,
  );
  static const head = CoachCard(
    'HEAD LAUNCH!',
    'Out of limbs: your head rockets off. Where it lands is your score.',
  );
}
