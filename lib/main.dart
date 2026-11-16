import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/sound.dart';
import 'profile/player_profile.dart';
import 'profile/profile_store.dart';
import 'ui/main_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Plays both ways: pages switch layout when the screen is taller than
  // wide (see ui/layout.dart). Upside-down portrait is left out (phones).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Saved data is loaded before the first page, so the menu shows it at once.
  final store = await ProfileStore.load();
  // Sounds load in the background; the menu doesn't wait for them.
  unawaited(Sound.init(store.profile));
  runApp(ScrapyardDerbyApp(profile: store.profile));
}

/// The app shell: a plain Navigator starting at the main menu.
/// Pages: Menu → Game (with pause and run summary), Workshop, Settings.
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
