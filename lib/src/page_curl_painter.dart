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
    configureCurlShader(
      shader,
      size: size,
      geometry: geometry,
      backColor: backColor,
      ink: ink,
      shadow: shadow,
      liveInput: false,
    );
    shader.setImageSampler(0, image);
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

/// Sets every uniform of the page curl shader except its image.
///
/// [size] is the page size in logical pixels. With [liveInput] the shader
/// is used through `ImageFilter.shader`, where the engine supplies the
/// texture size and the page itself.
void configureCurlShader(
  ui.FragmentShader shader, {
  required Size size,
  required CurlGeometry geometry,
  required Color backColor,
  required double ink,
  required double shadow,
  required bool liveInput,
}) {
  shader
    // overwritten by the engine when used as an image filter
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
    ..setFloat(13, size.width)
    ..setFloat(14, size.height)
    ..setFloat(15, liveInput ? 1 : 0);
}
