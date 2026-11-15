import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/derby_game.dart';
import '../game/palette.dart';
import '../profile/player_profile.dart';
import 'derby_button.dart';
import 'hud.dart';
import 'outlined_text.dart';

/// One play session: a fresh [DerbyGame] with the HUD on top. Opened from
/// the menu with Play; "Play again" restarts inside the same game.
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const _pauseKey = 'pause';

  // Created once per page, so hot reload doesn't restart the run.
  late final DerbyGame _game = DerbyGame(profile: widget.profile);

  void _pause() {
    _game.pauseEngine();
    _game.overlays.add(_pauseKey);
  }

  void _resume() {
    _game.overlays.remove(_pauseKey);
    _game.resumeEngine();
  }

  void _toMenu() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<DerbyGame>(
        game: _game,
        overlayBuilderMap: {
          Hud.overlayKey: (context, game) =>
              Hud(game: game, onMenu: _toMenu, onPause: _pause),
          _pauseKey: (context, game) =>
              _PauseMenu(onResume: _resume, onMenu: _toMenu),
        },
        initialActiveOverlays: const [Hud.overlayKey],
      ),
    );
  }
}

/// Dims the frozen game and offers Resume or Menu. Leaving mid-run earns
/// nothing; only finished runs count.
class _PauseMenu extends StatelessWidget {
  const _PauseMenu({required this.onResume, required this.onMenu});

  final VoidCallback onResume;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.outline.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OutlinedText('PAUSED', fontSize: 44, color: Palette.cream),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DerbyButton(label: 'Menu', icon: Icons.home, onPressed: onMenu),
                const SizedBox(width: 12),
                DerbyButton(
                  label: 'Resume',
                  icon: Icons.play_arrow,
                  primary: true,
                  onPressed: onResume,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
