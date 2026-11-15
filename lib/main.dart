import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/derby_game.dart';
import 'ui/hud.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A downhill racer reads best sideways.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ScrapyardDerbyApp());
}

class ScrapyardDerbyApp extends StatefulWidget {
  const ScrapyardDerbyApp({super.key});

  @override
  State<ScrapyardDerbyApp> createState() => _ScrapyardDerbyAppState();
}

class _ScrapyardDerbyAppState extends State<ScrapyardDerbyApp> {
  // Created once, so hot reload doesn't restart the run.
  final DerbyGame _game = DerbyGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrapyard Derby',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<DerbyGame>(
          game: _game,
          overlayBuilderMap: {
            Hud.overlayKey: (context, game) => Hud(game: game),
          },
          initialActiveOverlays: const [Hud.overlayKey],
        ),
      ),
    );
  }
}
