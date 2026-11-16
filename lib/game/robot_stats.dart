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
    partNames: [
      'Scrap Springs',
      'Coil Hoppers',
      'Racer Springs',
      'Piston Striders',
      'Mag Shocks',
      'Obsidian Steps',
    ],
    specs: [
      PartSpec('Bent bedsprings and baling wire', 'Hope and a lot of tape'),
      PartSpec('Salvaged truck coils', 'Twin-coil hop pistons'),
      PartSpec('Chromed racing steel', 'Tuned rally suspension'),
      PartSpec('Forged iron pistons', 'Hydraulic stride dampers'),
      PartSpec('Neon-lit alloy struts', 'Magnetic levitation shocks'),
      PartSpec('Volcanic obsidian plates', 'Ember-core gravity springs'),
    ],
  ),
  gyroArms(
    id: 'gyroArms',
    name: 'Arms',
    art: 'arms',
    partNames: [
      'Hose Claws',
      'Pipe Grippers',
      'Racer Mitts',
      'Hydraulic Pincers',
      'Gyro Claws',
      'Obsidian Hands',
    ],
    specs: [
      PartSpec('Garden hose and rusty tongs', 'Flail and pray'),
      PartSpec('Plumbing pipe, brass joints', 'Counterweight swing'),
      PartSpec('Carbon racing gloves', 'Quick-shift wrist bearings'),
      PartSpec('Hardened steel pincers', 'Hydraulic balance rams'),
      PartSpec('Neon alloy shell', 'Twin spinning gyroscopes'),
      PartSpec('Polished obsidian knuckles', 'Ember gyro, instant recovery'),
    ],
  ),
  plating(
    id: 'plating',
    name: 'Body',
    art: 'body',
    partNames: [
      'Rust Barrel',
      'Riveted Drum',
      'Racer Chassis',
      'Iron Works Frame',
      'Neon Hull',
      'Obsidian Frame',
    ],
    specs: [
      PartSpec('One oil barrel, mostly rust', 'Dents soak up the hits'),
      PartSpec('Riveted sheet steel', 'Double-wall drum frame'),
      PartSpec('Lightweight racing alloy', 'Crumple-zone roll cage'),
      PartSpec('Foundry-cast iron', 'Shock-mounted girder spine'),
      PartSpec('Neon-lit composite hull', 'Energy-field impact buffer'),
      PartSpec('Obsidian over ember steel', 'Self-bracing crash core'),
    ],
  ),
  rocketHead(
    id: 'rocketHead',
    name: 'Head',
    art: 'head',
    partNames: [
      'Paint Can',
      'Lantern Box',
      'Racer Helmet',
      'Foreman',
      'Neon Visor',
      'Obsidian Grin',
    ],
    specs: [
      PartSpec('An empty paint can', 'Bottle-rocket booster'),
      PartSpec('Tin lantern housing', 'Kerosene burner'),
      PartSpec('Fiberglass race helmet', 'Nitro canister'),
      PartSpec('Hard-hat steel', 'Twin jet nozzles'),
      PartSpec('Neon glass visor', 'Plasma thruster'),
      PartSpec('Obsidian dome', 'Ember afterburner'),
    ],
  ),
  energyCore(
    id: 'energyCore',
    name: 'Core',
    art: 'core',
    partNames: [
      'Patch Battery',
      'Car Battery',
      'Tube Amp',
      'Turbine Core',
      'Plasma Cell',
      'Ember Heart',
    ],
    specs: [
      PartSpec('Patched dry cells', 'Spin-charged dynamo'),
      PartSpec('Lead-acid car battery', 'Alternator spin coil'),
      PartSpec('Glass vacuum tubes', 'Valve-boosted charge'),
      PartSpec('Turbine-grade steel', 'Spin turbine generator'),
      PartSpec('Sealed plasma flask', 'Plasma overdrive loop'),
      PartSpec('Living ember crystal', 'Overdrive heart pulse'),
    ],
  );

  const UpgradeTrack({
    required this.id,
    required this.name,
    required this.art,
    required this.partNames,
    required this.specs,
  });

  /// Key in the saved profile. Never change it, or saves lose the level.
  final String id;

  /// The slot's name, e.g. "Legs".
  final String name;

  /// Art file prefix: `assets/robot/<art>_<tier>.svg`.
  final String art;

  /// The part at each tier (0 = the starting scrap part).
  final List<String> partNames;

  /// Each part's spec sheet (flavor text), by tier.
  final List<PartSpec> specs;

  /// The spec sheet of the part at [level].
  PartSpec spec(int level) => specs[level.clamp(0, specs.length - 1)];

  /// The part installed at [level].
  String partName(int level) => partNames[level.clamp(0, partNames.length - 1)];

  /// Scrap price of the next level after [level], or null when maxed.
  int? priceAfter(int level) =>
      level < Tuning.upgradeMaxLevel ? Tuning.upgradePrices[level] : null;
}

/// A part's spec sheet (1.1.1, D35): what it is made of and how it works.
/// Flavor only; the numbers live in [Tuning]'s tier tables.
@immutable
class PartSpec {
  const PartSpec(this.material, this.tech);

  final String material;
  final String tech;
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
    this.oneFootSpeedKept = Tuning.oneFootSpeedMultiplier,
    this.crashSpeedKept = Tuning.crashSpeedMultiplier,
    this.energyForwardShare = Tuning.energyForwardShare,
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
      oneFootSpeedKept: Tuning.legsGrip[spring],
      crashSpeedKept: Tuning.bodyCrashArmor[plating],
      energyForwardShare: Tuning.coreOverdrive[core],
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

  /// Grip (Legs): share of the speed along the ground kept on a one-foot
  /// landing.
  final double oneFootSpeedKept;

  /// Crash armor (Body): share of the speed along the ground kept on a
  /// crash.
  final double crashSpeedKept;

  /// Overdrive (Core): share of the released energy bounce that also
  /// pushes the robot forward along the ground.
  final double energyForwardShare;

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
}
