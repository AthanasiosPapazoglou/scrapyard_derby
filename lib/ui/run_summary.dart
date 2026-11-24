import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/derby_game.dart';
import '../game/landing.dart';
import '../game/levels.dart';
import '../game/races.dart';
import '../game/palette.dart';
import '../game/robot_sprites.dart';
import 'derby_button.dart';
import 'layout.dart';
import 'outlined_text.dart';
import 'scrap_plate.dart';

/// Shown over the wreck when a run is over: a "derby ticket" on a riveted
/// steel plate. A hazard-striped header (level, why it ended, the robot's
/// head), the distance, stars that slam in one by one, a NEW BEST / LEVEL
/// UNLOCKED stamp, a track strip (star flags, best, the head's flight),
/// the landing tally and the scrap earned (counting up).
///
/// After a Versus race the score and track make way for the podium: the
/// final order with the player's place, and a RACE UNLOCKED / FIRST WIN
/// stamp. Buttons: Ladder, Retry and Next race (no Workshop: upgrades
/// don't apply to races).
class RunSummary extends StatefulWidget {
  const RunSummary({
    super.key,
    required this.result,
    required this.bestDistance,
    required this.totalScrap,
    required this.onPlayAgain,
    this.onMenu,
    this.onWorkshop,
    this.onNextLevel,
    this.head,
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

  /// Plays the next level (Versus: the next race); hidden when null (the
  /// last one, or still locked).
  final VoidCallback? onNextLevel;

  /// The robot's head art for the header porthole (none while loading).
  final PartSprite? head;

  /// How long the card takes to fill in (stars, stamp, scrap count).
  static const Duration revealTime = Duration(milliseconds: 1800);

  @override
  State<RunSummary> createState() => _RunSummaryState();
}

class _RunSummaryState extends State<RunSummary>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: RunSummary.revealTime,
  )..forward();

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  /// 0 → 1 over the part of the reveal between [start] and [end] (0-1).
  Animation<double> _phase(
    double start,
    double end, [
    Curve curve = Curves.easeOut,
  ]) => CurvedAnimation(
    parent: _reveal,
    curve: Interval(start, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final portrait = context.isPortrait;
    final versus = result.race != null;
    final score = versus
        ? _Podium(
            result: result,
            rowPhase: (i) => _phase(0.1 + i * 0.12, 0.35 + i * 0.12),
            stampPhase: _phase(0.7, 0.9, Curves.easeOutBack),
          )
        : _Score(
            result: result,
            bestDistance: widget.bestDistance,
            starPhase: (i) =>
                _phase(0.2 + i * 0.16, 0.45 + i * 0.16, Curves.elasticOut),
            stampPhase: _phase(0.7, 0.9, Curves.easeOutBack),
          );
    final track = _TrackStrip(
      result: result,
      best: widget.bestDistance,
      progress: _phase(0, 0.5),
    );
    final tally = _Tally(result: result);
    final scrap = _ScrapBox(
      result: result,
      totalScrap: widget.totalScrap,
      count: _phase(0.3, 1),
    );
    final buttons = Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        if (widget.onMenu != null)
          DerbyButton(
            label: versus ? 'Ladder' : 'Levels',
            icon: versus ? Icons.emoji_events : Icons.map,
            onPressed: widget.onMenu,
          ),
        if (!versus)
          DerbyButton(
            label: 'Workshop',
            icon: Icons.build,
            onPressed: widget.onWorkshop,
            disabledNote: 'SOON',
          ),
        DerbyButton(
          label: versus ? 'Retry' : 'Play again',
          icon: Icons.replay,
          primary: widget.onNextLevel == null,
          onPressed: widget.onPlayAgain,
        ),
        if (widget.onNextLevel != null)
          DerbyButton(
            label: versus ? 'Next race' : 'Next level',
            icon: Icons.arrow_forward,
            primary: true,
            onPressed: widget.onNextLevel,
          ),
      ],
    );

    return RivetedPlate(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: SizedBox(
        width: portrait ? 340 : 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(result: result, head: widget.head),
            const SizedBox(height: 10),
            _Ticket(
              child: portrait
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        score,
                        if (!versus) ...[const SizedBox(height: 10), track],
                        const SizedBox(height: 10),
                        tally,
                        const SizedBox(height: 10),
                        scrap,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: score),
                              const _Perforation(),
                              Expanded(flex: 4, child: tally),
                              const _Perforation(),
                              Expanded(flex: 4, child: scrap),
                            ],
                          ),
                        ),
                        if (!versus) ...[const SizedBox(height: 10), track],
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            buttons,
          ],
        ),
      ),
    );
  }
}

