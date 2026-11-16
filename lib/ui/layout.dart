import 'package:flutter/widgets.dart';

/// Screen shape helpers shared by every page, so portrait and landscape
/// are decided the same way everywhere.
///
/// Portrait = taller than wide. "Compact" = a phone (short side under
/// [compactShortSide] logical pixels); tablets get roomier sizes.
abstract final class Layout {
  static const double compactShortSide = 500;

  static bool isPortraitSize(Size size) => size.height > size.width;

  static bool isCompactSize(Size size) => size.shortestSide < compactShortSide;
}

/// Shortcuts on [BuildContext] for the whole screen's shape.
extension ScreenShape on BuildContext {
  /// True when the screen is taller than it is wide.
  bool get isPortrait => Layout.isPortraitSize(MediaQuery.sizeOf(this));

  /// True on phone-sized screens.
  bool get isCompact => Layout.isCompactSize(MediaQuery.sizeOf(this));

  /// The screen's short side, for sizing things that must fit both ways.
  double get shortSide => MediaQuery.sizeOf(this).shortestSide;
}

/// Builds [portrait] or [landscape] from the space this widget is given
/// (not the whole screen), so it also works inside panels and in tests.
class OrientationSwitch extends StatelessWidget {
  const OrientationSwitch({
    super.key,
    required this.portrait,
    required this.landscape,
  });

  final WidgetBuilder portrait;
  final WidgetBuilder landscape;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxHeight > constraints.maxWidth
          ? portrait(context)
          : landscape(context),
    );
  }
}
