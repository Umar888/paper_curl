#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Page curl around a cylinder.
//
// The page is folded along a line through uOrigin; everything past it in
// uDir wraps around a cylinder of radius uRadius, and whatever goes over
// the top lies flat again showing the page's back. For each output pixel we
// work backwards to the point of the page that ends up there.

// as an image filter the engine sets uSize to the input texture's size in
// physical pixels, so all geometry is done in logical pixels and converted
uniform vec2 uSize;       // texture size
uniform vec2 uOrigin;     // a point on the fold line
uniform vec2 uDir;        // unit vector towards the lifted edge
uniform float uRadius;    // curl radius
uniform vec4 uBackColor;  // paper color of the page's back
uniform float uInk;       // how much of the front shows through the back
uniform float uShadow;    // shadow strength
uniform vec2 uLogicalSize;  // page size, logical pixels
uniform float uLiveInput;   // 1 when uPage is a live image filter input (unused, kept for layout)

uniform sampler2D uPage;

out vec4 fragColor;

const float PI = 3.14159265359;

// 1 inside the page, 0 outside, with a one pixel soft edge
float inside(vec2 q) {
  vec2 d = min(q, uLogicalSize - q);
  return clamp(min(d.x, d.y) + 0.5, 0.0, 1.0);
}

vec4 pageAt(vec2 q) {
  // no GLES y-flip: since Flutter 3.44 the engine hands live filter input
  // over the right way up on every backend (verified on Metal and GLES)
  return texture(uPage, q / uLogicalSize);
}

vec4 frontAt(vec2 q) {
  return pageAt(q);
}

// the back of the sheet: paper, with the front's ink faintly showing
// through. sampling the same page point mirrors it naturally
vec4 backAt(vec2 q) {
  vec4 ink = pageAt(q);
  vec3 seen = ink.a > 0.0 ? ink.rgb / ink.a : vec3(1.0);
  float darkness = 1.0 - dot(seen, vec3(0.299, 0.587, 0.114));
  vec3 paper = uBackColor.rgb * (1.0 - uInk * darkness);
  return vec4(paper, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy * (uLogicalSize / uSize);
  float r = max(uRadius, 0.0001);
  // distance from the fold line towards the lifted edge
  float e = dot(p - uOrigin, uDir);
  vec4 color = vec4(0.0);

  if (e > r) {
    // past the cylinder: the next page shows here, shaded near the curl
    float falloff = exp(-(e - r) / (r * 0.9 + 10.0));
    color = vec4(0.0, 0.0, 0.0, uShadow * 0.55 * falloff);
  } else if (e >= 0.0) {
    // on the cylinder: the front curving up (angle a), or the back coming
    // over the top (pi - a), which is nearer the viewer
    float a = asin(clamp(e / r, 0.0, 1.0));
    float arcFront = a * r;
    float arcBack = (PI - a) * r;
    vec2 qFront = p + uDir * (arcFront - e);
    vec2 qBack = p + uDir * (arcBack - e);
    float inFront = inside(qFront);
    float inBack = inside(qBack);

    // the front darkens as it turns away from the light
    vec4 front = frontAt(qFront);
    front.rgb *= mix(1.0, 0.62, sin(a));
    // the back is lit on top of the roll and darker towards the fold
    vec4 back = backAt(qBack);
    back.rgb *= mix(0.78, 1.04, sin(a));

    vec4 shade = vec4(0.0, 0.0, 0.0, uShadow * 0.55);
    color = mix(shade, front, inFront);
    color = mix(color, back, inBack);
  } else {
    // flat: the page itself, unless part of the turned-over sheet lies on
    // top of it here
    float arcFlipped = PI * r - e;
    vec2 qFlipped = p + uDir * (arcFlipped - e);
    float inFlipped = inside(qFlipped);

    vec4 front = frontAt(p) * inside(p);
    // the folded sheet casts a soft shadow onto the page just past its edge
    float edge = min(min(qFlipped.x, uLogicalSize.x - qFlipped.x),
                     min(qFlipped.y, uLogicalSize.y - qFlipped.y));
    float castShadow = inFlipped < 1.0
        ? uShadow * 0.35 * exp(-max(-edge, 0.0) / 14.0) * step(0.0, uRadius - 0.001)
        : 0.0;
    front.rgb *= 1.0 - castShadow;

    vec4 back = backAt(qFlipped);
    back.rgb *= 0.97;
    color = mix(front, back, inFlipped);
  }

  fragColor = color;
}
