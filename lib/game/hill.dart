import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config/tuning.dart';
import 'palette.dart';
import 'scrap_props.dart';

/// The shape of the endless hill, as plain math (no physics), so it can be
/// unit tested.
///
/// The ground height is a formula of x: a straight 35° slope plus a few sine
/// waves for bumps. Because it works for any x, the hill can be built in
/// chunks just ahead of the robot, forever.
class HillGeometry {
  HillGeometry({int seed = Tuning.hillSeed}) {
    final random = math.Random(seed);
    _phases = [
      for (var i = 0; i < Tuning.bumpAmplitudes.length; i++)
        random.nextDouble() * 2 * math.pi,
    ];
  }

  late final List<double> _phases;

  static final double _slope = math.tan(Tuning.hillSlopeDeg * math.pi / 180);

  /// Ground height (y, pointing down) at horizontal position [x], in meters.
  ///
  /// Bumps fade in over the first [Tuning.bumpFadeIn] meters, so the robot's
  /// first landing is on a smooth slope.
  double heightAt(double x) {
    final fade = (x / Tuning.bumpFadeIn).clamp(0.0, 1.0);
    var bumps = 0.0;
    for (var i = 0; i < _phases.length; i++) {
      final k = 2 * math.pi / Tuning.bumpWavelengths[i];
      bumps += Tuning.bumpAmplitudes[i] * math.sin(k * x + _phases[i]);
    }
    return x * _slope + bumps * fade;
  }

  /// Angle of the ground at [x] in radians (positive = going down to the
  /// right, which is the normal case).
  double slopeAngleAt(double x) {
    const dx = 0.25;
    return math.atan2(heightAt(x + dx) - heightAt(x - dx), 2 * dx);
  }

  /// X where chunk number [index] starts. Chunk 0 starts at x = 0.
  static double chunkStartX(int index) => index * Tuning.hillChunkLength;

  /// Which chunk contains [x].
  static int chunkIndexAt(double x) => (x / Tuning.hillChunkLength).floor();

  /// The chain points for one chunk.
  ///
  /// Each chunk also gets one extra point before and after it. Box2D uses
  /// these "ghost" points only to smooth the joins, so the robot doesn't
  /// catch on the seam between two chunks.
  List<Vector2> chunkPoints(int index) {
    const step = Tuning.hillPointSpacing;
    final count = (Tuning.hillChunkLength / step).round();
    final startX = chunkStartX(index);
    return [
      for (var i = -1; i <= count + 1; i++)
        Vector2(startX + i * step, heightAt(startX + i * step)),
    ];
  }
}

/// Keeps hill chunks built around the robot: a few ahead, one behind.
class Hill extends Component {
  Hill(this.geometry, {required this.focusX});

  final HillGeometry geometry;

  /// Returns the x position the hill should be built around.
  final double Function() focusX;

  final Map<int, HillChunk> _chunks = {};

  @override
  Future<void> onLoad() async {
    _updateChunks();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateChunks();
  }

  void _updateChunks() {
    final center = HillGeometry.chunkIndexAt(focusX());
    final first = center - Tuning.hillChunksBehind;
    final last = center + Tuning.hillChunksAhead;

    // Remove chunks that are out of range.
    _chunks.removeWhere((index, chunk) {
      final outOfRange = index < first || index > last;
      if (outOfRange) {
        chunk.removeFromParent();
      }
      return outOfRange;
    });
    // Add the missing ones.
    for (var index = first; index <= last; index++) {
      if (!_chunks.containsKey(index)) {
        final chunk = HillChunk(
          geometry.chunkPoints(index),
          props: propsForChunk(geometry, index),
        );
        _chunks[index] = chunk;
        add(chunk);
      }
    }
  }
}

/// One static piece of the hill: a chain shape plus its drawing.
///
/// Drawn in the cutout style: a flat fill, one lighter highlight band
/// just under the surface, a thick dark outline, and scrap props on top.
class HillChunk extends BodyComponent {
  HillChunk(this.points, {this.props = const []}) : super(priority: 1);

  /// Chain points, including the ghost point at each end.
  final List<Vector2> points;

  /// Junk lying on this piece of slope (decoration only).
  final List<PropPlacement> props;

  late final Path _surfacePath = _buildSurfacePath();
  late final Path _groundPath = _buildGroundPath();

  static final PropPainter _propPainter = PropPainter();

  final Paint _fillPaint = Paint()..color = Palette.steelDark;
  final Paint _bandPaint = Paint()
    ..color = Palette.steel
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeJoin = StrokeJoin.round;
  final Paint _highlightPaint = Paint()
    ..color = Palette.steelLight
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..strokeJoin = StrokeJoin.round;
  final Paint _edgePaint = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.18
    ..strokeJoin = StrokeJoin.round;

  @override
  Body createBody() {
    // userData = this, so robot parts can recognize the ground in contacts.
    final body = world.createBody(BodyDef(userData: this));
    body.createChain(
      ChainDef(
        points: points,
        materials: [SurfaceMaterial(friction: Tuning.hillFriction)],
      ),
    );
    return body;
  }

  // Points without the invisible ghost points at both ends.
  List<Vector2> get _visiblePoints => points.sublist(1, points.length - 1);

  Path _buildSurfacePath() {
    final pts = _visiblePoints;
    final path = Path()..moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    return path;
  }

  Path _buildGroundPath() {
    // Close the surface line far below, so the ground is a filled shape.
    final pts = _visiblePoints;
    final bottom = pts.last.y + 200;
    return Path.from(_buildSurfacePath())
      ..lineTo(pts.last.x, bottom)
      ..lineTo(pts.first.x, bottom)
      ..close();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPath(_groundPath, _fillPaint);
    // Bands along the surface, clipped to the ground so only their lower
    // halves show: a mid-tone band and a thin light highlight on top.
    canvas
      ..save()
      ..clipPath(_groundPath)
      ..drawPath(_surfacePath, _bandPaint)
      ..drawPath(_surfacePath, _highlightPaint)
      ..restore()
      ..drawPath(_surfacePath, _edgePaint);
    for (final prop in props) {
      _propPainter.paint(canvas, prop);
    }
  }
}
