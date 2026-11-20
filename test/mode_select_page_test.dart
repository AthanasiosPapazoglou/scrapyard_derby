import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/races.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/level_select_page.dart';
import 'package:scrapyard_derby/ui/main_menu.dart';
import 'package:scrapyard_derby/ui/mode_select_page.dart';
import 'package:scrapyard_derby/ui/versus_ladder_page.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('Play opens the mode choice; each mode opens its page', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(home: MainMenu(profile: PlayerProfile())),
    );
    await tester.pump();

    // A page push builds on the next frame; the fade takes 220 ms.
    Future<void> tapAndWait(Finder target) async {
      await tester.tap(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tapAndWait(find.text('PLAY'));
    expect(find.byType(ModeSelectPage), findsOne);
    expect(find.text('SURVIVAL'), findsOne);
    expect(find.text('VERSUS'), findsOne);

    await tapAndWait(find.text('SURVIVAL'));
    expect(find.byType(LevelSelectPage), findsOne);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tapAndWait(find.text('VERSUS'));
    expect(find.byType(VersusLadderPage), findsOne);
  });

  testWidgets('ladder shows best places and locks', (tester) async {
    phone(tester);
    final profile = PlayerProfile(raceBestPlace: {1: 1, 2: 3});
    await tester.pumpWidget(
      MaterialApp(home: VersusLadderPage(profile: profile)),
    );
    final hill = Races.levelOf;
    expect(
      find.bySemanticsLabel('Race 1, ${hill(1).name}, best 1st'),
      findsOne,
    );
    expect(
      find.bySemanticsLabel('Race 2, ${hill(2).name}, best 3rd'),
      findsOne,
    );
    for (var race = 3; race <= Races.count; race++) {
      expect(
        find.bySemanticsLabel('Race $race, ${hill(race).name}, locked'),
        findsOne,
      );
    }
    expect(find.text('Win race 2'), findsOne);
    // Rivals are listed by name.
    for (final rival in Races.of(1).rivals) {
      expect(find.text(rival.name), findsOne);
    }
  });
}
