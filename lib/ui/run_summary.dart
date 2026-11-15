import 'package:flutter/material.dart';

import '../game/derby_game.dart';
import '../game/landing.dart';
import '../game/levels.dart';
import '../game/palette.dart';
import 'derby_button.dart';

/// Shown over the wreck when a run is over: why it ended, the distance,
/// best / NEW BEST, the run's stats, and the scrap it earned.
class RunSummary extends StatelessWidget {
  const RunSummary({
    super.key,
    required this.result,
    required this.bestDistance,
    required this.totalScrap,
    required this.onPlayAgain,
    this.onMenu,
    this.onWorkshop,
    this.onNextLevel,
  });

  final RunResult result;
  final double bestDistance;

  /// The player's scrap after this run's reward was added.
  final int totalScrap;

  final VoidCallback onPlayAgain;

  /// Hidden when null.
  final VoidCallback? onMenu;

  /// Greyed out ("soon") when null.
  final VoidCallback? onWorkshop;

  /// Plays the next level; hidden when null (last level, or still locked).
  final VoidCallback? onNextLevel;

  static const _ink = Palette.outline;

  @override
  Widget build(BuildContext context) {
    final stats = result.stats;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
      decoration: BoxDecoration(
        color: Palette.hazard,
        border: Border.all(color: _ink, width: 4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: _ink,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: the score.
                  Column(
                    children: [
                      Text(
                        'LEVEL ${result.level} · '
                        '${Levels.of(result.level).name.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        result.end.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${result.distance.toStringAsFixed(0)} m',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      _SummaryStars(
                        before: result.starsBefore,
                        after: result.starsAfter,
                      ),
                      const SizedBox(height: 4),
                      if (result.unlockedLevel case final unlocked?)
                        _Badge('LEVEL $unlocked UNLOCKED!')
                      else if (result.isNewBest)
                        const _Badge('NEW BEST!')
                      else
                        Text('Best: ${bestDistance.toStringAsFixed(0)} m'),
                      if (result.unlockedLevel != null && result.isNewBest)
                        Text('New best: ${bestDistance.toStringAsFixed(0)} m'),
                    ],
                  ),
                  const _Divider(),
                  // Middle: what happened.
                  _Lines(
                    title: 'RUN',
                    rows: [
                      (
                        'Clean landings',
                        '${stats.landingsOf(LandingType.clean)}',
                      ),
                      ('One-foot', '${stats.landingsOf(LandingType.oneFoot)}'),
                      ('Crashes', '${stats.landingsOf(LandingType.crash)}'),
                      (
                        'Highest jump',
                        '${stats.highestJump.toStringAsFixed(1)} m',
                      ),
                      ('Limbs lost', '${stats.limbsLost}/4'),
                      if (stats.headFlight case final flight?)
                        ('Head flight', '${flight.toStringAsFixed(0)} m'),
                    ],
                  ),
                  const _Divider(),
                  // Right: scrap earned.
                  _Lines(
                    title: 'SCRAP',
                    rows: [
                      for (final line in result.scrap)
                        (line.label, '+${line.amount}'),
                    ],
                    footer: ('Total', '+${result.scrapEarned}'),
                    note: 'You have $totalScrap',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMenu != null) ...[
                  DerbyButton(
                    label: 'Levels',
                    icon: Icons.map,
                    onPressed: onMenu,
                  ),
                  const SizedBox(width: 10),
                ],
                DerbyButton(
                  label: 'Workshop',
                  icon: Icons.build,
                  onPressed: onWorkshop,
                  disabledNote: 'SOON',
                ),
                const SizedBox(width: 10),
                DerbyButton(
                  label: 'Play again',
                  icon: Icons.replay,
                  primary: onNextLevel == null,
                  onPressed: onPlayAgain,
                ),
                if (onNextLevel != null) ...[
                  const SizedBox(width: 10),
                  DerbyButton(
                    label: 'Next level',
                    icon: Icons.arrow_forward,
                    primary: true,
                    onPressed: onNextLevel,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled list of "label ... value" rows.
class _Lines extends StatelessWidget {
  const _Lines({
    required this.title,
    required this.rows,
    this.footer,
    this.note,
  });

  final String title;
  final List<(String, String)> rows;
  final (String, String)? footer;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          for (final (label, value) in rows) _row(label, value),
          if (footer case (final label, final value)) ...[
            const Divider(color: RunSummary._ink, thickness: 2, height: 8),
            _row(label, value, bold: true),
          ],
          if (note != null) Text(note!, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: Palette.hazardShadow,
    );
  }
}

/// The level's stars after this run; the ones earned by this run glow.
class _SummaryStars extends StatelessWidget {
  const _SummaryStars({required this.before, required this.after});

  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$after of ${Levels.maxStars} stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < Levels.maxStars; i++)
            Icon(
              i < after ? Icons.star : Icons.star_border,
              size: 30,
              color: i < before
                  ? RunSummary._ink
                  : (i < after ? Palette.cream : Palette.hazardShadow),
              shadows: i >= before && i < after
                  ? const [Shadow(color: RunSummary._ink, blurRadius: 4)]
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Palette.outline,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Palette.eyeGlow,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
