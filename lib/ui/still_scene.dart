import 'package:flutter/material.dart';

import '../game/dusk_scene.dart';
import '../game/palette.dart';

/// A level's sky, heaps and weather, standing still. [cameraX] picks the
/// stretch of heaps shown, so cards don't all look the same.
class StillScene extends CustomPainter {
  StillScene(this.theme, {this.cameraX = 0}) : _scene = DuskScene(theme);

  final LevelTheme theme;
  final double cameraX;
  final DuskScene _scene;

  @override
  void paint(Canvas canvas, Size size) {
    // Weather (rain streaks, sparks) would otherwise spill past the window.
    canvas.clipRect(Offset.zero & size);
    // A moment into the weather, so rain and sparks are mid-air.
    _scene.paint(canvas, size, cameraX: cameraX, time: 2.3);
  }

  @override
  bool shouldRepaint(StillScene old) =>
      old.theme != theme || old.cameraX != cameraX;
}

/// Turns locked scenery grey.
const ColorFilter greyscaleFilter = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// No colour change (the unlocked counterpart of [greyscaleFilter]).
const ColorFilter noFilter = ColorFilter.mode(
  Colors.transparent,
  BlendMode.dst,
);
