import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/game/levels.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/level_select_page.dart';

void main() {
  Future<void> open(WidgetTester tester, PlayerProfile profile) async {
    tester.view.physicalSize = const Size(2400, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: LevelSelectPage(profile: profile)),
    );
  }

  testWidgets('shows every level; only reached ones are open', (tester) async {
    final first = Levels.of(1);
    final profile = PlayerProfile(levelBest: {1: first.starDistances[1]});
    await open(tester, profile);

    expect(find.bySemanticsLabel('Level 1, ${first.name}, 2 stars'), findsOne);
    expect(
      find.bySemanticsLabel('Level 2, ${Levels.of(2).name}, 0 stars'),
      findsOne,
    );
    for (var level = 3; level <= Levels.count; level++) {
      expect(
        find.bySemanticsLabel('Level $level, ${Levels.of(level).name}, locked'),
        findsOne,
      );
    }
    // Total stars in the header (outlined text: drawn twice).
    expect(
      find.text('2 / ${Levels.count * Levels.maxStars}'),
      findsNWidgets(2),
    );
    // A locked level says what opens it.
    final second = Levels.of(2);
    expect(
      find.text(
        'Reach ${second.starDistances.first.toStringAsFixed(0)} m '
        'on ${second.name}',
      ),
      findsOneWidget,
    );
  });
}
