import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/tuning.dart';
import '../game/sound.dart';
import '../game/robot_stats.dart';
import '../profile/player_profile.dart';
import 'crt.dart';

/// Spend scrap on robot upgrades. A green CRT screen like the robot status
/// panel: a robot schematic on the left (lighting up the part of the
/// selected track) and the five upgrade tracks on the right.
class WorkshopPage extends StatefulWidget {
  const WorkshopPage({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}

class _WorkshopPageState extends State<WorkshopPage> {
  UpgradeTrack _selected = UpgradeTrack.values.first;

  PlayerProfile get _profile => widget.profile;

  void _buy(UpgradeTrack track) {
    setState(() => _selected = track);
    if (!_profile.buyUpgrade(track)) {
      return;
    }
    Sound.play(Sfx.uiBuy);
    if (_profile.hapticsOn) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07110A),
      body: SafeArea(
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Crt.green,
            fontFamily: Crt.font,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          child: ListenableBuilder(
            listenable: _profile,
            builder: (context, _) => Column(
              children: [
                _Header(
                  scrap: _profile.scrap,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 190,
                          child: _Screen(
                            child: _Schematic(
                              track: _selected,
                              level: _profile.upgradeLevel(_selected.id),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Screen(
                            child: ListView(
                              padding: const EdgeInsets.all(8),
                              children: [
                                for (final track in UpgradeTrack.values)
                                  _TrackRow(
                                    track: track,
                                    level: _profile.upgradeLevel(track.id),
                                    canBuy: _profile.canBuy(track),
                                    selected: track == _selected,
                                    onSelect: () =>
                                        setState(() => _selected = track),
                                    onBuy: () => _buy(track),
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
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.scrap, required this.onBack});

  final int scrap;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Crt.green, size: 28),
          ),
          const Text(
            '> WORKSHOP_',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          const Icon(Icons.settings, color: Crt.amber, size: 20),
          const SizedBox(width: 6),
          Text(
            '$scrap SCRAP',
            style: const TextStyle(color: Crt.amber, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

/// A rounded CRT screen with a green edge and scanlines on top.
class _Screen extends StatelessWidget {
  const _Screen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Crt.background,
        border: Border.all(color: Crt.green.withValues(alpha: 0.7), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(foregroundPainter: _Scanlines(), child: child),
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

/// One upgrade track: name, part, level pips, description, now → next,
/// and the Buy button with its price.
class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.level,
    required this.canBuy,
    required this.selected,
    required this.onSelect,
    required this.onBuy,
  });

  final UpgradeTrack track;
  final int level;
  final bool canBuy;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final price = track.priceAfter(level);
    final maxed = price == null;
    final now = RobotStats.fromLevels({track: level}).summary(track);
    final next = maxed
        ? null
        : RobotStats.fromLevels({track: level + 1}).summary(track);
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        decoration: BoxDecoration(
          color: selected ? Crt.green.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: selected ? Crt.green : Crt.dim,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        track.name.toUpperCase(),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '[${track.part.toUpperCase()}]',
                        style: TextStyle(
                          color: Crt.green.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _LevelPips(level: level),
                    ],
                  ),
                  Text(
                    track.description,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    maxed ? '$now  (MAX)' : '$now  →  $next',
                    style: const TextStyle(color: Crt.amber, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _BuyButton(price: price, enabled: canBuy, onPressed: onBuy),
          ],
        ),
      ),
    );
  }
}

/// Filled pips for bought levels, hollow ones for the rest.
class _LevelPips extends StatelessWidget {
  const _LevelPips({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Level $level of ${Tuning.upgradeMaxLevel}',
      child: Row(
        children: [
          for (var i = 0; i < Tuning.upgradeMaxLevel; i++)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < level ? Crt.green : null,
                border: Border.all(color: Crt.green, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.price,
    required this.enabled,
    required this.onPressed,
  });

  /// Null when the track is maxed.
  final int? price;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = price == null ? 'MAX' : 'BUY ${price!}';
    return SizedBox(
      width: 96,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: Crt.ink,
          backgroundColor: Crt.green,
          disabledForegroundColor: Crt.dim,
          disabledBackgroundColor: Colors.transparent,
          side: BorderSide(color: enabled ? Crt.green : Crt.dim, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          textStyle: const TextStyle(
            fontFamily: Crt.font,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// The robot figure on the CRT screen; the parts the selected track
/// upgrades are lit up, the rest are dim.
class _Schematic extends StatelessWidget {
  const _Schematic({required this.track, required this.level});

  final UpgradeTrack track;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _SchematicPainter(track),
            ),
          ),
          Text(track.name.toUpperCase(), style: const TextStyle(fontSize: 15)),
          Text(
            'LEVEL $level/${Tuning.upgradeMaxLevel}',
            style: const TextStyle(color: Crt.amber),
          ),
        ],
      ),
    );
  }
}

class _SchematicPainter extends CustomPainter {
  _SchematicPainter(this.track);

  final UpgradeTrack track;

  // The same figure as the status panel, in a 96 × 116 box.
  static const _head = Rect.fromLTWH(34, 0, 28, 22);
  static const _body = Rect.fromLTWH(30, 26, 36, 44);
  static const _leftArm = Rect.fromLTWH(15, 28, 11, 42);
  static const _rightArm = Rect.fromLTWH(70, 28, 11, 42);
  static const _leftLeg = Rect.fromLTWH(33, 74, 12, 40);
  static const _rightLeg = Rect.fromLTWH(51, 74, 12, 40);
  static const _figure = Size(96, 116);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.height / _figure.height).clamp(
      0.0,
      size.width / _figure.width,
    );
    canvas
      ..save()
      ..translate(
        (size.width - _figure.width * scale) / 2,
        (size.height - _figure.height * scale) / 2,
      )
      ..scale(scale);

    final lit = switch (track) {
      UpgradeTrack.plating => {_body},
      UpgradeTrack.springLegs => {_leftLeg, _rightLeg},
      UpgradeTrack.gyroArms => {_leftArm, _rightArm},
      UpgradeTrack.energyCore => <Rect>{},
      UpgradeTrack.rocketHead => {_head},
    };
    for (final rect in [
      _head,
      _body,
      _leftArm,
      _rightArm,
      _leftLeg,
      _rightLeg,
    ]) {
      final on = lit.contains(rect);
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas
        ..drawRRect(
          shape,
          Paint()..color = Crt.green.withValues(alpha: on ? 0.75 : 0.08),
        )
        ..drawRRect(
          shape,
          Paint()
            ..color = on ? Crt.green : Crt.dim
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
    // The energy core: a glowing circle in the middle of the body.
    final coreOn = track == UpgradeTrack.energyCore;
    canvas.drawCircle(
      _body.center,
      8,
      Paint()..color = coreOn ? Crt.amber : Crt.dim,
    );
    // The head's eye.
    canvas
      ..drawCircle(const Offset(54, 11), 4, Paint()..color = Crt.ink)
      ..restore();
  }

  @override
  bool shouldRepaint(_SchematicPainter oldDelegate) =>
      oldDelegate.track != track;
}
