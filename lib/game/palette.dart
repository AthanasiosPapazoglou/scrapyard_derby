import 'dart:ui';

/// The art palette from CLAUDE.md.
abstract final class Palette {
  static const outline = Color(0xFF2B1D16);

  static const rust = Color(0xFFC4622D);
  static const rustShadow = Color(0xFF8A3B1C);
  static const rustLight = Color(0xFFE39056);

  static const steel = Color(0xFF6B7B8C);
  static const steelDark = Color(0xFF4A5563);
  static const steelLight = Color(0xFFB4C0CB);

  static const hazard = Color(0xFFF2B233);
  static const hazardShadow = Color(0xFFB97F14);

  static const eyeGlow = Color(0xFF5FE3D0);

  // ---------------------------------------------------------------- World
  // Scene colours from the style test scene (art/make_style_test.py).

  /// Dusk sky: top, middle and horizon, plus the low sun.
  static const skyTop = Color(0xFF2E3558);
  static const skyMid = Color(0xFFC9605A);
  static const skyHorizon = Color(0xFFF4B868);
  static const sun = Color(0xFFFCD98A);

  /// Fallback clear colour (the sky gradient normally covers it).
  static const sky = skyMid;

  /// Distant scrap heaps: far layer (with lighter details) and near layer.
  static const heapFar = Color(0xFF6E3F4E);
  static const heapFarLight = Color(0xFF8A5363);
  static const heapNear = Color(0xFF4E2B38);

  /// The hill: dirt fill, its highlight band, and darker specks of junk.
  static const dirt = Color(0xFF7A4A30);
  static const dirtHighlight = Color(0xFFB8743E);
  static const dirtSpeck = Color(0xFF5C3522);

  /// Old rubber (tires).
  static const tire = Color(0xFF3A2A2A);

  /// Light text over the dark sky (with an [outline] edge).
  static const cream = Color(0xFFFFF2D6);

  /// Smoke for the head's rocket trail.
  static const smoke = Color(0xFF9AA3AC);
}
