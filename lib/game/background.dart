import 'dart:ui';

import 'package:flame/components.dart';

import 'derby_game.dart';
import 'dusk_scene.dart';
import 'palette.dart';

/// The level's sky, distant scrap heaps and weather behind the hill. Sits
/// in the camera's backdrop (screen pixels) and scrolls with the camera's x.
class Background extends Component with HasGameReference<DerbyGame> {
  Background(LevelTheme theme) : _scene = DuskScene(theme);

  final DuskScene _scene;

  /// Seconds since the level started, for the weather.
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    _scene.paint(
      canvas,
      Size(size.x, size.y),
      cameraX: game.camera.viewfinder.position.x,
      time: _time,
    );
  }
}
