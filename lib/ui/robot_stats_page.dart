import 'package:flutter/material.dart';

import '../config/tuning.dart';
import '../game/gadgets.dart';
import '../game/levels.dart';
import '../game/palette.dart';
import '../game/robot_stats.dart';
import '../game/stat_sheet.dart';
import '../profile/player_profile.dart';
import 'crt.dart';
import 'outlined_text.dart';

/// Every robot stat on a green CRT screen: its value now, how far the
/// parts on sale now could take it, and the most it can ever be. Next to
/// it: stars, scrap bonuses and what is unlocked.
class RobotStatsPage extends StatelessWidget {
  const RobotStatsPage({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _floor,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_wall, _floor],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profile,
            builder: (context, _) => Column(
              children: [
                _Header(
                  scrap: profile.scrap,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: _StatsScreen(profile)),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: _ProgressScreen(profile)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The Workshop's garage colours.
  static const _wall = Color(0xFF2A2E3B);
  static const _floor = Color(0xFF181A22);
}

class _Header extends StatelessWidget {
  const _Header({required this.scrap, required this.onBack});

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
          const OutlinedText(
            'ROBOT STATS',
            fontSize: 28,
            color: Palette.hazard,
          ),
          const Spacer(),
          const Icon(Icons.settings, color: Palette.hazard, size: 22),
          const SizedBox(width: 6),
          OutlinedText('$scrap Scrap', fontSize: 22, color: Palette.cream),
        ],
      ),
    );
  }
}

/// A CRT panel with a title and scanlines.
class _CrtPanel extends StatelessWidget {
  const _CrtPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Crt.background,
        border: Border.all(color: Crt.dim, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        foregroundPainter: _Scanlines(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Crt.green,
              fontFamily: Crt.font,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Expanded(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Scanlines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Crt.scanline;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_Scanlines oldDelegate) => false;
}

/// The stats, grouped by slot, each with a bar and "now / max".
class _StatsScreen extends StatelessWidget {
  const _StatsScreen(this.profile);

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final lines = statSheet(
      installed: profile.tierOf,
      maxPartTier: profile.maxPartTier,
    );
    return _CrtPanel(
      title: 'ROBOT  ·  NOW / MAX',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final slot in UpgradeTrack.values) ...[
            _SlotHeading(slot: slot, tier: profile.tierOf(slot)),
            for (final line in lines.where((l) => l.slot == slot))
              _StatRow(line),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 5, bottom: 1),
            child: Text('GADGETS', style: TextStyle(color: Crt.amber)),
          ),
          for (final gadget in Gadget.values)
            _GadgetStatRow(
              gadget: gadget,
              level: profile.gadgetLevel(gadget),
              unlocked: profile.isGadgetUnlocked(gadget),
            ),
          const SizedBox(height: 6),
          const _Legend(),
        ],
      ),
    );
  }
}

class _SlotHeading extends StatelessWidget {
  const _SlotHeading({required this.slot, required this.tier});

  final UpgradeTrack slot;
  final int tier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 1),
      child: Text(
        '${slot.name.toUpperCase()}  ${slot.partName(tier)}  '
        '(tier $tier/${Tuning.upgradeMaxLevel})',
        style: const TextStyle(color: Crt.amber),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.line);

  final StatLine line;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${line.label} ${line.format(line.now)}, '
          'max ${line.format(line.max)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          children: [
            SizedBox(width: 125, child: Text(line.label)),
            Expanded(
              child: SizedBox(
                height: 10,
                child: CustomPaint(
                  painter: _StatBar(
                    now: line.share(line.now),
                    reachable: line.share(line.reachable),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 185,
              child: Text(
                '${line.format(line.now)} / ${line.format(line.max)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A gadget's level as a bar, and what it does now (or what unlocks it).
class _GadgetStatRow extends StatelessWidget {
  const _GadgetStatRow({
    required this.gadget,
    required this.level,
    required this.unlocked,
  });

  final Gadget gadget;
  final int level;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final text = unlocked || level > 0
        ? gadget.effect(level)
        : 'Unlocks with level ${gadget.unlockLevel}';
    return Semantics(
      label: '${gadget.name} level $level of ${Tuning.gadgetMaxLevel}, $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          children: [
            SizedBox(width: 125, child: Text(gadget.name)),
            Expanded(
              child: SizedBox(
                height: 10,
                child: CustomPaint(
                  painter: _StatBar(
                    now: level / Tuning.gadgetMaxLevel,
                    reachable: unlocked ? 1 : level / Tuning.gadgetMaxLevel,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 185,
              child: Text(
                text,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked || level > 0
                      ? Crt.green
                      : Crt.green.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bar of upgrade progress (empty = the plain robot, full = max):
/// bright up to the installed parts, dim up to what the parts on sale now
/// could reach.
class _StatBar extends CustomPainter {
  _StatBar({required this.now, required this.reachable});

  final double now;
  final double reachable;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Offset.zero & size;
    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width * reachable, size.height),
        Paint()..color = Crt.dim,
      )
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width * now, size.height),
        Paint()..color = Crt.green,
      )
      ..drawRect(
        frame,
        Paint()
          ..color = Crt.dim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_StatBar old) =>
      old.now != now || old.reachable != reachable;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 8, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 12),
      ],
    );
    return Wrap(
      children: [
        swatch(Crt.green, 'installed'),
        swatch(Crt.dim, 'parts on sale now'),
        const Text(
          'empty = scrap robot, full = max',
          style: TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

/// Stars, scrap bonuses and unlocks.
class _ProgressScreen extends StatelessWidget {
  const _ProgressScreen(this.profile);

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final maxStars = Levels.count * Levels.maxStars;
    final level = profile.highestUnlockedLevel;
    final cleared = [for (var l = 1; l <= Levels.count; l++) profile.starsOn(l)]
        .where((stars) => stars > 0)
        .length;
    String percent(double share) => '+${(share * 100).round()}%';
    return _CrtPanel(
      title: 'PROGRESS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pair('Stars', '${profile.totalStars} / $maxStars'),
          _Pair('Levels cleared', '$cleared / ${Levels.count}'),
          _Pair('Furthest level', '$level / ${Levels.count}'),
          _Pair(
            'Parts on sale',
            'tier ${profile.maxPartTier} / ${Tuning.upgradeMaxLevel}',
          ),
          const SizedBox(height: 8),
          const Text('SCRAP BONUS', style: TextStyle(color: Crt.amber)),
          _Pair(
            'From stars',
            '${percent(profile.starScrapBonus)} / '
                '${percent(maxStars * Tuning.scrapBonusPerStar)}',
          ),
          _Pair(
            'Level $level pays',
            '×${Levels.of(level).scrapMultiplier.toStringAsFixed(1)} / '
                '×${Levels.of(Levels.count).scrapMultiplier.toStringAsFixed(1)}',
          ),
          _Pair('New star', '+${Tuning.scrapPerNewStar} each'),
          const SizedBox(height: 8),
          Text(
            'Every star earned adds scrap on all levels, for good.',
            style: TextStyle(
              fontSize: 10,
              color: Crt.green.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}
