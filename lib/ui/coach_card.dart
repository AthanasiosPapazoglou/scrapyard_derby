import 'package:flutter/material.dart';

import '../game/coach.dart';
import '../game/palette.dart';
import 'layout.dart';
import 'status_panel.dart';

/// The tutorial card over the game (see lib/game/coach.dart), placed near
/// what it talks about, plus a small "Skip tutorial" pill. The card itself
/// ignores touches, so holding anywhere still steers the robot.
class CoachOverlay extends StatelessWidget {
  const CoachOverlay({super.key, required this.card, required this.onSkip});

  final CoachCard card;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final portrait = context.isPortrait;
    final body = _CoachBody(card: card, onSkip: onSkip);
    return Stack(
      children: [
        // Below the robot in portrait; up and to the right in landscape,
        // clear of the robot (centre) and the card (bottom).
        if (card.finger)
          Align(
            alignment: portrait
                ? const Alignment(0, 0.35)
                : const Alignment(0.6, -0.2),
            child: const _HoldFinger(),
          ),
        switch (card.pointer) {
          // Under the distance and energy bar, pointing up at it
          // (landscape: right of the status panel's column, so short
          // screens don't put it beside the panel).
          CoachPointer.energyBar => Positioned(
            top: portrait ? 176 : 112,
            left: portrait ? 16 : 12 + StatusPanel.size.width + 12,
            right: 16,
            child: Center(child: body),
          ),
          // Next to the status panel (above it in portrait).
          CoachPointer.statusPanel =>
            portrait
                ? Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12 + StatusPanel.size.height * 0.8 + 8,
                    child: Align(alignment: Alignment.centerLeft, child: body),
                  )
                : Positioned(
                    left: 12 + StatusPanel.size.width + 12,
                    bottom: 12,
                    child: body,
                  ),
          // Low and centred, clear of the robot in the middle (landscape:
          // in the space right of the status panel).
          CoachPointer.none => Positioned(
            left: portrait ? 16 : 12 + StatusPanel.size.width + 12,
            right: 16,
            bottom: portrait ? 12 + StatusPanel.size.height * 0.8 + 8 : 16,
            child: Center(child: body),
          ),
        },
      ],
    );
  }
}

class _CoachBody extends StatelessWidget {
  const _CoachBody({required this.card, required this.onSkip});

  final CoachCard card;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final arrow = switch (card.pointer) {
      CoachPointer.energyBar => Icons.arrow_upward_rounded,
      CoachPointer.statusPanel =>
        context.isPortrait
            ? Icons.arrow_downward_rounded
            : Icons.arrow_back_rounded,
      CoachPointer.none => null,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IgnorePointer(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: Palette.outline.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.hazard, width: 3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (arrow != null) ...[
                    Icon(arrow, color: Palette.hazard, size: 30),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: const TextStyle(
                            color: Palette.hazard,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.text,
                          style: const TextStyle(
                            color: Palette.cream,
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            label: 'Skip tutorial',
            child: GestureDetector(
              onTap: onSkip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Palette.outline.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'SKIP TUTORIAL',
                  style: TextStyle(
                    color: Palette.cream.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A finger pressing down, pulsing: "hold anywhere".
class _HoldFinger extends StatefulWidget {
  const _HoldFinger();

  @override
  State<_HoldFinger> createState() => _HoldFingerState();
}

class _HoldFingerState extends State<_HoldFinger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70 + 30 * t,
                height: 70 + 30 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.hazard.withValues(alpha: 0.25 * (1 - t)),
                  border: Border.all(
                    color: Palette.hazard.withValues(alpha: 0.8 * (1 - t)),
                    width: 3,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(6, 10 + 6 * t),
                child: const Icon(
                  Icons.touch_app_rounded,
                  size: 64,
                  color: Palette.cream,
                  shadows: [Shadow(color: Palette.outline, blurRadius: 6)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
