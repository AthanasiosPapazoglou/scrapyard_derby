import 'package:flutter/material.dart';

import '../config/tuning.dart';
import '../game/derby_game.dart';
import '../game/palette.dart';
import 'debug_overlay.dart';

/// Everything drawn on top of the game: distance, debug info, restart
/// button and the run-over banner.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  static const overlayKey = 'hud';

  final DerbyGame game;

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
                child: FilledButton.icon(
                  onPressed: game.restart,
                  icon: const Icon(Icons.replay),
                  label: const Text('Restart'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.hazard,
                    foregroundColor: Palette.outline,
                  ),
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
                      Text(
                        '${info.distance.toStringAsFixed(0)} m',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Palette.outline,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
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
              if (info.runEnd case final end?)
                Center(
                  child: _RunOverBanner(end: end, info: info, game: game),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Shown when the run is over: why, how far, and the best so far.
class _RunOverBanner extends StatelessWidget {
  const _RunOverBanner({
    required this.end,
    required this.info,
    required this.game,
  });

  final RunEnd end;
  final HudInfo info;
  final DerbyGame game;

  @override
  Widget build(BuildContext context) {
    const ink = Palette.outline;
    final isNewBest = info.distance > 0 && info.distance >= info.bestDistance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      decoration: BoxDecoration(
        color: Palette.hazard,
        border: Border.all(color: ink, width: 4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            end.label,
            style: const TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${info.distance.toStringAsFixed(0)} m',
            style: const TextStyle(
              color: ink,
              fontSize: 44,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            isNewBest
                ? 'NEW BEST!'
                : 'Best: ${info.bestDistance.toStringAsFixed(0)} m',
            style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: game.restart,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Palette.hazard,
            ),
            child: const Text('Go again'),
          ),
        ],
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
        Icon(icon, color: Palette.outline, size: 20),
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
        Icon(Icons.rocket_launch, color: Palette.rust, size: 20),
        SizedBox(width: 4),
        Text(
          'HEAD LAUNCH!',
          style: TextStyle(
            color: Palette.rust,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
