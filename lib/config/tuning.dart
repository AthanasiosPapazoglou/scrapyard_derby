/// Every tunable gameplay number lives here.
///
/// Units: the physics world is in meters, with y pointing DOWN (like the
/// screen). Angles are in degrees here for readability and converted to
/// radians where they are used. Speeds are meters per second.
abstract final class Tuning {
  // ---------------------------------------------------------------- World
  /// Downward gravity in m/s². Close to Earth's, so jumps are long and
  /// floaty for a calm, "flow" feel (was 18).
  static const double gravity = 11.0;

  /// Overall game speed: 1 = normal, 0.75 = everything (physics, spin,
  /// timers, camera) runs at 75% speed. All other times in this file are in
  /// game time, so e.g. a 0.2 s game-time ramp takes 0.27 s on the clock.
  static const double gameSpeed = 0.75;

  /// Physics sub-steps per frame. More = more stable joints, slower.
  static const int physicsSubSteps = 4;

  /// Art pixels per physics meter. The robot art (and joint positions in
  /// CLAUDE.md) is in pixels; divide by this to get meters.
  static const double artPixelsPerMeter = 100.0;

  // ---------------------------------------------------------------- Robot shape (art pixels)
  // Collision shapes, matched to the sprites in assets/robot/ (drawn by
  // art/make_style_test.py). Change these together with the art.

  /// Half width / half height of the torso box.
  static const double torsoHalfWidth = 61.0;
  static const double torsoHalfHeight = 78.0;

  /// Head circle radius, and how far its center sits above the neck pivot.
  /// (The art is a paint can; a circle keeps the launched head rolling and
  /// landing cleanly.)
  static const double headRadius = 38.0;
  static const double headOffset = 40.0;

  /// Arm capsule: length from the shoulder pivot, and thickness (radius).
  static const double armLength = 80.0;
  static const double armRadius = 13.0;

  /// Leg capsule: length from the hip pivot, and thickness (radius).
  static const double legLength = 64.0;
  static const double legRadius = 11.0;

  /// Foot box below each leg: half width, half height, and its center
  /// relative to the hip (the tread foot sticks out a bit to the front).
  static const double footHalfWidth = 29.0;
  static const double footHalfHeight = 9.0;
  static const double footCenterX = 5.0;
  static const double footCenterY = 71.0;

  /// Debug: draw the collision shapes as outlines on top of the sprites.
  static const bool debugShowPhysicsShapes = false;

  // ---------------------------------------------------------------- Robot mass and joints
  /// Density of each part (mass = area × density). Torso heavier = steadier.
  static const double torsoDensity = 1.0;
  static const double headDensity = 0.6;
  static const double limbDensity = 0.6;

  /// Ground friction for robot parts (0 = ice, 1 = rubber).
  static const double robotFriction = 0.5;

  /// How far each joint may swing either way from rest, in degrees.
  static const double neckLimitDeg = 15.0;
  static const double shoulderLimitDeg = 60.0;
  static const double hipLimitDeg = 25.0;

  /// Spring pulling limbs back to their rest pose: stiffness (Hz) and
  /// damping (0 = wobbly forever, 1 = no overshoot).
  static const double jointSpringHertz = 8.0;
  static const double jointSpringDamping = 0.6;

  // ---------------------------------------------------------------- Spin
  /// Full spin speed of the robot, in radians per second. The robot spins
  /// clockwise at this speed by default. Slow and calm: roughly one turn
  /// per clean jump (was 3.85).
  static const double spinSpeed = 2.2;

  /// Holding a finger on the screen applies counter-spin: the spin slows,
  /// stops, then builds up counter-clockwise. Seconds of holding to go from
  /// full clockwise to full counter-clockwise speed.
  static const double counterSpinTime = 0.2;

  /// Seconds after letting go to go from full counter-clockwise back to
  /// full clockwise speed.
  static const double releaseSpinTime = 0.3;

  // ---------------------------------------------------------------- Spin energy
  /// Every full turn the robot makes in the air (either direction) gathers
  /// one unit of energy. On every landing, whatever kind, ALL gathered
  /// energy is released into that bounce, adding this much (m/s) per unit;
  /// then the next airtime gathers from zero. More spins = higher launch.
  static const double spinEnergyPerTurn = 4.0;

