import 'package:flutter/material.dart';

import '../config/tuning.dart';
import '../game/gadgets.dart';
import '../game/levels.dart';
import '../game/palette.dart';
import '../game/robot_sprites.dart';
import '../game/robot_stats.dart';
import '../game/stat_sheet.dart';
import '../profile/page_tour.dart';
import '../profile/player_profile.dart';
import 'crt.dart';
import 'layout.dart';
import 'outlined_text.dart';
import 'page_header.dart';
import 'robot_figure.dart';
import 'spotlight_tour.dart';

/// The robot's spec sheet: the robot in its installed parts with an
/// overall power rank, one card per slot with plain-word gauges (now, the
/// next part ghosted ahead, what's on sale, and the max), gadget badges
/// and progress chips. Opened from the main menu and the Workshop.
class RobotStatsPage extends StatefulWidget {
  const RobotStatsPage({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  State<RobotStatsPage> createState() => _RobotStatsPageState();
}

class _RobotStatsPageState extends State<RobotStatsPage> {
  late final Future<RobotSprites> _sprites = RobotSprites.load();

  PlayerProfile get _profile => widget.profile;

  // First-visit tour targets.
  final _showcaseKey = GlobalKey();
  final _firstCardKey = GlobalKey();
  final _gadgetsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Garage.floor,
      body: SpotlightTour(
        tour: PageTour.stats,
        profile: _profile,
        steps: [
          TourStep(
            target: _showcaseKey,
            title: 'YOUR ROBOT',
            text:
                'Its power rank goes up with every better part you '
                'install.',
          ),
          TourStep(
            target: _firstCardKey,
            title: 'EVERY STAT',
            text:
                'Bars show now, the next part (light) and the best part on '
                'sale (tick). Long-press a bar for what it means.',
          ),
          TourStep(
            target: _gadgetsKey,
            title: 'GADGETS',
            text: 'The helpers you own, and their levels.',
          ),
        ],
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_Garage.wall, _Garage.floor],
            ),
          ),
          child: SafeArea(
            child: FutureBuilder<RobotSprites>(
              future: _sprites,
              builder: (context, snapshot) => ListenableBuilder(
                listenable: _profile,
                builder: (context, _) => _layout(snapshot.data),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _layout(RobotSprites? sprites) {
    final lines = statSheet(
      installed: _profile.tierOf,
      maxPartTier: _profile.maxPartTier,
    );
    final showcase = _Showcase(
      key: _showcaseKey,
      profile: _profile,
      look: sprites?.look(_profile.tierOf),
    );
    final cards = [
      for (final slot in UpgradeTrack.values)
        _SlotCard(
          key: slot == UpgradeTrack.values.first ? _firstCardKey : null,
          slot: slot,
          tier: _profile.tierOf(slot),
          sprite: sprites?.part(slot, _profile.tierOf(slot)),
          lines: [
            for (final line in lines)
              if (line.slot == slot) line,
          ],
        ),
      _GadgetBadges(key: _gadgetsKey, profile: _profile),
    ];
    return Column(
      children: [
        PageHeader(
          title: 'ROBOT STATS',
          onBack: () => Navigator.of(context).pop(),
          trailing: [
            HeaderCount(
              icon: Icons.settings,
              text: '${_profile.scrap}',
              label: 'Scrap',
            ),
          ],
        ),
        Expanded(
          child: OrientationSwitch(
            // Portrait: everything in one scrolling column. (Built in full,
            // not lazily, so the first-visit tour can scroll to any card.)
            portrait: (context) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 330, child: showcase),
                  for (final card in cards) ...[
                    const SizedBox(height: 10),
                    card,
                  ],
                ],
              ),
            ),
            // Landscape: the robot on the left, the cards scroll on the right.
            landscape: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 4, child: showcase),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            cards[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Garage colours, shared with the Workshop look.
abstract final class _Garage {
  static const wall = Color(0xFF2A2E3B);
  static const floor = Color(0xFF181A22);
  static const panel = Color(0xFF242833);
  static const panelEdge = Color(0xFF3A4050);
  static const card = Color(0xFFF3E9DC);
  static const spotlight = Color(0x66FCD98A);
}

// ---------------------------------------------------------------- Showcase

/// The robot in a spotlight with its power rank on top and progress chips
/// below.
class _Showcase extends StatelessWidget {
  const _Showcase({super.key, required this.profile, required this.look});

  final PlayerProfile profile;
  final RobotLook? look;

  @override
  Widget build(BuildContext context) {
    final share = powerShare(profile.tierOf);
    final art = look;
    final maxStars = Levels.count * Levels.maxStars;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _Garage.panelEdge, width: 2),
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          center: Alignment(0, 0.1),
          radius: 0.85,
          colors: [_Garage.spotlight, _Garage.panel],
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          _RankPlate(share: share),
          Expanded(
            child: art == null
                ? const SizedBox.expand()
                : CustomPaint(
                    size: Size.infinite,
                    painter: RobotFigurePainter(
                      look: art,
                      angle: 0,
                      armSwing: 0.3,
                      legSwing: 0.08,
                      metersTall: 4.4,
                    ),
                  ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Chip(
                  icon: Icons.star,
                  text: '${profile.totalStars} / $maxStars',
                  tooltip: 'Stars earned',
                ),
                _Chip(
                  icon: Icons.flag,
                  text: 'Level ${profile.highestUnlockedLevel}',
                  tooltip: 'Furthest level unlocked',
                ),
                _Chip(
                  icon: Icons.settings,
                  text: '+${(profile.starScrapBonus * 100).round()}%',
                  tooltip: 'Scrap bonus from stars, on every run',
                ),
                _Chip(
                  icon: Icons.build,
                  text: 'Tier ${profile.maxPartTier}',
                  tooltip: 'Best parts on sale',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "POWER 37%" with a rank title and a hazard-striped meter.
class _RankPlate extends StatelessWidget {
  const _RankPlate({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Power ${(share * 100).round()}%, ${powerRank(share)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        decoration: BoxDecoration(
          color: Palette.outline,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.hazard, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedText(
                    powerRank(share).toUpperCase(),
                    fontSize: 22,
                    color: Palette.hazard,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'POWER ${(share * 100).round()}%',
                    style: const TextStyle(
                      color: Palette.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 10,
              width: double.infinity,
              child: CustomPaint(painter: _PowerMeter(share)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded meter, hazard stripes up to [share].
class _PowerMeter extends CustomPainter {
  _PowerMeter(this.share);

  final double share;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas
      ..drawRRect(track, Paint()..color = Palette.steelDark)
      ..save()
      ..clipRRect(track)
      ..clipRect(Rect.fromLTWH(0, 0, size.width * share, size.height))
      ..drawRect(Offset.zero & size, Paint()..color = Palette.hazard);
    final stripe = Paint()..color = Palette.hazardShadow;
    for (var x = -size.height; x < size.width; x += size.height * 1.6) {
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + size.height * 0.7, size.height)
          ..lineTo(x + size.height * 1.4, 0)
          ..lineTo(x + size.height * 0.7, 0)
          ..close(),
        stripe,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PowerMeter old) => old.share != share;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.tooltip});

  final IconData icon;
  final String text;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _Garage.panelEdge, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Palette.hazard),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                color: Palette.cream,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Slot cards

/// One Workshop slot: its part's art and name, tier pips, and a gauge per
/// stat it changes.
class _SlotCard extends StatelessWidget {
  const _SlotCard({
    super.key,
    required this.slot,
    required this.tier,
    required this.sprite,
    required this.lines,
  });

  final UpgradeTrack slot;
  final int tier;
  final PartSprite? sprite;
  final List<StatLine> lines;

  @override
  Widget build(BuildContext context) {
    final art = sprite;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
      decoration: BoxDecoration(
        color: _Garage.card,
        border: Border.all(color: Palette.outline, width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The installed part, in a little display window.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Palette.steelLight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.outline, width: 2),
            ),
            padding: const EdgeInsets.all(5),
            child: art == null
                ? null
                : CustomPaint(size: Size.infinite, painter: _PartPainter(art)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      slot.name.toUpperCase(),
                      style: const TextStyle(
                        color: Palette.rustShadow,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TierPips(tier: tier),
                  ],
                ),
                Text(
                  slot.partName(tier),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.outline,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${slot.spec(tier).material} · ${slot.spec(tier).tech}',
                  style: TextStyle(
                    color: Palette.outline.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final line in lines) _Gauge(line),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartPainter extends CustomPainter {
  _PartPainter(this.sprite);

  final PartSprite sprite;

  @override
  void paint(Canvas canvas, Size size) => sprite.renderFitted(canvas, size);

  @override
  bool shouldRepaint(_PartPainter old) => old.sprite != sprite;
}

class _TierPips extends StatelessWidget {
  const _TierPips({required this.tier});

  final int tier;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= Tuning.upgradeMaxLevel; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: i <= tier ? Palette.rust : null,
              border: Border.all(color: Palette.outline, width: 1.4),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// A stat as a chunky gauge: label and value (plus the next part's value),
/// a bar split into tier sections, filled to now, the next part ghosted
/// ahead, and a tick at the best part on sale. Long-press for what it
/// means.
class _Gauge extends StatelessWidget {
  const _Gauge(this.line);

  final StatLine line;

  @override
  Widget build(BuildContext context) {
    final next = line.next;
    return Semantics(
      container: true,
      label:
          '${line.label} ${line.format(line.now)}, '
          'max ${line.format(line.max)}',
      excludeSemantics: true,
      child: Tooltip(
        message: line.hint,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      line.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Palette.outline,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  // The numbers shrink rather than overflow on narrow
                  // phones (long units like m/s²).
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            line.format(line.now),
                            style: const TextStyle(
                              color: Palette.outline,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            next == null ? 'MAX' : '→ ${line.format(next)}',
                            style: TextStyle(
                              color: next == null
                                  ? const Color(0xFF2F9E5B)
                                  : Palette.hazardShadow,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 14,
                child: CustomPaint(
                  painter: _GaugeBar(
                    now: line.share(line.now),
                    next: next == null ? null : line.share(next),
                    reachable: line.share(line.reachable),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugeBar extends CustomPainter {
  _GaugeBar({required this.now, required this.next, required this.reachable});

  /// Shares of the way from the scrap robot (0) to the max (1).
  final double now;
  final double? next;
  final double reachable;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas
      ..drawRRect(track, Paint()..color = Palette.steelLight)
      ..save()
      ..clipRRect(track);
    final n = next;
    if (n != null && n > now) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * n, size.height),
        Paint()..color = Palette.hazard.withValues(alpha: 0.55),
      );
    }
    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width * now, size.height),
        Paint()..color = Palette.rust,
      )
      // A shine along the top of the fill.
      ..drawRect(
        Rect.fromLTWH(0, 2, size.width * now, size.height * 0.22),
        Paint()..color = Palette.rustLight.withValues(alpha: 0.8),
      );
    // Tier sections.
    final divider = Paint()
      ..color = Palette.outline.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    for (var i = 1; i < Tuning.upgradeMaxLevel; i++) {
      final x = size.width * i / Tuning.upgradeMaxLevel;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), divider);
    }
    canvas.restore();
    // The best part on sale now: a small tick.
    if (reachable > now + 1e-6) {
      final x = size.width * reachable;
      canvas.drawLine(
        Offset(x, -2),
        Offset(x, size.height + 2),
        Paint()
          ..color = Palette.outline
          ..strokeWidth = 2,
      );
    }
    canvas.drawRRect(
      track,
      Paint()
        ..color = Palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_GaugeBar old) =>
      old.now != now || old.next != next || old.reachable != reachable;
}

// ---------------------------------------------------------------- Gadgets

/// Every gadget as a round badge: lit with its level when owned, dim when
/// on sale but not owned, locked (with the level that opens it) otherwise.
class _GadgetBadges extends StatelessWidget {
  const _GadgetBadges({super.key, required this.profile});

  final PlayerProfile profile;

  static const Map<Gadget, IconData> _icons = {
    Gadget.comboCoil: Icons.repeat,
    Gadget.scrapMagnet: Icons.recycling,
    Gadget.autoGyro: Icons.explore,
    Gadget.shockPads: Icons.shield,
    Gadget.crashCage: Icons.grid_on,
    Gadget.levelerTreads: Icons.terrain,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: _Garage.panel,
        border: Border.all(color: _Garage.panelEdge, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GADGETS',
            style: TextStyle(
              color: Palette.hazard,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final gadget in Gadget.values)
                _GadgetBadge(
                  gadget: gadget,
                  icon: _icons[gadget] ?? Icons.extension,
                  level: profile.gadgetLevel(gadget),
                  unlocked: profile.isGadgetUnlocked(gadget),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GadgetBadge extends StatelessWidget {
  const _GadgetBadge({
    required this.gadget,
    required this.icon,
    required this.level,
    required this.unlocked,
  });

  final Gadget gadget;
  final IconData icon;
  final int level;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final owned = level > 0;
    final color = owned
        ? Crt.green
        : (unlocked ? Palette.steelLight : Palette.steel);
    final status = owned
        ? gadget.effect(level)
        : (unlocked ? 'Not owned' : 'Unlocks with level ${gadget.unlockLevel}');
    return Semantics(
      container: true,
      label: '${gadget.name} level $level of ${Tuning.gadgetMaxLevel}, $status',
      excludeSemantics: true,
      child: Tooltip(
        message: '${gadget.name}: $status',
        child: SizedBox(
          width: 74,
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: owned ? Crt.background : Colors.black26,
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: owned
                      ? [
                          BoxShadow(
                            color: Crt.green.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  unlocked || owned ? icon : Icons.lock,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                gadget.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: owned ? Palette.cream : Palette.steelLight,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= Tuning.gadgetMaxLevel; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 3, left: 1, right: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= level ? color : null,
                        border: Border.all(color: color, width: 1),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