const _ink = Palette.outline;

// ---------------------------------------------------------------- Header

/// Hazard stripes with the level and why the run ended, and the robot's
/// head peeking out of a porthole.
class _Header extends StatelessWidget {
  const _Header({required this.result, required this.head});

  final RunResult result;
  final PartSprite? head;

  @override
  Widget build(BuildContext context) {
    final art = head;
    return SizedBox(
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: _ink, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const CustomPaint(painter: HazardStripesPainter()),
              ),
            ),
          ),
          Positioned.fill(
            left: 72,
            right: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result.race == null ? 'SURVIVAL · LEVEL ${result.level}' : 'VERSUS · RACE ${result.race}'} · '
                        '${Levels.of(result.level).name.toUpperCase()}',
                        style: const TextStyle(
                          color: Palette.hazard,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        result.end.label,
                        style: const TextStyle(
                          color: Palette.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The porthole with the robot's head.
          Positioned(
            left: 4,
            top: -6,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.skyMid,
                border: Border.all(color: _ink, width: 4),
                boxShadow: const [
                  BoxShadow(color: Palette.steelLight, spreadRadius: 3),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: art == null
                  ? null
                  : CustomPaint(painter: _SpritePainter(art)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.sprite);

  final PartSprite sprite;

  @override
  void paint(Canvas canvas, Size size) => sprite.renderFitted(canvas, size);

  @override
  bool shouldRepaint(_SpritePainter old) => old.sprite != sprite;
}

/// The cream ticket card inside the plate.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Palette.cream,
        border: Border.all(color: _ink, width: 3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        child: child,
      ),
    );
  }
}

/// A dotted tear line between ticket sections.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 26, child: CustomPaint(painter: _DotsPainter()));
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Palette.steelLight;
    for (var y = 4.0; y < size.height; y += 9) {
      canvas.drawCircle(Offset(size.width / 2, y), 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

// ---------------------------------------------------------------- Score

/// The distance, the level's stars (new ones slam in) and the stamp.
class _Score extends StatelessWidget {
  const _Score({
    required this.result,
    required this.bestDistance,
    required this.starPhase,
    required this.stampPhase,
  });

  final RunResult result;
  final double bestDistance;
  final Animation<double> Function(int star) starPhase;
  final Animation<double> stampPhase;

  @override
  Widget build(BuildContext context) {
    final stamp = switch (result) {
      RunResult(unlockedLevel: final unlocked?) => 'LEVEL $unlocked UNLOCKED!',
      RunResult(isNewBest: true) => 'NEW BEST!',
      _ => null,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Full width, so the score sits centered in its section.
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const Text(
                'DISTANCE',
                style: TextStyle(fontSize: 11, letterSpacing: 2.5),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${result.distance.toStringAsFixed(0)} m',
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Semantics(
                label: '${result.starsAfter} of ${Levels.maxStars} stars',
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < Levels.maxStars; i++)
                      _Star(
                        had: i < result.starsBefore,
                        earned:
                            i >= result.starsBefore && i < result.starsAfter,
                        phase: starPhase(i - result.starsBefore),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                result.isNewBest && result.unlockedLevel != null
                    ? 'New best: ${bestDistance.toStringAsFixed(0)} m'
                    : 'Best: ${bestDistance.toStringAsFixed(0)} m',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        if (stamp != null)
          Positioned(
            right: -6,
            top: 4,
            child: _Stamp(text: stamp, phase: stampPhase),
          ),
      ],
    );
  }
}

/// Versus: the player's place, big, over the final order (rows slide in
/// one by one; the player's row is highlighted), and a stamp for a race
/// unlocked or a first win.
class _Podium extends StatelessWidget {
  const _Podium({
    required this.result,
    required this.rowPhase,
    required this.stampPhase,
  });

  final RunResult result;
  final Animation<double> Function(int row) rowPhase;
  final Animation<double> stampPhase;

  @override
  Widget build(BuildContext context) {
    final place = result.place ?? Races.racers;
    final stamp = switch (result) {
      RunResult(unlockedRace: final unlocked?) => 'RACE $unlocked UNLOCKED!',
      RunResult(isFirstWin: true) => 'FIRST WIN!',
      _ => null,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'YOU FINISHED',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, letterSpacing: 2.5),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                Races.placeLabel(place).toUpperCase(),
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  color: place == 1 ? Palette.hazardShadow : _ink,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < result.standings.length; i++)
              AnimatedBuilder(
                animation: rowPhase(i),
                builder: (context, child) => Opacity(
                  opacity: rowPhase(i).value,
                  child: Transform.translate(
                    offset: Offset(24 * (1 - rowPhase(i).value), 0),
                    child: child,
                  ),
                ),
                child: _PodiumRow(place: i + 1, standing: result.standings[i]),
              ),
          ],
        ),
        if (stamp != null)
          Positioned(
            right: -6,
            top: 8,
            child: _Stamp(text: stamp, phase: stampPhase),
          ),
      ],
    );
  }
}

