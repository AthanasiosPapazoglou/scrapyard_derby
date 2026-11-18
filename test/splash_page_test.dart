import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/main.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';
import 'package:scrapyard_derby/ui/main_menu.dart';
import 'package:thanos_productions/thanos_productions.dart';

void main() {
  Future<void> frames(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the app opens on the creator splash, then the menu', (
    tester,
  ) async {
    await tester.pumpWidget(ScrapyardDerbyApp(profile: PlayerProfile()));
    expect(find.byType(ThanosSplash), findsOneWidget);
    expect(find.byType(MainMenu), findsNothing);
    await frames(tester, 1500);
    expect(find.byType(ThanosSplash), findsOneWidget);
    // Splash (2.6 s) plus the cross-fade.
    await frames(tester, 1600);
    expect(find.byType(ThanosSplash), findsNothing);
    expect(find.byType(MainMenu), findsOneWidget);
  });

  testWidgets('a tap skips the splash', (tester) async {
    await tester.pumpWidget(ScrapyardDerbyApp(profile: PlayerProfile()));
    await frames(tester, 400);
    await tester.tap(find.byType(ThanosSplash));
    await frames(tester, 700);
    expect(find.byType(ThanosSplash), findsNothing);
    expect(find.byType(MainMenu), findsOneWidget);
  });
}
