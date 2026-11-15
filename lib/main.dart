import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'profile/player_profile.dart';
import 'profile/profile_store.dart';
import 'ui/main_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A downhill racer reads best sideways.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Saved data is loaded before the first page, so the menu shows it at once.
  final store = await ProfileStore.load();
  runApp(ScrapyardDerbyApp(profile: store.profile));
}

/// The app shell: a plain Navigator starting at the main menu.
/// Pages: Menu → Game (later: Run summary, Workshop, Settings).
class ScrapyardDerbyApp extends StatelessWidget {
  const ScrapyardDerbyApp({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrapyard Derby',
      debugShowCheckedModeBanner: false,
      home: MainMenu(profile: profile),
    );
  }
}
