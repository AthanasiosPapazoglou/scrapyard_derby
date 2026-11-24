# Scrapyard Derby (working title)

A one-button, physics-based endless downhill robot game for mobile. Hobby project, no monetization.
All names, art, sound and code are original.

## Stack
- Flutter + Flame + flame_forge2d (Box2D port). Dart only.
- Day-to-day testing: iOS Simulator on the developer's Mac (`open -a Simulator`, then `flutter run -d <simulator id>` from `flutter devices`).
  A mouse click in the Simulator is a tap; click and hold is a held finger. Haptics don't work there, and performance isn't representative of a phone.
- Real-device checks later on the developer's Android phone; ship Android first, then iOS.
- A web build is published to GitHub Pages on every push to main (`.github/workflows/deploy-web.yml`,
  https://athanasiospapazoglou.github.io/scrapyard_derby/). Box2D runs there as WebAssembly. Must stay free:
  public repo + standard `ubuntu-latest` runner only (no larger runners).
- All tunable gameplay numbers live in ONE config file (e.g. `lib/config/tuning.dart`).

## Core loop
A robot is dropped from high up (not spinning yet) onto a steep, bumpy, endless scrap hill (no flat start, no finish line).
The robot spins clockwise on its own; touching and holding anywhere applies counter-spin. Land on your feet to keep bouncing and gain speed.
The feel is calm and floaty ("flow"): the whole game runs slightly slowed down (game speed 0.75), slow spin, very high jumps, but holding reacts quickly. Spinning in the air gathers energy that is fully released into the next bounce (capped), so more spins = higher launches.
Bad landings break limbs off; with no limbs left the head is launched like a rocket and the attempt ends where it lands. The goal is to cover as much distance as possible.
The score is horizontal distance in meters; the best distance is shown after each run.

## Progression (Nov 2026 scope change)
Not a single endless level anymore: 6 levels, each still an endless hill but with a distance goal and 1-3 stars
(1 star unlocks the next level; 2-3 stars need longer distances). Each level is rougher (steeper slope, bigger bumps),
with its own scenery and darker music. Stars permanently boost scrap. Part tier N is buyable once level N is unlocked,
and a robot with every slot at tier N should clear level N with normal effort. Extra "gadgets" help weaker players.
A robot stats screen shows current vs max stats. Details, numbers and steps: `docs/ROADMAP.md`, "Block 2: Progression".
This level ladder is now the **Survival** mode.

## Versus mode (Nov 2026 scope change, Block 6)
A second mode: a ladder of 6 races, one per level hill. Each race = the player + 3 AI rivals (`Autopilot`) on the same hill at once,
every robot for itself, no contact (robots never collide; they just overlap). Live standings by distance. No finish line:
each racer finishes like a Survival run; the final order is by final distance. Win (1st) a race to unlock the next.
Each race hands the player fixed "race gear" (same gear as the rivals); Workshop upgrades and gadgets apply only in Survival.
Rivals get harder per race (skill). Versus pays scrap (distance + place bonus + first-win bonus), spent on Survival upgrades.
When the player finishes before their place is settled (a running rival behind could still pass), the race fast-forwards
(whole game frames back to back, camera on the chasing rival, tap to go faster) until it is. Then the place is recorded and paid,
and the race runs on even faster (camera on the leader) until every rival is down, so the race card (podium) shows final distances only.
Code: `lib/game/racer.dart`, `races.dart`, `race_standings.dart` (plain, tested race rules), `lib/ui/race_hud.dart`,
`versus_ladder_page.dart`. Balance: `tool/versus_report_test.dart`.
Details, numbers and steps: `docs/ROADMAP.md`, "Block 6: Version 1.2.0" (done, version 1.2.0+5).

## Mechanics spec
1. **Spin**: clockwise at a constant speed by default. Holding a finger down is a counter-spin force: the clockwise spin quickly (but not instantly) slows to zero, then builds up counter-clockwise until it reaches the same speed the other way. Releasing returns gradually to full clockwise. No instant flips. Holding is the only correction mechanism.
2. **Spin energy**: every airtime gathers energy from the turns made in the air (either direction; counter-clockwise turns, made by holding, count 1.5×), capped (currently 2 turns = +8 m/s bounce, jumps at most ~21 m). On every landing, whatever the type, ALL of it is released into that bounce and the next airtime starts from zero. Shown as an energy bar under the distance.
3. **Landings** (robot angle vs ground normal at contact):
   - Both feet within a tolerance angle: strong bounce along the normal + speed bonus.
   - One foot: weaker bounce, speed loss.
   - Any other part: crash bounce, a limb's worth of damage, big speed loss.
4. **Limb loss**: linear, not location-based. Every landing adds to one shared damage total (crash 100 = one whole limb, one foot 35, clean 10). Parts break in a fixed order: left arm, right arm, left leg, right leg (at 100/200/300/400); then the body is left behind at the head launch and the head ends the attempt when it lands. Each part's HP = 1 - damage / its breaking point, so all parts drain together, the next in line fastest. Broken limbs call `joint.destroy()` and stay on the track as debris for a few seconds. A green CRT-style status panel (bottom left) shows each part's HP.
5. **Run end**: the run ends the moment the launched head first touches the ground (distance measured there), or when the robot gets stuck (too slow for a few seconds). Losing all four limbs does NOT end the run; it leads to the head launch.
6. **Head launch**: when only torso + head remain, the next landing (or ~0.6 s of sliding on the ground) fires the head like a rocket: along the facing direction, bent strongly away from the ground, with power from speed and landing angle (capped), plus a short rocket burn with a flame. The torso stays behind as debris. The head's first ground contact finishes the attempt; it does not roll on. Broken-off parts are flung away from the robot and fade out, so they never look attached.
7. **Rivals** (Versus mode only): 3 AI robots on the same hill, using the same physics and `Autopilot` (holds when that predicts a better landing, with per-bot skill noise). They never collide with the player (shared collision group), make no sound/haptics/shake, and are drawn tinted behind the player.
8. **Camera**: follows the player and always frames both the robot and the ground right below it: the higher the robot, the further it zooms out, zooming back in as it lands (capped). Slightly wider when fast. Distance counter and energy bar at the top.
9. **Juice**: sparks on clean landings, dust on one-foot landings and crashes, screen shake (scaled by landing type), scrap bits on limb loss, slow-mo + spark burst + smoke trail on head launch, haptics on landings/limb loss/launch. All numbers in the Juice section of tuning.dart.

## Physics setup
- Robot = 6 `BodyComponent`s (torso, head, arm_l, arm_r, leg_l, leg_r) joined by `RevoluteJoint`s with angle limits.
- Joint positions in torso-local units (art pixels, scale to world units in config):
  neck (0,-72), shoulders (-56,-42) and (58,-42), hips (-24,66) and (24,66).
- Hill = endless: ground height is a formula of x (35 degree slope + sine bumps from a seed), built as static chain-shape chunks ahead of the robot and removed behind it. Chunks overlap by one ghost point so seams are smooth.

## Art
- Style: hand-drawn cutout vector look. Thick dark outlines, flat fills with one shadow and one highlight.
- Palette: outline #2B1D16, rust #C4622D / #8A3B1C / #E39056, steel #6B7B8C / #4A5563 / #B4C0CB,
  hazard yellow #F2B233 / #B97F14, eye glow #5FE3D0. World colours (sky, heaps, dirt) come from the style test scene; all live in lib/game/palette.dart.
- Source of truth: `art/make_style_test.py` generates SVGs. Each part is drawn around its joint pivot,
  so parts can be exported as separate PNG sprites with the pivot at a known offset.
- Robot sprites: `python3 art/make_style_test.py art assets/robot` writes one SVG per part (torso, head, arm, leg) to `assets/robot/`,
  each with its joint pivot at (0,0) of the viewBox. The game draws them as vectors (flutter_svg) on the physics bodies.
  The collision shapes in tuning.dart are matched to this art; `test/robot_sprites_test.dart` checks they still fit.
  `Tuning.debugShowPhysicsShapes` draws the collision shapes on top for checking.
- World visuals (code-drawn, following the style test scene): dusk sky gradient (navy, coral, amber) with a low sun, 3 parallax layers of purple-brown scrap heaps with tire/car/girder silhouettes (camera backdrop), dirt hill with a highlight band, a deeper shadow tone, specks and buried junk, decorative scrap props on the slope (no physics). HUD text is cream with an ink outline.

- Title logo: `python3 art/make_logo.py` writes `assets/logo/logo.svg` (scrap-metal tube lettering, no fonts), shown on the main menu.
- Upgrade parts: `python3 art/make_parts.py` writes `assets/robot/<slot>_<tier>.svg` for legs/arms/body/head/core,
  tiers 0-5 (scrap cartoon → black-and-crimson obsidian, always a happy face; bodies get more athletic per tier) plus the preview `art/parts_sheet.svg`.
  Tier 0 reuses make_style_test.py's drawing. Every tier covers the same collision shapes (checked by `test/robot_sprites_test.dart`).
  The Workshop sells the next tier per slot; the robot (game, menu, Workshop bay) wears the installed parts.

## Audio
- All audio is generated by scripts, like the art: `python3 art/make_sfx.py` (sound effects, `assets/audio/sfx/`)
  and `python3 art/make_music.py` (a happy menu loop, "Scrap Sunshine", and one loop per level, from "Scrapyard Dusk" to "Obsidian Maw", `assets/audio/music/`). Original synth, standard library only.
- `lib/game/sound.dart` plays everything (`Sound.play(Sfx...)`, looping music via flame_audio's Bgm) at the saved volumes.
  Each level plays its own track (`Sound.musicForLevel`); all menus play the happy menu track (`Sound.menuMusic`).
- Menus (main menu, level select) always use level 1's dusk scenery as a happy baseline; the robot there wears its installed parts.

## Phases
1. **Feel prototype**: done (spin, hold to counter-spin, landings, endless hill, limb loss, head launch, distance, tuning).
2. **Playable MVP** (now): art style test in game is done. Remaining: main menu, run summary, saved best distance,
   settings, Android build (rivals: decided, Versus mode).
3. **Content and upgrades**: Workshop (scrap currency, part upgrades), sound effects and music, hill variants
   (biomes / difficulty ramping with distance), full art set.
4. **Launch**: Play closed testing, iOS build, store listings, final name/app IDs/icon, optional online leaderboard.

**Work plan: `docs/ROADMAP.md`**. Block 6 (Version 1.2.0, Versus mode) is the latest block and is done;
new work starts a new block there, with steps, decisions, code map and known gotchas.
Read it before starting; tick steps off there as they land.

## Working rules
- Keep the code simple and readable; the developer knows Flutter but is new to game dev.
- After each change: run `flutter analyze` and the tests, and fix problems before reporting back.
- The developer commits and pushes themself: end each step with a single chained command
  (`git add -A && git commit -m "..." -m "..." && git push`), subject line plus one short detail line.
