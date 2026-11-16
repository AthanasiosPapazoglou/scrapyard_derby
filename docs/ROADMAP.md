# Roadmap: menus, workshop, settings, audio

The working plan for the next block of work. Read this together with `CLAUDE.md`
(project brief and rules). Tick steps off here as they land, and keep the
"Decisions" section current.

## Where the game is now (Nov 2026)

- Phase 1 (feel prototype) is done; the developer judged the gameplay solid.
- Phase 2 art is in: robot sprites (vector, from `art/make_style_test.py`),
  dusk world, styled hill, props, juice (particles, shake, slow-mo, haptics),
  CRT-style robot status panel.
- App shell: `main.dart` loads the `PlayerProfile` (shared_preferences),
  then Menu → `GamePage` (`GameWidget<DerbyGame>` + `Hud` overlay).
  Best distance is saved in the profile.
- The end-of-run card (`_RunOverBanner` in `lib/ui/hud.dart`) shows reason,
  distance, best and "Go again".

### Code map
| Area | Files |
|---|---|
| Tuning (all numbers) | `lib/config/tuning.dart` |
| Game loop, camera, run end, HUD data | `lib/game/derby_game.dart` (`HudInfo`, `RunEnd`) |
| Robot (spin, landings, damage, head launch) | `lib/game/robot.dart`, `robot_part.dart` |
| Bots / balance | `autopilot.dart`, `tool/simulate_runs_test.dart`, `test/balance_test.dart` |
| Pure, tested logic | `robot_stats.dart`, `run_stats.dart`, `scrap_reward.dart`, `landing.dart`, `spin.dart`, `damage.dart`, `head_launch.dart`, `camera_framing.dart`, `hill.dart` (`HillGeometry`) |
| Audio | `sound.dart`, generators `art/make_sfx.py` and `art/make_music.py`, files in `assets/audio/` |
| Visuals | `background.dart`, `dusk_scene.dart`, `effects.dart`, `scrap_props.dart`, `robot_sprites.dart`, `palette.dart` |
| Flutter UI | `lib/ui/hud.dart`, `debug_overlay.dart`, `status_panel.dart`, `main_menu.dart`, `game_page.dart`, `settings_page.dart`, `workshop_page.dart`, `crt.dart`, `run_summary.dart`, `robot_figure.dart`, `derby_button.dart`, `outlined_text.dart` |
| Saved data | `lib/profile/player_profile.dart`, `profile_store.dart` |

### Gotchas learned so far
- `flame_forge2d` 0.20 / `forge2d` 0.15 wrap **Box2D v3**, not the classic API:
  `world.physicsWorld.createRevoluteJoint(...)`, `body.createShape(geometry, ShapeDef)`,
  `body.createChain(ChainDef)`, contact events need `enableContactEvents: true`,
  `Contact.normal` points from shape A to B. Most online tutorials don't match.
- Chains are one-sided: list hill points left to right (y down) so the solid side faces up.
- `Vector2` is 32-bit: compare floats in tests with a tolerance (≈1e-4).
- `DerbyGame.updateTree` scales world time (`Tuning.gameSpeed`, head-launch slow-mo);
  `DerbyGame.update` itself gets real time (camera, HUD, stall timer).
- Flame particles don't pass `lifespan` down to child particles; set it explicitly.
- Hot restart keeps the old native music player running, so the music can
  double up in development; a full `flutter run` restart fixes it.
- Headless runs (tests/tools): call `await game.ready()` after every
  `game.update(...)`, or async loads (new hill chunks) never finish and the
  robot falls through the world.
- Never touch a removed part's `body`: after the head launch the torso is
  debris and gets destroyed; reading it crashes natively (segfault).
- A `CustomPaint` without a child is zero-sized; give it `size: Size.infinite`.
- Simulator: `flutter run` runs in a Terminal tab; `kill -USR1 <flutter_tools pid>`
  hot-reloads, `-USR2` hot-restarts. Simulator screenshots arrive a few seconds
  late, so verify timing-sensitive things with temporary `debugPrint` logs.
- New assets or packages need a full `flutter run` restart, not a hot restart.
- This SDK supports private named parameters (`this._field = 0` in a named
  constructor list, called as `field:`); use them to satisfy
  `prefer_initializing_formals`.

## Decisions

Defaults are in use until the developer changes them.

| # | Question | Current choice |
|---|---|---|
| D1 | Currency name | **Scrap** (default) |
| D2 | Upgrade tracks | **The five below** (default) |
| D3 | Shop name in menus | **Workshop** (default) |
| D4 | Music source | **Generated** by `art/make_music.py` (original composition and synth, like the sound effects). One loop for menu and game for now. |
| D5 | Sound effects | **Generated** by a script in `art/` (original, retro synth style), like the art |
| D6 | Rivals | Still open (see CLAUDE.md spec item 7). Not part of this roadmap. |

## Steps

Work in this order; each step ends with `flutter analyze` clean, tests
passing, a check in the Simulator, and a commit command for the developer.

### Step 1 — Saved player data + navigation  ☑
- `lib/profile/player_profile.dart`: `PlayerProfile` (ChangeNotifier) with
  best distance, scrap, upgrade levels (map track → level), settings
  (music volume, sfx volume, haptics on, debug overlay on). JSON in/out.
- `lib/profile/profile_store.dart`: load/save via `shared_preferences`
  (new dependency). Save after each run, purchase and settings change.
  Version the JSON (`"version": 1`) so it can be migrated later.
