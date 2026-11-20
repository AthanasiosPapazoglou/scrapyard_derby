import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/profile/page_tour.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/level_select_page.dart';
import 'package:scrapyard_derby/ui/robot_stats_page.dart';
import 'package:scrapyard_derby/ui/settings_page.dart';
import 'package:scrapyard_derby/ui/spotlight_tour.dart';
import 'package:scrapyard_derby/ui/versus_ladder_page.dart';
import 'package:scrapyard_derby/ui/workshop_page.dart';

/// Lets the start delay pass and the hole be measured.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(SpotlightTour.startDelay);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapAnywhere(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await settle(tester);
}

Widget _tour(
  PlayerProfile profile, {
  required List<GlobalKey> keys,
  bool active = true,
  bool missingMiddle = false,
}) => MaterialApp(
  home: Scaffold(
    body: SpotlightTour(
      tour: PageTour.levels,
      profile: profile,
      active: active,
      steps: [
        for (var i = 0; i < keys.length; i++)
          TourStep(target: keys[i], title: 'STEP $i', text: 'Text $i'),
      ],
      child: Column(
        children: [
          for (var i = 0; i < keys.length; i++)
            if (!(missingMiddle && i == 1))
              SizedBox(key: keys[i], height: 60, child: Text('Box $i')),
        ],
      ),
    ),
  ),
);

