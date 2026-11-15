import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/tuning.dart';

/// One robot part's artwork, drawn as vectors (sharp at every zoom).
///
/// The SVGs come from `art/make_style_test.py`. Each one's viewBox is set
/// up so that (0, 0) is the part's joint pivot, which is exactly where the
/// physics body's origin is, so the art lines up with the body without any
/// extra offsets.
class PartSprite {
  PartSprite._(this._picture, this._viewBoxOrigin);

  final Picture _picture;

  /// Top-left of the SVG viewBox, in art pixels (relative to the pivot).
  final Offset _viewBoxOrigin;

  /// Loads `assets/robot/<name>.svg`.
  static Future<PartSprite> load(String name) async {
    final svg = await rootBundle.loadString('assets/robot/$name.svg');
    final info = await vg.loadPicture(SvgStringLoader(svg), null);
    return PartSprite._(info.picture, _readViewBoxOrigin(svg));
  }

  /// Reads the x and y of `viewBox="x y w h"` from the SVG text.
  static Offset _readViewBoxOrigin(String svg) {
    final match = RegExp(r'viewBox="([^"]+)"').firstMatch(svg);
    if (match == null) {
      return Offset.zero;
    }
    final numbers = match
        .group(1)!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.parse)
        .toList();
    return Offset(numbers[0], numbers[1]);
  }

  /// Draws the part around the canvas origin (= the body origin), scaled
  /// from art pixels to meters.
  void render(Canvas canvas) {
    const scale = 1 / Tuning.artPixelsPerMeter;
    canvas
      ..save()
      ..scale(scale)
      ..translate(_viewBoxOrigin.dx, _viewBoxOrigin.dy)
      ..drawPicture(_picture)
      ..restore();
  }
}

/// All robot part sprites, loaded once when the game starts.
class RobotSprites {
  RobotSprites._({
    required this.torso,
    required this.head,
    required this.arm,
    required this.leg,
  });

  final PartSprite torso;
  final PartSprite head;
  final PartSprite arm;
  final PartSprite leg;

  static Future<RobotSprites> load() async {
    final parts = await Future.wait([
      PartSprite.load('torso'),
      PartSprite.load('head'),
      PartSprite.load('arm'),
      PartSprite.load('leg'),
    ]);
    return RobotSprites._(
      torso: parts[0],
      head: parts[1],
      arm: parts[2],
      leg: parts[3],
    );
  }
}
