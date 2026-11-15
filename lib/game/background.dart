import 'dart:ui';

import 'package:flame/components.dart';

import 'derby_game.dart';
import 'dusk_scene.dart';

/// The dusk sky and distant scrap heaps behind the hill. Sits in the
/// camera's backdrop (screen pixels) and scrolls with the camera's x.
class Background extends Component with HasGameReference<DerbyGame> {
  final DuskScene _scene = DuskScene();

  @override
  void render(Canvas canvas) {
    final size = game.size;
    _scene.paint(
      canvas,
      Size(size.x, size.y),
      cameraX: game.camera.viewfinder.position.x,
    );
  }
}
