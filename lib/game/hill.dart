import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config/tuning.dart';
import 'levels.dart';
import 'palette.dart';
import 'scrap_props.dart';

/// The shape of the endless hill, as plain math (no physics), so it can be
/// unit tested.
///
/// The ground height is a formula of x: a straight slope (35° on level 1)
/// plus a few sine waves for bumps, bigger on later levels. Because it works for any x, the hill can be built in
/// chunks just ahead of the robot, forever.
class HillGeometry {
  /// The hill of [level] (1-based, see [Tuning.levels]): its own seed,
  /// slope and bump size.
  HillGeometry({this.level = 1})
    : _slope = math.tan(Levels.of(level).slopeDeg * math.pi / 180),
      _bumpScale = Levels.of(level).bumpScale {
    final random = math.Random(Tuning.hillSeed + level - 1);
    _phases = [
      for (var i = 0; i < Tuning.bumpAmplitudes.length; i++)
        random.nextDouble() * 2 * math.pi,
    ];
  }

  final int level;

  late final List<double> _phases;

  final double _slope;
  final double _bumpScale;

  /// Ground height (y, pointing down) at horizontal position [x], in meters.
  ///
  /// Bumps fade in over the first [Tuning.bumpFadeIn] meters, so the robot's
  /// first landing is on a smooth slope.
  double heightAt(double x) {
    final fade = (x / Tuning.bumpFadeIn).clamp(0.0, 1.0);
    var bumps = 0.0;
    for (var i = 0; i < _phases.length; i++) {
      final k = 2 * math.pi / Tuning.bumpWavelengths[i];
      bumps +=
          Tuning.bumpAmplitudes[i] * _bumpScale * math.sin(k * x + _phases[i]);
    }
    return x * _slope + bumps * fade;
  }

  /// The hill's overall slope angle in radians (without bumps).
  double get baseSlopeAngle => math.atan(_slope);

  /// Angle of the ground at [x] in radians (positive = going down to the
  /// right, which is the normal case).
  double slopeAngleAt(double x) {
    const dx = 0.25;
    return math.atan2(heightAt(x + dx) - heightAt(x - dx), 2 * dx);
  }

  /// Unit normal (pointing up, away from the ground) of the ground's
  /// average slope over [span] meters around [x]. Used by Leveler Treads,
  /// so a sharp bump under one foot counts less.
  Vector2 averageNormalAt(double x, double span) {
    final half = math.max(span, 0.5) / 2;
    final angle = math.atan2(heightAt(x + half) - heightAt(x - half), 2 * half);
    return Vector2(math.sin(angle), -math.cos(angle));
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
  Hill(this.geometry, {required this.focusXs, LevelTheme? theme})
    : theme = theme ?? LevelTheme.of(geometry.level);

  final HillGeometry geometry;

  /// Dirt colours of the level.
  final LevelTheme theme;

  /// Returns the x positions the hill should be built around (the
  /// player, and the rivals in Versus).
  final Iterable<double> Function() focusXs;

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
    final wanted = chunksAround(focusXs());

    // Remove chunks that are out of range.
    _chunks.removeWhere((index, chunk) {
      final outOfRange = !wanted.contains(index);
      if (outOfRange) {
        chunk.removeFromParent();
      }
      return outOfRange;
    });
    // Add the missing ones.
    for (final index in wanted) {
      if (!_chunks.containsKey(index)) {
        final chunk = HillChunk(
          geometry.chunkPoints(index),
          props: propsForChunk(geometry, index),
          theme: theme,
        );
        _chunks[index] = chunk;
        add(chunk);
      }
    }
  }
}

/// Chunk indexes to keep built: [Tuning.hillChunksBehind] behind to
/// [Tuning.hillChunksAhead] ahead of each focus x.
Set<int> chunksAround(Iterable<double> focusXs) => {
  for (final x in focusXs)
    for (
      var index = HillGeometry.chunkIndexAt(x) - Tuning.hillChunksBehind;
      index <= HillGeometry.chunkIndexAt(x) + Tuning.hillChunksAhead;
      index++
    )
      index,
};

/// One static piece of the hill: a chain shape plus its drawing.
///
/// Drawn in the cutout style: a flat fill, one lighter highlight band
/// just under the surface, a thick dark outline, and scrap props on top.
class HillChunk extends BodyComponent {
  HillChunk(this.points, {this.props = const [], LevelTheme? theme})
    : theme = theme ?? LevelTheme.all.first,
      super(priority: 1);

  /// The level's dirt colours.
  final LevelTheme theme;

