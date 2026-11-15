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

  /// Warning red (Landing Sight: this landing will crash).
  static const danger = Color(0xFFE5483B);

  /// Smoke for the head's rocket trail.
  static const smoke = Color(0xFF9AA3AC);
}

/// Weather drawn over each level's sky (see `DuskScene`).
enum Weather {
  /// Clear dusk.
  none,

  /// Glowing embers drifting up.
  embers,

  /// Slow banks of green smog.
  smog,

  /// Slanted rain and lightning flashes.
  storm,

  /// Grey ash falling, with embers.
  ash,

  /// Crimson sparks rising.
  crimsonSparks,
}

/// One level's world colours: sky, sun or moon, distant heaps, the hill's
/// dirt, and its weather. The robot and props keep their own colours.
/// Darker and more menacing level by level.
class LevelTheme {
  const LevelTheme({
    required this.skyTop,
    required this.skyMid,
    required this.skyHorizon,
    required this.sun,
    required this.heapFar,
    required this.heapFarLight,
    required this.heapNear,
    required this.dirt,
    required this.dirtHighlight,
    required this.dirtSpeck,
    this.sunSize = 0.16,
    this.eclipse = false,
    this.weather = Weather.none,
  });

  final Color skyTop;
  final Color skyMid;
  final Color skyHorizon;

  /// The sun (or moon) over the horizon, and its radius as a share of the
  /// screen height. [eclipse] covers most of it with a dark disc.
  final Color sun;
  final double sunSize;
  final bool eclipse;

  /// Distant heaps: far layer, its lighter details, near layer.
  final Color heapFar;
  final Color heapFarLight;
  final Color heapNear;

  /// The hill: dirt, its highlight band (the edge you land on) and specks.
  final Color dirt;
  final Color dirtHighlight;
  final Color dirtSpeck;

  final Weather weather;

  /// The theme of [level] (1-based; clamped).
  static LevelTheme of(int level) => all[(level - 1).clamp(0, all.length - 1)];

  /// One theme per level, in order.
  static const List<LevelTheme> all = [
    // 1 Rust Hollow: the dusk of the style test scene.
    LevelTheme(
      skyTop: Palette.skyTop,
      skyMid: Palette.skyMid,
      skyHorizon: Palette.skyHorizon,
      sun: Palette.sun,
      heapFar: Palette.heapFar,
      heapFarLight: Palette.heapFarLight,
      heapNear: Palette.heapNear,
      dirt: Palette.dirt,
      dirtHighlight: Palette.dirtHighlight,
      dirtSpeck: Palette.dirtSpeck,
    ),
    // 2 Cinder Flats: late dusk, a low red sun and embers in the air.
    LevelTheme(
      skyTop: Color(0xFF231C3A),
      skyMid: Color(0xFF8E3B4A),
      skyHorizon: Color(0xFFE0743F),
      sun: Color(0xFFF2945A),
      sunSize: 0.14,
      heapFar: Color(0xFF5A3140),
      heapFarLight: Color(0xFF744256),
      heapNear: Color(0xFF3D2230),
      dirt: Color(0xFF6A3E2C),
      dirtHighlight: Color(0xFFA8653A),
      dirtSpeck: Color(0xFF4A2A1C),
      weather: Weather.embers,
    ),
    // 3 Smog Ridge: night, a sickly moon and green smog.
    LevelTheme(
      skyTop: Color(0xFF10181F),
      skyMid: Color(0xFF2B4639),
      skyHorizon: Color(0xFF6F8E52),
      sun: Color(0xFFD8E6B0),
      sunSize: 0.10,
      heapFar: Color(0xFF26352E),
      heapFarLight: Color(0xFF3A5244),
      heapNear: Color(0xFF17211C),
      dirt: Color(0xFF4E4A36),
      dirtHighlight: Color(0xFF8C8650),
      dirtSpeck: Color(0xFF34311F),
      weather: Weather.smog,
    ),
    // 4 Crusher Pass: a storm, red sky and lightning.
    LevelTheme(
      skyTop: Color(0xFF170F1C),
      skyMid: Color(0xFF481C29),
      skyHorizon: Color(0xFF8E2E2E),
      sun: Color(0xFFC2453A),
      sunSize: 0.08,
      heapFar: Color(0xFF2E1C24),
      heapFarLight: Color(0xFF4A2E3A),
      heapNear: Color(0xFF1C1116),
      dirt: Color(0xFF4A3030),
      dirtHighlight: Color(0xFF85504A),
      dirtSpeck: Color(0xFF2E1C1C),
      weather: Weather.storm,
    ),
    // 5 Furnace Drop: molten sky, black heaps, a glowing edge, ash.
    LevelTheme(
      skyTop: Color(0xFF1E0E08),
      skyMid: Color(0xFF6E1E0A),
      skyHorizon: Color(0xFFF06A1A),
      sun: Color(0xFFFFB040),
      sunSize: 0.2,
      heapFar: Color(0xFF241816),
      heapFarLight: Color(0xFF4A2A1E),
      heapNear: Color(0xFF120B0A),
      dirt: Color(0xFF3A2A26),
      dirtHighlight: Color(0xFFE0662A),
      dirtSpeck: Color(0xFF1E1412),
      weather: Weather.ash,
    ),
    // 6 Obsidian Maw: black and crimson under an eclipse.
    LevelTheme(
      skyTop: Color(0xFF09090E),
      skyMid: Color(0xFF2A0A14),
      skyHorizon: Color(0xFF6E0F1E),
      sun: Color(0xFFD0203A),
      sunSize: 0.18,
      eclipse: true,
      heapFar: Color(0xFF16111A),
      heapFarLight: Color(0xFF3A1622),
      heapNear: Color(0xFF08060A),
      dirt: Color(0xFF1F1A24),
      dirtHighlight: Color(0xFFB0203A),
      dirtSpeck: Color(0xFF0E0C12),
      weather: Weather.crimsonSparks,
    ),
  ];
}
