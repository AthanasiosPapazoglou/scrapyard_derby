import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/settings_page.dart';

void main() {
  late PlayerProfile profile;

  Future<void> openSettings(WidgetTester tester) async {
    // Landscape phone size, like the game.
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SettingsPage(profile: profile)));
  }

  setUp(() {
    profile = PlayerProfile(
      levelBest: {1: 640},
      scrap: 90,
      upgradeLevels: {'plating': 2},
    );
  });

  testWidgets('switches change the profile', (tester) async {
    await openSettings(tester);
    expect(profile.hapticsOn, isTrue);
    expect(profile.showLandingSight, isTrue);
    expect(profile.showDebugInfo, isFalse);

    // Vibration, Landing Sight, debug info.
    await tester.tap(find.byType(Switch).at(0));
    await tester.tap(find.byType(Switch).at(1));
    await tester.tap(find.byType(Switch).at(2));
    await tester.pump();

    expect(profile.hapticsOn, isFalse);
    expect(profile.showLandingSight, isFalse);
    expect(profile.showDebugInfo, isTrue);
  });

  testWidgets('the sound effects slider sets the volume', (tester) async {
    await openSettings(tester);
    final slider = find.byType(Slider).at(1);
    // Tap the left end of the slider track: close to 0.
    await tester.tapAt(tester.getTopLeft(slider) + const Offset(30, 20));
    await tester.pump();
    expect(profile.sfxVolume, lessThan(0.2));
    expect(find.text('${(profile.sfxVolume * 100).round()}%'), findsOneWidget);
  });

  testWidgets('reset asks first; cancel keeps everything', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();

    expect(find.text('Reset progress?'), findsOneWidget);
    expect(find.textContaining('640 m'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(profile.bestDistance, 640);
    expect(profile.scrap, 90);
  });

  testWidgets('confirming reset wipes progress but keeps settings', (
    tester,
  ) async {
    profile.hapticsOn = false;
    await openSettings(tester);
    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(profile.bestDistance, 0);
    expect(profile.scrap, 0);
    expect(profile.upgradeLevel('plating'), 0);
    expect(profile.hapticsOn, isFalse);
    expect(find.text('0 stars  ·  Best 0 m  ·  0 Scrap'), findsOneWidget);
  });
}