- App shell in `main.dart`: plain `Navigator` with pages
  Menu → Game → Run summary → Workshop / Settings. Load the profile before
  the first page. The `DerbyGame` is created per Play press (fresh run).
- Best distance moves from `DerbyGame` to the profile.
- Tests: profile JSON round trip, defaults, unknown/missing keys.
- Done: `PlayerProfile` saves itself through `ProfileStore` (it listens for
  every change). `lib/ui/main_menu.dart` is a plain placeholder (title, best,
  scrap, Play) and `lib/ui/game_page.dart` hosts the game; the run-over card
  got a Menu button. Settings exist in the profile but nothing reads them
  yet (step 3). `OutlinedText` moved to `lib/ui/outlined_text.dart`.

### Step 2 — Main menu + run summary  ☑
- `lib/ui/main_menu.dart`: dusk background (reuse the sky/heap drawing:
  factor the painting out of `background.dart` so a Flutter `CustomPainter`
  can use it too), robot sprite idling/slowly spinning, title, buttons
  **Play / Workshop / Settings**, best distance and scrap shown.
- Run stats collected during a run (`lib/game/run_stats.dart`, pure): landings
  per type, highest jump (height above ground), head-launch distance, limbs
  lost, distance.
- Scrap earned (`lib/game/scrap_reward.dart`, pure, numbers in `Tuning`):
  1 per 10 m, + bonus per clean landing, + bonus for head-launch distance,
  + bonus for a new best. Returns a breakdown list for the summary.
- `lib/ui/run_summary.dart` replaces `_RunOverBanner`: reason, distance,
  best / NEW BEST, stats, scrap breakdown and total; buttons
  **Play again / Workshop / Menu**. Scrap is added to the profile once.
- HUD keeps Restart; add a small pause/menu button.
- Tests: scrap reward breakdown, run stats.
- Done: sky/heap drawing now lives in `lib/game/dusk_scene.dart` (`DuskScene`),
  used by `Background` and the menu. The idle robot is
  `lib/ui/robot_figure.dart` (sprites posed at the joint pivots). The robot
  collects `RunStats`; `DerbyGame._finishRun` records best + scrap once and
  publishes a `RunResult` in `HudInfo.result`. The summary is an overlay
  over the wreck (not a separate page), so the landing spot stays visible.
  Pause = `pauseEngine()` + a `pause` overlay in `GamePage`. Restarting or
  leaving mid-run earns nothing. Workshop/Settings buttons show "SOON"
  until steps 3–4 wire them. Shared button: `lib/ui/derby_button.dart`.
- Balance note for step 6: in a test run the head flight was 194 of 546 m
  and earned 38 of 119 scrap; head-launch power may be too high.

### Step 3 — Settings page  ☑
- `lib/ui/settings_page.dart`: music volume, sfx volume, vibration on/off,
  show debug info (default off), reset progress (confirm dialog), credits.
- Haptics read the profile setting instead of `Tuning.hapticsEnabled`
  (keep the Tuning value as the default).
- The debug overlay shows only when the setting is on.
- Widget tests: toggles change the profile; reset asks first.
- Done: `lib/ui/settings_page.dart` (two columns for landscape). Reset
  (`PlayerProfile.resetProgress`) wipes best, scrap and upgrades but keeps
  settings. `Effects` reads `game.profile.hapticsOn`; the HUD hides the debug
  panel unless `showDebugInfo` is on. Music slider is saved but labelled
  "No music yet" until D4 was decided (label removed with the music). Credits link to Flutter's license page.

### Step 4 — Upgrade stats layer + Workshop  ☑
- `lib/game/robot_stats.dart` (pure): the robot's effective values =
  `Tuning` base values modified by upgrade levels. Robot, damage, spin,
  landing and head-launch code read `RobotStats` for the upgradeable values
  instead of `Tuning` directly. Level 0 must equal today's behaviour.
- Upgrade tracks (5 levels each; per-level effects and prices in `Tuning`):

  | Track | Part | Effect per level (starting guess) |
  |---|---|---|
  | Plating | Body | `limbMaxHp` +15% (damage between part breaks) |
  | Spring legs | Legs | clean bounce +6%, clean-landing tolerance +2° |
  | Gyro arms | Arms | counter-spin / release time −10% (faster control) |
  | Energy core | Core | spin energy per turn +10%, energy cap +0.25 turn |
  | Rocket head | Head | launch speed +8%, rocket burn +0.08 s |

  Prices rise per level (e.g. 50, 120, 250, 450, 750 Scrap). Every effect
  has a hard cap so no upgrade breaks the physics.
- `lib/ui/workshop_page.dart`: CRT style like the status panel. Per track:
  name, level pips, short description, "now → next" number, price, Buy
  (disabled if not enough scrap / maxed). Robot figure highlights the part.
- Tests: stats at level 0 equal Tuning; each level moves the right value;
  caps hold; purchase deducts scrap and saves; can't overspend.
- Done: `lib/game/robot_stats.dart` has `UpgradeTrack` (ids are save keys,
  never rename) and `RobotStats` (`base` = Tuning; `fromLevels` applies the
  per-level effects and caps from the Upgrades section of `tuning.dart`).
  The pure functions take an optional `stats:` (default `RobotStats.base`),
  `RobotDamage` takes `limbMaxHp`, and `Robot.stats` holds them (the run
  stats field is now `Robot.runStats`). New robots read
  `profile.robotStats`, so purchases apply from the next run / Play again.
  `PlayerProfile.buyUpgrade` / `canBuy` do the purchase. Energy core's total
  extra bounce is capped (`coreMaxExtraBounce`); the HUD energy bar uses the
  robot's own max. Workshop: `lib/ui/workshop_page.dart`, CRT colours
  shared via `lib/ui/crt.dart`. Opened from the menu and the run summary.

