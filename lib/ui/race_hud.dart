import 'package:flutter/material.dart';

import '../config/tuning.dart';
import '../game/derby_game.dart';
import '../game/palette.dart';
import '../game/races.dart';
import 'outlined_text.dart';

/// The Versus parts of the HUD (D49, D50): standings, edge markers for
/// rivals out of view, the place callout and the fast-forward banner.
/// Fills the HUD's stack; lets every tap through to the game.
class RaceHud extends StatelessWidget {
  const RaceHud({super.key, required this.info, required this.portrait});

  final HudInfo info;
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            // Under the run card they'd only peek out at its edges.
            if (info.result == null) ..._markers(box.maxHeight),
            Positioned(
              right: 12,
              // Portrait: bottom right, beside the status panel (up top it
              // covers the rivals' name tags above the robots); landscape:
              // under the buttons.
              top: portrait ? null : 70,
              bottom: portrait ? 12 : null,
              // Fades in at the player's first touchdown.
              child: AnimatedOpacity(
                opacity: info.standings.isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                child: info.standings.isEmpty
                    ? const SizedBox.shrink()
                    : StandingsPanel(standings: info.standings),
              ),
            ),
            if (info.raceHint && info.result == null)
              Positioned(
                left: 16,
                right: 16,
                bottom: box.maxHeight * (portrait ? 0.3 : 0.2),
                child: const Center(child: RaceHintCard()),
              ),
            if (info.callout case final callout? when info.result == null)
              Positioned(
                left: 0,
                right: 0,
                top: box.maxHeight * 0.3,
                child: Center(child: _PlaceCalloutText(callout: callout)),
              ),
            if (info.fastForward > 1 && info.result == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: box.maxHeight * 0.22,
                child: Center(child: _FinishingBanner(speed: info.fastForward)),
              ),
          ],
        ),
      ),
    );
  }

  /// Edge markers, nudged apart when two sit on the same edge.
  List<Widget> _markers(double height) {
    const minGap = 30.0;
    final widgets = <Widget>[];
    for (final right in [false, true]) {
      final side = [
        for (final m in info.markers)
          if (m.onRight == right) m,
      ]..sort((a, b) => a.height.compareTo(b.height));
      var lastTop = double.negativeInfinity;
      for (final marker in side) {
        final top = (marker.height * height).clamp(
          lastTop + minGap,
          double.infinity,
        );
        lastTop = top;
        widgets.add(
          Positioned(
            top: top - minGap / 2,
            left: right ? null : 4,
            right: right ? 4 : null,
            child: _EdgeMarker(marker: marker),
          ),
        );
      }
    }
    return widgets;
  }
}

/// The first race's one-line hint (D53).
class RaceHintCard extends StatelessWidget {
  const RaceHintCard({super.key});

  static const text =
      'Beat 3 rivals down the hill: when everyone is down, the furthest '
      'wins. Win to unlock the next race!';

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.outline.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.hazard, width: 2),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: Palette.hazard, size: 26),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: Palette.cream,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The live race order: place, colour dot, name, distance; a flag once
/// that racer has finished. The player's row stands out.
class StandingsPanel extends StatelessWidget {
  const StandingsPanel({super.key, required this.standings});

  final List<Standing> standings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 204,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Palette.outline.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.hazardShadow, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < standings.length; i++)
            _StandingRow(place: i + 1, standing: standings[i]),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.place, required this.standing});

  final int place;
  final Standing standing;

  @override
  Widget build(BuildContext context) {
    final color = standing.isPlayer ? Palette.hazard : Palette.cream;
    final style = TextStyle(
      color: color,
      fontSize: 13,
      fontWeight: standing.isPlayer ? FontWeight.w900 : FontWeight.w700,
      height: 1.5,
    );
    return Row(
      children: [
        SizedBox(width: 16, child: Text('$place', style: style)),
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: standing.color,
            shape: BoxShape.circle,
            border: Border.all(color: Palette.cream, width: 1),
          ),
        ),
        Expanded(
          child: Text(
            standing.name.toUpperCase(),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text('${standing.distance.toStringAsFixed(0)} m', style: style),
        SizedBox(
          width: 16,
          child: standing.finished
              ? Icon(Icons.flag, size: 13, color: color)
              : null,
        ),
      ],
    );
  }
}

/// A rival out of view: an arrow toward it, its colour and how far it is
/// ahead of (or behind) the player.
class _EdgeMarker extends StatelessWidget {
  const _EdgeMarker({required this.marker});

  final RivalMarker marker;

  @override
  Widget build(BuildContext context) {
    final arrow = Icon(
      marker.onRight ? Icons.arrow_right : Icons.arrow_left,
      color: marker.color,
      size: 22,
    );
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Palette.outline.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: marker.color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!marker.onRight) arrow,
          Text(
            marker.gapLabel,
            style: const TextStyle(
              color: Palette.cream,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (marker.onRight) arrow,
        ],
      ),
    );
  }
}

/// "2ND!" popping up when the player's place changes.
class _PlaceCalloutText extends StatelessWidget {
  const _PlaceCalloutText({required this.callout});

  final PlaceCallout callout;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // A new key per callout replays the pop.
      key: ValueKey(callout.serial),
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: OutlinedText(
        '${Races.placeLabel(callout.place).toUpperCase()}!',
        fontSize: 46,
        color: callout.improved ? Palette.hazard : Palette.danger,
      ),
    );
  }
}

/// Shown while the race fast-forwards after the player finished.
class _FinishingBanner extends StatelessWidget {
  const _FinishingBanner({required this.speed});

  final int speed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.outline.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.hazard, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fast_forward, color: Palette.hazard, size: 22),
              const SizedBox(width: 6),
              Text(
                'FINISHING…  ×$speed',
                style: const TextStyle(
                  color: Palette.hazard,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          if (speed < Tuning.raceFastForwardSkip)
            const Text(
              'tap to skip',
              style: TextStyle(
                color: Palette.cream,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