  /// Most energy (in turns) one airtime can gather. Caps the extra bounce
  /// at spinEnergyMaxTurns × spinEnergyPerTurn = +8 m/s: jumps go from
  /// ≈ 8 m to at most ≈ 21 m high, and no more.
  static const double spinEnergyMaxTurns = 2.0;

  /// How hard the robot holds its wanted spin speed (rad/s²), e.g. to
  /// recover after scraping the ground. This is NOT the hold/release speed.
  static const double spinAcceleration = 100.0;

  // ---------------------------------------------------------------- Landings
  /// Max angle (deg) between robot "up" and the ground normal that still
  /// counts as a clean two-foot landing.
  static const double cleanLandingToleranceDeg = 25.0;

  /// Max angle (deg) for a one-foot landing. Beyond this, a foot touching
  /// down is a crash.
  static const double oneFootToleranceDeg = 50.0;

  /// Minimum time in the air (s) before a touch-down counts as a landing.
  /// Stops tiny hops and rolling from triggering landings constantly.
  static const double minAirTime = 0.2;

  /// Clean landing: bounce speed away from the ground (m/s), multiplier on
  /// speed along the ground, and a flat speed bonus added on top (m/s).
  /// Jump height = bounce² / (2 × gravity): 13.5 m/s with gravity 11 gives
  /// jumps about 8 m high, ~2.4 s in the air (before spin energy).
  static const double cleanBounce = 13.5;
  static const double cleanSpeedMultiplier = 1.05;
  static const double cleanSpeedBonus = 1.5;

  /// One-foot landing: weaker bounce and a speed loss.
  static const double oneFootBounce = 8.5;
  static const double oneFootSpeedMultiplier = 0.85;

  /// Crash (head, torso, arm or a badly angled foot): small bounce, big loss.
  static const double crashBounce = 5.0;
  static const double crashSpeedMultiplier = 0.55;

  /// Hard cap on the robot's speed (m/s), so it can't run away.
  static const double maxRobotSpeed = 28.0;

  // ---------------------------------------------------------------- Hill
  /// Overall slope of the hill in degrees.
  static const double hillSlopeDeg = 35.0;

  /// The hill is endless: it is built in chunks of this many meters
  /// (horizontal), a few ahead of the robot, and removed once passed.
  static const double hillChunkLength = 50.0;

  /// How many chunks to keep built ahead of / behind the robot's chunk.
  static const int hillChunksAhead = 2;
  static const int hillChunksBehind = 1;

  /// Distance (m) between hill points. Smaller = smoother, more segments.
  static const double hillPointSpacing = 1.0;

  /// Bumps are a sum of sine waves: height (m) and wavelength (m) of each.
  /// Keep them small enough that the ground never slopes uphill, or the
  /// robot gets stuck in dips (test/hill_test.dart checks this).
  static const List<double> bumpAmplitudes = [0.8, 0.3, 0.1];
  static const List<double> bumpWavelengths = [23.0, 11.0, 5.3];

  /// Distance (m) over which bumps fade in from x = 0, so the first landing
  /// is on a smooth slope.
  static const double bumpFadeIn = 12.0;

  /// Random seed for bump phases: same seed = same hill every run.
  static const int hillSeed = 7;

  /// Ground friction for the hill.
  static const double hillFriction = 0.6;

  // ---------------------------------------------------------------- Robot start
  /// Horizontal position (m) where the robot is dropped onto the slope.
  static const double startX = 4.0;

  /// Height (m) above the slope the robot is dropped from at the start
  /// (measured from its feet, along the slope's normal). It starts tilted to
  /// match the slope and only begins spinning once it touches down, so the
  /// first landing is a clean one. Was 0.4.
  static const double startDropHeight = 8.0;

  // ---------------------------------------------------------------- Limb damage
  // Damage is linear: every landing adds to one shared total, and parts
  // break in a fixed order (left arm, right arm, left leg, right leg),
  // whatever part hit the ground. See lib/game/damage.dart.

  /// Damage between one part breaking and the next. The left arm breaks at
  /// 100, the right arm at 200, the left leg at 300, the right leg at 400.
  static const double limbMaxHp = 100.0;

