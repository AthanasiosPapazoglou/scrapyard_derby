import 'package:flutter/foundation.dart';

import '../config/tuning.dart';
import 'gadgets.dart';

/// The five Workshop slots. Each one has six parts (tier 0 = the scrap
/// robot's own, tiers 1-5 to buy); a better part looks more high-tech and
/// improves the robot (see [RobotStats]). The art comes from
/// `art/make_parts.py` as `assets/robot/<art>_<tier>.svg`.
enum UpgradeTrack {
  springLegs(
    id: 'springLegs',
    name: 'Legs',
    art: 'legs',
    description: 'Bouncier clean landings, and a wider angle counts as clean.',
    partNames: [
      'Scrap Springs',
      'Coil Hoppers',
      'Racer Springs',
      'Piston Striders',
      'Mag Shocks',
      'Obsidian Steps',
    ],
  ),
  gyroArms(
    id: 'gyroArms',
    name: 'Arms',
    art: 'arms',
    description: 'Faster spin control when you hold and let go.',
    partNames: [
      'Hose Claws',
      'Pipe Grippers',
      'Racer Mitts',
      'Hydraulic Pincers',
      'Gyro Claws',
      'Obsidian Hands',
    ],
  ),
  plating(
    id: 'plating',
    name: 'Body',
    art: 'body',
    description: 'Tougher frame: more damage before each limb breaks.',
    partNames: [
      'Rust Barrel',
      'Riveted Drum',
      'Racer Chassis',
      'Iron Works Frame',
      'Neon Hull',
      'Obsidian Frame',
    ],
  ),
  rocketHead(
    id: 'rocketHead',
    name: 'Head',
    art: 'head',
    description: 'A faster head launch and a longer rocket burn.',
    partNames: [
      'Paint Can',
      'Lantern Box',
      'Racer Helmet',
      'Foreman',
      'Neon Visor',
      'Obsidian Grin',
    ],
  ),
  energyCore(
    id: 'energyCore',
    name: 'Core',
    art: 'core',
    description: 'More energy per spin, and a bigger energy tank.',
    partNames: [
      'Patch Battery',
      'Car Battery',
      'Tube Amp',
      'Turbine Core',
      'Plasma Cell',
      'Ember Heart',
    ],
  );

  const UpgradeTrack({
    required this.id,
    required this.name,
    required this.art,
    required this.description,
    required this.partNames,
  });

  /// Key in the saved profile. Never change it, or saves lose the level.
  final String id;

  /// The slot's name, e.g. "Legs".
  final String name;

  /// Art file prefix: `assets/robot/<art>_<tier>.svg`.
  final String art;

  /// What better parts in this slot do.
  final String description;

  /// The part at each tier (0 = the starting scrap part).
  final List<String> partNames;

  /// The part installed at [level].
  String partName(int level) => partNames[level.clamp(0, partNames.length - 1)];

  /// Scrap price of the next level after [level], or null when maxed.
  int? priceAfter(int level) =>
      level < Tuning.upgradeMaxLevel ? Tuning.upgradePrices[level] : null;
}

/// The robot's effective numbers: the [Tuning] base values changed by
/// upgrade levels. Robot, damage, spin, landing and head-launch code read
/// the upgradeable values from here instead of from [Tuning] directly.
///
/// [RobotStats.base] (all levels 0) equals the plain robot exactly.
@immutable
class RobotStats {
  const RobotStats({
    this.limbMaxHp = Tuning.limbMaxHp,
    this.cleanBounce = Tuning.cleanBounce,
    this.cleanToleranceDeg = Tuning.cleanLandingToleranceDeg,
    this.counterSpinTime = Tuning.counterSpinTime,
    this.releaseSpinTime = Tuning.releaseSpinTime,
    this.spinEnergyPerTurn = Tuning.spinEnergyPerTurn,
    this.spinEnergyMaxTurns = Tuning.spinEnergyMaxTurns,
    this.maxEnergyBounce = Tuning.coreMaxExtraBounce,
    this.headLaunchScale = 1,
    this.headRocketBurnTime = Tuning.headRocketBurnTime,
    this.headRocketThrust = Tuning.headRocketThrust,
    this.landingSightTime = Tuning.landingSightTime,
    this.comboCoilSteps = 0,
    this.scrapMagnet = 0,
    this.autoGyroWindow = 0,
    this.landingDamageScale = 1,
    this.crashCageCrashes = 0,
    this.levelerSpan = 0,
  });

  /// The plain robot, no upgrades.
  static const RobotStats base = RobotStats();