/// One racer on the podium: place, colour, name, final distance and a
/// flag; "racing…" for a rival still being played out behind the card.
class _PodiumRow extends StatelessWidget {
  const _PodiumRow({required this.place, required this.standing});

  final int place;
  final Standing standing;

  @override
  Widget build(BuildContext context) {
    final you = standing.isPlayer;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: you ? Palette.hazard : null,
        border: Border.all(
          color: you ? _ink : Palette.steelLight,
          width: you ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              Races.placeLabel(place),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Container(
            width: 11,
            height: 11,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: standing.color,
              shape: BoxShape.circle,
              border: Border.all(color: _ink, width: 1.5),
            ),
          ),
          Expanded(
            child: Text(
              standing.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: you ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          // A rival still running behind the card fills in a moment later.
          if (standing.finished)
            Text(
              '${standing.distance.toStringAsFixed(0)} m',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )
          else
            const Text(
              'racing…',
              style: TextStyle(
                color: Palette.steel,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              ),
            ),
          SizedBox(
            width: 18,
            child: standing.finished
                ? const Icon(Icons.flag, size: 14, color: _ink)
                : null,
          ),
        ],
      ),
    );
  }
}

/// One star: an old one (ink), a new one (slams in, glowing) or empty.
class _Star extends StatelessWidget {
  const _Star({required this.had, required this.earned, required this.phase});

  final bool had;
  final bool earned;
  final Animation<double> phase;

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    if (!earned) {
      return Icon(
        had ? Icons.star : Icons.star_border,
        size: size,
        color: had ? _ink : Palette.steelLight,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: phase,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.star_border,
              size: size,
              color: Palette.steelLight,
            ),
            Transform.scale(
              scale: phase.value,
              child: const Icon(
                Icons.star,
                size: size,
                color: Palette.hazard,
                shadows: [
                  Shadow(color: _ink, blurRadius: 0, offset: Offset(1.5, 1.5)),
                  Shadow(color: Palette.hazard, blurRadius: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tilted rubber stamp that thumps down onto the ticket.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, required this.phase});

  final String text;
  final Animation<double> phase;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC8352B);
    return AnimatedBuilder(
      animation: phase,
      builder: (context, child) => Opacity(
        opacity: phase.value.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -0.22,
          child: Transform.scale(scale: 2.2 - 1.2 * phase.value, child: child),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: red, width: 3),
          borderRadius: BorderRadius.circular(6),
          color: Palette.cream.withValues(alpha: 0.75),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: red,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Track

/// The run along the hill: a bar to the distance reached, the level's star
/// flags, the best distance, and the head's rocket flight as an arc.
class _TrackStrip extends StatelessWidget {
  const _TrackStrip({
    required this.result,
    required this.best,
    required this.progress,
  });

  final RunResult result;
  final double best;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _TrackPainter(
            distance: result.distance * progress.value,
            finalDistance: result.distance,
            best: best,
            stars: Levels.of(result.level).starDistances,
            headFlight: result.stats.headFlight,
          ),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.distance,
    required this.finalDistance,
    required this.best,
    required this.stars,
    required this.headFlight,
  });

  /// Distance drawn so far (it grows as the card appears).
  final double distance;
  final double finalDistance;
  final double best;
  final List<double> stars;
  final double? headFlight;

  @override
  void paint(Canvas canvas, Size size) {
    final end = [finalDistance, best, stars.last].reduce(math.max) * 1.06 + 1;
    const left = 6.0;
    final width = size.width - 12;
    double x(double meters) => left + width * (meters / end).clamp(0, 1);
    final y = size.height - 14;

    // The track and the distance covered.
    final track = RRect.fromLTRBR(
      left,
      y - 4,
      left + width,
      y + 4,
      const Radius.circular(4),
    );
    canvas.drawRRect(track, Paint()..color = Palette.steelLight);
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        y - 4,
        x(distance),
        y + 4,
        const Radius.circular(4),
      ),
      Paint()..color = Palette.rust,
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Best (a dashed post) when it isn't this run.
    if (best > finalDistance + 0.5) {
      final bx = x(best);
      final dash = Paint()
        ..color = _ink
        ..strokeWidth = 2;
      for (var d = y - 26; d < y + 6; d += 6) {
        canvas.drawLine(Offset(bx, d), Offset(bx, d + 3), dash);
      }
      _label(canvas, 'BEST', Offset(bx, y - 36));
    }

    // Star flags.
    for (final s in stars) {
      final fx = x(s);
      final reached = finalDistance >= s;
      canvas.drawLine(
        Offset(fx, y + 4),
        Offset(fx, y - 24),
        Paint()
          ..color = _ink
          ..strokeWidth = 2,
      );
      final flag = Path()
        ..moveTo(fx, y - 24)
        ..lineTo(fx + 13, y - 19)
        ..lineTo(fx, y - 14)
        ..close();
      canvas
        ..drawPath(
          flag,
          Paint()..color = reached ? Palette.hazard : Palette.cream,
        )
        ..drawPath(
          flag,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }

    // The head's rocket flight: an arc from launch to touchdown.
    final flight = headFlight;
    if (flight != null && flight > 0 && distance >= finalDistance - 0.5) {
      final from = Offset(x(finalDistance - flight), y);
      final to = Offset(x(finalDistance), y);
      final arc = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(
          (from.dx + to.dx) / 2,
          y - 2 * math.min(30, 10 + (to.dx - from.dx) * 0.4),
          to.dx,
          to.dy,
        );
      final dashPaint = Paint()
        ..color = Palette.rustShadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final metric in arc.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 7) {
          canvas.drawPath(metric.extractPath(d, d + 4), dashPaint);
        }
      }
    }

    // Where the run ended: a marker on the track.
    final mx = x(distance);
    canvas
      ..drawCircle(Offset(mx, y), 7, Paint()..color = Palette.eyeGlow)
      ..drawCircle(
        Offset(mx, y),
        7,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
  }

  void _label(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _ink,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, 0));
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.distance != distance || old.best != best;
}