  /// Chain points, including the ghost point at each end.
  final List<Vector2> points;

  /// Junk lying on this piece of slope (decoration only).
  final List<PropPlacement> props;

  late final Path _surfacePath = _buildSurfacePath();
  late final Path _groundPath = _buildGroundPath();

  late final PropPainter _propPainter = PropPainter(dirt: theme.dirt);

  late final Paint _fillPaint = Paint()..color = theme.dirt;
  late final Paint _shadowPaint = Paint()
    ..color = Color.lerp(theme.dirt, theme.dirtSpeck, 0.55)!;
  late final Paint _speckPaint = Paint()..color = theme.dirtSpeck;
  late final Paint _highlightPaint = Paint()
    ..color = theme.dirtHighlight
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.75
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

  /// Darker dirt from this deep below the surface down (the "shadow").
  static const double _shadowDepth = 3.5;

  late final Path _shadowPath = _groundPath.shift(
    const Offset(0, _shadowDepth),
  );

  /// Specks and junk buried in the ground, the same for this chunk every
  /// time it is built (seeded by where the chunk starts).
  late final List<_Buried> _buried = _buildBuried();

  List<_Buried> _buildBuried() {
    final pts = _visiblePoints;
    final random = math.Random(pts.first.x.round() * 31 + 7);
    final buried = <_Buried>[];
    double surfaceAt(double x) {
      final i = (x - pts.first.x).floor().clamp(0, pts.length - 2);
      final a = pts[i];
      final b = pts[i + 1];
      return a.y + (b.y - a.y) * ((x - a.x) / (b.x - a.x));
    }

    final width = pts.last.x - pts.first.x;
    for (var i = 0; i < 26; i++) {
      final x = pts.first.x + random.nextDouble() * width;
      buried.add(
        _Buried(
          kind: 0,
          x: x,
          y: surfaceAt(x) + 0.9 + random.nextDouble() * 7,
          size: 0.1 + random.nextDouble() * 0.18,
          angle: 0,
        ),
      );
    }
    for (var i = 0; i < 3; i++) {
      final x = pts.first.x + random.nextDouble() * width;
      buried.add(
        _Buried(
          kind: random.nextBool() ? 1 : 2,
          x: x,
          y: surfaceAt(x) + 1.6 + random.nextDouble() * 4,
          size: 0.4 + random.nextDouble() * 0.3,
          angle: random.nextDouble() * math.pi,
        ),
      );
    }
    return buried;
  }

  static final Paint _junkFill = Paint();
  static final Paint _junkOutline = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.07;

  @override
  void render(Canvas canvas) {
    // Ground: dirt, a darker tone deeper down, buried specks and junk.
    canvas
      ..drawPath(_groundPath, _fillPaint)
      ..drawPath(_shadowPath, _shadowPaint);
    for (final b in _buried) {
      _renderBuried(canvas, b);
    }
    // Highlight band along the surface, clipped to the ground so only its
    // lower half shows, then the thick ink outline on top.
    canvas
      ..save()
      ..clipPath(_groundPath)
      ..drawPath(_surfacePath, _highlightPaint)
      ..restore()
      ..drawPath(_surfacePath, _edgePaint);
    for (final prop in props) {
      _propPainter.paint(canvas, prop);
    }
  }

  void _renderBuried(Canvas canvas, _Buried b) {
    switch (b.kind) {
      case 0: // speck
        canvas.drawCircle(Offset(b.x, b.y), b.size, _speckPaint);
      case 1: // buried tire
        _junkFill.color = Palette.tire;
        canvas
          ..drawCircle(Offset(b.x, b.y), b.size, _junkFill)
          ..drawCircle(Offset(b.x, b.y), b.size, _junkOutline);
        _junkFill.color = theme.dirt;
        canvas.drawCircle(Offset(b.x, b.y), b.size * 0.4, _junkFill);
      default: // buried steel plate
        _junkFill.color = Palette.steel;
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: b.size * 2.2,
          height: b.size * 1.2,
        );
        canvas
          ..save()
          ..translate(b.x, b.y)
          ..rotate(b.angle)
          ..drawRect(rect, _junkFill)
          ..drawRect(rect, _junkOutline)
          ..restore();
    }
  }
}

/// A speck (kind 0), tire (1) or steel plate (2) buried in the ground.
class _Buried {
  const _Buried({
    required this.kind,
    required this.x,
    required this.y,
    required this.size,
    required this.angle,
  });

  final int kind;
  final double x;
  final double y;
  final double size;
  final double angle;
}
