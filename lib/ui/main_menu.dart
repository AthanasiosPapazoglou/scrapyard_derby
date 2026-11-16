import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/dusk_scene.dart';
import '../game/palette.dart';
import '../game/robot_sprites.dart';
import '../profile/player_profile.dart';
import 'derby_route.dart';
import 'layout.dart';
import 'derby_button.dart';
import 'level_select_page.dart';
import 'outlined_text.dart';
import 'robot_figure.dart';
import 'robot_stats_page.dart';
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
      DerbyRoute<void>(builder: (_) => WorkshopPage(profile: widget.profile)),
    );
  }

  void _openStats() {
    Navigator.of(context).push(
      DerbyRoute<void>(builder: (_) => RobotStatsPage(profile: widget.profile)),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      DerbyRoute<void>(builder: (_) => SettingsPage(profile: widget.profile)),
    );
  }

  void _play() {
    Navigator.of(context).push(
      DerbyRoute<void>(
        builder: (_) => LevelSelectPage(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The robot idling in the air, in its installed parts.
    final robot = FutureBuilder<RobotSprites>(
      future: _sprites,
      builder: (context, snapshot) {
        final sprites = snapshot.data;
        if (sprites == null) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<double>(
          valueListenable: _time,
          builder: (context, t, _) =>
              IdleRobot(look: sprites.look(widget.profile.tierOf), time: t),
        );
      },
    );
    final actions = _MenuActions(
      profile: widget.profile,
      onPlay: _play,
      onSettings: _openSettings,
      onWorkshop: _openWorkshop,
      onStats: _openStats,
    );
    return Scaffold(
      backgroundColor: Palette.skyTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The happy baseline: level 1's dusk, whatever level is reached.
          CustomPaint(painter: _DriftingScene(_time, LevelTheme.of(1))),
          SafeArea(
            child: OrientationSwitch(
              // Portrait: title on top, the robot in the middle, numbers
              // and buttons at the bottom.
              portrait: (context) => Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: FittedBox(fit: BoxFit.scaleDown, child: _Title()),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      child: robot,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: FittedBox(fit: BoxFit.scaleDown, child: actions),
                  ),
                ],
              ),
              // Landscape: the robot on the left, everything else right.
              landscape: (context) => Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: robot,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _Title(),
                              const SizedBox(height: 10),
                              actions,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The game's name. (A proper logo comes in roadmap step V11.)
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedText('SCRAPYARD', fontSize: 52, color: Palette.hazard),
        OutlinedText('DERBY', fontSize: 52, color: Palette.rustLight),
      ],
    );
  }
}

/// Level, stars, scrap and the buttons.
class _MenuActions extends StatelessWidget {
  const _MenuActions({
    required this.profile,
    required this.onPlay,
    required this.onSettings,
    required this.onWorkshop,
    required this.onStats,
  });

  final PlayerProfile profile;
  final VoidCallback onPlay;
  final VoidCallback onSettings;
  final VoidCallback onWorkshop;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    // Rebuilds when a run sets a new best or earns scrap.
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stat(
                icon: Icons.flag,
                text: 'Level ${profile.highestUnlockedLevel}',
              ),
              const SizedBox(width: 20),
              _Stat(icon: Icons.star, text: '${profile.totalStars} Stars'),
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
                label: 'Stats',
                icon: Icons.bar_chart,
                onPressed: onStats,
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

/// A level's sky, heaps and weather, drifting slowly sideways.
class _DriftingScene extends CustomPainter {
  _DriftingScene(this.time, this.theme)
    : _scene = DuskScene(theme),
      super(repaint: time);

  final ValueNotifier<double> time;
  final LevelTheme theme;
  final DuskScene _scene;

  @override
  void paint(Canvas canvas, Size size) {
    _scene.paint(
      canvas,
      size,
      cameraX: time.value * MainMenu.driftSpeed,
      time: time.value,
    );
  }

  @override
  bool shouldRepaint(_DriftingScene old) => old.theme != theme;
}