  /// Stats for the given upgrade levels (missing tracks = level 0; levels
  /// are clamped to 0..[Tuning.upgradeMaxLevel]), read from the per-tier
  /// tables in [Tuning] (Upgrades section), and [gadgets] levels
  /// (missing = not owned).
  factory RobotStats.fromLevels(
    Map<UpgradeTrack, int> levels, {
    Map<Gadget, int> gadgets = const {},
  }) {
    // The tier installed in a slot, as an index into the Tuning tables.
    int tier(UpgradeTrack track) =>
        (levels[track] ?? 0).clamp(0, Tuning.upgradeMaxLevel);

    final plating = tier(UpgradeTrack.plating);
    final spring = tier(UpgradeTrack.springLegs);
    final gyro = tier(UpgradeTrack.gyroArms);
    final core = tier(UpgradeTrack.energyCore);
    final rocket = tier(UpgradeTrack.rocketHead);

    int owned(Gadget gadget) =>
        (gadgets[gadget] ?? 0).clamp(0, Tuning.gadgetMaxLevel);
    double perLevel(List<double> values, Gadget gadget) =>
        owned(gadget) == 0 ? 0 : values[owned(gadget) - 1];

    final gyroShare = Tuning.gyroTimeShare[gyro];
    return RobotStats(
      limbMaxHp: Tuning.platingHp[plating],
      cleanBounce: Tuning.cleanBounce * Tuning.springBounceScale[spring],
      cleanToleranceDeg: Tuning.springToleranceDeg[spring],
      counterSpinTime: Tuning.counterSpinTime * gyroShare,
      releaseSpinTime: Tuning.releaseSpinTime * gyroShare,
      spinEnergyPerTurn:
          Tuning.spinEnergyPerTurn * Tuning.corePerTurnScale[core],
      spinEnergyMaxTurns: Tuning.coreTankTurns[core],
      headLaunchScale: Tuning.rocketSpeedScale[rocket],
      headRocketBurnTime: Tuning.rocketBurnTime[rocket],
      headRocketThrust: Tuning.rocketThrust[rocket],
      comboCoilSteps: owned(Gadget.comboCoil) == 0
          ? 0
          : Tuning.comboCoilMaxSteps[owned(Gadget.comboCoil) - 1],
      scrapMagnet: Tuning.scrapMagnetPerLevel * owned(Gadget.scrapMagnet),
      autoGyroWindow: perLevel(Tuning.autoGyroWindows, Gadget.autoGyro),
      landingDamageScale:
          1 - Tuning.shockPadsPerLevel * owned(Gadget.shockPads),
      crashCageCrashes: Tuning.crashCagePerLevel * owned(Gadget.crashCage),
      levelerSpan: perLevel(Tuning.levelerSpans, Gadget.levelerTreads),
    );
  }

  /// Stats for a profile's saved levels, looked up by track id (and
  /// gadget id).
  factory RobotStats.fromLevelOf(
    int Function(String trackId) levelOf, {
    int Function(String gadgetId)? gadgetLevelOf,
  }) => RobotStats.fromLevels(
    {for (final track in UpgradeTrack.values) track: levelOf(track.id)},
    gadgets: {
      if (gadgetLevelOf != null)
        for (final gadget in Gadget.values) gadget: gadgetLevelOf(gadget.id),
    },
  );

  /// Damage between one part breaking and the next (see damage.dart).
  final double limbMaxHp;

  /// Bounce speed (m/s) of a clean landing.
  final double cleanBounce;

  /// Max angle (deg) that still counts as a clean landing.
  final double cleanToleranceDeg;

  /// Seconds of holding from full clockwise to full counter-clockwise, and
  /// of letting go to come back (see spin.dart).
  final double counterSpinTime;
  final double releaseSpinTime;

  /// Extra bounce (m/s) per turn of spin energy, and the most turns one
  /// airtime can gather.
  final double spinEnergyPerTurn;
  final double spinEnergyMaxTurns;

  /// Hard cap on the extra bounce from spin energy (m/s).
  final double maxEnergyBounce;

  /// Multiplier on the head launch speed (and its cap).
  final double headLaunchScale;

  /// Seconds of rocket burn after the head launch.
  final double headRocketBurnTime;

  /// Rocket push (m/s²) during the burn.
  final double headRocketThrust;

  /// Landing Sight (built in): seconds before touchdown the predicted
  /// landing shows. Settings can hide it.
  final double landingSightTime;

  // Gadgets (0 / 1 = off).

  /// Combo Coil: most clean landings in a row that add a bonus step.
  final int comboCoilSteps;

  /// Scrap Magnet: extra scrap share, e.g. 0.2 = +20%.
  final double scrapMagnet;

  /// Auto-Gyro: seconds before touchdown it may hold for the player.
  final double autoGyroWindow;

  /// Shock Pads: multiplier on one-foot and crash damage.
  final double landingDamageScale;

  /// Crash Cage: crashes per run that cost no damage.
  final int crashCageCrashes;

  /// Leveler Treads: meters of ground averaged for the landing check.
  final double levelerSpan;

  /// A short "now" value for the Workshop, e.g. "115 HP".
  String summary(UpgradeTrack track) => switch (track) {
    UpgradeTrack.plating => '${limbMaxHp.round()} HP per part',
    UpgradeTrack.springLegs =>
      '${cleanBounce.toStringAsFixed(1)} m/s, '
          '${cleanToleranceDeg.round()}°',
    UpgradeTrack.gyroArms => '${counterSpinTime.toStringAsFixed(2)} s flip',
    UpgradeTrack.energyCore =>
      '+${spinEnergyPerTurn.toStringAsFixed(1)}/turn, '
          '${spinEnergyMaxTurns.toStringAsFixed(2)} max',
    UpgradeTrack.rocketHead =>
      '×${headLaunchScale.toStringAsFixed(2)}, '
          '${headRocketBurnTime.toStringAsFixed(2)} s burn',
  };
}
