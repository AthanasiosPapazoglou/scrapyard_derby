import 'dart:math' as math;

import '../config/tuning.dart';

/// The robot's parts as shown in the status panel.
enum RobotSlot {
  leftArm('L ARM'),
  rightArm('R ARM'),
  leftLeg('L LEG'),
  rightLeg('R LEG'),
  body('BODY'),
  head('HEAD');

  const RobotSlot(this.label);

  /// Short name for the status panel.
  final String label;
}

/// The order parts break in: arms first, then legs. After the legs, the
/// body is left behind at the head launch and the head ends the attempt
/// when it lands. (Not based on which part hit the ground.)
const List<RobotSlot> destructionOrder = [
  RobotSlot.leftArm,
  RobotSlot.rightArm,
  RobotSlot.leftLeg,
  RobotSlot.rightLeg,
  RobotSlot.body,
  RobotSlot.head,
];

/// The four limbs, in the order they break off.
final List<RobotSlot> limbOrder = destructionOrder.sublist(0, 4);

/// Linear robot damage.
///
/// Every landing adds to one shared damage [total]. Each part has its own
/// breaking point: the n-th part in [destructionOrder] breaks at
/// n × [Tuning.limbMaxHp]. A part's HP is `1 - total / breakingPoint`, so
/// all parts lose HP together, but the next one to break loses it fastest.
class RobotDamage {
  /// Damage taken so far this run.
  double total = 0;

  /// Damage at which [slot] breaks.
  static double breakingPoint(RobotSlot slot) =>
      (destructionOrder.indexOf(slot) + 1) * Tuning.limbMaxHp;

  /// Remaining HP of [slot], from 1 (full) to 0 (broken).
  double hpOf(RobotSlot slot) =>
      (1 - total / breakingPoint(slot)).clamp(0.0, 1.0);

  /// How many limbs have broken off at the current damage (0 to 4).
  int get limbsBroken =>
      math.min(limbOrder.length, (total / Tuning.limbMaxHp).floor());

  /// Adds [amount] of damage and returns the limbs that broke because of
  /// it, in order (usually none, sometimes one, rarely more).
  List<RobotSlot> add(double amount) {
    final before = limbsBroken;
    total += amount;
    return limbOrder.sublist(before, limbsBroken);
  }
}
