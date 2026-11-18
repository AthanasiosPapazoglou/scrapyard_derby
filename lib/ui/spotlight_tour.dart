import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../profile/page_tour.dart';
import '../profile/player_profile.dart';

/// One stop of a page tour: what to point at ([target], a key on that
/// widget) and what to say about it.
@immutable
class TourStep {
  const TourStep({
    required this.target,
    required this.title,
    required this.text,
  });

  final GlobalKey target;
  final String title;
  final String text;
}

/// A first-visit spotlight tour over [child]: the page dims except a
/// rounded hole around each step's target, with a short card next to it.
/// Tap anywhere for the next step; SKIP ends it. Shown once per [tour]
/// (saved in the profile; Settings > How to play shows it again).
///
/// [active] lets a page start its tour later (the Workshop's Gadgets tab
/// starts its tour when first opened).
class SpotlightTour extends StatefulWidget {
  const SpotlightTour({
    super.key,
    required this.tour,
    required this.profile,
    required this.steps,
    required this.child,
    this.active = true,
  });

  final PageTour tour;
  final PlayerProfile profile;
  final List<TourStep> steps;
  final Widget child;
  final bool active;

  /// Wait after the page appears (its fade-in) before the tour starts.
  static const Duration startDelay = Duration(milliseconds: 450);

  @override
  State<SpotlightTour> createState() => _SpotlightTourState();
}

class _SpotlightTourState extends State<SpotlightTour> {
  /// The step showing, or null when no tour is running.
  int? _step;
  Rect? _hole;
  Size? _measuredFor;
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(SpotlightTour old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _maybeStart();
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    super.dispose();
  }

  void _maybeStart() {
    if (!widget.active ||
        _step != null ||
        widget.steps.isEmpty ||
        widget.profile.tourSeen(widget.tour)) {
      return;
    }
    _start?.cancel();
    _start = Timer(SpotlightTour.startDelay, () => _show(0));
  }

  Future<void> _show(int index) async {
    if (!mounted) {
      return;
    }
    final target = widget.steps[index].target.currentContext;
    if (target == null) {
      // Not on screen (e.g. a narrow layout): skip that step.
      _advance(index);
      return;
    }
    setState(() {
      _step = index;
      _hole = null;
    });
    // Bring it into view if it's in a scrolling list.
    await Scrollable.ensureVisible(
      target,
      alignment: 0.3,
      duration: const Duration(milliseconds: 250),
    );
    _measureSoon();
  }

  void _measureSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final step = _step;
    if (!mounted || step == null) {
      return;
    }
    final box =
        widget.steps[step].target.currentContext?.findRenderObject()
            as RenderBox?;
    final overlay = context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.attached) {
      return;
    }
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    setState(() {
      _hole = rect;
      _measuredFor = overlay.size;
    });
  }

  void _advance(int from) {
    if (from + 1 < widget.steps.length) {
      unawaited(_show(from + 1));
    } else {
      _finish();
    }
  }

  void _finish() {
    widget.profile.markTourSeen(widget.tour);
    if (mounted) {
      setState(() {
        _step = null;
        _hole = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final hole = _hole;
    // Rotation or resize: measure the hole again.
    final size = MediaQuery.sizeOf(context);
    if (step != null && _measuredFor != null && _measuredFor != size) {
      _measuredFor = null;
      _measureSoon();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (step != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _advance(step),
              child: hole == null
                  ? const SizedBox.expand()
                  : _Spotlight(
                      hole: hole,
                      step: widget.steps[step],
                      index: step,
                      count: widget.steps.length,
                      onSkip: _finish,
                    ),
            ),
          ),
      ],
    );
  }
}

class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.hole,
    required this.step,
    required this.index,
    required this.count,
    required this.onSkip,
  });

  final Rect hole;
  final TourStep step;
  final int index;
  final int count;
  final VoidCallback onSkip;

  static const double _gap = 14;
  static const double _cardHeight = 150;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final width = math.min(320.0, screen.width - 24);
        final lit = hole.inflate(6);
        final card = _TourCard(
          step: step,
          index: index,
          count: count,
          onSkip: onSkip,
        );
        // Below, above, or beside the hole, wherever there is room.
        double left(double centerX) =>
            (centerX - width / 2).clamp(12.0, screen.width - width - 12);
        final Widget placed;
        if (screen.height - lit.bottom >= _cardHeight + _gap) {
          placed = Positioned(
            top: lit.bottom + _gap,
            left: left(lit.center.dx),
            width: width,
            child: card,
          );
        } else if (lit.top >= _cardHeight + _gap) {
          placed = Positioned(
            bottom: screen.height - lit.top + _gap,
            left: left(lit.center.dx),
            width: width,
            child: card,
          );
        } else if (screen.width - lit.right >= width + 2 * _gap) {
          placed = Positioned(
            left: lit.right + _gap,
            width: width,
            top: 0,
            bottom: 0,
            child: Center(child: card),
          );
        } else if (lit.left >= width + 2 * _gap) {
          placed = Positioned(
            right: screen.width - lit.left + _gap,
            width: width,
            top: 0,
            bottom: 0,
            child: Center(child: card),
          );
        } else {
          // Nowhere free: over the bottom of the screen.
          placed = Positioned(
            bottom: 16,
            left: (screen.width - width) / 2,
            width: width,
            child: card,
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DimPainter(lit))),
            placed,
          ],
        );
      },
    );
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final cut = RRect.fromRectAndRadius(hole, const Radius.circular(16));
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(cut),
    );
    canvas
      ..drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.62))
      ..drawRRect(
        cut,
        Paint()
          ..color = Palette.hazard
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.count,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int count;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final last = index == count - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
      decoration: BoxDecoration(
        color: Palette.outline.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.hazard, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: const TextStyle(
              color: Palette.hazard,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            step.text,
            style: const TextStyle(
              color: Palette.cream,
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${index + 1} / $count',
                style: TextStyle(
                  color: Palette.cream.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (!last)
                GestureDetector(
                  onTap: onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'SKIP',
                      style: TextStyle(
                        color: Palette.cream.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                last ? 'DONE' : 'NEXT ›',
                style: const TextStyle(
                  color: Palette.hazard,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