  /// Damage added by a crash landing.
  static const double crashDamage = 45.0;

  /// Damage added by a one-foot landing.
  static const double oneFootDamage = 20.0;

  /// Damage added by a clean landing (wear and tear; was 3 on each of the
  /// two legs).
  static const double cleanLandingDamage = 6.0;

  /// Seconds a broken-off part stays on the track before disappearing. It
  /// fades out over this time.
  static const double debrisLifetime = 3.0;

  /// Speed (m/s) a broken-off part is flung away from the torso with, so
  /// it clearly separates instead of looking still attached.
  static const double debrisKick = 4.0;

  // ---------------------------------------------------------------- Head launch
  /// When only the torso and head are left, the next landing fires the head
  /// off like a rocket (the torso stays behind as debris). The run ends the
  /// moment the head first touches the ground; the distance is measured
  /// there.
  ///
  /// Launch speed (m/s) = (base + robot speed × factor) × angle factor,
  /// capped at max. The angle factor is 1 when landing upright and
  /// [headLaunchMinAngleFactor] when sideways or upside down.
  static const double headLaunchBaseSpeed = 20.0;
  static const double headLaunchSpeedFactor = 0.6;
  static const double headLaunchMaxSpeed = 36.0;
  static const double headLaunchMinAngleFactor = 0.6;

  /// How strongly the launch is bent away from the ground (on top of the
  /// direction the robot faces). Higher = steeper, more rocket-like.
  static const double headLaunchUpBias = 1.5;

  /// After launch, a rocket burn keeps pushing the head along its flight
  /// for this many seconds, with this acceleration (m/s²).
  static const double headRocketBurnTime = 0.5;
  static const double headRocketThrust = 20.0;

  /// Ground touches in the first moments after launch don't end the run
  /// (the head starts right next to the ground). Seconds.
  static const double headLandingGrace = 0.3;

  /// If the robot is down to torso + head but keeps sliding on the ground
  /// without a proper landing, the head launches anyway after this long (s).
  static const double headLaunchGroundDelay = 0.6;

  // ---------------------------------------------------------------- Run end
  /// The run ends when the launched head first touches the ground, or when
  /// the robot stays slower than [stallSpeed] (m/s) for [stallTime] seconds.
  static const double stallSpeed = 1.5;
  static const double stallTime = 2.5;

  // ---------------------------------------------------------------- Camera
  /// How many meters of world are visible across the screen when still.
  static const double cameraBaseWidth = 26.0;

  /// Extra visible meters per m/s of speed (zoom out when fast).
  static const double cameraZoomPerSpeed = 0.45;

  /// The camera always keeps both the robot and the ground right below it
  /// on screen: the higher the robot, the further it zooms out, and it
  /// zooms back in as the robot comes down. This is the empty space (m)
  /// kept above the robot and below the ground.
  static const double cameraGroundMargin = 4.0;

  /// How far between robot (0) and the ground below it (1) the camera
  /// centers when the robot is high up. 0.5 = exactly halfway. Once the
  /// head is launched, the camera centers on the head (0) instead.
  static const double cameraGroundBias = 0.5;

  /// Max visible width (m) when zoomed fully out.
  static const double cameraMaxWidth = 110.0;

  /// How quickly the camera catches up (higher = tighter follow).
  static const double cameraFollowSharpness = 6.0;

  /// Tighter follow while the launched head is flying, so the fast rocket
  /// stays centered on screen.
  static const double cameraHeadFollowSharpness = 14.0;

  /// How quickly zoom changes (higher = snappier).
  static const double cameraZoomSharpness = 4.0;

  /// How far ahead the camera looks, in seconds of current velocity.
  static const double cameraLookAhead = 0.25;

  /// Share of the screen height at the top kept clear for the distance
  /// counter, so the robot is never drawn behind it.
  static const double cameraHudReserve = 0.18;

  // ---------------------------------------------------------------- Juice
  // Visual and touch feedback. None of these change the physics.

  /// Sparks on a clean landing: how many, how fast (m/s), how long (s).
  static const int sparkCount = 14;
  static const double sparkSpeed = 7.0;
  static const double sparkLifetime = 0.4;

