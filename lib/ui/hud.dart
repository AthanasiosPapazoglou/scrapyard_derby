import 'package:flutter/material.dart';

import '../game/derby_game.dart';
import '../game/landing.dart';
import '../game/levels.dart';
import '../game/palette.dart';
import '../game/sound.dart';
import 'debug_overlay.dart';
import 'layout.dart';
import 'outlined_text.dart';
import 'run_summary.dart';
import 'status_panel.dart';

/// Everything drawn on top of the game: distance, energy, status panel,
/// debug info, pause and restart buttons, and the run summary.
class Hud extends StatelessWidget {
  const Hud({
    super.key,
    required this.game,
    this.onMenu,
    this.onPause,
    this.onWorkshop,
    this.onNextLevel,
  });

  static const overlayKey = 'hud';

  final DerbyGame game;

  /// Leaves the run for the main menu (hidden when null).
  final VoidCallback? onMenu;

  /// Opens the Workshop from the run summary (greyed out when null).
  final VoidCallback? onWorkshop;

  /// Pauses the run (button hidden when null or once the run is over).
  final VoidCallback? onPause;

  /// Starts the next level from the run summary (shown only when that
  /// level is unlocked).
  final VoidCallback? onNextLevel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<HudInfo>(
        valueListenable: game.hud,
        builder: (context, info, _) {
          // Portrait: the buttons get their own row at the top and the
          // distance counter sits under them, so they never overlap.
          final portrait = context.isPortrait;
          return Stack(
            children: [
              Positioned(
                left: 12,
                top: portrait ? 150 : 12,
                // IgnorePointer: taps on the panel still reach the game.
                child: IgnorePointer(
                  // Developer numbers, only with Settings > Show debug info.
                  child: ListenableBuilder(
                    listenable: game.profile,
                    builder: (context, _) => game.profile.showDebugInfo
                        ? DebugOverlay(info: info)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Row(
                  children: [
                    if (onPause != null && info.result == null) ...[
                      IconButton.filled(
                        onPressed: () {
                          Sound.play(Sfx.uiClick);
                          onPause!();
                        },
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
                      onPressed: () {
                        Sound.play(Sfx.uiClick);
                        game.restart();
                      },
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
                top: portrait ? 64 : 8,
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
                        _EnergyBar(
                          energy: info.spinEnergy,
                          max: info.spinEnergyMax,
                        ),
                      const SizedBox(height: 4),
                      _StarProgress(
                        targets: Levels.of(game.level).starDistances,
                        passed: info.starsPassed,
                      ),
                    ],
                  ),
                ),
              ),
              // Robot status screen, bottom left.
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  // Smaller on a narrow portrait screen.
                  child: Transform.scale(
                    scale: portrait ? 0.8 : 1,
                    alignment: Alignment.bottomLeft,
                    child: StatusPanel(partHp: info.partHp),
                  ),
                ),
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
                        onWorkshop: onWorkshop,
                        onNextLevel:
                            game.level < Levels.count &&
                                game.profile.isUnlocked(game.level + 1)
                            ? onNextLevel
                            : null,
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

/// The spin energy bar under the distance: one segment per turn of spin
/// (the last one shorter when the tank holds a part turn), filling as the
/// robot spins in the air. Full = every segment glows cyan.
class _EnergyBar extends StatelessWidget {
  const _EnergyBar({required this.energy, required this.max});

  /// Gathered energy and tank size, in turns.
  final double energy;
  final double max;

  static const double _width = 180;
  static const double _height = 16;

  @override
  Widget build(BuildContext context) {
    final full = isFullCharge(energy, max: max);
    return Semantics(
      label: 'Spin energy ${(energy / max * 100).round()}%',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt,
            color: full ? Palette.eyeGlow : Palette.cream,
            size: 22,
            shadows: const [Shadow(color: Palette.outline, blurRadius: 3)],
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_height / 2),
              boxShadow: full
                  ? [
                      BoxShadow(
                        color: Palette.eyeGlow.withValues(alpha: 0.7),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: CustomPaint(
              size: const Size(_width, _height),
              painter: _EnergyPainter(energy: energy, max: max, full: full),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyPainter extends CustomPainter {
  _EnergyPainter({required this.energy, required this.max, required this.full});

  final double energy;
  final double max;
  final bool full;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final turns = max.ceil();
    final usable = size.width - gap * (turns - 1);
    final fill = Paint()..color = full ? Palette.eyeGlow : Palette.hazard;
    final empty = Paint()..color = Palette.steelLight;
    final ink = Paint()
      ..color = Palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    var left = 0.0;
    for (var i = 0; i < turns; i++) {
      // This segment holds turns i .. i+share (the last may be partial).
      final share = (max - i).clamp(0.0, 1.0);
      final width = usable * share / max;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, size.height),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, empty);
      final filled = ((energy - i) / share).clamp(0.0, 1.0);
      if (filled > 0) {
        canvas
          ..save()
          ..clipRRect(rect)
          ..drawRect(Rect.fromLTWH(left, 0, width * filled, size.height), fill)
          ..restore();
      }
      canvas.drawRRect(rect, ink);
      left += width + gap;
    }
  }

  @override
  bool shouldRepaint(_EnergyPainter old) =>
      old.energy != energy || old.max != max || old.full != full;
}

/// The level's three stars under the energy bar: filled once passed this
/// run, with the next star distance to aim for.
class _StarProgress extends StatelessWidget {
  const _StarProgress({required this.targets, required this.passed});

  final List<double> targets;
  final int passed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < targets.length; i++)
          Icon(
            i < passed ? Icons.star : Icons.star_border,
            color: i < passed ? Palette.hazard : Palette.cream,
            size: 20,
            shadows: const [Shadow(color: Palette.outline, blurRadius: 3)],
          ),
        const SizedBox(width: 6),
        OutlinedText(
          passed < targets.length
              ? 'next ${targets[passed].toStringAsFixed(0)} m'
              : 'ALL STARS!',
          fontSize: 15,
          color: Palette.cream,
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