// ---------------------------------------------------------------- Tally

/// Landings as three tiles (clean / one foot / crash), then the jump,
/// limbs and head flight.
class _Tally extends StatelessWidget {
  const _Tally({required this.result});

  final RunResult result;

  @override
  Widget build(BuildContext context) {
    final stats = result.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'RUN',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _TallyTile(
              icon: Icons.check_circle,
              color: const Color(0xFF2F9E5B),
              count: stats.landingsOf(LandingType.clean),
              label: 'Clean',
            ),
            _TallyTile(
              icon: Icons.adjust,
              color: Palette.hazardShadow,
              count: stats.landingsOf(LandingType.oneFoot),
              label: 'One-foot',
            ),
            _TallyTile(
              icon: Icons.cancel,
              color: const Color(0xFFC8352B),
              count: stats.landingsOf(LandingType.crash),
              label: 'Crash',
            ),
          ],
        ),
        const SizedBox(height: 6),
        _Row('Highest jump', '${stats.highestJump.toStringAsFixed(1)} m'),
        _Row('Limbs lost', '${stats.limbsLost}/4'),
        if (stats.headFlight case final flight?)
          _Row('Head flight', '${flight.toStringAsFixed(0)} m'),
      ],
    );
  }
}

class _TallyTile extends StatelessWidget {
  const _TallyTile({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        container: true,
        label: '$label landings $count',
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Scrap

/// Scrap earned, line by line, with the total counting up.
class _ScrapBox extends StatelessWidget {
  const _ScrapBox({
    required this.result,
    required this.totalScrap,
    required this.count,
  });

  final RunResult result;
  final int totalScrap;
  final Animation<double> count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.settings, size: 16, color: _ink),
            SizedBox(width: 4),
            Text(
              'SCRAP',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final line in result.scrap) _Row(line.label, '+${line.amount}'),
        const Divider(color: _ink, thickness: 2, height: 10),
        AnimatedBuilder(
          animation: count,
          builder: (context, _) => Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedText(
                '+${(result.scrapEarned * count.value).round()}',
                fontSize: 22,
                color: Palette.hazard,
              ),
            ],
          ),
        ),
        Text('You have $totalScrap', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
