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
| Pure, tested logic | `run_stats.dart`, `scrap_reward.dart`, `landing.dart`, `spin.dart`, `damage.dart`, `head_launch.dart`, `camera_framing.dart`, `hill.dart` (`HillGeometry`) |
| Visuals | `background.dart`, `dusk_scene.dart`, `effects.dart`, `scrap_props.dart`, `robot_sprites.dart`, `palette.dart` |
| Flutter UI | `lib/ui/hud.dart`, `debug_overlay.dart`, `status_panel.dart`, `main_menu.dart`, `game_page.dart`, `run_summary.dart`, `robot_figure.dart`, `derby_button.dart`, `outlined_text.dart` |
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
| D4 | Music source | **Open.** CLAUDE.md says all sound is original. Options: developer/composer makes it, or CC0 track + credits + CLAUDE.md exception, or silence for now. Until decided: no music, sound effects only. |
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

### Step 3 — Settings page  ☐
- `lib/ui/settings_page.dart`: music volume, sfx volume, vibration on/off,
  show debug info (default off), reset progress (confirm dialog), credits.
- Haptics read the profile setting instead of `Tuning.hapticsEnabled`
  (keep the Tuning value as the default).
- The debug overlay shows only when the setting is on.
- Widget tests: toggles change the profile; reset asks first.

### Step 4 — Upgrade stats layer + Workshop  ☐
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

### Step 5 — Audio  ☐
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

### Step 6 — Balance pass  ☐
- First make landings less forgiving (unassisted runs currently reach
  1000 m+): e.g. tighter `cleanLandingToleranceDeg`, a bit faster
  `spinSpeed`, more crash damage. Target: no-input runs end early; skilled
  runs go far.
- Then tune scrap rewards and upgrade prices together: first upgrade after
  1–2 runs, a full track after many runs.
- Record the targets and results here.

## Later (not in this roadmap)
- Android build and phone check (phase 2 item, do soon: native Box2D,
  haptics, frame rate on real hardware).
- Rivals (D6), hill variants/biomes, robot skins per upgrade level, store
  listings, final name, app IDs (`com.example…`), app icon.
