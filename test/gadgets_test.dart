import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/gadgets.dart';
import 'package:scrapyard_derby/game/hill.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/robot_stats.dart';
import 'package:scrapyard_derby/game/run_stats.dart';
import 'package:scrapyard_derby/game/scrap_reward.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/workshop_page.dart';

void main() {
  test('every gadget has a price per level and a known unlock level', () {
    for (final gadget in Gadget.values) {
      expect(
        Tuning.gadgetPrices[gadget.id],
        hasLength(Tuning.gadgetMaxLevel),
        reason: gadget.id,
      );
      expect(gadget.unlockLevel, inInclusiveRange(1, Tuning.levels.length));
      expect(gadget.priceAfter(Tuning.gadgetMaxLevel), isNull);
      for (var level = 0; level <= Tuning.gadgetMaxLevel; level++) {
        expect(gadget.effect(level), isNotEmpty);
      }
    }
  });

  test('no gadgets = the plain robot; each gadget moves its own value', () {
    expect(RobotStats.fromLevels({}).landingSightTime, 0);
    final none = RobotStats.fromLevels({});
    final all = RobotStats.fromLevels(
      {},
      gadgets: {for (final g in Gadget.values) g: Tuning.gadgetMaxLevel},
    );
    expect(none.landingSightTime, 0);
    expect(none.scrapMagnet, 0);
    expect(none.autoGyroWindow, 0);
    expect(none.landingDamageScale, 1);
    expect(none.crashCageCrashes, 0);
    expect(none.levelerSpan, 0);
    expect(all.landingSightTime, Tuning.landingSightTimes.last);
    expect(all.scrapMagnet, closeTo(3 * Tuning.scrapMagnetPerLevel, 1e-9));
    expect(all.autoGyroWindow, Tuning.autoGyroWindows.last);
    expect(
      all.landingDamageScale,
      closeTo(1 - 3 * Tuning.shockPadsPerLevel, 1e-9),
    );
    expect(all.crashCageCrashes, 3 * Tuning.crashCagePerLevel);
    expect(all.levelerSpan, Tuning.levelerSpans.last);
    // Gadgets don't touch the part stats.
    expect(all.limbMaxHp, none.limbMaxHp);
    expect(all.cleanBounce, none.cleanBounce);
  });

  test('Shock Pads soften one-foot and crash damage, not clean wear', () {
    final pads = RobotStats.fromLevels({}, gadgets: {Gadget.shockPads: 2});
    expect(
      landingDamage(LandingType.clean, stats: pads),
      Tuning.cleanLandingDamage,
    );
    expect(
      landingDamage(LandingType.crash, stats: pads),
      closeTo(Tuning.crashDamage * (1 - 2 * Tuning.shockPadsPerLevel), 1e-9),
    );
  });

  test('Leveler Treads: the averaged normal points up and smooths bumps', () {
    final hill = HillGeometry(level: 6);
    for (var x = 30.0; x < 200; x += 7.3) {
      final n = hill.averageNormalAt(x, 3);
      expect(n.length, closeTo(1, 1e-4));
      expect(n.y, lessThan(0));
    }
    // Wider spans vary less along the hill.
    double spread(double span) {
      var lo = double.infinity, hi = -double.infinity;
      for (var x = 30.0; x < 500; x += 0.5) {
        final a = math.atan2(hill.averageNormalAt(x, span).x, 1);
        lo = math.min(lo, a);
        hi = math.max(hi, a);
      }
      return hi - lo;
    }

    expect(spread(3), lessThan(spread(0.5)));
  });

  test('Scrap Magnet adds its line', () {
    final stats = RunStats()..distance = 1000;
    final base = (1000 / Tuning.scrapMetersPerScrap).floor();
    final lines = scrapReward(stats, newBest: false, magnetBonus: 0.2);
    expect(
      lines,
      contains(ScrapLine('Scrap Magnet +20%', (base * 0.2).round())),
    );
  });

  group('profile', () {
    test('gadgets open with their level, cost scrap and are saved', () {
      final p = PlayerProfile(scrap: 100000);
      expect(p.buyGadget(Gadget.landingSight), isTrue);
      expect(p.gadgetLevel(Gadget.landingSight), 1);
      expect(p.scrap, 100000 - Tuning.gadgetPrices['landingSight']![0]);
      // Auto-Gyro needs level 2.
      expect(p.isGadgetUnlocked(Gadget.autoGyro), isFalse);
      expect(p.buyGadget(Gadget.autoGyro), isFalse);
      p.recordRun(1, Tuning.levels[0].starDistances[0]);
      expect(p.buyGadget(Gadget.autoGyro), isTrue);
      expect(p.robotStats.autoGyroWindow, Tuning.autoGyroWindows[0]);

      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>;
      final back = PlayerProfile.fromJson(json);
      expect(back.gadgetLevel(Gadget.autoGyro), 1);
      expect(back.toJson(), p.toJson());

      p.resetProgress();
      expect(p.gadgetLevels, isEmpty);
    });

    test("can't buy past the max level or without scrap", () {
      final p = PlayerProfile(
        scrap: 10,
        gadgetLevels: {'scrapMagnet': Tuning.gadgetMaxLevel},
      );
      expect(p.buyGadget(Gadget.scrapMagnet), isFalse);
      expect(p.buyGadget(Gadget.landingSight), isFalse);
      expect(p.scrap, 10);
    });
  });

  testWidgets('Workshop Gadgets tab buys and shows locks', (tester) async {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final price = Tuning.gadgetPrices['landingSight']![0];
    final profile = PlayerProfile(scrap: price);
    await tester.pumpWidget(MaterialApp(home: WorkshopPage(profile: profile)));
    await tester.tap(find.bySemanticsLabel('Gadgets, 0 owned'));
    await tester.pump();
    for (final gadget in Gadget.values) {
      expect(find.text(gadget.name), findsOneWidget);
    }
    expect(find.text('UNLOCKS WITH LEVEL 5'), findsOneWidget);
    await tester.tap(find.text('BUY $price').first);
    await tester.pump();
    expect(profile.gadgetLevel(Gadget.landingSight), 1);
    expect(find.bySemanticsLabel('Gadgets, 1 owned'), findsOneWidget);
  });
}
