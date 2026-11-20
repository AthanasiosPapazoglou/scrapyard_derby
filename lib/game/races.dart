import '../config/tuning.dart';
import 'gadgets.dart';
import 'levels.dart';
import 'robot_stats.dart';

/// Looks up Versus races by number. Race numbers are 1-based: 1 to
/// [count]. The numbers themselves live in [Tuning.versusRaces].
abstract final class Races {
  static int get count => Tuning.versusRaces.length;

  /// Racers in one race: the player and the rivals.
  static const int racers = 4;

  /// The numbers of race [race] (clamped to a real race).
  static RaceTuning of(int race) =>
      Tuning.versusRaces[race.clamp(1, count) - 1];

  /// The level hill race [race] is run on.
  static LevelTuning levelOf(int race) => Levels.of(of(race).level);

  /// The race gear's part tier in [track]'s slot (every slot the same).
  static int tierOf(int race, UpgradeTrack track) => of(race).partTier;

  /// The race gear's gadget levels.
  static Map<Gadget, int> gadgetsOf(int race) => {
    for (final gadget in Gadget.values) gadget: ?of(race).gadgets[gadget.id],
  };

  /// The robot's numbers with race [race]'s gear (player and rivals).
  static RobotStats statsOf(int race) => RobotStats.fromLevels({
    for (final track in UpgradeTrack.values) track: tierOf(race, track),
  }, gadgets: gadgetsOf(race));

  /// "1st", "2nd", "3rd", "4th".
  static String placeLabel(int place) => switch (place) {
    1 => '1st',
    2 => '2nd',
    3 => '3rd',
    _ => '${place}th',
  };
}
