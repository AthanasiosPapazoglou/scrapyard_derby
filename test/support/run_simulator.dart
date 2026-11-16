import 'package:flame_test/flame_test.dart';
import 'package:scrapyard_derby/game/autopilot.dart';
import 'package:scrapyard_derby/game/derby_game.dart';
import 'package:scrapyard_derby/profile/player_profile.dart';

/// One finished headless run.
class SimulatedRun {
  SimulatedRun(this.result, this.seconds);

  /// Null if the run hit the time limit without ending.
  final RunResult? result;

  /// Real (clock) seconds the run took.
  final double seconds;
}

/// Plays one full run of the real game, physics and all, without a screen.
/// [pilot] plays (null = nobody touches the screen). Needs
/// `TestWidgetsFlutterBinding.ensureInitialized()` (sprites load from the
/// asset bundle).
Future<SimulatedRun> simulateRun({
  Autopilot? pilot,
  PlayerProfile? profile,
  int level = 1,
  double maxSeconds = 900,
  double frame = 1 / 60,
}) async {
  final game = await initializeGame(
    () => DerbyGame(profile: profile ?? PlayerProfile(), level: level),
  );
  game.autopilot = pilot;
  await game.ready();
  var t = 0.0;
  while (game.hud.value.result == null && t < maxSeconds) {
    game.update(frame);
    // Lets async loads (new hill chunks) finish, like a real frame would.
    await game.ready();
    t += frame;
  }
  final result = game.hud.value.result;
  // Box2D allows only so many worlds at once; free this one, or long
  // reports (many runs) fail after ~128 runs.
  game.world.physicsWorld.destroy();
  return SimulatedRun(result, t);
}
