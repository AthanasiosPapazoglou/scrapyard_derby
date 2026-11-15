import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/derby_game.dart';
import '../profile/player_profile.dart';
import 'hud.dart';

/// One play session: a fresh [DerbyGame] with the HUD on top. Opened from
/// the menu with Play; "Go again" restarts inside the same game.
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  // Created once per page, so hot reload doesn't restart the run.
  late final DerbyGame _game = DerbyGame(profile: widget.profile);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<DerbyGame>(
        game: _game,
        overlayBuilderMap: {
          Hud.overlayKey: (context, game) =>
              Hud(game: game, onMenu: () => Navigator.of(context).pop()),
        },
        initialActiveOverlays: const [Hud.overlayKey],
      ),
    );
  }
}
