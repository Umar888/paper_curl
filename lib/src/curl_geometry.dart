import 'dart:math' as math;
import 'dart:ui';

/// Where a page is folded: a cylinder lying along a line on the page.
///
/// Everything on the page past [origin] in [direction] wraps around a
/// cylinder of [radius]. Whatever passes over the top lies flat again on
/// the other side, showing the page's back.
class CurlGeometry {
  /// Creates a geometry.
  const CurlGeometry({
    required this.origin,
    required this.direction,
    required this.radius,
  });

  /// A point on the fold line, in page coordinates.
  final Offset origin;

  /// Unit vector from the fold line towards the edge being lifted.
  final Offset direction;

  /// Radius of the curl.
  final double radius;

  /// No curl at all.
  static const flat = CurlGeometry(
    origin: Offset(1e6, 0),
    direction: Offset(1, 0),
    radius: 0,
  );

  /// Folds the page so the point at [corner] lands on [touch].
  ///
  /// [touch] is first constrained so the page stays attached at its spine
  /// (the left edge), see [constrainTouch]. The radius grows from zero as
  /// the corner moves away, so a light touch curls gently instead of
  /// jumping.
  factory CurlGeometry.fromCorner({
    required Size size,
    required Offset corner,
    required Offset touch,
    required double maxRadius,
  }) {
    final p = constrainTouch(size, corner, touch);
    final delta = corner - p;
    final distance = delta.distance;
    if (distance < 0.5) return flat;
    final n = delta / distance;
    final r = math.min(maxRadius, distance / math.pi);
    // corner travels t past the fold, round the cylinder (pi * r) and t
    // back again, ending exactly at p
    final t = (distance - math.pi * r) / 2;
    var origin = p + n * t;
    // the cylinder sits a little further in than a flat fold would, which
    // could lift the bound edge. slide the fold back so neither spine
    // corner ever leaves the page; the page then resists being pulled
    // further, like a real one
    double past(Offset point) =>
        (point.dx - origin.dx) * n.dx + (point.dy - origin.dy) * n.dy;
    final lift = math.max(past(Offset.zero), past(Offset(0, size.height)));
    if (lift > 0) origin += n * lift;
    return CurlGeometry(origin: origin, direction: n, radius: r);
  }

  /// Keeps [touch] where a page bound at its left edge could put [corner]:
  /// no farther from the spine than the page is wide, and no farther from
  /// the opposite spine corner than the page's diagonal.
  static Offset constrainTouch(Size size, Offset corner, Offset touch) {
    var p = touch;
    final spine = Offset(0, corner.dy);
    p = _clampToCircle(p, spine, size.width);
    final opposite = Offset(0, corner.dy < size.height / 2 ? size.height : 0);
    final diagonal = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    return _clampToCircle(p, opposite, diagonal);
  }

  static Offset _clampToCircle(Offset p, Offset center, double radius) {
    final d = p - center;
    final length = d.distance;
    if (length <= radius || length == 0) return p;
    return center + d * (radius / length);
  }

  /// Where [corner] ends up when the page is turned all the way over.
  static Offset turnedCorner(Size size, Offset corner) =>
      Offset(-size.width, corner.dy);

  @override
  String toString() =>
      'CurlGeometry(origin: $origin, direction: $direction, radius: '
      '${radius.toStringAsFixed(1)})';
}
