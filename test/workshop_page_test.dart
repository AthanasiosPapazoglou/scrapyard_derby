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

  testWidgets('Workshop lists the tracks and buys with scrap', (tester) async {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final price = Tuning.upgradePrices[0];
    final profile = PlayerProfile(scrap: price + 10);
    await tester.pumpWidget(MaterialApp(home: WorkshopPage(profile: profile)));

    for (final track in UpgradeTrack.values) {
      expect(find.text(track.name.toUpperCase()), findsWidgets);
    }
    expect(find.text('${price + 10} SCRAP'), findsOneWidget);
    expect(find.text('BUY $price'), findsNWidgets(UpgradeTrack.values.length));

    await tester.tap(find.text('BUY $price').first);
    await tester.pump();

    expect(profile.upgradeLevel(UpgradeTrack.values.first.id), 1);
    expect(find.text('10 SCRAP'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 1 of 5'), findsOneWidget);

    // Now nothing is affordable: tapping another Buy does nothing.
    await tester.tap(find.text('BUY $price').first);
    await tester.pump();
    expect(profile.scrap, 10);
  });
}
