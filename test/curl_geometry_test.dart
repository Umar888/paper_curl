import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_curl/paper_curl.dart';

// The shader's forward model: where a page point ends up after curling.
// Points before the fold stay put, points on the cylinder rise and come
// back, points past it lie flat again on the other side.
Offset curl(CurlGeometry g, Offset point) {
  final s =
      (point - g.origin).dx * g.direction.dx +
      (point - g.origin).dy * g.direction.dy;
  if (s <= 0) return point;
  final double e;
  if (s < math.pi * g.radius) {
    e = g.radius * math.sin(s / g.radius);
  } else {
    e = math.pi * g.radius - s;
  }
  return point + g.direction * (e - s);
}

void main() {
  const size = Size(400, 600);
  const bottomRight = Offset(400, 600);

  test('the lifted corner lands exactly under the finger', () {
    for (final touch in const [
      Offset(300, 520),
      Offset(150, 400),
      Offset(20, 590),
      Offset(-200, 600),
    ]) {
      final g = CurlGeometry.fromCorner(
        size: size,
        corner: bottomRight,
        touch: touch,
        maxRadius: 50,
      );
      final landed = curl(g, bottomRight);
      final expected = CurlGeometry.constrainTouch(size, bottomRight, touch);
      expect(landed.dx, closeTo(expected.dx, 0.01), reason: '$touch');
      expect(landed.dy, closeTo(expected.dy, 0.01), reason: '$touch');
    }
  });

  test('no curl when the corner has not moved', () {
    final g = CurlGeometry.fromCorner(
      size: size,
      corner: bottomRight,
      touch: bottomRight,
      maxRadius: 50,
    );
    expect(g.radius, 0);
    expect(curl(g, const Offset(399, 599)), const Offset(399, 599));
  });

  test('the curl opens up gradually to maxRadius', () {
    final small = CurlGeometry.fromCorner(
      size: size,
      corner: bottomRight,
      touch: const Offset(390, 600),
      maxRadius: 50,
    );
    final big = CurlGeometry.fromCorner(
      size: size,
      corner: bottomRight,
      touch: const Offset(100, 600),
      maxRadius: 50,
    );
    expect(small.radius, lessThan(5));
    expect(big.radius, 50);
  });

  test('the page stays attached at its spine', () {
    // pulled far past where a bound page could reach
    final p = CurlGeometry.constrainTouch(
      size,
      bottomRight,
      const Offset(-900, 100),
    );
    expect((p - const Offset(0, 600)).distance, lessThanOrEqualTo(400.001));
    // the spine edge itself never moves
    final g = CurlGeometry.fromCorner(
      size: size,
      corner: bottomRight,
      touch: const Offset(-900, 100),
      maxRadius: 50,
    );
    expect(curl(g, const Offset(0, 600)), const Offset(0, 600));
  });

  test('a fully turned page ends up beyond the spine', () {
    final turned = CurlGeometry.turnedCorner(size, bottomRight);
    expect(turned, const Offset(-400, 600));
    final g = CurlGeometry.fromCorner(
      size: size,
      corner: bottomRight,
      touch: turned,
      maxRadius: 50,
    );
    // every page point now sits left of the screen
    for (final point in const [
      Offset(400, 0),
      Offset(200, 300),
      Offset(399, 599),
    ]) {
      expect(curl(g, point).dx, lessThan(0), reason: '$point');
    }
  });
}