  /// Dust puffs on one-foot landings and crashes: count and lifetime (s).
  static const int dustCount = 10;
  static const double dustLifetime = 0.7;

  /// Screen shake strength (m) per landing type and on limb loss/launch.
  /// It fades out at [shakeDecay] per second.
  static const double shakeClean = 0.08;
  static const double shakeOneFoot = 0.2;
  static const double shakeCrash = 0.6;
  static const double shakeLimbLost = 0.5;
  static const double shakeHeadLaunch = 0.8;
  static const double shakeDecay = 7.0;

  /// Bits of scrap thrown off when a limb breaks.
  static const int limbBreakBits = 8;

  /// Slow motion on head launch: the game runs at this speed share right
  /// after the launch and eases back to normal over this many real seconds.
  static const double headLaunchSlowMo = 0.3;
  static const double headLaunchSlowMoTime = 1.0;

  /// Smoke puffs behind the flying head: seconds between puffs during the
  /// rocket burn and after it, and how long a puff lasts.
  static const double smokeIntervalBurn = 0.03;
  static const double smokeIntervalCoast = 0.09;
  static const double smokeLifetime = 0.9;

  /// Wait after the run ends before the "new best" jingle plays.
  static const Duration newBestSoundDelay = Duration(milliseconds: 600);

  /// Phone vibration on landings, limb loss and launch (no effect in the
  /// iOS Simulator). Only the default: the player's Settings decide.
  static const bool hapticsEnabled = true;

  // ---------------------------------------------------------------- Scrap
  // Currency earned at the end of each run (see scrap_reward.dart).

  /// 1 scrap per this many meters of distance.
  static const double scrapMetersPerScrap = 10;

  /// Bonus per clean (both feet) landing.
  static const int scrapPerCleanLanding = 2;

  /// 1 scrap per this many meters the launched head flies.
  static const double scrapHeadFlightMetersPerScrap = 5;

  /// Bonus for beating the best distance.
  static const int scrapNewBestBonus = 25;

  // ---------------------------------------------------------------- Upgrades
  // Workshop upgrades (see lib/game/robot_stats.dart). Each track has
  // [upgradeMaxLevel] levels; level 0 is the plain robot above. Every
  // effect also has a hard cap, so no upgrade can break the physics.

  static const int upgradeMaxLevel = 5;

  /// Scrap price of each level (index 0 = buying level 1).
  static const List<int> upgradePrices = [50, 120, 250, 450, 750];

  /// Plating (body): limb HP (damage between part breaks) +15% per level.
  static const double platingHpPerLevel = 0.15;
  static const double platingHpMax = 180.0;

  /// Spring legs: clean bounce +6% and clean-landing tolerance +2° per level.
  static const double springBouncePerLevel = 0.06;
  static const double springBounceMax = 18.0;
  static const double springTolerancePerLevel = 2.0;
  static const double springToleranceMax = 36.0;

  /// Gyro arms: counter-spin and release times −10% per level (faster
  /// control), never below this share of the base times.
  static const double gyroTimePerLevel = 0.10;
  static const double gyroTimeMinShare = 0.5;

  /// Energy core: spin energy per turn +10% and energy cap +0.25 turn per
  /// level. The total extra bounce from spin energy is capped (m/s).
  static const double corePerTurnPerLevel = 0.10;
  static const double coreCapPerLevel = 0.25;
  static const double coreMaxExtraBounce = 16.0;

  /// Rocket head: launch speed +8% and rocket burn +0.08 s per level.
  static const double rocketSpeedPerLevel = 0.08;
  static const double rocketSpeedMaxScale = 1.4;
  static const double rocketBurnPerLevel = 0.08;
  static const double rocketBurnMax = 0.9;

  // ---------------------------------------------------------------- Background
  /// Parallax layers of distant scrap heaps, far to near: how much each
  /// moves with the camera (0 = not at all, 1 = like the ground).
  static const List<double> parallaxFactors = [0.04, 0.09, 0.16];

  /// Where the distant horizon sits, as a share of the screen height.
  static const double horizonHeight = 0.62;

  /// Scrap props lying on the slope: average spacing (m) between them.
  static const double propSpacing = 9.0;
}
