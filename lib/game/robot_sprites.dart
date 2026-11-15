import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/tuning.dart';
import 'robot_stats.dart';

/// One robot part's artwork, drawn as vectors (sharp at every zoom).
///
/// The SVGs come from `art/make_parts.py`. Each one's viewBox is set
/// up so that (0, 0) is the part's joint pivot, which is exactly where the
/// physics body's origin is, so the art lines up with the body without any
/// extra offsets.
class PartSprite {
  PartSprite._(this._picture, Rect viewBox)
    : _viewBoxOrigin = viewBox.topLeft,
      viewBoxSize = viewBox.size;

  final Picture _picture;

  /// Top-left of the SVG viewBox, in art pixels (relative to the pivot).
  final Offset _viewBoxOrigin;

  /// Size of the artwork in art pixels.
  final Size viewBoxSize;

  /// Loads `assets/robot/<name>.svg`.
  static Future<PartSprite> load(String name) async {
    final svg = await rootBundle.loadString('assets/robot/$name.svg');
    final info = await vg.loadPicture(SvgStringLoader(svg), null);
    return PartSprite._(info.picture, _readViewBox(svg));
  }

  /// Reads `viewBox="x y w h"` from the SVG text.
  static Rect _readViewBox(String svg) {
    final match = RegExp(r'viewBox="([^"]+)"').firstMatch(svg);
    if (match == null) {
      return Rect.zero;
    }
    final numbers = match
        .group(1)!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.parse)
        .toList();
    return Rect.fromLTWH(numbers[0], numbers[1], numbers[2], numbers[3]);
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

  /// Draws the whole part scaled to fit inside [size], centred (for menus
  /// and Workshop cards).
  void renderFitted(Canvas canvas, Size size) {
    final w = viewBoxSize.width;
    final h = viewBoxSize.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    final scale = (size.width / w) < (size.height / h)
        ? size.width / w
        : size.height / h;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-w / 2, -h / 2)
      ..drawPicture(_picture)
      ..restore();
  }
}

/// The art for one robot: the installed part in each slot.
class RobotLook {
  const RobotLook({
    required this.torso,
    required this.core,
    required this.head,
    required this.arm,
    required this.leg,
  });

  final PartSprite torso;

  /// Drawn on the chest, over the torso.
  final PartSprite core;
  final PartSprite head;
  final PartSprite arm;
  final PartSprite leg;
}

/// Every robot part sprite (all slots, all tiers), loaded once per app.
/// The files come from `art/make_parts.py`.
class RobotSprites {
  RobotSprites._(this._parts);

  /// Slot art prefix (e.g. "legs") → sprite per tier.
  final Map<String, List<PartSprite>> _parts;

  static Future<RobotSprites>? _loading;

  /// Loads every part the first time; later calls reuse it.
  static Future<RobotSprites> load() => _loading ??= _load();

  static Future<RobotSprites> _load() async {
    final parts = <String, List<PartSprite>>{};
    await Future.wait([
      for (final track in UpgradeTrack.values)
        Future.wait([
          for (var tier = 0; tier <= Tuning.upgradeMaxLevel; tier++)
            PartSprite.load('${track.art}_$tier'),
        ]).then((sprites) => parts[track.art] = sprites),
    ]);
    return RobotSprites._(parts);
  }

  /// The sprite for [track] at [tier] (clamped to the tiers that exist).
  PartSprite part(UpgradeTrack track, int tier) {
    final tiers = _parts[track.art]!;
    return tiers[tier.clamp(0, tiers.length - 1)];
  }

  /// The robot wearing the part at [tierOf] in each slot.
  RobotLook look(int Function(UpgradeTrack track) tierOf) => RobotLook(
    torso: part(UpgradeTrack.plating, tierOf(UpgradeTrack.plating)),
    core: part(UpgradeTrack.energyCore, tierOf(UpgradeTrack.energyCore)),
    head: part(UpgradeTrack.rocketHead, tierOf(UpgradeTrack.rocketHead)),
    arm: part(UpgradeTrack.gyroArms, tierOf(UpgradeTrack.gyroArms)),
    leg: part(UpgradeTrack.springLegs, tierOf(UpgradeTrack.springLegs)),
  );
}
