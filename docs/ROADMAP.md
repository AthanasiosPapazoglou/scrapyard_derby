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
| D12 | Level scrap | Higher levels pay more: ×1.0, 1.2, 1.4, 1.6, 1.8, 2.0. |
| D13 | Gadgets | A second Workshop tab, separate from the 5 part slots. 3 levels each, unlocked by reaching a level (table below). |
| D14 | Old saves | v1 `bestDistance` becomes level 1's best (JSON version 2). |

### Levels (placeholders)

| # | Name | Mood / scenery | Slope, bump scale | Stars (m) | Parts |
|---|---|---|---|---|---|
| 1 | Rust Hollow | today's dusk | 35°, ×1.0 | 1000 / 1800 / 2800 | tier 1 |
| 2 | Cinder Flats | late dusk, embers | 36°, ×1.2 | 1300 / 2300 / 3400 | tier 2 |
| 3 | Smog Ridge | night, green smog | 38°, ×1.4 | 1600 / 2800 / 4000 | tier 3 |
| 4 | Crusher Pass | storm, red lightning | 40°, ×1.55 | 1900 / 3200 / 4600 | tier 4 |
| 5 | Furnace Drop | molten orange, black heaps | 42°, ×1.7 | 2200 / 3600 / 5200 | tier 5 |
| 6 | Obsidian Maw | black and crimson | 44°, ×1.85 | 2600 / 4200 / 6000 | gadgets |

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

### P7 — Progression balance  ☐
- Simulator per level and upgrade set: a skill ~0.4 bot with every slot at
  tier N should reach level N's first star; 3 stars need skill ~0.9 or
  gadgets. Set star distances, prices and scrap from the results and
  record them here.

## Later (not in this roadmap)
- Android build and phone check (phase 2 item, do soon: native Box2D,
  haptics, frame rate on real hardware).
- Rivals (D6), hill variants/biomes, robot skins per upgrade level, store
  listings, final name, app IDs (`com.example…`), app icon.
