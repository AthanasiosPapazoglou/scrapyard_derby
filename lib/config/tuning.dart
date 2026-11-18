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

  // ---------------------------------------------------------------- Limb motion
  // Arms and legs swing, flail and jiggle (1.1.0, roadmap V8). Purely
  // VISUAL: the sprites turn around their joints, the physics shapes don't,
  // so landings and distances are unchanged. Angles in radians (+ =
  // clockwise on screen).

  /// How the drawn limbs follow their target pose: spring frequency (Hz)
  /// and damping (0 = wobbles forever, 1 = no overshoot). Low damping =
  /// jiggly.
  static const double limbSpringHz = 3.0;
  static const double limbSpringDamping = 0.3;

  /// Never turned further than this from the real limb.
  static const double limbMaxAngle = 0.9;

  /// Arms flail in the air: swing size, swings per second (the two arms
  /// swing opposite), and how far they trail the spin (per rad/s).
  static const double armFlailAngle = 0.55;
  static const double armFlailHz = 1.6;
  static const double armSpinLag = 0.1;

  /// Arms on the ground: a gentle sway.
  static const double armGroundSway = 0.12;

  /// Legs in the air tuck up (feet forward) and kick a little, then reach
  /// out straight in the last [legReachTime] seconds before touchdown.
  static const double legTuckAngle = -0.45;
  static const double legKickAngle = 0.12;
  static const double legKickHz = 2.2;
  static const double legReachTime = 0.35;

  /// Jolts (rad/s) given to every limb by a landing, by type, and by a
  /// sudden change of spin (per rad/s of change).
  static const double limbKickClean = 3.0;
  static const double limbKickOneFoot = 6.0;
  static const double limbKickCrash = 10.0;
  static const double limbKickPerSpinChange = 0.6;

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
  /// one unit of energy. On every landing, ALL gathered energy is used up:
  /// the bounce gets this much (m/s) per unit, times the landing's release
  /// share below; then the next airtime gathers from zero. More spins =
  /// higher launch. (1.0.0: 4 per turn, 2 turns max.)
  static const double spinEnergyPerTurn = 5.0;

  /// Most energy (in turns) one airtime can gather. A full charge adds
  /// 2.5 × 5 = +12.5 m/s to a clean bounce (13.5): nearly double the bounce
  /// speed, jumps ≈ 8 m → ≈ 30 m high.
  static const double spinEnergyMaxTurns = 2.5;

  /// Share of the energy bounce each landing type releases. The landing
  /// angle still matters most: a sloppy landing wastes the charge.
  static const double energyReleaseClean = 1.0;
  static const double energyReleaseOneFoot = 0.6;
  static const double energyReleaseCrash = 0.25;

  /// Share of the released energy bounce that is also added as speed along
  /// the ground (a charged landing shoots you forward too).
  static const double energyForwardShare = 0.25;

  /// Energy at least this share of the tank counts as a full charge: the
  /// bar glows, and a clean landing with it is a "super bounce".
  static const double energyFullShare = 0.98;

  /// How hard the robot holds its wanted spin speed (rad/s²), e.g. to
  /// recover after scraping the ground. This is NOT the hold/release speed.
  static const double spinAcceleration = 100.0;

  // ---------------------------------------------------------------- Landings
  /// Max angle (deg) between robot "up" and the ground normal that still
  /// counts as a clean two-foot landing. (Balance pass: was 25.)
  static const double cleanLandingToleranceDeg = 20.0;

  /// Max angle (deg) for a one-foot landing. Beyond this, a foot touching
  /// down is a crash. (Balance pass: was 50.)
  static const double oneFootToleranceDeg = 40.0;

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

  /// Cap on the robot's speed along the ground after a landing (m/s), so
  /// it can't run away.
  static const double maxRobotSpeed = 28.0;

  /// Caps on the robot's speed in the air (m/s): horizontal (how fast it
  /// travels, so distances stay in check) and total (safety). 1.0.0 capped
  /// the TOTAL at 28, which squashed every energy bounce; now a charged
  /// jump goes as high as its energy sends it, at the same travel speed.
  static const double maxFlightHorizontalSpeed = 28.0;
  static const double maxFlightSpeed = 42.0;

  // ---------------------------------------------------------------- Hill
  // Each level's slope and bump size are in [levels] below; the numbers
  // here are shared by every level.

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

  /// Random seed for bump phases: same seed = same hill every run. Level n
  /// uses hillSeed + n - 1, so every level has its own hill.
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

  /// Damage added by a crash landing: one whole limb, so "crash = lose a
  /// limb" is easy to read. (Balance pass: was 45; see docs/ROADMAP.md.)
  static const double crashDamage = 100.0;

  /// Damage added by a one-foot landing. (Balance pass: was 20.)
  static const double oneFootDamage = 35.0;

  /// Damage added by a clean landing: wear and tear, so even a perfect run
  /// ends after about 40 landings (~4 minutes). (Balance pass: was 6.)
  static const double cleanLandingDamage = 10.0;

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
  /// The head keeps the robot's momentum (V4, 1.1.0): its velocity just
  /// before the landing, minus the part going into the ground, times
  /// [headLaunchCarry]. On top comes a rocket kick along the robot's line
  /// of travel (bent away from the ground by [headLaunchUpBias]; 1.1.1,
  /// D32: it used to follow where the robot faced, which could veer off):
  /// kick (m/s) = (base + robot speed × factor) × angle factor, capped at
  /// [headLaunchMaxKick]. The angle factor is 1 when landing upright and
  /// [headLaunchMinAngleFactor] when sideways or upside down.
  /// (1.0.0 replaced the robot's velocity with the kick alone, read after
  /// the impact had already stopped the robot.)
  static const double headLaunchCarry = 0.9;
  static const double headLaunchBaseSpeed = 10.0;
  static const double headLaunchSpeedFactor = 0.25;
  static const double headLaunchMaxKick = 18.0;
  static const double headLaunchMinAngleFactor = 0.6;

  /// The head always leaves the ground at least this fast (m/s, along the
  /// ground normal), so it never skims or dives into the slope.
  static const double headLaunchMinLift = 6.0;

  /// Hard cap on the launch speed (m/s), before the Rocket head's scale.
  static const double headLaunchMaxSpeed = 36.0;

  /// How strongly the kick is bent away from the ground (on top of the
  /// robot's line of travel). Higher = steeper. (1.0.0: 1.5 on top of the
  /// facing, nearly straight up; 1.1.0: 0.7; 1.1.1: 1.6, since the kick
  /// now follows the travel, which runs along the slope.)
  static const double headLaunchUpBias = 1.6;

  /// Below this speed (m/s, kept momentum) the kick's travel direction
  /// fades out, so a robot that is barely moving fires its head straight
  /// off the ground.
  static const double headLaunchTravelSpeed = 2.0;

  /// After launch, a rocket burn keeps pushing the head along its flight
  /// for this many seconds, with this acceleration (m/s²).
  static const double headRocketBurnTime = 0.6;
  static const double headRocketThrust = 16.0;

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
  /// (1.1.1: 26 → 22, a closer view on the ground.)
  static const double cameraBaseWidth = 22.0;

  /// Extra visible meters per m/s of speed (zoom out when fast).
  static const double cameraZoomPerSpeed = 0.45;

  /// The camera always keeps both the robot and the ground right below it
  /// on screen: the higher the robot, the further it zooms out, and it
  /// zooms back in as the robot comes down. This is the empty space (m)
  /// kept above the robot and below the ground.
  static const double cameraGroundMargin = 4.0;

  /// Room (m) kept between the robot (its torso) and the HUD band above it.
  static const double cameraTopMargin = 2.0;

  /// How far between robot (0) and the ground below it (1) the camera
  /// centers when the robot is high up. 0.5 = exactly halfway. Once the
  /// head is launched, the camera centers on the head (0) instead.
  static const double cameraGroundBias = 0.5;

  /// Max visible width (m) when zoomed fully out. (1.1.1: 110 → 60, so big
  /// jumps don't shrink the robot to a speck; past this the camera keeps
  /// the robot on screen and lets the ground drop out of view.)
  static const double cameraMaxWidth = 60.0;

  /// How quickly the camera catches up (higher = tighter follow).
  static const double cameraFollowSharpness = 6.0;

  /// Tighter follow while the launched head is flying, so the fast rocket
  /// stays centered on screen.
  static const double cameraHeadFollowSharpness = 14.0;

  /// How quickly zoom changes (higher = snappier).
  static const double cameraZoomSharpness = 4.0;

  /// How far ahead the camera looks, in seconds of current velocity.
  static const double cameraLookAhead = 0.25;

  /// Share of the screen height at the top kept clear for the HUD
  /// (distance, energy bar, stars and the Combo chip), so the robot is never
  /// drawn behind it. (1.1.1: 0.18 → 0.3; the Combo chip covered the robot.)
  static const double cameraHudReserve = 0.3;

  /// Portrait screens (taller than wide). The view's width is the
  /// landscape width times this, so the robot stays a good size on a
  /// narrow screen; the tall screen shows more hill below instead.
  /// Applies to the base, speed and max widths alike.
  static const double cameraPortraitWidthScale = 0.55;

  /// Portrait: the robot sits this share of the visible height above the
  /// screen's middle, so more of the slope ahead (below) is in view.
  static const double cameraPortraitLead = 0.12;

  /// Portrait: share of the screen height kept clear for the HUD (buttons
  /// stack above the distance counter, so it is taller).
  static const double cameraPortraitHudReserve = 0.3;

  /// High up, the robot is DRAWN bigger (its physics shapes never change),
  /// so it stays readable when the camera zooms out: ×1 up to
  /// [robotZoomFromHeight] m above the ground, growing to
  /// [robotZoomMaxScale] at [robotZoomFullHeight] m. Back to ×1 before
  /// touchdown, so it never looks sunk into the ground.
  static const double robotZoomMaxScale = 1.8;
  static const double robotZoomFromHeight = 4.0;
  static const double robotZoomFullHeight = 30.0;

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
  static const double shakeSuperBounce = 0.4;
  static const double shakeDecay = 7.0;

  /// Spin energy glow around the robot: radius (m) when the tank is full,
  /// and how strongly it shows (0-1 opacity at full).
  static const double energyAuraRadius = 1.9;
  static const double energyAuraStrength = 0.55;

  /// Bits of scrap thrown off when a limb breaks.
  static const int limbBreakBits = 8;

  /// Slow motion on head launch: the game runs at this speed share right
  /// after the launch and eases back to normal over this many real seconds.
  static const double headLaunchSlowMo = 0.3;
  static const double headLaunchSlowMoTime = 0.6;

  /// Smoke puffs behind the flying head: seconds between puffs during the
  /// rocket burn and after it, and how long a puff lasts.
  static const double smokeIntervalBurn = 0.03;
  static const double smokeIntervalCoast = 0.09;
  static const double smokeLifetime = 0.9;

  /// Background music level relative to the player's music volume, so it
  /// sits under the sound effects.
  static const double musicMix = 0.6;

  /// Music level share during the head-launch slow motion (ducking).
  static const double musicDuckShare = 0.35;

  /// Wait after the run ends before the "new best" jingle plays.
  static const Duration newBestSoundDelay = Duration(milliseconds: 600);

  /// Phone vibration on landings, limb loss and launch (no effect in the
  /// iOS Simulator). Only the default: the player's Settings decide.
  static const bool hapticsEnabled = true;

  // ---------------------------------------------------------------- Scrap
  // Currency earned at the end of each run (see scrap_reward.dart).

  /// 1 scrap per this many meters of distance. (Balance pass: was 10, with
  /// 2 per clean landing and 1 per 5 m of head flight. Targets: first
  /// upgrade after 1-2 runs, a full track after ~10-20 runs.)
  static const double scrapMetersPerScrap = 25;

  /// Bonus per clean (both feet) landing.
  static const int scrapPerCleanLanding = 1;

  /// 1 scrap per this many meters the launched head flies.
  static const double scrapHeadFlightMetersPerScrap = 10;

  /// Bonus for beating the best distance.
  static const int scrapNewBestBonus = 25;

  /// Every star earned (on any level) adds this share to all scrap rewards,
  /// for good: 18 stars = +54%.
  static const double scrapBonusPerStar = 0.03;

  /// One-off bonus for each star earned for the first time.
  static const int scrapPerNewStar = 50;

  // ---------------------------------------------------------------- Levels
  // Six levels, each an endless hill with a distance goal and three star
  // distances. 1 star (the goal) unlocks the next level. Later levels are
  // steeper and bumpier, so landing angles vary more, and pay more scrap.
  // Part tier N can be bought once level N is unlocked.
  // Star distances come from tool/progression_report_test.dart (P7, then
  // V12 and 1.1.1 W6 in docs/ROADMAP.md): with every slot at the level's
  // tier, a skill-0.4 bot averages about 1 star on every level, skill 0.7
  // about 2, and skill 0.9 2-3 (fewer third stars on later levels). Star
  // 1 never went up (no save loses an unlock); 1.1.1 lowered star 1 on
  // levels 4-6 and star 3 everywhere. damageScale grows faster than body
  // HP (V12) and is set so the same skill goes about 2% less far on each
  // level (level 6 the harshest).
  //
  // Bump scale check: the ground must never go uphill. The bumps' steepest
  // possible slope is about 0.51 × bumpScale; keep it below tan(slopeDeg)
  // (test/hill_test.dart checks every level).
  static const List<LevelTuning> levels = [
    LevelTuning(
      name: 'Rust Hollow',
      slopeDeg: 35,
      bumpScale: 1.0,
      starDistances: [1600, 3900, 5300],
      scrapMultiplier: 1.0,
      partTier: 1,
    ),
    LevelTuning(
      name: 'Cinder Flats',
      slopeDeg: 36,
      bumpScale: 1.2,
      starDistances: [1650, 3950, 5350],
      scrapMultiplier: 1.3,
      partTier: 2,
      damageScale: 1.5,
    ),
    LevelTuning(
      name: 'Smog Ridge',
      slopeDeg: 38,
      bumpScale: 1.4,
      starDistances: [1700, 4000, 5400],
      scrapMultiplier: 1.7,
      partTier: 3,
      damageScale: 2.0,
    ),
    LevelTuning(
      name: 'Crusher Pass',
      slopeDeg: 40,
      bumpScale: 1.55,
      starDistances: [1750, 4050, 5450],
      scrapMultiplier: 2.2,
      partTier: 4,
      damageScale: 2.9,
    ),
    LevelTuning(
      name: 'Furnace Drop',
      slopeDeg: 42,
      bumpScale: 1.7,
      starDistances: [1800, 4100, 5500],
      scrapMultiplier: 2.6,
      partTier: 5,
      damageScale: 3.55,
    ),
    LevelTuning(
      name: 'Obsidian Maw',
      slopeDeg: 44,
      bumpScale: 1.85,
      starDistances: [1850, 4150, 5550],
      scrapMultiplier: 3.0,
      partTier: 5,
      damageScale: 3.95,
    ),
  ];

  /// Star flags planted on the hill at each star distance (meters): pole
  /// height, cloth size and ink outline width.
  static const double starFlagHeight = 4.5;
  static const double starFlagClothWidth = 2.6;
  static const double starFlagClothHeight = 1.5;
  static const double starFlagOutline = 0.15;

  // ---------------------------------------------------------------- Upgrades
  // Workshop upgrades (see lib/game/robot_stats.dart). Each track has
  // [upgradeMaxLevel] levels; level 0 is the plain robot above. Every
  // effect also has a hard cap, so no upgrade can break the physics.

  static const int upgradeMaxLevel = 5;

  /// Scrap price of each level (index 0 = buying level 1).
  static const List<int> upgradePrices = [80, 150, 300, 550, 900];

  // Per-tier tables (1.1.0, roadmap V6): index = tier 0..5. Tier 0 is the
  // plain robot (equal to the base values above, checked by a test). The
  // steps grow with the tier, so every upgrade is clearly felt and the top
  // tiers feel special. (1.0.0 used small equal steps per level.)

  /// Body: HP per part (damage between part breaks). ×2.4 at the top.
  /// Level damage (`LevelTuning.damageScale`) follows this table, so tier
  /// N on level N stays as tough as tier 1 on level 1.
  static const List<double> platingHp = [100, 120, 145, 175, 205, 240];

  /// Body Crash armor (1.1.1, D36): share of the speed along the ground
  /// kept on a crash (tier 0 = [crashSpeedMultiplier]).
  static const List<double> bodyCrashArmor = [
    0.55, 0.57, 0.60, 0.63, 0.67, 0.72, //
  ];

  /// Legs: clean bounce multiplier, and the widest angle (deg) that still
  /// counts as a clean landing (must stay under [oneFootToleranceDeg]).
  /// 1.1.1 (D33): top tier ×1.45 → ×1.3 and 34° → 31°, since the top legs
  /// stacked with the Combo Coil made late levels very bouncy.
  static const List<double> springBounceScale = [
    1.0, 1.04, 1.09, 1.15, 1.22, 1.30, //
  ];
  static const List<double> springToleranceDeg = [20, 21, 23, 25, 28, 31];

  /// Legs Grip (1.1.1, D36): share of the speed along the ground kept on a
  /// one-foot landing (tier 0 = [oneFootSpeedMultiplier]).
  static const List<double> legsGrip = [0.85, 0.86, 0.875, 0.895, 0.92, 0.95];

  /// Arms: share of the base counter-spin and release times (lower =
  /// snappier control).
  static const List<double> gyroTimeShare = [
    1.0, 0.9, 0.79, 0.67, 0.54, 0.4, //
  ];

  /// Core: spin energy per turn multiplier, and the tank size in turns.
  /// Total extra bounce from energy is capped at [coreMaxExtraBounce] (m/s).
  static const List<double> corePerTurnScale = [
    1.0, 1.12, 1.26, 1.42, 1.6, 1.8, //
  ];
  static const List<double> coreTankTurns = [2.5, 2.6, 2.8, 3.0, 3.2, 3.5];
  static const double coreMaxExtraBounce = 22.0;

  /// Core Overdrive (1.1.1, D36): share of the released energy bounce that
  /// also pushes the robot forward along the ground (tier 0 =
  /// [energyForwardShare]).
  static const List<double> coreOverdrive = [
    0.25, 0.27, 0.30, 0.34, 0.39, 0.45, //
  ];

  /// Head: launch speed multiplier (kick and caps), rocket burn time (s)
  /// and rocket thrust (m/s²). Every head got stronger in 1.1.0 (tier 0
  /// burn 0.5 → 0.6 s, thrust 14 → 16), and the top head flies at least
  /// twice as far as tier 0 (test/robot_stats_test.dart).
  static const List<double> rocketSpeedScale = [
    1.0, 1.08, 1.17, 1.27, 1.38, 1.5, //
  ];
  static const List<double> rocketBurnTime = [0.6, 0.7, 0.8, 0.95, 1.1, 1.3];
  static const List<double> rocketThrust = [16, 16.5, 17, 18, 19, 20];

  // ---------------------------------------------------------------- Gadgets
  // Extra helpers bought in the Workshop's Gadgets tab (see
  // lib/game/gadgets.dart). Each has [gadgetMaxLevel] levels and opens with
  // a level (Gadget.unlockLevel). Level 0 = not owned, no effect.

  static const int gadgetMaxLevel = 3;

  /// Scrap price of each gadget level (index 0 = buying level 1), by
  /// gadget id.
  static const Map<String, List<int>> gadgetPrices = {
    'comboCoil': [80, 200, 400],
    'scrapMagnet': [100, 250, 500],
    'autoGyro': [200, 450, 800],
    'shockPads': [300, 600, 1000],
    'crashCage': [400, 800, 1300],
    'levelerTreads': [500, 1000, 1600],
  };

  /// Gadgets taken out of the shop, with what their levels cost, so saves
  /// that bought them get the scrap back (PlayerProfile.fromJson).
  /// Landing Sight became a built-in feature in 1.1.0.
  static const Map<String, List<int>> retiredGadgetPrices = {
    'landingSight': [60, 150, 300],
  };

  /// Landing Sight (built into every robot since 1.1.0; Settings can hide
  /// it): shows the predicted landing this many seconds (game time) before
  /// touchdown.
  static const double landingSightTime = 0.6;

  /// Size (radius) of the Landing Sight gauge next to the robot, as a
  /// share of the screen's long side (in landscape: the visible width).
  static const double landingSightGaugeSize = 0.035;

  /// Length of the Landing Sight's ground marker (the robot's feet line at
  /// touchdown), as a share of the screen's long side, so it is the same
  /// size on screen in both orientations and at any zoom. The up stick,
  /// line widths and the pad ring on the ground scale with it.
  static const double landingSightMarkerSize = 0.05;

  /// Combo Coil: every clean landing in a row adds one step, up to this
  /// many steps per level; each step adds this much bounce and speed along
  /// the ground (m/s) to the clean landing. Any other landing resets it.
  static const List<int> comboCoilMaxSteps = [3, 4, 5];

  /// (1.1.1, D34: 0.8 / 0.6 → 0.5 / 0.4.)
  static const double comboBouncePerStep = 0.5;
  static const double comboSpeedPerStep = 0.4;

  /// Scrap Magnet: extra scrap share per level.
  static const double scrapMagnetPerLevel = 0.10;

  /// Auto-Gyro: in the last this-many seconds before touchdown, while the
  /// player isn't holding and the landing would not be clean, it holds for
  /// them whenever holding lands closer to upright. Per level.
  static const List<double> autoGyroWindows = [0.3, 0.5, 0.8];

  /// Shock Pads: one-foot and crash damage −15% per level.
  static const double shockPadsPerLevel = 0.15;

  /// Crash Cage: crashes per run that cost no damage, per level.
  static const int crashCagePerLevel = 1;

  /// Leveler Treads: the landing check uses the ground's average slope
  /// over this many meters around the touchdown, per level, so sharp
  /// bumps count less.
  static const List<double> levelerSpans = [1.0, 2.0, 3.0];

  // ---------------------------------------------------------------- Tutorial
  // The guided first run (lib/game/coach.dart): level 1, until played once.

  /// Game speed while the coach waits for the first hold (in the air).
  static const double coachHoldSlow = 0.12;

  /// Seconds (real time) of holding that count as "got it".
  static const double coachHoldTime = 0.5;

  /// Game speed while the Landing Sight shows during the "land on both
  /// feet" step, so there is time to read it.
  static const double coachSightSlow = 0.45;

  /// Landings after which the "land on both feet" step moves on even
  /// without a clean one (no getting stuck).
  static const int coachLandTries = 5;

  /// Seconds (real time) the energy and damage cards stay up.
  static const double coachEnergyTime = 5;
  static const double coachDamageTime = 4;

  /// How fast the game eases into and out of the coach's slow-downs
  /// (per second; higher = snappier).
  static const double coachSlowEase = 6;

  // ---------------------------------------------------------------- Background
  /// Parallax layers of distant scrap heaps, far to near: how much each
  /// moves with the camera (0 = not at all, 1 = like the ground).
  static const List<double> parallaxFactors = [0.04, 0.09, 0.16];

  /// Where the distant horizon sits, as a share of the screen height.
  static const double horizonHeight = 0.62;

  /// Scrap props lying on the slope: average spacing (m) between them.
  static const double propSpacing = 9.0;
}

/// One level's numbers (see [Tuning.levels]).
class LevelTuning {
  const LevelTuning({
    required this.name,
    required this.slopeDeg,
    required this.bumpScale,
    required this.starDistances,
    required this.scrapMultiplier,
    required this.partTier,
    this.damageScale = 1,
  });

  final String name;

  /// Overall slope of the hill in degrees.
  final double slopeDeg;

  /// Multiplier on [Tuning.bumpAmplitudes]: bigger = rougher ground.
  final double bumpScale;

  /// Meters for 1, 2 and 3 stars. The first is the goal that unlocks the
  /// next level.
  final List<double> starDistances;

  /// Scrap from runs on this level is multiplied by this.
  final double scrapMultiplier;

  /// Unlocking this level lets the Workshop sell parts up to this tier.
  final int partTier;

  /// Multiplier on all landing damage: later levels are harsher, which
  /// roughly cancels the extra part HP of the tier they unlock.
  final double damageScale;
}
