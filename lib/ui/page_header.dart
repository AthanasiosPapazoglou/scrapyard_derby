import 'package:flutter/material.dart';

import '../game/palette.dart';
import 'layout.dart';
import 'outlined_text.dart';

/// The top bar of the menu pages: back arrow, big title, and [trailing]
/// counters/buttons on the right. On a narrow screen the trailing part
/// shrinks to fit instead of overflowing, and the title gets smaller.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing = const [],
    this.note,
  });

  final String title;

  /// A short line under the title (e.g. "Upgrades apply to Survival").
  final String? note;
  final VoidCallback onBack;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact && context.isPortrait;
    final row = Padding(
      padding: EdgeInsets.fromLTRB(4, 2, 12, note == null ? 4 : 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Palette.cream, size: 28),
          ),
          OutlinedText(
            title,
            fontSize: compact ? 24 : 28,
            color: Palette.hazard,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: trailing),
              ),
            ),
          ),
        ],
      ),
    );
    final line = note;
    if (line == null) {
      return row;
    }
    // On its own line under the title, so it never squeezes the counts.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(52, 0, 12, 4),
          child: OutlinedText(line, fontSize: 12, color: Palette.cream),
        ),
      ],
    );
  }
}

/// An icon and an outlined number for a [PageHeader], e.g. scrap or stars.
/// [label] (e.g. "Scrap") is dropped on narrow portrait screens.
class HeaderCount extends StatelessWidget {
  const HeaderCount({
    super.key,
    required this.icon,
    required this.text,
    this.label,
  });

  final IconData icon;
  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final showLabel = label != null && !context.isPortrait;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Palette.hazard, size: 22),
          const SizedBox(width: 6),
          OutlinedText(
            showLabel ? '$text $label' : text,
            fontSize: 22,
            color: Palette.cream,
          ),
        ],
      ),
    );
  }
}
