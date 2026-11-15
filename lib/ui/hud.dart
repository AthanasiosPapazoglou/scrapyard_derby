import 'package:flutter/material.dart';

import '../config/tuning.dart';
import '../game/derby_game.dart';
import '../game/palette.dart';
import 'debug_overlay.dart';
import 'outlined_text.dart';
import 'run_summary.dart';
import 'status_panel.dart';

/// Everything drawn on top of the game: distance, energy, status panel,
/// debug info, pause and restart buttons, and the run summary.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game, this.onMenu, this.onPause});

  static const overlayKey = 'hud';

  final DerbyGame game;

  /// Leaves the run for the main menu (hidden when null).
  final VoidCallback? onMenu;

  /// Pauses the run (button hidden when null or once the run is over).
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<HudInfo>(
        valueListenable: game.hud,
        builder: (context, info, _) {
          return Stack(
            children: [
              Positioned(
                left: 12,
                top: 12,
                // IgnorePointer: taps on the panel still reach the game.
                child: IgnorePointer(child: DebugOverlay(info: info)),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Row(
                  children: [
                    if (onPause != null && info.result == null) ...[
                      IconButton.filled(
                        onPressed: onPause,
                        tooltip: 'Pause',
                        icon: const Icon(Icons.pause),
                        style: IconButton.styleFrom(
                          backgroundColor: Palette.outline,
                          foregroundColor: Palette.hazard,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton.icon(
                      onPressed: game.restart,
                      icon: const Icon(Icons.replay),
                      label: const Text('Restart'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.hazard,
                        foregroundColor: Palette.outline,
                      ),
                    ),
                  ],
                ),
              ),
              // The score: distance covered, big and centered at the top.
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Column(
                    children: [
                      OutlinedText(
                        '${info.distance.toStringAsFixed(0)} m',
                        fontSize: 36,
                        color: Palette.cream,
                      ),
                      // Energy bar while the robot is whole; a rocket label
                      // once the head has been launched.
                      if (info.headLaunched)
                        const _HeadLaunchLabel()
                      else
                        _MeterBar(
                          icon: Icons.bolt,
                          fraction: info.spinEnergy / Tuning.spinEnergyMaxTurns,
                          color: Palette.hazard,
                          fullColor: Palette.eyeGlow,
                        ),
                    ],
                  ),
                ),
              ),
              // Robot status screen, bottom left.
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(child: StatusPanel(partHp: info.partHp)),
              ),
              if (info.result case final result?)
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: RunSummary(
                        result: result,
                        bestDistance: info.bestDistance,
                        totalScrap: game.profile.scrap,
                        onPlayAgain: game.restart,
                        onMenu: onMenu,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A small horizontal meter under the distance (the spin energy bar).
class _MeterBar extends StatelessWidget {
  const _MeterBar({
    required this.icon,
    required this.fraction,
    required this.color,
    required this.fullColor,
  });

  final IconData icon;

  /// 0 = empty, 1 = full.
  final double fraction;
  final Color color;

  /// Colour when the meter is full.
  final Color fullColor;

  @override
  Widget build(BuildContext context) {
    final value = fraction.clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Palette.cream, size: 20),
        Container(
          width: 160,
          height: 14,
          decoration: BoxDecoration(
            color: Palette.steelLight,
            border: Border.all(color: Palette.outline, width: 2.5),
            borderRadius: BorderRadius.circular(7),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: ColoredBox(color: value >= 0.999 ? fullColor : color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown under the distance while the launched head is in flight.
class _HeadLaunchLabel extends StatelessWidget {
  const _HeadLaunchLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.rocket_launch, color: Palette.hazard, size: 20),
        SizedBox(width: 4),
        OutlinedText('HEAD LAUNCH!', fontSize: 16, color: Palette.hazard),
      ],
    );
  }
}
