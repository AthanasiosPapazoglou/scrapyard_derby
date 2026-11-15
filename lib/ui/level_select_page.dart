import 'package:flutter/material.dart';

import '../game/dusk_scene.dart';
import '../game/levels.dart';
import '../game/palette.dart';
import '../game/sound.dart';
import '../profile/player_profile.dart';
import 'game_page.dart';
import 'outlined_text.dart';

/// Opened with Play: the six levels as cards, with stars, best distance and
/// star distances. Locked levels say what opens them.
class LevelSelectPage extends StatelessWidget {
  const LevelSelectPage({super.key, required this.profile});

  final PlayerProfile profile;

  void _play(BuildContext context, int level) {
    Sound.play(Sfx.uiClick);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(profile: profile, level: level),
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
          CustomPaint(painter: _StillScene()),
          SafeArea(
            // Rebuilds when a run (from this page) earns stars or unlocks.
            child: ListenableBuilder(
              listenable: profile,
              builder: (context, _) => Column(
                children: [
                  _Header(
                    stars: profile.totalStars,
                    scrap: profile.scrap,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          for (var row = 0; row < 2; row++)
                            Expanded(
                              child: Row(
                                children: [
                                  for (var col = 1; col <= 3; col++)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: _LevelCard(
                                          level: row * 3 + col,
                                          profile: profile,
                                          onPlay: (level) =>
                                              _play(context, level),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
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

class _Header extends StatelessWidget {
  const _Header({
    required this.stars,
    required this.scrap,
    required this.onBack,
  });

  final int stars;
  final int scrap;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Palette.cream, size: 28),
          ),
          const OutlinedText('LEVELS', fontSize: 28, color: Palette.hazard),
          const Spacer(),
          const Icon(Icons.star, color: Palette.hazard, size: 24),
          const SizedBox(width: 4),
          OutlinedText(
            '$stars / ${Levels.count * Levels.maxStars}',
            fontSize: 22,
            color: Palette.cream,
          ),
          const SizedBox(width: 20),
          const Icon(Icons.settings, color: Palette.hazard, size: 22),
          const SizedBox(width: 6),
          OutlinedText('$scrap Scrap', fontSize: 22, color: Palette.cream),
        ],
      ),
    );
  }
}

/// One level: number, name, stars, best, star distances, or a lock.
/// The furthest unlocked level is highlighted in hazard yellow.
class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.profile,
    required this.onPlay,
  });

  final int level;
  final PlayerProfile profile;
  final void Function(int level) onPlay;

  static const _ink = Palette.outline;

  @override
  Widget build(BuildContext context) {
    final tuning = Levels.of(level);
    final unlocked = profile.isUnlocked(level);
    final stars = profile.starsOn(level);
    final best = profile.bestOn(level);
    final current = level == profile.highestUnlockedLevel;
    final fill = !unlocked
        ? Palette.steel
        : (current ? Palette.hazard : Palette.cream);
    final distances = tuning.starDistances
        .map((d) => d.toStringAsFixed(0))
        .join(' · ');

    final String detail;
    if (!unlocked) {
      final previous = Levels.of(level - 1);
      detail =
          'Reach ${previous.starDistances.first.toStringAsFixed(0)} m '
          'on ${previous.name}';
    } else {
      detail = best > 0 ? 'Best ${best.toStringAsFixed(0)} m' : 'Not played';
    }

    return Semantics(
      button: unlocked,
      label:
          'Level $level, ${tuning.name}, '
          '${unlocked ? '$stars stars' : 'locked'}',
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _ink, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unlocked ? () => onPlay(level) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DefaultTextStyle(
                style: TextStyle(
                  color: unlocked ? _ink : Palette.steelLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$level',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tuning.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        if (!unlocked) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.lock,
                            size: 18,
                            color: Palette.steelLight,
                          ),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < Levels.maxStars; i++)
                          Icon(
                            i < stars ? Icons.star : Icons.star_border,
                            size: 26,
                            color: unlocked ? _ink : Palette.steelLight,
                          ),
                      ],
                    ),
                    Text(detail),
                    Text(
                      '★ $distances m',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dusk sky and heaps, standing still.
class _StillScene extends CustomPainter {
  final DuskScene _scene = DuskScene();

  @override
  void paint(Canvas canvas, Size size) =>
      _scene.paint(canvas, size, cameraX: 0);

  @override
  bool shouldRepaint(_StillScene old) => false;
}
