import '../config/tuning.dart';

/// Looks up levels by number. Level numbers are 1-based: 1 to [count].
/// The numbers themselves live in [Tuning.levels].
abstract final class Levels {
  static int get count => Tuning.levels.length;

  /// The numbers of level [level] (clamped to a real level).
  static LevelTuning of(int level) => Tuning.levels[level.clamp(1, count) - 1];

  /// Stars (0-3) a best distance of [best] meters earns on [level].
  static int starsFor(int level, double best) =>
      of(level).starDistances.where((distance) => best >= distance).length;

  /// Most stars one level can give.
  static const int maxStars = 3;
}