### Step 5 — Audio  ☑
- Dependency: `flame_audio`. Volumes from the profile settings.
- `art/make_sfx.py`: generates original WAV effects (simple synth: noise
  bursts, pitch sweeps) into `assets/audio/sfx/`: land_clean, land_onefoot,
  land_crash, limb_break, rocket_launch, rocket_loop (or burn), head_down,
  ui_click, ui_buy, new_best.
- `lib/game/sound.dart`: one place that plays them; hooked into the same
  events as `Effects` (landing, limb lost, head launch/landed) and the UI.
- Music: only once D4 is decided (menu track + gameplay loop, looping,
  ducked during head-launch slow-mo).
- Check on the Simulator (audio works there) and later on the phone.
- Done (effects): `python3 art/make_sfx.py` writes 9 WAVs (22 kHz mono,
  ~200 KB total; rocket_loop was folded into rocket_launch, which lasts
  about the burn). `lib/game/sound.dart`: `Sfx` enum + `Sound.play(sfx)`,
  a no-op until `Sound.init(profile)` runs in `main.dart` (so tests stay
  silent). Volume = profile sfx volume. Audio session: iOS ambient
  (respects the silent switch, mixes with the player's music), Android
  game usage without audio focus. Played from `Effects` (landing types,
  limb break, launch, head down), `DerbyGame._finishRun` (new best, after
  `Tuning.newBestSoundDelay`), `DerbyButton` + HUD buttons (click),
  Workshop (buy), Settings (sample on releasing the sfx slider).
  `test/sound_test.dart` checks every `Sfx` has a file and a generator entry.
- Developer listened: sound effects "sound cool for now".
- Done (music): `python3 art/make_music.py` composes "Scrapyard Dusk", a
  16-bar loop at 88 BPM (~44 s, 1.9 MB WAV; Am9–Fmaj7–Cmaj7–G6–Am9–Fmaj7–
  Dm9–E7sus4 twice, melody in bars 9–16). Notes and echoes that ring past
  the end wrap to the start, so the loop is seamless. Played by
  `FlameAudio.bgm` from startup through menu and game (pauses when the app
  is backgrounded) at music volume × `Tuning.musicMix`; volume 0 pauses it.
  Ducked to `Tuning.musicDuckShare` during the head-launch slow motion.
  One track for now; a separate menu track could come later.

### Step 6 — Balance pass  ☑
- First make landings less forgiving (unassisted runs currently reach
  1000 m+): e.g. tighter `cleanLandingToleranceDeg`, a bit faster
  `spinSpeed`, more crash damage. Target: no-input runs end early; skilled
  runs go far.
- Then tune scrap rewards and upgrade prices together: first upgrade after
  1–2 runs, a full track after many runs.
- Record the targets and results here.

**How to measure:** `flutter test tool/simulate_runs_test.dart` plays full
headless runs of the real game (physics and all, ~10 s for the whole report)
with `Autopilot` bots (`lib/game/autopilot.dart`: looks ahead to touchdown
under hold / release and picks the more upright one; `skill` adds judgement
noise and slower reactions). Set `upgrades` at the top of the file to test an
upgraded robot. `test/balance_test.dart` guards the main targets in CI-style
runs (`test/support/run_simulator.dart` is the shared runner).

**Targets:** no input ends early with little scrap; skill matters a lot; a
perfect run ends in ~4 min; head flight is a finish, not a third of the
score; first upgrade after 1-2 runs, a full track after ~10-20 runs.

**Changes:** clean tolerance 25→20°, one-foot tolerance 50→40°, damage
crash 45→100 (one crash = one limb), one foot 20→35, clean 6→10; head launch
base 20→10, max 36→24, rocket thrust 20→14; scrap 1 per 10 m→25 m, clean
bonus 2→1, head flight 1 per 5 m→10 m. Spin speed and jump feel unchanged.

**Results** (avg of 6 seeds; scrap includes the +25 new-best bonus, since
every simulated run starts from a fresh profile):

| bot | before: dist / scrap / time | after: dist / scrap / time |
|---|---|---|
| no input | 496 m / 107 / 43 s | 433 m / 44 / 44 s |
| skill 0.0 | 2083 m / 303 / 141 s | 787 m / 68 / 61 s |
| skill 0.4 | 3640 m / 495 / 239 s | 1469 m / 102 / 104 s |
| skill 0.7 | 5231 m / 695 / 341 s | 2807 m / 172 / 191 s |
| skill 1.0 | 6588 m / 866 / 434 s | 3462 m / 209 / 231 s |

Head flights went from ~150-250 m to ~60-100 m. With every upgrade maxed:
sloppy 2220 m, good 7282 m (runs ~8.5 min, mostly from Plating; revisit if
end-game runs feel too long). No input could not go much below ~430 m
without changing the bounce physics; it is ~1/3 of a casual run.

**Head flight "0 m" finding:** the launch replaces the head's velocity with
one along the facing direction (spec), so launching while facing uphill
fires the head backwards. That's a "bad launch" by design; the summary now
shows the signed value (e.g. -6 m) and the scrap bonus never goes negative.

# Block 2: Progression (levels, stars, gadgets)

Scope change (Nov 15, 2026): the game is no longer one endless replayable
hill. It becomes **6 levels**, each with a distance goal, 1-3 stars, its own
scenery and music, and a rougher hill than the one before. Upgrades are
balanced so that a robot with (nearly) every slot at tier N clears level N
with normal effort. New "gadgets" give struggling players extra help.

## Progression decisions

Defaults in use until the developer changes them. Numbers are placeholders
until the balance step (P7) measures them with the simulator.

| # | Question | Current choice |
|---|---|---|
| D7 | Is a level still endless? | **Yes.** No finish line; the run ends as before (head down / stuck). Stars are earned by distance; star flags stand on the hill at each target. |
| D8 | Stars | 1 star = pass the level's goal (unlocks the next level), 2 and 3 stars = longer distances. Stars come from the level's **best distance**, so they are never stored separately (retuning targets re-grades saves). |
| D9 | Star reward | **+3% scrap per star earned** (all levels, max 18 stars = +54%), permanent. Plus a one-off **+50 scrap per new star**. |
| D10 | Tier ↔ level | Part tier N can be bought once **level N is unlocked** (tier 1 from the start, tier 5 with level 5). Level 6 = tier 5 + gadgets. |
| D11 | Rugged hills | Per level: steeper base slope and bigger bumps (`Tuning.levels`), so landing angles vary much more than the steady 35°. The ground still never goes uphill (tested for every level). |
| D12 | Level scrap | Higher levels pay more: ×1.0, 1.3, 1.7, 2.2, 2.6, 3.0 (P7). |
| D13 | Gadgets | A second Workshop tab, separate from the 5 part slots. 3 levels each, unlocked by reaching a level (table below). |
| D14 | Old saves | v1 `bestDistance` becomes level 1's best (JSON version 2). |

### Levels (balanced in P7)

| # | Name | Mood / scenery | Slope, bump scale | Damage | Stars (m) | Scrap | Parts |
|---|---|---|---|---|---|---|---|
| 1 | Rust Hollow | today's dusk | 35°, ×1.0 | ×1.0 | 1600 / 3100 / 4300 | ×1.0 | tier 1 |
| 2 | Cinder Flats | late dusk, embers | 36°, ×1.2 | ×1.15 | 1650 / 3200 / 4400 | ×1.3 | tier 2 |
| 3 | Smog Ridge | night, green smog | 38°, ×1.4 | ×1.3 | 1700 / 3300 / 4500 | ×1.7 | tier 3 |
| 4 | Crusher Pass | storm, red lightning | 40°, ×1.55 | ×1.45 | 1800 / 3500 / 4600 | ×2.2 | tier 4 |
| 5 | Furnace Drop | molten orange, black heaps | 42°, ×1.7 | ×1.6 | 1900 / 3600 / 4700 | ×2.6 | tier 5 |
| 6 | Obsidian Maw | black and crimson | 44°, ×1.85 | ×1.8 | 2000 / 3700 / 4800 | ×3.0 | gadgets |

Music gets more menacing per level (slower, lower, darker chords, more
percussion); generated by `art/make_music.py` like today's loop.

### Gadgets (placeholders)

| Gadget | Unlocks | Effect per level (1-3) |
|---|---|---|
| Landing Sight | level 1 | HUD marker showing the predicted touchdown angle (green = clean). Shows for the last 0.6 / 1.2 s / whole flight. |
| Scrap Magnet | level 1 | +10% scrap per level. |
| Auto-Gyro | level 2 | When not holding, gently steers toward an upright landing in the last moments before touchdown (stronger per level). |
| Shock Pads | level 3 | One-foot and crash damage −15% per level. |
| Crash Cage | level 4 | The first 1 / 2 / 3 crashes of a run cost no damage. |
| Leveler Treads | level 5 | The landing check uses the ground averaged over 1 / 2 / 3 m, so sharp bumps count less. |

## Progression steps

Same rules as before: `flutter analyze` clean, tests pass, Simulator check,
commit command for the developer.

### P1 — Level data and saved progress  ☑
- `Tuning.levels`: name, base slope, bump scale, star distances, scrap
  multiplier, highest part tier it unlocks. `HillGeometry(level:)` builds
  each level's hill (own seed, slope, bump scale).
- `PlayerProfile`: best distance per level, stars (derived), unlocked levels,
  total stars, star scrap bonus, highest buyable tier (`canBuy` respects it).
  JSON version 2 with the v1 migration (D14).
- `scrapReward`: level multiplier, star bonus, new-star bonus lines.
- `DerbyGame(level:)` records the run on its level; Play starts the highest
  unlocked level until P2 adds the level select.
- Tests: hills for every level go downhill and average their slope; stars
  and unlocks; tier gate; migration; scrap lines.
- Done: `lib/game/levels.dart` (`Levels.of`, `starsFor`), `LevelTuning` at
  the bottom of `tuning.dart` (`Tuning.hillSlopeDeg` is gone: slope is per
  level). Profile: `bestOn(level)`, `starsOn`, `totalStars`, `isUnlocked`,
  `highestUnlockedLevel`, `maxPartTier`, `starScrapBonus`,
  `isNextTierUnlocked`; `recordRun(level, distance)` returns a `RunRecord`
  (new best, stars before/after, unlocked level). `bestDistance` is now the
  best on any level. `RunResult` carries level, stars and unlock for P2.
  Workshop shows "UNLOCKS WITH LEVEL N" on parts above the tier gate. Menu
  shows the furthest level and total stars. The simulator takes `level`.
- First look (simulator, tier 0, level 6 vs level 1): rougher hills barely
  slow the autopilot (skill 0.4: 1661 m vs 1469 m; skill 0.7: 2674 m vs
  2807 m), because the steeper slope also adds speed and the bot reads the
  ground perfectly. P7 will need much rougher ground (shorter, sharper
  bumps, maybe small kickers) to make later levels truly harder.

### P2 — Level select, star flags, summary stars  ☑
- Level select page (Play → map of 6 levels: name, stars, best, lock and
  what unlocks it). Locked parts in the Workshop say "Unlocks with level N".
- Star flags on the hill at each target; HUD shows the next target.
- Run summary: stars earned this run, "LEVEL CLEARED" / "NEXT LEVEL UNLOCKED".
- Done: Play → `lib/ui/level_select_page.dart` (2×3 cards; the furthest
  unlocked level is yellow, locked ones say "Reach X m on <level>").
  `lib/game/star_flags.dart` plants a flag per star distance (goal yellow,
  then rust, then glow; sizes in `Tuning`), and passing one plays the
  new-best jingle. HUD: star row + "next X m" under the energy bar
  (`HudInfo.starsPassed`). Summary: level name, stars (new ones glow),
  "LEVEL N UNLOCKED!", and a "Next level" button whenever the next level
  is open (replaces the game page). "Menu" buttons in the game are now
  "Levels" and go back to the level select.

### P3 — Robot stats screen  ☑
- Every stat with its current value and the max possible (all tiers +
  gadgets), as CRT bars; star scrap bonus and level multipliers too.
  Opened from the menu and the Workshop.
- Done: `lib/game/stat_sheet.dart` (pure) lists 10 stats by slot with
  base / now / reachable (parts on sale now) / max; bars show upgrade
  progress (empty = scrap robot, full = max; times count down).
  `lib/ui/robot_stats_page.dart`: CRT "ROBOT" panel (slot, installed part,
  tier, bar, "now / max") and "PROGRESS" panel (stars, levels cleared,
  furthest level, parts tier on sale, star bonus, level multiplier, new-star
  bonus). Opened from the menu ("Stats") and the Workshop header
  ("All stats"). P4 adds gadget rows here.

### P4 — Gadgets  ☑
- `GadgetType` (save ids never renamed) + effects in `RobotStats`, prices
  and per-level numbers in `Tuning`, Workshop tab, unlock by level.
- Landing Sight and Auto-Gyro reuse `predictLandingError` from the autopilot.
- Done: `lib/game/gadgets.dart` (`Gadget` enum: ids are save keys, never
  rename; `effect(level)` texts), numbers in the Gadgets section of
  `tuning.dart`, effects as `RobotStats` fields (`fromLevels(..., gadgets:)`).
  Profile: `gadgetLevel`, `isGadgetUnlocked`, `canBuyGadget`, `buyGadget`,
  saved under `"gadgets"` (no version bump needed).
  - Landing Sight: `lib/game/landing_sight.dart`, uses `predictLanding`
    (autopilot.dart, now also returns time, ground point and angle). A
    gauge beside the robot (ground slope line + coloured "up" stick, sized
    by zoom, so it stays on screen on big jumps) plus a marker on the
    ground at touchdown. Hidden during the opening drop.
  - Auto-Gyro: `autoGyroWantsHold` in autopilot.dart; `DerbyGame.update`
    ORs it with the player's (or bot's) hold.
  - Shock Pads: `landingDamage(type, stats:)`. Crash Cage:
    `Robot.crashCageLeft`. Leveler Treads: `HillGeometry.averageNormalAt`
    is used for the landing check only (the bounce uses the real normal).
  - Scrap Magnet: extra line in `scrapReward(magnetBonus:)`.
  - Workshop: a sixth "GADGETS" tab with a row per gadget; Robot Stats
    lists gadgets too.
