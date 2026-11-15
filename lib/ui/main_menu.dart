import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/dusk_scene.dart';
import '../game/palette.dart';
import '../game/robot_sprites.dart';
import '../profile/player_profile.dart';
import 'derby_button.dart';
import 'game_page.dart';
import 'outlined_text.dart';
import 'robot_figure.dart';
import 'settings_page.dart';
import 'workshop_page.dart';

/// The first screen: the dusk scrapyard drifting by, the robot idling in
/// the air, the title, best distance, scrap, and Play / Workshop / Settings.
class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.profile});

  final PlayerProfile profile;

  /// How fast the background heaps drift past (camera meters per second).
  static const double driftSpeed = 6;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Seconds since the menu opened; drives the drift and the idle robot.
  final ValueNotifier<double> _time = ValueNotifier(0);

  late final Future<RobotSprites> _sprites = RobotSprites.load();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
    )..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _openWorkshop() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkshopPage(profile: widget.profile),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(profile: widget.profile),
      ),
    );
  }

  void _play() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.skyTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _DriftingScene(_time)),
          SafeArea(
            child: Row(
              children: [
                // Left: the robot idling in the air.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FutureBuilder<RobotSprites>(
                      future: _sprites,
                      builder: (context, snapshot) {
                        final sprites = snapshot.data;
                        if (sprites == null) {
                          return const SizedBox.shrink();
                        }
                        return ValueListenableBuilder<double>(
                          valueListenable: _time,
                          builder: (context, t, _) =>
                              IdleRobot(sprites: sprites, time: t),
                        );
                      },
                    ),
                  ),
                ),
                // Right: title, numbers and buttons.
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _MenuPanel(
                          profile: widget.profile,
                          onPlay: _play,
                          onSettings: _openSettings,
                          onWorkshop: _openWorkshop,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Title, best distance, scrap and the buttons.
class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.profile,
    required this.onPlay,
    required this.onSettings,
    required this.onWorkshop,
  });

  final PlayerProfile profile;
  final VoidCallback onPlay;
  final VoidCallback onSettings;
  final VoidCallback onWorkshop;

  @override
  Widget build(BuildContext context) {
    // Rebuilds when a run sets a new best or earns scrap.
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OutlinedText('SCRAPYARD', fontSize: 52, color: Palette.hazard),
          const OutlinedText('DERBY', fontSize: 52, color: Palette.rustLight),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stat(
                icon: Icons.flag,
                text: 'Best ${profile.bestDistance.toStringAsFixed(0)} m',
              ),
              const SizedBox(width: 20),
              _Stat(icon: Icons.settings, text: '${profile.scrap} Scrap'),
            ],
          ),
          const SizedBox(height: 20),
          DerbyButton(
            label: 'PLAY',
            icon: Icons.play_arrow,
            primary: true,
            big: true,
            onPressed: onPlay,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DerbyButton(
                label: 'Workshop',
                icon: Icons.build,
                onPressed: onWorkshop,
              ),
              const SizedBox(width: 12),
              DerbyButton(
                label: 'Settings',
                icon: Icons.tune,
                onPressed: onSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Palette.cream, size: 20),
        const SizedBox(width: 6),
        OutlinedText(text, fontSize: 20, color: Palette.cream),
      ],
    );
  }
}

/// The game's dusk sky and heaps, drifting slowly sideways.
class _DriftingScene extends CustomPainter {
  _DriftingScene(this.time) : super(repaint: time);

  final ValueNotifier<double> time;
  final DuskScene _scene = DuskScene();

  @override
  void paint(Canvas canvas, Size size) {
    _scene.paint(canvas, size, cameraX: time.value * MainMenu.driftSpeed);
  }

  @override
  bool shouldRepaint(_DriftingScene old) => false;
}
