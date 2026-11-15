import 'dart:ui';

/// Colours of the green retro-CRT screens (robot status panel, Workshop).
abstract final class Crt {
  static const background = Color(0xE00B1A10);
  static const green = Color(0xFF5CFF9A);
  static const dim = Color(0xFF1E5A35);
  static const amber = Color(0xFFF2B233);
  static const red = Color(0xFFFF5A4A);

  /// Very dark green, e.g. the robot's eye on the screen.
  static const ink = Color(0xFF0B1A10);

  /// Faint horizontal lines over the screen.
  static const scanline = Color(0x1A5CFF9A);

  static const String font = 'Menlo';
}