- Measured (no input, average of all 6 hills): Auto-Gyro 0/1/2/3 =
  388 / 434 / 515 / 842 m. Sloppy bot (skill 0): 915 m without, 1000-1180 m
  with any level (not monotonic, as the bot's own holds override). Tune in
  P7.
- Gotcha: widget tests run on a fake clock; keep full headless runs
  (`simulateRun`) in files without `testWidgets` (see
  `test/gadget_runs_test.dart`), or they time out.

### P5 — Level scenery  ☑
- `LevelTheme` per level (sky gradient, heap colours, dirt, props mix, sun /
  moon, weather particles), drawn by the existing dusk scene code with
  different colours. Menu and level select show each level's look.
- Done: `LevelTheme` + `Weather` at the bottom of `lib/game/palette.dart`
  (`LevelTheme.of(level)`; level 1 = the style-test dusk colours). Themes:
  1 dusk; 2 late dusk, red sun, embers; 3 night, pale moon, green smog;
  4 red storm sky, rain + lightning flashes; 5 molten sky, black heaps,
  glowing orange dirt edge, ash + embers; 6 black and crimson, eclipse,
  crimson sparks. `DuskScene(theme)` draws sky / sun (or eclipse) / heaps
  and, via `lib/game/weather.dart` (`WeatherPainter`, particles placed by
  formula, nothing stored), the weather; `paint(..., time:)` animates it.
  `Background(theme)`, `Hill(theme:)` / `HillChunk` dirt colours and
  `PropPainter(dirt:)` take the theme; `DerbyGame.theme`. The menu shows
  the furthest unlocked level's scenery; level select cards have a window
  onto each level's scenery (greyscale while locked).
- Robot, props, flags and HUD keep their colours on every level (checked
  on level 6, the darkest: the robot still stands out).

### P6 — Level music  ☑
- `make_music.py` writes one loop per level, darker as levels go up;
  `Sound` switches tracks per level.
- Done: `art/make_music.py` now has a `TRACKS` table (tempo, chords,
  melody, voice styles; `DEFAULTS` = the level 1 sound, which is still
  byte-identical). Six 16-bar loops, ~12.8 MB of WAV in total:

  | Level | File | BPM | Key / feel |
  |---|---|---|---|
  | 1 | scrapyard_dusk.wav | 88 | A minor, warm lo-fi (unchanged) |
  | 2 | cinder_wind.wav | 84 | D minor, darker chords, same groove |
  | 3 | smog_lanterns.wav | 76 | E phrygian, drone bass, sparse kick, wavering lead |
  | 4 | crusher_storm.wav | 96 | C minor, driving 8th bass, hard snare, metal clanks, square lead |
  | 5 | furnace_heart.wav | 74 | F# minor with flat 2nd, gritty clipped bass, toms, metal hits |
  | 6 | obsidian_maw.wav | 66 | B minor + tritone, heartbeat kick, bells, very dark |

  Brightness (zero crossings/s) falls 646 → 282 from level 1 to 6 (storm
  stays bright on purpose); all have similar loudness and clean seams.
- `lib/game/sound.dart`: `levelMusic`, `musicPathFor(level)`,
  `Sound.musicForLevel(level)` (switches only when the track changes) and
  `Sound.menuMusic()` (furthest unlocked level). `GamePage` starts its
  level's track; leaving it (Levels button or system back, via `PopScope`)
  goes back to the menu track. "Next level" replaces the page, so it keeps
  the new track.
- Checked in the Simulator after a full `flutter run` restart: startup and
  track switches run without errors. Not listened to (no audio from here):
  the developer should listen and judge each track.
- If app size matters later: convert the loops to AAC/OGG (about 10× smaller).
- Follow-up (developer request): the menus now have a happy baseline
  instead of the furthest level's mood: their own track, "Scrap Sunshine"
  (`MENU_TRACK` in make_music.py: 100 BPM, C major, bouncy "oom-pah" bass;
  `menuMusicPath`), and level 1's dusk scenery on the main menu and level
  select. The robot there still wears its installed parts.

### P7 — Progression balance  ☑
- Simulator per level and upgrade set: a skill ~0.4 bot with every slot at
  tier N should reach level N's first star; 3 stars need skill ~0.9 or
  gadgets. Set star distances, prices and scrap from the results and
  record them here.

**How to measure:** `flutter test tool/progression_report_test.dart` plays
every level with the level's tier and one tier below, bots of skill 0, 0.4,
0.7, 0.9, 4 seeds each (set `levels`, `skills`, `gadgetLevel` at the top).
Upgraded robots run long: the full report takes ~40+ minutes, so run levels
in separate copies in parallel (`--concurrency=2`) and raise the timeout.
`test/progression_balance_test.dart` guards the shape (stars rise, damage
and scrap rise, plating keeps up with damage) without full runs.

**First measurement (P1 tuning):** stars far too easy (skill 0.7 got all 3
stars everywhere, skill 0.4 cleared every level); rougher levels were not
harder (the bot reads every bump exactly); tier 5 runs lasted ~9 minutes.

**Changes:**
- Bots read the ground as well as their skill: `predictLanding(...,
  slopeReading:)` mixes the exact landing slope with the hill's average
  slope (`HillGeometry.baseSlopeAngle`); `Autopilot` passes its skill. So a
  sloppy bot is caught out by bumps, like a person judging rough ground by
  eye. Auto-Gyro and Landing Sight still read exactly (that is their help).
- Per-level landing damage (`LevelTuning.damageScale`, ×1.0 to ×1.8):
  roughly cancels the plating of the tier each level unlocks, so tier N on
  level N feels like tier 1 on level 1 (level 6 a bit harsher). Runs are
  shorter and upgrades are needed.
- Star distances re-set from the results (star 1 ≈ 80% of skill 0.4,
  star 2 ≈ 80% of skill 0.7, star 3 ≈ 95% of skill 0.9, gently rising).
- Level scrap multipliers raised (see D12) for the economy below.

**Results** (average distance, m; robot at the level's tier, no gadgets):

| Level | tier | skill 0 | 0.4 | 0.7 | 0.9 | 0.4, one tier lower | 0.4 + all gadgets max |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 1040 | 2058 | 3931 | 4624 | 1087 (tier 0) | - |
| 2 | 2 | 1296 | 2005 | 3966 | 4650 | 1748 | - |
| 3 | 3 | 1116 | 2005 | 4103 | 4723 | 2216 | - |
| 4 | 4 | 1585 | 2802 | 4571 | 4820 | 1727 | 4561 |
| 5 | 5 | 1368 | 2645 | 3870 | 4751 | 2981 (tier 4) | 4651 |
| 6 | 5 | 1058 | 2095 | 3781 | 4133 | 2434 (tier 4) | 3988 |

Run lengths (real time): skill 0.4 ~2.5-3 min, skill 0.9 ~5-6 min. With
every gadget maxed even a no-input bot reaches ~3000 m on levels 4-6
(Auto-Gyro 3 nearly flies it): gadgets are the "bad player" path, but cost
~10k scrap in total. Level 6's third star (4800 m) is above skill 0.9's
average without gadgets. Spread between seeds is large (4 seeds), so
treat single numbers as ±15%.

**Economy** (repeat-run scrap at skill 0.4, level's tier, new multipliers;
new-star bonuses not counted): 109 / 148 / 199 / 373 / 455 / 417 scrap per
run on levels 1-6. Runs to buy the next full tier set: tier 1 ~4 (on level
1 with tier 0), tier 2 ~5.5, tier 3 ~8.5 (level 2), tier 4 ~11 (level 3),
tier 5 ~10 (level 4); all gadgets ~24 runs on levels 5-6. Prices unchanged.

**Effect on existing saves:** stars are derived from best distances, so the
new targets re-grade them (e.g. a 1915 m best on level 1 drops from 2 stars
to 1; the next level stays unlocked as long as star 1 is still reached).

**Not covered by bots:** how hard rough ground feels to a real thumb; the
developer should play levels 3-6 and adjust `bumpScale` / `damageScale`.

## Later (not in this roadmap)
- Android build and phone check (phase 2 item, do soon: native Box2D,
  haptics, frame rate on real hardware).
- Rivals (D6), hill variants/biomes, robot skins per upgrade level, store
  listings, final name, app IDs (`com.example…`), app icon.

# Block 3: Version 1.1.0 (feedback and polish)

Branch `v1.1.0` (from `main` at 8f5d613). Developer feedback from playing 1.0.0,
Nov 16, 2026. Same rules as before: `flutter analyze` clean, tests pass,
Simulator check (now in **both orientations**), commit command for the developer.

## What the feedback found in the code

- **Portrait**: `main.dart` locks the app to landscape. Every page is laid out
  as left/right halves (e.g. `workshop_page.dart`: bay | tabs+cards in one
  `Row`, fixed 124 px card rows), so a portrait screen squeezes them.
- **Head launch**: `Robot._launchHead` runs from the ground-contact event,
  after Box2D has already stopped the torso, so `speed` (and the head's new
  velocity) starts from almost nothing. The velocity is then *replaced*
  (not added to), and bent hard upward (`headLaunchUpBias` 1.5), so the
  flight ignores the momentum the robot had.
- **Tier gaps**: every slot grows linearly by small steps (`platingHpPerLevel`
  0.15, `springBouncePerLevel` 0.06, `rocketSpeedPerLevel` 0.08 capped at
  ×1.4, ...), so neighbouring tiers feel the same.
- **Spin energy**: +4 m/s per turn, at most 2 turns, on top of a 13.5 m/s
  clean bounce: a full charge adds about +60% bounce, but nothing on screen
  sells it, and one turn is barely noticeable.
- **Stiff limbs**: joint springs at 8 Hz / 0.6 damping and tight hip limits
  (25°) pull limbs straight back to rest; nothing drives them.
- **Page changes**: plain `MaterialPageRoute` everywhere (iOS slide
  transition over custom-painted pages, and a `GameWidget` still rendering
  underneath). Likely source of the flicker; to confirm when the developer
  names the screen.

## 1.1.0 decisions (defaults until the developer changes them)

| # | Question | Default |
|---|---|---|
| D15 | Orientations | Portrait (upright) and both landscapes. Layout switches when the screen is taller than wide. |
| D16 | Portrait gameplay | Same world, camera zoomed so the view is as wide (in meters) as landscape's height allows, robot framed in the upper-middle third so the slope ahead stays visible. HUD stacks top; status panel shrinks to bottom left. |
| D17 | Built-in Landing Sight | Every robot has it at today's level 1 (last 0.6 s of a flight). A Settings toggle can hide it. |
| D18 | Gadget replacing Landing Sight | **Combo Coil** (unlocks with level 1): each clean landing in a row adds a speed and bounce bonus that stacks up to 3 / 4 / 5 steps; any other landing resets it. HUD shows the combo count. New save id `comboCoil`; the old `landingSight` id is retired (never reused). |
| D19 | Landing Sight owners | Saves that bought Landing Sight get the scrap they spent back on load (one-off, JSON version 3). |
| D20 | Tier power | Per-tier **tables** in `tuning.dart` (6 values per stat) instead of "+x% per level", with growing gaps so each tier is clearly felt. Rough targets lowest → highest: body HP ×1 → ×2.4, legs bounce ×1 → ×1.45 and tolerance 20° → 34°, arms flip time ×1 → ×0.45, core per-turn ×1 → ×1.8 and cap 2 → 3.5 turns. |
| D21 | Head ceiling | All heads boosted (tier 0 included), then tier 0 → tier 5 at least **doubles** the head's flight distance: launch speed ×1.0 → ×1.8, burn 0.6 s → 1.5 s with stronger thrust. Verified by a test that measures flight distance, not just the multiplier. |
| D22 | Head launch feel | The head keeps the robot's momentum: launch = velocity *before* the landing (captured each air step) + a rocket kick along the facing direction, with a much softer up bend (only enough to never dive into the slope). |
| D23 | Spin energy weight | Energy per turn up (≈ +6 m/s), cap 2.5 turns, and a forward speed share too, so a full charge roughly doubles a jump. Clean landings release 100%, one-foot 60%, crash 25% (angle still matters most). Visible: bar fills in segments per turn, robot glows/sparks as it charges, a "SUPER BOUNCE" burst on full-charge releases. |
| D24 | Lively limbs | Visual and light-physics motion: softer joint springs, wider hip limits, small torques that swing arms with the spin and flail in the air, legs tuck while airborne and reach out just before a predicted landing (from `predictLanding`). Landing classification stays torso-angle based, so the motion can't change landing results. |
| D25 | "Reset button" | The in-game **Restart** button (top right of the HUD, a plain Material `FilledButton`). Becomes a chunky scrap-metal lever/plate in the game's style, matching a restyled pause button. |
| D26 | Logo | Generated by a new `art/make_logo.py` (like the other art): chunky riveted scrap-metal letters with outline, rust and hazard fills, a bolt/gear in the title, as SVG drawn with flutter_svg. |
| D27 | Version | `pubspec.yaml` → `1.1.0+2`. |

## 1.1.0 steps

Order: foundations first, then gameplay (needs a rebalance at the end),
then the redesigns (built responsive from the start).

### V1 — Foundations  ☑
- Version bump (D27). Portrait allowed (D15) in `main.dart` and
  `web/manifest.json` (iOS/Android native settings already allowed it).
- `lib/ui/layout.dart`: `context.isPortrait`, `isCompact`, `shortSide`, and
  `OrientationSwitch` (picks a builder from the space it's given).
- `test/layout_fit_test.dart` pumps every page (main menu, level select,
  Workshop, robot stats, settings, run summary) at 6 sizes (phones
  390×844 / 360×640 both ways, tablet 820×1180 both ways) and fails on
  overflow. Pages that still overflow are listed in `_knownMisfits` with
  the step that fixes them (V3: Workshop, level select, settings; V9:
  robot stats) and skipped. Each step must empty its entries; nothing may
  be added. Note: the main menu and run summary "fit" only because they
  are scaled down with `FittedBox`, so they still need V3/V10 by eye.
- Page transitions: `lib/ui/derby_route.dart` (`DerbyRoute`, a 220 ms
  cross-fade) replaces every `MaterialPageRoute`. The game page now has a
  sky background and loading colour (it flashed white while the game
  loaded), and the game engine pauses while the Workshop covers it (its
  loop kept running underneath). Trade-off: no iOS edge swipe-back; every
  page has a back button. Still waiting on the developer's report of
  which screen glitched.
- Simulator (iPhone 17 Pro): opens in portrait, menu → levels → game fade
  correctly, rotating mid-run keeps the run going.

### V2 — Portrait gameplay  ☐
- Camera framing for portrait (D16) in `camera_framing.dart` (tested pure
  logic), parallax backdrop and sky fill a tall screen.
- HUD, status panel, pause menu, Landing Sight gauge sized by the short side.
- Simulator check both ways, rotating mid-run.

### V3 — Responsive menus  ☐
- Workshop: portrait = bay on top, slot tabs as a row, part cards in a
  scrollable list; landscape keeps today's layout with fewer fixed sizes.
- Main menu, level select, settings, pause menu: portrait variants.
  (Stats screen and run card are redone in V9/V10.)

### V4 — Head launch rework  ☐
- D22: remember the robot's last airborne velocity; launch from it plus a
  rocket kick; softer up bend; slow-mo kept but shorter.
- `head_launch.dart` tests: launch keeps forward speed, never points into
  the ground, faster robot = longer flight.

### V5 — Spin energy weight  ☐
- D23 numbers in `tuning.dart`, release share by landing type in
  `velocityAfterLanding`, segmented energy bar and charge effects, a sound
  for full charge and for the big release.

### V6 — Tier tables and head ceiling  ☐
- D20/D21: replace per-level steps with per-tier lists; `RobotStats` reads
  them. Workshop and stats screen show the bigger jumps.
- Test: head flight distance tier 5 ≥ 2 × tier 0 on a flat launch.

### V7 — Built-in Landing Sight + Combo Coil  ☐
- D17-D19: sight always on at level 1 (Settings toggle), Combo Coil gadget
  (effect in `RobotStats`, streak in `Robot`, HUD counter, juice), save
  migration with refund, Workshop/stats texts.

### V8 — Lively limbs  ☐
- D24 in `robot.dart` / `robot_part.dart`, numbers in a new "Limb motion"
  section of `tuning.dart`. Check that bots' distances don't change much
  (landing results must not depend on limb motion).

### V9 — Robot stats screen redesign  ☐
- Big robot figure in its installed parts with call-outs per slot (part
  name, tier pips, part art); stats as chunky gauges (current vs max, next
  tier ghosted) in plain words ("Jump", "Toughness", "Flip speed",
  "Spin power", "Head rocket") instead of rows of small numbers; gadget
  badges. Garage/CRT styling, portrait and landscape layouts.

### V10 — Run card redesign  ☐
- A "derby ticket"/scrap-metal plate: riveted frame, hazard stripe header
  with the level name, big distance stamp, star slots that slam in one by
  one, new-best stamp, a mini track strip showing star flags vs where the
  head landed, landing tally (clean / one-foot / crash icons), scrap
  earned counting up, the robot head's portrait. Responsive.

### V11 — Logo and reset button  ☐
- D26 logo on the main menu (small idle wobble/shine), D25 reset button.

### V12 — Rebalance  ☐
- V4-V7 change distances a lot: rerun `tool/progression_report_test.dart`,
  re-set star distances, prices and level damage so tier N still clears
  level N with normal effort. Record results here.
- Developer playtest on the Simulator and on the Android phone, both
  orientations.
