import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/damage.dart';

void main() {
  const hp = Tuning.limbMaxHp;

  test('arms break first, then legs', () {
    final damage = RobotDamage();
    final broken = <RobotSlot>[];
    for (var i = 0; i < 100; i++) {
      broken.addAll(damage.add(hp / 10));
    }
    expect(broken, [
      RobotSlot.leftArm,
      RobotSlot.rightArm,
      RobotSlot.leftLeg,
      RobotSlot.rightLeg,
    ]);
  });

  test('every part loses HP, the next to break the fastest', () {
    final damage = RobotDamage()..add(hp / 2);
    final hps = destructionOrder.map(damage.hpOf).toList();
    // All below full...
    expect(hps.every((h) => h < 1), isTrue);
    // ...and strictly ordered: earlier in the order = lower HP.
    for (var i = 1; i < hps.length; i++) {
      expect(hps[i], greaterThan(hps[i - 1]));
    }
    expect(damage.hpOf(RobotSlot.leftArm), closeTo(0.5, 1e-9));
  });

  test('a part is at 0 exactly when it breaks', () {
    final damage = RobotDamage();
    expect(damage.add(hp - 1), isEmpty);
    expect(damage.hpOf(RobotSlot.leftArm), greaterThan(0));
    expect(damage.add(1), [RobotSlot.leftArm]);
    expect(damage.hpOf(RobotSlot.leftArm), 0);
    expect(damage.hpOf(RobotSlot.rightArm), closeTo(0.5, 1e-9));
  });

  test('one huge hit can break several limbs at once, in order', () {
    final damage = RobotDamage();
    expect(damage.add(hp * 2.5), [RobotSlot.leftArm, RobotSlot.rightArm]);
  });

  test('no more than four limbs ever break', () {
    final damage = RobotDamage()..add(hp * 100);
    expect(damage.limbsBroken, 4);
  });
}
