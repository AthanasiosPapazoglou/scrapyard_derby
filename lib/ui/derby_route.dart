import 'package:flutter/widgets.dart';

/// The one page transition used everywhere: a quick cross-fade.
///
/// Replaces `MaterialPageRoute`, whose iOS slide moved custom-painted
/// pages (and a running game) side by side and could show seams or a
/// flash of the wrong background mid-slide. Every page paints an opaque
/// background, so a fade never shows anything underneath.
class DerbyRoute<T> extends PageRouteBuilder<T> {
  DerbyRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
      );
}
