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

  /// Sky colour behind the hill (not in the brief; a pale warm tone).
  static const sky = Color(0xFFF4E6CF);

  /// Sky gradient: top and near the horizon (warm, dusty haze).
  static const skyTop = Color(0xFFF8EEDC);
  static const skyHorizon = Color(0xFFEBCBA2);

  /// Smoke for the head's rocket trail.
  static const smoke = Color(0xFF9AA3AC);
}
