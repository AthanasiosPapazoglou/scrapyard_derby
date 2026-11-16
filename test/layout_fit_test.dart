import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/damage.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/game/landing.dart';
import 'package:scrapyard_derby/game/run_stats.dart';
import 'package:scrapyard_derby/game/scrap_reward.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/hud.dart';
import 'package:scrapyard_derby/ui/level_select_page.dart';
import 'package:scrapyard_derby/ui/main_menu.dart';
import 'package:scrapyard_derby/ui/robot_stats_page.dart';
import 'package:scrapyard_derby/ui/settings_page.dart';
import 'package:scrapyard_derby/ui/workshop_page.dart';

/// Every page must lay out without overflow on phones held either way and
/// on tablets. Overflow ("RenderFlex overflowed") is reported as an error,
/// which fails the test.
///
/// Sizes are logical pixels (device pixel ratio 1).
const _screens = {
  'phone portrait': Size(390, 844),
  'phone landscape': Size(844, 390),
  'small phone portrait': Size(360, 640),
  'small phone landscape': Size(640, 360),
  'tablet portrait': Size(820, 1180),
  'tablet landscape': Size(1180, 820),
};

/// Pages not yet made responsive, per screen: skipped until the roadmap
/// step that fixes them (V3 menus, V9 stats screen). Empty this as
/// Block 3 lands; nothing may be added.
const Map<String, Set<String>> _knownMisfits = {
  // V3
  // V9
  'robot stats': {
    'phone portrait',
    'small phone portrait',
    'small phone landscape',
  },
};

/// A player part-way through the game, so pages show realistic content.
PlayerProfile _midGameProfile() => PlayerProfile(
  scrap: 12345,
  levelBest: {1: 4400, 2: 2100, 3: 800},
  upgradeLevels: {'plating': 2, 'springLegs': 3, 'rocketHead': 1},
  gadgetLevels: {'scrapMagnet': 1, 'autoGyro': 2},
);

/// A HUD with a finished run, so the run summary card shows.
Widget _hudWithSummary() {
  final profile = _midGameProfile();
  final game = DerbyGame(profile: profile);
  final stats = RunStats()
    ..addLanding(LandingType.clean)
    ..addLanding(LandingType.oneFoot)
    ..addLanding(LandingType.crash)
    ..addLimbLost()
    ..reportHeight(18.4)
    ..headLaunchedAt(3700)
    ..headLandedAt(3812);
  game.hud.value = HudInfo(
    distance: 3812,
    bestDistance: 4400,
    limbsLeft: 0,
    partHp: const {RobotSlot.leftArm: 0, RobotSlot.rightArm: 0.5},
    result: RunResult(
      end: RunEnd.headDown,
      distance: 3812,
      isNewBest: true,
      stats: stats,
      scrap: const [
        ScrapLine('Distance', 381),
        ScrapLine('Clean landings x1', 2),
        ScrapLine('Stars x5', 57),
        ScrapLine('New star', 50),
      ],
      starsBefore: 1,
      starsAfter: 3,
    ),
  );
  return Scaffold(
    body: Hud(game: game, onMenu: () {}, onWorkshop: () {}, onNextLevel: () {}),
  );
}

final Map<String, Widget Function()> _pages = {
  'main menu': () => MainMenu(profile: _midGameProfile()),
  'level select': () => LevelSelectPage(profile: _midGameProfile()),
  'workshop': () => WorkshopPage(profile: _midGameProfile()),
  'workshop gadgets': () => WorkshopPage(profile: _midGameProfile()),
  'robot stats': () => RobotStatsPage(profile: _midGameProfile()),
  'settings': () => SettingsPage(profile: _midGameProfile()),
  'run summary': _hudWithSummary,
};

void main() {
  for (final MapEntry(key: screen, value: size) in _screens.entries) {
    group(screen, () {
      for (final MapEntry(key: page, value: build) in _pages.entries) {
        final misfit = _knownMisfits[page]?.contains(screen) ?? false;
        testWidgets('$page fits', skip: misfit, (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(MaterialApp(home: build()));
          if (page == 'workshop gadgets') {
            await tester.tap(find.text('GADGETS'));
          }
          // A few frames: sprites load, animations start. (Pages with
          // endless tickers never "settle".)
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          // Async sprite loading finishes outside the fake clock.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
          await tester.pump(const Duration(milliseconds: 100));
          // Overflow errors fail the test on their own, with the full
          // report (which widget, where in the source).
        });
      }
    });
  }
}