void main() {
  group('SpotlightTour', () {
    testWidgets('waits for the page, steps on tap, then saves it', (
      tester,
    ) async {
      final profile = PlayerProfile();
      final keys = [GlobalKey(), GlobalKey()];
      await tester.pumpWidget(_tour(profile, keys: keys));
      expect(find.text('STEP 0'), findsNothing);
      await settle(tester);
      expect(find.text('STEP 0'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      await tapAnywhere(tester);
      expect(find.text('STEP 1'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(profile.tourSeen(PageTour.levels), isFalse);
      await tapAnywhere(tester);
      expect(find.text('STEP 1'), findsNothing);
      expect(profile.tourSeen(PageTour.levels), isTrue);
    });

    testWidgets('SKIP ends it at once', (tester) async {
      final profile = PlayerProfile();
      await tester.pumpWidget(
        _tour(profile, keys: [GlobalKey(), GlobalKey(), GlobalKey()]),
      );
      await settle(tester);
      await tester.tap(find.text('SKIP'));
      await settle(tester);
      expect(find.text('STEP 0'), findsNothing);
      expect(profile.tourSeen(PageTour.levels), isTrue);
    });

    testWidgets('a step whose target is not on screen is skipped', (
      tester,
    ) async {
      final profile = PlayerProfile();
      await tester.pumpWidget(
        _tour(
          profile,
          keys: [GlobalKey(), GlobalKey(), GlobalKey()],
          missingMiddle: true,
        ),
      );
      await settle(tester);
      await tapAnywhere(tester);
      expect(find.text('STEP 2'), findsOneWidget);
    });

    testWidgets('seen once, never again', (tester) async {
      final profile = PlayerProfile(toursSeen: {PageTour.levels});
      await tester.pumpWidget(_tour(profile, keys: [GlobalKey()]));
      await settle(tester);
      expect(find.text('STEP 0'), findsNothing);
    });

    testWidgets('an inactive tour starts when it becomes active', (
      tester,
    ) async {
      final profile = PlayerProfile();
      final keys = [GlobalKey()];
      await tester.pumpWidget(_tour(profile, keys: keys, active: false));
      await settle(tester);
      expect(find.text('STEP 0'), findsNothing);
      await tester.pumpWidget(_tour(profile, keys: keys));
      await settle(tester);
      expect(find.text('STEP 0'), findsOneWidget);
    });
  });

  group('pages', () {
    Future<void> open(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await settle(tester);
    }

    testWidgets('level select: the hills, then the stars', (tester) async {
      final profile = PlayerProfile();
      await open(tester, LevelSelectPage(profile: profile));
      expect(find.text('PICK A HILL'), findsOneWidget);
      await tapAnywhere(tester);
      expect(find.text('STARS'), findsOneWidget);
      await tapAnywhere(tester);
      expect(profile.tourSeen(PageTour.levels), isTrue);
    });

    testWidgets('workshop: four stops, then gadgets on first open', (
      tester,
    ) async {
      final profile = PlayerProfile(scrap: 500);
      await open(tester, WorkshopPage(profile: profile));
      for (final line in [
        'Legs, arms, body',
        'Tap a part to try it on',
        'Every run pays scrap',
        'Extra helpers for when',
      ]) {
        expect(find.textContaining(line), findsOneWidget, reason: line);
        await tapAnywhere(tester);
      }
      expect(profile.tourSeen(PageTour.workshop), isTrue);
      expect(profile.tourSeen(PageTour.gadgets), isFalse);
      await tester.tap(find.text('GADGETS'));
      await settle(tester);
      expect(find.textContaining('Helpers for tough hills'), findsOneWidget);
      await tapAnywhere(tester);
      expect(profile.tourSeen(PageTour.gadgets), isTrue);
    });

    testWidgets('robot stats: three stops', (tester) async {
      final profile = PlayerProfile();
      await open(tester, RobotStatsPage(profile: profile));
      for (final line in [
        'power rank',
        'Bars show now',
        'The helpers you own',
      ]) {
        expect(find.textContaining(line), findsOneWidget, reason: line);
        await tapAnywhere(tester);
      }
      expect(profile.tourSeen(PageTour.stats), isTrue);
    });

    testWidgets('versus ladder: gear, rivals, unlocking', (tester) async {
      final profile = PlayerProfile();
      await open(tester, VersusLadderPage(profile: profile));
      for (final title in ['RACE GEAR', 'RIVALS', 'WIN TO UNLOCK']) {
        expect(find.text(title), findsOneWidget, reason: title);
        await tapAnywhere(tester);
      }
      expect(profile.tourSeen(PageTour.ladder), isTrue);
      expect(find.text('RACE GEAR'), findsNothing);
    });

    testWidgets('settings: How to play brings everything back', (tester) async {
      final profile = PlayerProfile(
        firstRunCoached: true,
        toursSeen: PageTour.values.toSet(),
      );
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SettingsPage(profile: profile)),
      );
      await tester.tap(find.text('How to play'));
      await tester.pump();
      expect(profile.firstRunCoached, isFalse);
      for (final tour in PageTour.values) {
        expect(profile.tourSeen(tour), isFalse, reason: tour.id);
      }
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('profile', () {
    test('tours are saved and loaded', () {
      final p = PlayerProfile()
        ..markTourSeen(PageTour.workshop)
        ..markTourSeen(PageTour.stats);
      final back = PlayerProfile.fromJson(p.toJson());
      expect(back.tourSeen(PageTour.workshop), isTrue);
      expect(back.tourSeen(PageTour.stats), isTrue);
      expect(back.tourSeen(PageTour.levels), isFalse);
    });

    test('older saves that have played count as toured', () {
      final old = PlayerProfile.fromJson(const {
        'version': 3,
        'levelBest': {'1': 420.0},
      });
      for (final tour in PageTour.values) {
        expect(old.tourSeen(tour), isTrue, reason: tour.id);
      }
      final fresh = PlayerProfile.fromJson(const {});
      expect(fresh.tourSeen(PageTour.levels), isFalse);
    });

    test('unknown tour ids in a save are ignored', () {
      final p = PlayerProfile.fromJson(const {
        'tutorial': {
          'tours': ['levels', 'someday'],
        },
      });
      expect(p.tourSeen(PageTour.levels), isTrue);
      expect(p.tourSeen(PageTour.workshop), isFalse);
    });
  });
}
