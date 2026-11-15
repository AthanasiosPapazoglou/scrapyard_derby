import '../config/tuning.dart';

/// Extra helpers from the Workshop's Gadgets tab, separate from the five
/// part slots. Each has [Tuning.gadgetMaxLevel] levels and opens for sale
/// once its [unlockLevel] is unlocked. They mostly help players who
/// struggle with landings. Effects are read through `RobotStats`.
enum Gadget {
  landingSight(
    id: 'landingSight',
    name: 'Landing Sight',
    description: 'Shows how you will land: green = clean, amber = one foot.',
    unlockLevel: 1,
  ),
  scrapMagnet(
    id: 'scrapMagnet',
    name: 'Scrap Magnet',
    description: 'Pulls in extra scrap after every run.',
    unlockLevel: 1,
  ),
  autoGyro(
    id: 'autoGyro',
    name: 'Auto-Gyro',
    description: 'Holds for you just before a bad landing, if that helps.',
    unlockLevel: 2,
  ),
  shockPads(
    id: 'shockPads',
    name: 'Shock Pads',
    description: 'Less damage from one-foot landings and crashes.',
    unlockLevel: 3,
  ),
  crashCage(
    id: 'crashCage',
    name: 'Crash Cage',
    description: 'The first crashes of every run cost no damage.',
    unlockLevel: 4,
  ),
  levelerTreads(
    id: 'levelerTreads',
    name: 'Leveler Treads',
    description: 'Sharp bumps count less when judging a landing.',
    unlockLevel: 5,
  );

  const Gadget({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockLevel,
  });

  /// Key in the saved profile. Never change it, or saves lose the level.
  final String id;
  final String name;
  final String description;

  /// The level (1-based) that has to be unlocked before it is for sale.
  final int unlockLevel;

  /// Scrap price of the level after [level], or null when maxed.
  int? priceAfter(int level) =>
      level < Tuning.gadgetMaxLevel ? Tuning.gadgetPrices[id]![level] : null;

  /// What the gadget does at [level] (0 = not owned), e.g. "+20% scrap".
  String effect(int level) {
    if (level <= 0) {
      return 'Not owned';
    }
    final i = level.clamp(1, Tuning.gadgetMaxLevel) - 1;
    return switch (this) {
      landingSight =>
        level >= Tuning.gadgetMaxLevel
            ? 'Shown the whole flight'
            : 'Shown ${Tuning.landingSightTimes[i]} s before landing',
      scrapMagnet =>
        '+${(Tuning.scrapMagnetPerLevel * level * 100).round()}% scrap',
      autoGyro => 'Helps in the last ${Tuning.autoGyroWindows[i]} s',
      shockPads =>
        '−${(Tuning.shockPadsPerLevel * level * 100).round()}% landing damage',
      crashCage =>
        '${Tuning.crashCagePerLevel * level} free '
            '${Tuning.crashCagePerLevel * level == 1 ? 'crash' : 'crashes'} per run',
      levelerTreads =>
        'Ground averaged over ${Tuning.levelerSpans[i].toStringAsFixed(0)} m',
    };
  }
}
