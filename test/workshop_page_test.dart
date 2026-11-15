import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/workshop_page.dart';

void main() {
  group('buying', () {
    test('deducts the price, raises the level and saves', () {
      final p = PlayerProfile(scrap: 200);
      var notified = 0;
      p.addListener(() => notified++);

      expect(p.buyUpgrade(UpgradeTrack.plating), isTrue);
      expect(p.scrap, 200 - Tuning.upgradePrices[0]);
      expect(p.upgradeLevel('plating'), 1);
      // One change notification = one save (the store listens).
      expect(notified, 1);
      expect(p.robotStats.limbMaxHp, greaterThan(Tuning.limbMaxHp));
    });

    test("can't overspend", () {
      final p = PlayerProfile(scrap: Tuning.upgradePrices[0] - 1);
      expect(p.canBuy(UpgradeTrack.gyroArms), isFalse);
      expect(p.buyUpgrade(UpgradeTrack.gyroArms), isFalse);
      expect(p.scrap, Tuning.upgradePrices[0] - 1);
      expect(p.upgradeLevel('gyroArms'), 0);
    });

    test("can't buy past the max level", () {
      final p = PlayerProfile(
        scrap: 100000,
        upgradeLevels: {'rocketHead': Tuning.upgradeMaxLevel},
      );
      expect(p.buyUpgrade(UpgradeTrack.rocketHead), isFalse);
      expect(p.scrap, 100000);
    });
  });

  testWidgets('Workshop shows the parts per slot and buys in order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final price = Tuning.upgradePrices[0];
    final profile = PlayerProfile(scrap: price + 10);
    await tester.pumpWidget(MaterialApp(home: WorkshopPage(profile: profile)));

    // A tab per slot; the first slot (legs) shows its six parts.
    for (final track in UpgradeTrack.values) {
      expect(find.text(track.name.toUpperCase()), findsOneWidget);
    }
    final legs = UpgradeTrack.springLegs;
    for (final name in legs.partNames) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    // The next part is shown first, with its price. (Header text is
    // outlined: drawn twice.)
    expect(find.text('${price + 10} Scrap'), findsNWidgets(2));
    expect(find.text('BUY $price'), findsOneWidget);
    expect(find.text('TRYING ON: ${legs.partName(1)}'), findsOneWidget);

    await tester.tap(find.text('BUY $price'));
    await tester.pump();

    expect(profile.tierOf(legs), 1);
    expect(profile.scrap, 10);
    expect(find.text('10 Scrap'), findsNWidgets(2));
    expect(find.text('INSTALLED'), findsWidgets);

    // Switch to the arms: their parts, and the next one is unaffordable.
    await tester.tap(find.bySemanticsLabel('Arms, tier 0'));
    await tester.pump();
    expect(find.text(UpgradeTrack.gyroArms.partName(0)), findsOneWidget);
    await tester.tap(find.text('BUY $price'));
    await tester.pump();
    expect(profile.tierOf(UpgradeTrack.gyroArms), 0);
    expect(profile.scrap, 10);

    // A part further up is locked until the ones before it are bought.
    final locked = UpgradeTrack.gyroArms.partName(3);
    await tester.tap(find.bySemanticsLabel(RegExp('^$locked, tier 3')));
    await tester.pump();
    expect(
      find.text('BUY ${UpgradeTrack.gyroArms.partName(1).toUpperCase()} FIRST'),
      findsOneWidget,
    );
  });
}
