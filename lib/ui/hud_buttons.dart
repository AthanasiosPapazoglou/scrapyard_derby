import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../game/sound.dart';
import 'scrap_plate.dart';

/// Base for the in-game scrap-metal buttons: plays the click, and sinks
/// a few pixels while pressed (its drop-shadow shrinks to match).
abstract class _PressButton extends StatefulWidget {
  const _PressButton({super.key, required this.onPressed});

  final VoidCallback onPressed;
}

abstract class _PressButtonState<T extends _PressButton> extends State<T> {
  bool pressed = false;

  /// How far the button sinks when pressed.
  static const double travel = 3;

  Widget face(BuildContext context);

  String get label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => pressed = true),
          onTapCancel: () => setState(() => pressed = false),
          onTapUp: (_) => setState(() => pressed = false),
          onTap: () {
            Sound.play(Sfx.uiClick);
            widget.onPressed();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            transform: Matrix4.translationValues(0, pressed ? travel : 0, 0),
            child: face(context),
          ),
        ),
      ),
    );
  }
}

/// The in-game Restart: a bolted plate with a hazard-striped frame, a
/// yellow face, a chunky replay arrow and a stencil label.
class HudRestartButton extends _PressButton {
  const HudRestartButton({super.key, required super.onPressed});

  @override
  State<HudRestartButton> createState() => _HudRestartButtonState();
}

class _HudRestartButtonState extends _PressButtonState<HudRestartButton> {
  @override
  String get label => 'Restart';

  @override
  Widget face(BuildContext context) {
    const radius = 12.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: Palette.outline, offset: Offset(0, pressed ? 1 : 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: const HazardStripesPainter(width: 7),
          foregroundPainter: _FramePainter(radius),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
              decoration: BoxDecoration(
                color: Palette.hazard,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Palette.outline, width: 2.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.replay, color: Palette.outline, size: 24),
                  SizedBox(width: 6),
                  Text(
                    'RESTART',
                    style: TextStyle(
                      color: Palette.outline,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ink outline and corner rivets over the Restart plate's frame.
class _FramePainter extends CustomPainter {
  _FramePainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1.5),
        Radius.circular(radius),
      ),
      Paint()
        ..color = Palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.radius != radius;
}

/// The in-game Pause: a round steel bolt head with yellow pause bars.
class HudPauseButton extends _PressButton {
  const HudPauseButton({super.key, required super.onPressed});

  @override
  State<HudPauseButton> createState() => _HudPauseButtonState();
}

class _HudPauseButtonState extends _PressButtonState<HudPauseButton> {
  @override
  String get label => 'Pause';

  @override
  Widget face(BuildContext context) {
    const size = 48.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Palette.steelLight, Palette.steel, Palette.steelDark],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: Palette.outline, width: 3),
        boxShadow: [
          BoxShadow(color: Palette.outline, offset: Offset(0, pressed ? 1 : 4)),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i == 1) const SizedBox(width: 5),
              Container(
                width: 7,
                height: 18,
                decoration: BoxDecoration(
                  color: Palette.hazard,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Palette.outline, width: 1.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
