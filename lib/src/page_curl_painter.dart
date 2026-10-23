import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'curl_geometry.dart';

/// Paints a page snapshot curled by [geometry] using the page curl shader.
///
/// Areas the page has been lifted away from are left transparent (plus a
/// soft shadow), so whatever is painted underneath shows through.
class PageCurlPainter extends CustomPainter {
  /// Creates a painter.
  PageCurlPainter({
    required this.shader,
    required this.image,
    required this.geometry,
    required this.backColor,
    required this.ink,
    required this.shadow,
  });

  /// An instance of the page curl fragment shader.
  final ui.FragmentShader shader;

  /// The page as it looked when the curl started.
  final ui.Image image;

  /// Where the page is folded.
  final CurlGeometry geometry;

  /// Paper color of the page's back.
  final Color backColor;

  /// How much of the front's ink shows through the back, from 0 to 1.
  final double ink;

  /// Shadow strength, from 0 to 1.
  final double shadow;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, geometry.origin.dx)
      ..setFloat(3, geometry.origin.dy)
      ..setFloat(4, geometry.direction.dx)
      ..setFloat(5, geometry.direction.dy)
      ..setFloat(6, geometry.radius)
      ..setFloat(7, backColor.r)
      ..setFloat(8, backColor.g)
      ..setFloat(9, backColor.b)
      ..setFloat(10, backColor.a)
      ..setFloat(11, ink)
      ..setFloat(12, shadow)
      ..setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(PageCurlPainter oldDelegate) =>
      geometry != oldDelegate.geometry ||
      image != oldDelegate.image ||
      backColor != oldDelegate.backColor ||
      ink != oldDelegate.ink ||
      shadow != oldDelegate.shadow;
}
