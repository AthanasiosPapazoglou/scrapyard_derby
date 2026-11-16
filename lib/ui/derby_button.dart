import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../game/sound.dart';

/// The chunky cutout-style button used in menus: flat fill, thick ink
/// outline. [primary] buttons are hazard yellow, others are ink.
/// A null [onPressed] shows the button greyed out, with [disabledNote]
/// (e.g. "soon") under the label.
class DerbyButton extends StatelessWidget {
  const DerbyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.big = false,
    this.disabledNote,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool big;
  final String? disabledNote;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fill = !enabled
        ? Palette.steel
        : (primary ? Palette.hazard : Palette.outline);
    final text = !enabled
        ? Palette.steelLight
        : (primary ? Palette.outline : Palette.hazard);
    final fontSize = big ? 24.0 : 17.0;
    final action = onPressed;
    return FilledButton(
      onPressed: action == null
          ? null
          : () {
              Sound.play(Sfx.uiClick);
              action();
            },
      style: FilledButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: text,
        disabledBackgroundColor: fill,
        disabledForegroundColor: text,
        padding: EdgeInsets.symmetric(
          horizontal: big ? 40 : 22,
          vertical: big ? 14 : 10,
        ),
        side: const BorderSide(color: Palette.outline, width: 3),
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 4),
                const SizedBox(width: 6),
              ],
              // Shrinks rather than overflowing on narrow screens.
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
              ),
            ],
          ),
          if (!enabled && disabledNote != null)
            Text(
              disabledNote!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}
